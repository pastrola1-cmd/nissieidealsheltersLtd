-- =====================================================================
-- PPN LOOP 12: PUSH NOTIFICATIONS & IN-APP ALERTS - DATABASE SCHEMA
-- =====================================================================

-- 1. Add fcm_token column to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 2. Create notifications table
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

-- 3. Enable RLS and define policies
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

-- 4. Create Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_company ON public.notifications(company_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON public.notifications(read);

-- 5. Trigger functions for notification events

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
