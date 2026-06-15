-- =====================================================================
-- PPN CONSOLIDATED DATABASE CATCH-UP & FIX PATCH
-- =====================================================================
-- This script catches your database up by adding missing columns, 
-- creating missing tables (notifications, campaign_shares), recreating 
-- triggers, and fixing the RLS profile recursion.
-- Run this in your Supabase SQL Editor.
-- =====================================================================

-- 1. ADD MISSING COLUMNS
-- Companies Subscription columns
ALTER TABLE public.companies 
  ADD COLUMN IF NOT EXISTS subscription_tier TEXT NOT NULL DEFAULT 'basic' CHECK (subscription_tier IN ('basic', 'growth', 'enterprise')),
  ADD COLUMN IF NOT EXISTS subscription_status TEXT NOT NULL DEFAULT 'trialing' CHECK (subscription_status IN ('active', 'trialing', 'past_due', 'suspended')),
  ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMPTZ DEFAULT (now() + interval '14 days');

-- Profiles FCM token column
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Campaigns Analytics columns
ALTER TABLE public.campaigns
  ADD COLUMN IF NOT EXISTS share_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS lead_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS conversion_count INTEGER DEFAULT 0;

-- Leads Campaign association
ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS campaign_id UUID REFERENCES public.campaigns(id) ON DELETE SET NULL;


-- 2. CREATE MISSING TABLES
-- A. Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL,
  read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- B. Campaign Shares Table
CREATE TABLE IF NOT EXISTS public.campaign_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID REFERENCES public.campaigns(id) ON DELETE CASCADE NOT NULL,
  platform TEXT NOT NULL,
  shared_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.campaign_shares ENABLE ROW LEVEL SECURITY;


-- 3. INDEXES FOR NEW TABLES
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_company ON public.notifications(company_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON public.notifications(read);


-- 4. HELPER FUNCTIONS FOR SECURITY (WITH RECURSION FIX)
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

ALTER FUNCTION public.get_my_role() OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.get_my_company()
RETURNS UUID AS $$
  SELECT company_id FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

ALTER FUNCTION public.get_my_company() OWNER TO postgres;


-- 5. RLS POLICIES FOR NEW TABLES & UPDATED TABLES
-- Notifications policies
DROP POLICY IF EXISTS notifications_select ON public.notifications;
CREATE POLICY notifications_select ON public.notifications
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() 
    OR (public.get_my_role() = 'admin' AND company_id = public.get_my_company())
  );

DROP POLICY IF EXISTS notifications_update ON public.notifications;
CREATE POLICY notifications_update ON public.notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS notifications_delete ON public.notifications;
CREATE POLICY notifications_delete ON public.notifications
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Campaign shares policies
DROP POLICY IF EXISTS campaign_shares_policy ON public.campaign_shares;
CREATE POLICY campaign_shares_policy ON public.campaign_shares
  FOR ALL TO authenticated
  USING (
    campaign_id IN (
      SELECT id FROM public.campaigns WHERE company_id = (
        SELECT company_id FROM public.profiles WHERE id = auth.uid()
      )
    )
  )
  WITH CHECK (
    campaign_id IN (
      SELECT id FROM public.campaigns WHERE company_id = (
        SELECT company_id FROM public.profiles WHERE id = auth.uid()
      )
    )
  );

-- Allow public select on companies (so non-logged-in users can load companies on signup)
DROP POLICY IF EXISTS companies_public_select ON public.companies;
CREATE POLICY companies_public_select ON public.companies
  FOR SELECT USING (true);

-- Drop existing policies on public.profiles to rebuild them without duplicates
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN 
    SELECT policyname 
    FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'profiles'
  LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(pol.policyname) || ' ON public.profiles';
  END LOOP;
END
$$;

-- Create correct SELECT policy on profiles (recursion-free)
CREATE POLICY profiles_select ON public.profiles
  FOR SELECT TO authenticated
  USING (
    id = auth.uid()
    OR company_id = public.get_my_company()
    OR public.get_my_role() = 'platform_admin'
  );

-- Create correct UPDATE policy on profiles
CREATE POLICY profiles_update ON public.profiles
  FOR UPDATE TO authenticated
  USING (
    id = auth.uid()
    OR (public.get_my_role() = 'admin' AND company_id = public.get_my_company())
    OR public.get_my_role() = 'platform_admin'
  );

-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;


-- 6. DEFINITIVE handle_new_user() TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_company_id UUID;
  v_company_name TEXT;
  v_subscription_tier TEXT;
BEGIN
  -- Check if they want to create a new company
  v_company_name := new.raw_user_meta_data->>'create_company_name';
  v_subscription_tier := COALESCE(new.raw_user_meta_data->>'create_subscription_tier', 'basic');
  
  IF v_company_name IS NOT NULL AND v_company_name <> '' THEN
    -- Create the new company and get its ID (defaulting to 14 days trialing selected plan)
    INSERT INTO public.companies (name, subscription_tier, subscription_status, subscription_expires_at)
    VALUES (v_company_name, v_subscription_tier, 'trialing', now() + interval '14 days')
    RETURNING id INTO v_company_id;
  ELSIF (new.raw_user_meta_data->>'company_id') IS NOT NULL AND (new.raw_user_meta_data->>'company_id') <> '' THEN
    -- Use the provided company ID
    v_company_id := (new.raw_user_meta_data->>'company_id')::UUID;
  ELSE
    -- Fallback to the first company (default)
    SELECT id INTO v_company_id FROM public.companies ORDER BY created_at ASC LIMIT 1;
  END IF;

  -- Insert profile
  INSERT INTO public.profiles (id, company_id, full_name, email, phone, role, status)
  VALUES (
    new.id,
    v_company_id,
    COALESCE(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    new.phone,
    COALESCE(new.raw_user_meta_data->>'role', 'buyer'),
    CASE 
      WHEN COALESCE(new.raw_user_meta_data->>'role', 'buyer') = 'admin' THEN 'approved'
      WHEN COALESCE(new.raw_user_meta_data->>'role', 'buyer') = 'partner' THEN 'pending'
      WHEN COALESCE(new.raw_user_meta_data->>'role', 'buyer') = 'platform_admin' THEN 'approved'
      ELSE 'approved'
    END
  );

  -- Auto-confirm the email of the user on the database level (failsafe)
  UPDATE auth.users 
  SET email_confirmed_at = COALESCE(email_confirmed_at, now()),
      last_sign_in_at = COALESCE(last_sign_in_at, now())
  WHERE id = new.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- 7. NOTIFICATION TRIGGER FUNCTIONS & TRIGGERS
-- A. Partner Signup
CREATE OR REPLACE FUNCTION public.notify_on_partner_signup()
RETURNS TRIGGER AS $$
DECLARE
  v_admin_id UUID;
  v_title TEXT := 'New Partner Signup';
  v_body TEXT;
BEGIN
  v_body := COALESCE(NEW.full_name, 'A new partner') || ' has signed up and is awaiting approval.';
  
  FOR v_admin_id IN
    SELECT id FROM public.profiles 
    WHERE company_id = NEW.company_id AND role = 'admin' AND status = 'approved'
  LOOP
    INSERT INTO public.notifications (company_id, user_id, title, body, type, read)
    VALUES (NEW.company_id, v_admin_id, v_title, v_body, 'signup', false);
  END LOOP;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_notify_on_partner_signup ON public.profiles;
CREATE TRIGGER trigger_notify_on_partner_signup
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  WHEN (NEW.role = 'partner' AND NEW.status = 'pending')
  EXECUTE FUNCTION public.notify_on_partner_signup();

-- B. Partner Approved
CREATE OR REPLACE FUNCTION public.notify_on_partner_approved()
RETURNS TRIGGER AS $$
DECLARE
  v_title TEXT := 'Partner Approved';
  v_body TEXT := 'Your partner account has been approved! You can now start referring leads.';
BEGIN
  INSERT INTO public.notifications (company_id, user_id, title, body, type, read)
  VALUES (NEW.company_id, NEW.id, v_title, v_body, 'partner_approved', false);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_notify_on_partner_approved ON public.profiles;
CREATE TRIGGER trigger_notify_on_partner_approved
  AFTER UPDATE ON public.profiles
  FOR EACH ROW
  WHEN (OLD.status = 'pending' AND NEW.status = 'approved' AND NEW.role = 'partner')
  EXECUTE FUNCTION public.notify_on_partner_approved();

-- C. Lead Created
CREATE OR REPLACE FUNCTION public.notify_on_lead_created()
RETURNS TRIGGER AS $$
DECLARE
  v_admin_id UUID;
  v_property_title TEXT := 'property';
  v_title_admin TEXT := 'New Lead Received';
  v_body_admin TEXT;
  v_title_partner TEXT := 'Referral Lead Registered';
  v_body_partner TEXT;
BEGIN
  IF NEW.property_id IS NOT NULL THEN
    SELECT title INTO v_property_title FROM public.properties WHERE id = NEW.property_id;
  END IF;

  v_body_admin := 'New lead ' || NEW.buyer_name || ' for property ' || v_property_title || ' has been submitted.';
  v_body_partner := 'Your referral ' || NEW.buyer_name || ' has been registered for property ' || v_property_title || '.';

  -- Notify Admins
  FOR v_admin_id IN
    SELECT id FROM public.profiles 
    WHERE company_id = NEW.company_id AND role = 'admin' AND status = 'approved'
  LOOP
    INSERT INTO public.notifications (company_id, user_id, title, body, type, read)
    VALUES (NEW.company_id, v_admin_id, v_title_admin, v_body_admin, 'lead_created', false);
  END LOOP;

  -- Notify Partner
  IF NEW.partner_id IS NOT NULL THEN
    INSERT INTO public.notifications (company_id, user_id, title, body, type, read)
    VALUES (NEW.company_id, NEW.partner_id, v_title_partner, v_body_partner, 'lead_created', false);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_notify_on_lead_created ON public.leads;
CREATE TRIGGER trigger_notify_on_lead_created
  AFTER INSERT ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_lead_created();

-- E. Lead Stage Changed
CREATE OR REPLACE FUNCTION public.notify_on_lead_stage_changed()
RETURNS TRIGGER AS $$
DECLARE
  v_property_title TEXT := 'property';
  v_title TEXT := 'Lead Stage Updated';
  v_body TEXT;
BEGIN
  IF NEW.property_id IS NOT NULL THEN
    SELECT title INTO v_property_title FROM public.properties WHERE id = NEW.property_id;
  END IF;

  v_body := 'Your referred lead ' || NEW.buyer_name || ' has been moved to stage ' || NEW.stage || ' for property ' || v_property_title || '.';

  IF NEW.partner_id IS NOT NULL THEN
    INSERT INTO public.notifications (company_id, user_id, title, body, type, read)
    VALUES (NEW.company_id, NEW.partner_id, v_title, v_body, 'lead_stage_changed', false);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_notify_on_lead_stage_changed ON public.leads;
CREATE TRIGGER trigger_notify_on_lead_stage_changed
  AFTER UPDATE ON public.leads
  FOR EACH ROW
  WHEN (OLD.stage IS DISTINCT FROM NEW.stage)
  EXECUTE FUNCTION public.notify_on_lead_stage_changed();

-- F. Commission Approved
CREATE OR REPLACE FUNCTION public.notify_on_commission_approved()
RETURNS TRIGGER AS $$
DECLARE
  v_property_title TEXT := 'property';
  v_title TEXT := 'Commission Approved';
  v_body TEXT;
BEGIN
  IF NEW.property_id IS NOT NULL THEN
    SELECT title INTO v_property_title FROM public.properties WHERE id = NEW.property_id;
  END IF;

  v_body := 'Your commission of $' || NEW.commission_amount || ' for property ' || v_property_title || ' has been approved!';

  IF NEW.partner_id IS NOT NULL THEN
    INSERT INTO public.notifications (company_id, user_id, title, body, type, read)
    VALUES (NEW.company_id, NEW.partner_id, v_title, v_body, 'commission_approved', false);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_notify_on_commission_approved ON public.commissions;
CREATE TRIGGER trigger_notify_on_commission_approved
  AFTER UPDATE ON public.commissions
  FOR EACH ROW
  WHEN (OLD.status = 'pending' AND NEW.status = 'approved')
  EXECUTE FUNCTION public.notify_on_commission_approved();

-- G. Withdrawal Resolved
CREATE OR REPLACE FUNCTION public.notify_on_withdrawal_resolved()
RETURNS TRIGGER AS $$
DECLARE
  v_title TEXT;
  v_body TEXT;
BEGIN
  IF NEW.status = 'completed' THEN
    v_title := 'Withdrawal Approved';
    v_body := 'Your withdrawal request of $' || NEW.amount || ' has been approved and processed.';
  ELSE
    v_title := 'Withdrawal Rejected';
    v_body := 'Your withdrawal request of $' || NEW.amount || ' has been rejected.';
  END IF;

  IF NEW.partner_id IS NOT NULL THEN
    INSERT INTO public.notifications (company_id, user_id, title, body, type, read)
    VALUES (NEW.company_id, NEW.partner_id, v_title, v_body, 'withdrawal_resolved', false);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_notify_on_withdrawal_resolved ON public.transactions;
CREATE TRIGGER trigger_notify_on_withdrawal_resolved
  AFTER UPDATE ON public.transactions
  FOR EACH ROW
  WHEN (NEW.type = 'withdrawal' AND OLD.status = 'pending' AND NEW.status IN ('completed', 'rejected'))
  EXECUTE FUNCTION public.notify_on_withdrawal_resolved();


-- 8. CAMPAIGN ATTRIBUTION TRIGGERS
-- A. Campaign Share Inserted
CREATE OR REPLACE FUNCTION public.handle_campaign_share_inserted()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.campaigns
  SET share_count = COALESCE(share_count, 0) + 1
  WHERE id = NEW.campaign_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_campaign_share_inserted ON public.campaign_shares;
CREATE TRIGGER trg_campaign_share_inserted
  AFTER INSERT ON public.campaign_shares
  FOR EACH ROW EXECUTE FUNCTION public.handle_campaign_share_inserted();

-- B. Lead Campaign Attribution
CREATE OR REPLACE FUNCTION public.handle_lead_campaign_attribution()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.campaign_id IS NOT NULL THEN
      UPDATE public.campaigns
      SET lead_count = COALESCE(lead_count, 0) + 1
      WHERE id = NEW.campaign_id;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF (OLD.campaign_id IS DISTINCT FROM NEW.campaign_id) THEN
      IF OLD.campaign_id IS NOT NULL THEN
        UPDATE public.campaigns
        SET lead_count = GREATEST(0, COALESCE(lead_count, 0) - 1)
        WHERE id = OLD.campaign_id;
      END IF;
      IF NEW.campaign_id IS NOT NULL THEN
        UPDATE public.campaigns
        SET lead_count = COALESCE(lead_count, 0) + 1
        WHERE id = NEW.campaign_id;
      END IF;
    END IF;

    IF NEW.stage = 'closed' AND OLD.stage != 'closed' AND NEW.campaign_id IS NOT NULL THEN
      UPDATE public.campaigns
      SET conversion_count = COALESCE(conversion_count, 0) + 1
      WHERE id = NEW.campaign_id;
    ELSIF OLD.stage = 'closed' AND NEW.stage != 'closed' AND NEW.campaign_id IS NOT NULL THEN
      UPDATE public.campaigns
      SET conversion_count = GREATEST(0, COALESCE(conversion_count, 0) - 1)
      WHERE id = NEW.campaign_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_lead_campaign_attribution ON public.leads;
CREATE TRIGGER trg_lead_campaign_attribution
  AFTER INSERT OR UPDATE ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.handle_lead_campaign_attribution();


-- 9. LEAD FINGERPRINT TRIGGER
CREATE OR REPLACE FUNCTION public.generate_lead_fingerprint()
RETURNS TRIGGER AS $$
BEGIN
  IF (NEW.buyer_phone IS NOT NULL AND TRIM(NEW.buyer_phone) != '') OR (NEW.buyer_email IS NOT NULL AND TRIM(NEW.buyer_email) != '') THEN
    NEW.lead_fingerprint := COALESCE(LOWER(TRIM(NEW.buyer_phone)), '') || ':' || COALESCE(LOWER(TRIM(NEW.buyer_email)), '');
  ELSE
    NEW.lead_fingerprint := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_lead_fingerprint ON public.leads;
CREATE TRIGGER trg_lead_fingerprint
  BEFORE INSERT OR UPDATE ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.generate_lead_fingerprint();

CREATE UNIQUE INDEX IF NOT EXISTS idx_leads_fingerprint_company
  ON public.leads (lead_fingerprint, company_id)
  WHERE lead_fingerprint IS NOT NULL;
