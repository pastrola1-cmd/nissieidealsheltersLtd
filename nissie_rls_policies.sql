-- =====================================================================
-- NISSIE IDEAL SHELTERS - SINGLE TENANT ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================================

-- Enable RLS on all key tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------
-- 1. ROLE-BASED ACCESS CONTROL (RBAC) HELPER FUNCTIONS
-- ---------------------------------------------------------------------

-- Helper function to get current user's role from public.profiles
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS text AS $$
DECLARE
  user_role text;
BEGIN
  SELECT role::text INTO user_role
  FROM public.profiles
  WHERE id = auth.uid();
  
  RETURN COALESCE(user_role, 'buyer');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Helper function to check if the current user is an Admin or Manager
CREATE OR REPLACE FUNCTION public.is_admin_or_manager()
RETURNS boolean AS $$
BEGIN
  RETURN public.get_current_user_role() IN ('admin', 'platform_admin', 'platformAdmin', 'manager');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ---------------------------------------------------------------------
-- 2. POLICIES FOR profiles TABLE
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.profiles;
CREATE POLICY "Enable read access for authenticated users" ON public.profiles
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.profiles;
CREATE POLICY "Enable insert for authenticated users" ON public.profiles
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Enable update for users or admins" ON public.profiles;
CREATE POLICY "Enable update for users or admins" ON public.profiles
  FOR UPDATE TO authenticated USING (
    auth.uid() = id OR public.is_admin_or_manager()
  );

-- ---------------------------------------------------------------------
-- 3. POLICIES FOR properties TABLE
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS "Enable public read access for properties" ON public.properties;
CREATE POLICY "Enable public read access for properties" ON public.properties
  FOR SELECT TO public USING (status = 'available' OR public.is_admin_or_manager());

DROP POLICY IF EXISTS "Enable write access for admins and managers" ON public.properties;
CREATE POLICY "Enable write access for admins and managers" ON public.properties
  FOR ALL TO authenticated USING (public.is_admin_or_manager());

-- ---------------------------------------------------------------------
-- 4. POLICIES FOR leads TABLE
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS "Enable read access for leads" ON public.leads;
CREATE POLICY "Enable read access for leads" ON public.leads
  FOR SELECT TO authenticated USING (
    public.is_admin_or_manager() OR 
    assigned_agent_id = auth.uid() OR 
    buyer_id = auth.uid() OR 
    partner_id = auth.uid()
  );

DROP POLICY IF EXISTS "Enable insert for leads" ON public.leads;
CREATE POLICY "Enable insert for leads" ON public.leads
  FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Enable update for leads" ON public.leads;
CREATE POLICY "Enable update for leads" ON public.leads
  FOR UPDATE TO authenticated USING (
    public.is_admin_or_manager() OR 
    assigned_agent_id = auth.uid() OR 
    partner_id = auth.uid()
  );

-- ---------------------------------------------------------------------
-- 5. POLICIES FOR inspections TABLE
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS "Enable read access for inspections" ON public.inspections;
CREATE POLICY "Enable read access for inspections" ON public.inspections
  FOR SELECT TO authenticated USING (
    public.is_admin_or_manager() OR 
    buyer_id = auth.uid() OR 
    partner_id = auth.uid()
  );

DROP POLICY IF EXISTS "Enable insert for inspections" ON public.inspections;
CREATE POLICY "Enable insert for inspections" ON public.inspections
  FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Enable update for inspections" ON public.inspections;
CREATE POLICY "Enable update for inspections" ON public.inspections
  FOR UPDATE TO authenticated USING (
    public.is_admin_or_manager() OR 
    buyer_id = auth.uid() OR 
    partner_id = auth.uid()
  );

-- ---------------------------------------------------------------------
-- 6. POLICIES FOR commissions TABLE
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS "Enable read access for commissions" ON public.commissions;
CREATE POLICY "Enable read access for commissions" ON public.commissions
  FOR SELECT TO authenticated USING (
    public.is_admin_or_manager() OR 
    partner_id = auth.uid()
  );

DROP POLICY IF EXISTS "Enable write access for commissions" ON public.commissions;
CREATE POLICY "Enable write access for commissions" ON public.commissions
  FOR ALL TO authenticated USING (public.is_admin_or_manager());

-- ---------------------------------------------------------------------
-- 7. POLICIES FOR transactions TABLE
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS "Enable read access for transactions" ON public.transactions;
CREATE POLICY "Enable read access for transactions" ON public.transactions
  FOR SELECT TO authenticated USING (
    public.is_admin_or_manager() OR 
    partner_id = auth.uid()
  );

DROP POLICY IF EXISTS "Enable write access for transactions" ON public.transactions;
CREATE POLICY "Enable write access for transactions" ON public.transactions
  FOR ALL TO authenticated USING (public.is_admin_or_manager());
