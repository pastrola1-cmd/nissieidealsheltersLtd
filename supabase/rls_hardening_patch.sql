-- =====================================================================
-- PPN LOOP 14: DATABASE RLS SECURITY HARDENING PATCH
-- Run this script in the Supabase SQL Editor to update policies
-- =====================================================================

-- 1. COMPANIES POLICIES
DROP POLICY IF EXISTS companies_write ON public.companies;
CREATE POLICY companies_write ON public.companies
  FOR ALL TO authenticated
  USING (
    (public.get_my_role() = 'admin' AND id = public.get_my_company())
    OR public.get_my_role() = 'platform_admin'
  );

-- 2. PROFILES POLICIES
DROP POLICY IF EXISTS profiles_update ON public.profiles;
CREATE POLICY profiles_update ON public.profiles
  FOR UPDATE TO authenticated
  USING (
    id = auth.uid()
    OR (public.get_my_role() = 'admin' AND company_id = public.get_my_company())
    OR public.get_my_role() = 'platform_admin'
  );

-- 3. LEADS POLICIES
DROP POLICY IF EXISTS leads_write ON public.leads;
DROP POLICY IF EXISTS leads_insert ON public.leads;
DROP POLICY IF EXISTS leads_update ON public.leads;
DROP POLICY IF EXISTS leads_delete ON public.leads;

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

-- 4. INSPECTIONS POLICIES
DROP POLICY IF EXISTS inspections_write ON public.inspections;
DROP POLICY IF EXISTS inspections_insert ON public.inspections;
DROP POLICY IF EXISTS inspections_update ON public.inspections;
DROP POLICY IF EXISTS inspections_delete ON public.inspections;

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

-- 5. TRANSACTIONS POLICIES
DROP POLICY IF EXISTS transactions_write ON public.transactions;
DROP POLICY IF EXISTS transactions_insert ON public.transactions;
DROP POLICY IF EXISTS transactions_update ON public.transactions;
DROP POLICY IF EXISTS transactions_delete ON public.transactions;

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
