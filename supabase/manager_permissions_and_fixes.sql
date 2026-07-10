-- =====================================================================
-- NISSIE IDEAL SHELTERS — SYSTEM BUGS & PERMISSIONS FIX PATCH
-- Run this script in your Supabase SQL Editor to apply fixes.
-- =====================================================================

-- 1. ALTER PROPERTIES TABLE
-- Add the missing target_audience column to resolve property edit/save errors.
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS target_audience TEXT;

-- 2. CREATE PROFILES DELETE POLICY
-- Allow admins and platform_admins to delete staff/profiles.
DROP POLICY IF EXISTS profiles_delete ON public.profiles;
CREATE POLICY profiles_delete ON public.profiles
  FOR DELETE TO authenticated
  USING (
    (public.get_my_role() = 'admin' AND company_id = public.get_my_company())
    OR public.get_my_role() = 'platform_admin'
  );

-- 3. UPDATE LEADS POLICIES FOR MANAGERS & MARKETERS
DROP POLICY IF EXISTS leads_insert ON public.leads;
CREATE POLICY leads_insert ON public.leads
  FOR INSERT TO authenticated
  WITH CHECK (
    (public.get_my_role() = 'partner' AND partner_id = auth.uid())
    OR (public.get_my_role() = 'buyer' AND buyer_id = auth.uid())
    OR (public.get_my_role() IN ('admin', 'manager', 'platform_admin') AND company_id = public.get_my_company())
  );

DROP POLICY IF EXISTS leads_update ON public.leads;
CREATE POLICY leads_update ON public.leads
  FOR UPDATE TO authenticated
  USING (
    (public.get_my_role() IN ('admin', 'manager', 'platform_admin') AND company_id = public.get_my_company())
    OR (public.get_my_role() = 'marketer' AND assigned_agent_id = auth.uid())
  );

DROP POLICY IF EXISTS leads_delete ON public.leads;
CREATE POLICY leads_delete ON public.leads
  FOR DELETE TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'manager', 'platform_admin') AND company_id = public.get_my_company()
  );

-- 4. UPDATE PROPERTIES WRITE POLICY FOR MANAGERS
DROP POLICY IF EXISTS properties_write ON public.properties;
CREATE POLICY properties_write ON public.properties
  FOR ALL TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'manager', 'platform_admin') AND company_id = public.get_my_company()
  );

-- 5. UPDATE INSPECTIONS POLICIES FOR MANAGERS
DROP POLICY IF EXISTS inspections_insert ON public.inspections;
CREATE POLICY inspections_insert ON public.inspections
  FOR INSERT TO authenticated
  WITH CHECK (
    (public.get_my_role() IN ('admin', 'manager', 'platform_admin') AND company_id = public.get_my_company())
    OR (public.get_my_role() = 'partner' AND partner_id = auth.uid())
    OR (public.get_my_role() = 'buyer' AND buyer_id = auth.uid())
  );

DROP POLICY IF EXISTS inspections_update ON public.inspections;
CREATE POLICY inspections_update ON public.inspections
  FOR UPDATE TO authenticated
  USING (
    (public.get_my_role() IN ('admin', 'manager', 'platform_admin') AND company_id = public.get_my_company())
    OR (public.get_my_role() = 'buyer' AND buyer_id = auth.uid())
  );

DROP POLICY IF EXISTS inspections_delete ON public.inspections;
CREATE POLICY inspections_delete ON public.inspections
  FOR DELETE TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'manager', 'platform_admin') AND company_id = public.get_my_company()
  );

-- 6. UPDATE TRANSACTIONS POLICIES FOR MANAGERS
DROP POLICY IF EXISTS transactions_insert ON public.transactions;
CREATE POLICY transactions_insert ON public.transactions
  FOR INSERT TO authenticated
  WITH CHECK (
    (public.get_my_role() IN ('admin', 'manager', 'platform_admin') AND company_id = public.get_my_company())
    OR (partner_id = auth.uid() AND type = 'withdrawal' AND status = 'pending')
  );

DROP POLICY IF EXISTS transactions_update ON public.transactions;
CREATE POLICY transactions_update ON public.transactions
  FOR UPDATE TO authenticated
  USING (
    (public.get_my_role() IN ('admin', 'manager', 'platform_admin') AND company_id = public.get_my_company())
  );

DROP POLICY IF EXISTS transactions_delete ON public.transactions;
CREATE POLICY transactions_delete ON public.transactions
  FOR DELETE TO authenticated
  USING (
    (public.get_my_role() IN ('admin', 'manager', 'platform_admin') AND company_id = public.get_my_company())
  );

-- 7. SETUP PUBLIC STORAGE BUCKET 'company-assets' AND RLS POLICIES
-- Ensure bucket exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('company-assets', 'company-assets', true)
ON CONFLICT (id) DO NOTHING;

-- RLS policies for storage objects in company-assets bucket
DROP POLICY IF EXISTS "Allow public select on company-assets" ON storage.objects;
CREATE POLICY "Allow public select on company-assets" ON storage.objects
  FOR SELECT USING (bucket_id = 'company-assets');

DROP POLICY IF EXISTS "Allow authenticated insert on company-assets" ON storage.objects;
CREATE POLICY "Allow authenticated insert on company-assets" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'company-assets');

DROP POLICY IF EXISTS "Allow authenticated update on company-assets" ON storage.objects;
CREATE POLICY "Allow authenticated update on company-assets" ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'company-assets');

DROP POLICY IF EXISTS "Allow authenticated delete on company-assets" ON storage.objects;
CREATE POLICY "Allow authenticated delete on company-assets" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'company-assets');
