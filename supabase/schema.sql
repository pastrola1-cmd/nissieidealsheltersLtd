-- =====================================================================
-- PROPERTY PARTNER NETWORK (PPN) — DATABASE SCHEMA & MULTI-TENANT CONFIG
-- =====================================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- 1. COMPANIES (Tenants)
-- ==========================================
CREATE TABLE public.companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  logo_url TEXT,
  email TEXT,
  phone TEXT,
  address TEXT,
  is_hidden BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- 2. PROFILES (Extends auth.users)
-- ==========================================
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  company_id UUID REFERENCES public.companies(id) ON DELETE SET NULL,
  role TEXT NOT NULL CHECK (role IN ('admin','partner','buyer','platform_admin')),
  full_name TEXT,
  phone TEXT,
  email TEXT,
  avatar_url TEXT,
  referral_code TEXT UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','suspended')),
  bank_name TEXT,
  account_number TEXT,
  account_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- 3. PROPERTIES (Inventory)
-- ==========================================
CREATE TABLE public.properties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  location TEXT,
  price NUMERIC NOT NULL CHECK (price >= 0),
  status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available','reserved','sold')),
  images TEXT[] DEFAULT '{}',
  video_url TEXT,
  assigned_partner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  commission_type TEXT NOT NULL DEFAULT 'percentage' CHECK (commission_type IN ('percentage', 'flat_fee')),
  commission_value NUMERIC NOT NULL DEFAULT 5.0 CHECK (commission_value >= 0),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- 4. LEADS (Sales Pipeline)
-- ==========================================
CREATE TABLE public.leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  property_id UUID REFERENCES public.properties(id) ON DELETE SET NULL,
  partner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  buyer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  buyer_name TEXT NOT NULL,
  buyer_phone TEXT NOT NULL,
  buyer_email TEXT,
  source_channel TEXT NOT NULL DEFAULT 'whatsapp',
  stage TEXT NOT NULL DEFAULT 'new' CHECK (stage IN ('new','contacted','inspection_booked','negotiation','closed','lost')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- 5. COMMISSIONS (Earnings Calculation)
-- ==========================================
CREATE TABLE public.commissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  lead_id UUID REFERENCES public.leads(id) ON DELETE SET NULL,
  partner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  property_id UUID REFERENCES public.properties(id) ON DELETE SET NULL,
  sale_price NUMERIC NOT NULL CHECK (sale_price >= 0),
  commission_rate NUMERIC CHECK (commission_rate >= 0),
  commission_amount NUMERIC NOT NULL CHECK (commission_amount >= 0),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','paid','disputed')),
  approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- 6. INSPECTIONS (Property Viewings)
-- ==========================================
CREATE TABLE public.inspections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  property_id UUID REFERENCES public.properties(id) ON DELETE SET NULL,
  lead_id UUID REFERENCES public.leads(id) ON DELETE SET NULL,
  buyer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  partner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  scheduled_date DATE NOT NULL,
  scheduled_time TIME NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','confirmed','completed','cancelled','no_show')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- 7. TRANSACTIONS (Wallet & Payments Log)
-- ==========================================
CREATE TABLE public.transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  partner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  commission_id UUID REFERENCES public.commissions(id) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (type IN ('credit','debit','withdrawal')),
  amount NUMERIC NOT NULL CHECK (amount >= 0),
  balance_after NUMERIC,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- 8. REFERRAL CLICKS (Analytics & Attribution)
-- ==========================================
CREATE TABLE public.referral_clicks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_code TEXT NOT NULL,
  property_id UUID REFERENCES public.properties(id) ON DELETE CASCADE,
  partner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  ip_address TEXT,
  user_agent TEXT,
  clicked_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- INDEXES FOR PERFORMANCE
-- ==========================================
CREATE INDEX idx_profiles_company ON public.profiles(company_id);
CREATE INDEX idx_profiles_referral_code ON public.profiles(referral_code);
CREATE INDEX idx_properties_company ON public.properties(company_id);
CREATE INDEX idx_properties_status ON public.properties(status);
CREATE INDEX idx_leads_company ON public.leads(company_id);
CREATE INDEX idx_leads_partner ON public.leads(partner_id);
CREATE INDEX idx_leads_stage ON public.leads(stage);
CREATE INDEX idx_commissions_company ON public.commissions(company_id);
CREATE INDEX idx_commissions_partner ON public.commissions(partner_id);
CREATE INDEX idx_commissions_status ON public.commissions(status);
CREATE INDEX idx_inspections_company ON public.inspections(company_id);
CREATE INDEX idx_inspections_buyer ON public.inspections(buyer_id);
CREATE INDEX idx_inspections_date ON public.inspections(scheduled_date);
CREATE INDEX idx_transactions_company ON public.transactions(company_id);
CREATE INDEX idx_transactions_partner ON public.transactions(partner_id);
CREATE INDEX idx_referral_clicks_code ON public.referral_clicks(referral_code);

-- ==========================================
-- HELPER FUNCTIONS FOR SECURITY (RLS)
-- ==========================================
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.get_my_company()
RETURNS UUID AS $$
  SELECT company_id FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Calculates the running wallet balance for a partner
CREATE OR REPLACE FUNCTION public.get_partner_balance(p_partner_id UUID)
RETURNS NUMERIC AS $$
  SELECT COALESCE(SUM(
    CASE WHEN type = 'credit' THEN amount
         WHEN type = 'debit' THEN -amount
         WHEN type = 'withdrawal' AND status != 'rejected' THEN -amount
    END
  ), 0)
  FROM public.transactions
  WHERE partner_id = p_partner_id;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ==========================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==========================================

-- Enable RLS
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_clicks ENABLE ROW LEVEL SECURITY;

-- Companies Policies
CREATE POLICY companies_select ON public.companies
  FOR SELECT TO authenticated
  USING (id = public.get_my_company() OR public.get_my_role() = 'platform_admin');

CREATE POLICY companies_public_select ON public.companies
  FOR SELECT
  USING (true);

CREATE POLICY companies_write ON public.companies
  FOR ALL TO authenticated
  USING (
    (public.get_my_role() = 'admin' AND id = public.get_my_company())
    OR public.get_my_role() = 'platform_admin'
  );

-- Profiles Policies
CREATE POLICY profiles_select ON public.profiles
  FOR SELECT TO authenticated
  USING (company_id = public.get_my_company() OR public.get_my_role() = 'platform_admin');

CREATE POLICY profiles_update ON public.profiles
  FOR UPDATE TO authenticated
  USING (
    id = auth.uid()
    OR (public.get_my_role() = 'admin' AND company_id = public.get_my_company())
    OR public.get_my_role() = 'platform_admin'
  );

-- Properties Policies
CREATE POLICY properties_select ON public.properties
  FOR SELECT
  USING (true); -- Anyone (even anon buyer clicking a referral link) can view properties

CREATE POLICY properties_write ON public.properties
  FOR ALL TO authenticated
  USING (public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company());

-- Leads Policies
CREATE POLICY leads_select ON public.leads
  FOR SELECT TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company()
    OR partner_id = auth.uid()
    OR buyer_id = auth.uid()
  );

CREATE POLICY leads_insert ON public.leads
  FOR INSERT TO authenticated
  WITH CHECK (
    (public.get_my_role() = 'partner' AND partner_id = auth.uid())
    OR (public.get_my_role() = 'buyer' AND buyer_id = auth.uid())
    OR (public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company())
  );

CREATE POLICY leads_update ON public.leads
  FOR UPDATE TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company()
  );

CREATE POLICY leads_delete ON public.leads
  FOR DELETE TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company()
  );

-- Commissions Policies
CREATE POLICY commissions_select ON public.commissions
  FOR SELECT TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company()
    OR partner_id = auth.uid()
  );

CREATE POLICY commissions_write ON public.commissions
  FOR ALL TO authenticated
  USING (public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company());

-- Inspections Policies
CREATE POLICY inspections_select ON public.inspections
  FOR SELECT TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company()
    OR partner_id = auth.uid()
    OR buyer_id = auth.uid()
  );

CREATE POLICY inspections_insert ON public.inspections
  FOR INSERT TO authenticated
  WITH CHECK (
    (public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company())
    OR (public.get_my_role() = 'partner' AND partner_id = auth.uid())
    OR (public.get_my_role() = 'buyer' AND buyer_id = auth.uid())
  );

CREATE POLICY inspections_update ON public.inspections
  FOR UPDATE TO authenticated
  USING (
    (public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company())
    OR (public.get_my_role() = 'buyer' AND buyer_id = auth.uid())
  );

CREATE POLICY inspections_delete ON public.inspections
  FOR DELETE TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company()
  );

-- Transactions Policies
CREATE POLICY transactions_select ON public.transactions
  FOR SELECT TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company()
    OR partner_id = auth.uid()
  );

CREATE POLICY transactions_insert ON public.transactions
  FOR INSERT TO authenticated
  WITH CHECK (
    (public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company())
    OR (partner_id = auth.uid() AND type = 'withdrawal' AND status = 'pending')
  );

CREATE POLICY transactions_update ON public.transactions
  FOR UPDATE TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company()
  );

CREATE POLICY transactions_delete ON public.transactions
  FOR DELETE TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company()
  );

-- Referral Clicks Policies
CREATE POLICY referral_clicks_select ON public.referral_clicks
  FOR SELECT TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin')
    OR partner_id = auth.uid()
  );

CREATE POLICY referral_clicks_insert ON public.referral_clicks
  FOR INSERT
  WITH CHECK (true); -- Anyone can log a link click

-- ==========================================
-- AUTH SIGNUP TRIGGER TO AUTO-CREATE PROFILES
-- ==========================================
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
    'approved'
  );

  -- Auto-confirm the email of the user on the database level (failsafe)
  UPDATE auth.users 
  SET email_confirmed_at = COALESCE(email_confirmed_at, now()),
      last_sign_in_at = COALESCE(last_sign_in_at, now())
  WHERE id = new.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger definition
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==========================================
-- DEFAULT SEED DATA
-- ==========================================
-- Insert a default company for initial testing and configuration
INSERT INTO public.companies (id, name, email, phone, address)
VALUES (
  'd3b07384-d113-4ec6-a5d7-ecf9e01103e6',
  'Scalewealth Estate',
  'info@scalewealth.com',
  '+2348000000000',
  'Abuja, Nigeria'
) ON CONFLICT DO NOTHING;

-- =====================================================================
-- PPN LOOP 12: PUSH NOTIFICATIONS & IN-APP ALERTS - DATABASE SCHEMA
-- =====================================================================

-- Add fcm_token column to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Create notifications table
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

-- Enable RLS and define policies
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY notifications_select ON public.notifications
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() 
    OR (public.get_my_role() = 'admin' AND company_id = public.get_my_company())
  );

CREATE POLICY notifications_update ON public.notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY notifications_delete ON public.notifications
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Create Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_company ON public.notifications(company_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON public.notifications(read);

-- Trigger functions for notification events

-- A. New partner signup trigger (Notifies Admin)
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

CREATE OR REPLACE TRIGGER trigger_notify_on_partner_signup
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  WHEN (NEW.role = 'partner' AND NEW.status = 'pending')
  EXECUTE FUNCTION public.notify_on_partner_signup();


-- B. Partner approved trigger (Notifies Partner)
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

CREATE OR REPLACE TRIGGER trigger_notify_on_partner_approved
  AFTER UPDATE ON public.profiles
  FOR EACH ROW
  WHEN (OLD.status = 'pending' AND NEW.status = 'approved' AND NEW.role = 'partner')
  EXECUTE FUNCTION public.notify_on_partner_approved();


-- C. Lead created trigger (Notifies Admin + Partner)
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

  -- Notify Partner (if lead is referred by a partner)
  IF NEW.partner_id IS NOT NULL THEN
    INSERT INTO public.notifications (company_id, user_id, title, body, type, read)
    VALUES (NEW.company_id, NEW.partner_id, v_title_partner, v_body_partner, 'lead_created', false);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER trigger_notify_on_lead_created
  AFTER INSERT ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_lead_created();


-- D. Inspection booked trigger (Notifies Admin + Partner)
CREATE OR REPLACE FUNCTION public.notify_on_inspection_booked()
RETURNS TRIGGER AS $$
DECLARE
  v_admin_id UUID;
  v_property_title TEXT := 'property';
  v_buyer_name TEXT := 'A buyer';
  v_title TEXT := 'New Inspection Scheduled';
  v_body TEXT;
BEGIN
  IF NEW.property_id IS NOT NULL THEN
    SELECT title INTO v_property_title FROM public.properties WHERE id = NEW.property_id;
  END IF;

  IF NEW.buyer_id IS NOT NULL THEN
    SELECT full_name INTO v_buyer_name FROM public.profiles WHERE id = NEW.buyer_id;
  END IF;

  IF (v_buyer_name IS NULL OR v_buyer_name = '' OR v_buyer_name = 'A buyer') AND NEW.lead_id IS NOT NULL THEN
    SELECT buyer_name INTO v_buyer_name FROM public.leads WHERE id = NEW.lead_id;
  END IF;

  v_body := 'An inspection for property ' || v_property_title || ' has been scheduled on ' || NEW.scheduled_date || ' at ' || NEW.scheduled_time || ' by ' || COALESCE(v_buyer_name, 'a buyer') || '.';

  -- Notify Admins
  FOR v_admin_id IN
    SELECT id FROM public.profiles 
    WHERE company_id = NEW.company_id AND role = 'admin' AND status = 'approved'
  LOOP
    INSERT INTO public.notifications (company_id, user_id, title, body, type, read)
    VALUES (NEW.company_id, v_admin_id, v_title, v_body, 'inspection_booked', false);
  END LOOP;

  -- Notify Partner (if lead/inspection has associated partner)
  IF NEW.partner_id IS NOT NULL THEN
    INSERT INTO public.notifications (company_id, user_id, title, body, type, read)
    VALUES (NEW.company_id, NEW.partner_id, v_title, v_body, 'inspection_booked', false);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER trigger_notify_on_inspection_booked
  AFTER INSERT ON public.inspections
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_inspection_booked();


-- E. Lead stage changed trigger (Notifies Partner)
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

CREATE OR REPLACE TRIGGER trigger_notify_on_lead_stage_changed
  AFTER UPDATE ON public.leads
  FOR EACH ROW
  WHEN (OLD.stage IS DISTINCT FROM NEW.stage)
  EXECUTE FUNCTION public.notify_on_lead_stage_changed();


-- F. Commission approved trigger (Notifies Partner)
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

CREATE OR REPLACE TRIGGER trigger_notify_on_commission_approved
  AFTER UPDATE ON public.commissions
  FOR EACH ROW
  WHEN (OLD.status = 'pending' AND NEW.status = 'approved')
  EXECUTE FUNCTION public.notify_on_commission_approved();


-- G. Withdrawal request resolved trigger (Notifies Partner)
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

CREATE OR REPLACE TRIGGER trigger_notify_on_withdrawal_resolved
  AFTER UPDATE ON public.transactions
  FOR EACH ROW
  WHEN (NEW.type = 'withdrawal' AND OLD.status = 'pending' AND NEW.status IN ('completed', 'rejected'))
  EXECUTE FUNCTION public.notify_on_withdrawal_resolved();

