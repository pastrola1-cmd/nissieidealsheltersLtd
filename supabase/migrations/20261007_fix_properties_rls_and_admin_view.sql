-- =============================================================================
-- PROPERTIES RLS & VISIBILITY FIX FOR ADMIN AND LANDLORDS
-- =============================================================================
-- Fixes:
-- 1. Landlord user uploads not showing in Admin Portfolio or Landlord Dashboard.
-- 2. Grants Admins / Platform Admins full SELECT, INSERT, UPDATE, DELETE on all properties.
-- 3. Grants Landlords full SELECT and INSERT on their own properties (even unverified).
-- 4. Grants Public SELECT on all available / active listings.
-- 5. Backfills any null company_id to default company ID.

-- 1) Ensure all necessary columns exist on public.properties (idempotent)
ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS listing_type TEXT NOT NULL DEFAULT 'sale',
  ADD COLUMN IF NOT EXISTS property_category TEXT NOT NULL DEFAULT 'apartment',
  ADD COLUMN IF NOT EXISTS bedrooms INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS bathrooms INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS city TEXT DEFAULT 'Abuja',
  ADD COLUMN IF NOT EXISTS state TEXT DEFAULT 'FCT',
  ADD COLUMN IF NOT EXISTS district TEXT,
  ADD COLUMN IF NOT EXISTS rent_period TEXT DEFAULT 'year',
  ADD COLUMN IF NOT EXISTS inspection_fee NUMERIC NOT NULL DEFAULT 10000,
  ADD COLUMN IF NOT EXISTS is_marketplace BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS shielded_contact BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS target_audience TEXT,
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- 2) Enable Row Level Security
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;

-- 3) Clean up old/conflicting policies to ensure clean state
DROP POLICY IF EXISTS "properties_select" ON public.properties;
DROP POLICY IF EXISTS "properties_write" ON public.properties;
DROP POLICY IF EXISTS "properties_public_marketplace_read" ON public.properties;
DROP POLICY IF EXISTS "properties_public_read" ON public.properties;
DROP POLICY IF EXISTS "landlords_insert_own" ON public.properties;
DROP POLICY IF EXISTS "landlords_select_own" ON public.properties;
DROP POLICY IF EXISTS "landlords_update_own_pending" ON public.properties;
DROP POLICY IF EXISTS "landlords_update_own" ON public.properties;
DROP POLICY IF EXISTS "properties_admin_all" ON public.properties;

-- 4) Policy: Admins and Platform Admins can view and manage ALL properties
CREATE POLICY "properties_admin_all" ON public.properties
  FOR ALL TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin', 'manager')
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'platform_admin', 'manager')
    )
  )
  WITH CHECK (
    public.get_my_role() IN ('admin', 'platform_admin', 'manager')
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'platform_admin', 'manager')
    )
  );

-- 5) Policy: Landlords / Hosts can insert their own property listings
CREATE POLICY "landlords_insert_own" ON public.properties
  FOR INSERT TO authenticated
  WITH CHECK (
    created_by = auth.uid()
    OR created_by IS NULL
    OR public.get_my_role() IN ('admin', 'platform_admin', 'manager')
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'platform_admin', 'manager')
    )
  );

-- 6) Policy: Landlords / Hosts can SELECT their own listings (even when unverified/pending)
CREATE POLICY "landlords_select_own" ON public.properties
  FOR SELECT TO authenticated
  USING (
    created_by = auth.uid()
  );

-- 7) Policy: Landlords can update price & details of their own pending listings
CREATE POLICY "landlords_update_own" ON public.properties
  FOR UPDATE TO authenticated
  USING (
    created_by = auth.uid() AND is_verified = false
  )
  WITH CHECK (
    created_by = auth.uid()
  );

-- 8) Policy: Public (anon + authenticated) can view all available/active properties
CREATE POLICY "properties_public_read" ON public.properties
  FOR SELECT TO public
  USING (
    status IN ('available', 'active', 'reserved', 'sold')
  );

-- 9) Backfill any existing properties that have null company_id to default Nissie company ID
UPDATE public.properties
SET company_id = 'd3b07384-d113-4ec6-a5d7-ecf9e01103e6'
WHERE company_id IS NULL;
