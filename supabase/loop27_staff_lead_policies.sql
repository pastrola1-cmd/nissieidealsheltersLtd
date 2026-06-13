-- =============================================================================
-- LOOP 27: Staff Lead Access and RLS Policies Update
-- Allows Managers and Marketers to view, insert, and update leads.
-- =============================================================================

-- 1. DROP old leads policies to avoid conflicts
DROP POLICY IF EXISTS leads_select ON public.leads;
DROP POLICY IF EXISTS leads_insert ON public.leads;
DROP POLICY IF EXISTS leads_update ON public.leads;
DROP POLICY IF EXISTS leads_delete ON public.leads;
DROP POLICY IF EXISTS marketer_read_own_leads ON public.leads;
DROP POLICY IF EXISTS marketer_update_own_leads ON public.leads;

-- 2. CREATE updated SELECT policy
-- Admins, Platform Admins, and Managers can read all company leads.
-- Marketers can read leads assigned to them.
-- Partners can read leads referred by them.
-- Buyers can read their own leads.
CREATE POLICY leads_select ON public.leads
  FOR SELECT TO authenticated
  USING (
    (public.get_my_role() IN ('admin', 'platform_admin', 'manager') AND company_id = public.get_my_company())
    OR (public.get_my_role() = 'marketer' AND assigned_agent_id = auth.uid())
    OR (public.get_my_role() = 'partner' AND partner_id = auth.uid())
    OR (public.get_my_role() = 'buyer' AND buyer_id = auth.uid())
  );

-- 3. CREATE updated INSERT policy
-- Admins, Platform Admins, Managers, and Marketers can create leads for their company.
-- Partners can create leads referring buyers.
-- Buyers can create leads (e.g. from public registration/form).
CREATE POLICY leads_insert ON public.leads
  FOR INSERT TO authenticated
  WITH CHECK (
    (public.get_my_role() IN ('admin', 'platform_admin', 'manager', 'marketer') AND company_id = public.get_my_company())
    OR (public.get_my_role() = 'partner' AND partner_id = auth.uid())
    OR (public.get_my_role() = 'buyer' AND buyer_id = auth.uid())
  );

-- 4. CREATE updated UPDATE policy
-- Admins, Platform Admins, and Managers can update any company lead.
-- Marketers can update leads assigned to them.
CREATE POLICY leads_update ON public.leads
  FOR UPDATE TO authenticated
  USING (
    (public.get_my_role() IN ('admin', 'platform_admin', 'manager') AND company_id = public.get_my_company())
    OR (public.get_my_role() = 'marketer' AND assigned_agent_id = auth.uid())
  );

-- 5. CREATE updated DELETE policy
-- Admins, Platform Admins, and Managers can delete any company lead.
CREATE POLICY leads_delete ON public.leads
  FOR DELETE TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin', 'manager') AND company_id = public.get_my_company()
  );
