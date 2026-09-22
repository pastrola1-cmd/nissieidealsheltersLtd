-- Landlord self-service listings: columns + RLS
-- Run in Supabase SQL Editor after add_marketplace_and_wallet.sql

-- 1) Ensure marketplace columns exist (idempotent)
ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS listing_type TEXT NOT NULL DEFAULT 'sale' CHECK (listing_type IN ('rent','sale','shortlet')),
  ADD COLUMN IF NOT EXISTS property_category TEXT NOT NULL DEFAULT 'apartment',
  ADD COLUMN IF NOT EXISTS bedrooms INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS bathrooms INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS city TEXT DEFAULT 'Abuja',
  ADD COLUMN IF NOT EXISTS state TEXT DEFAULT 'FCT',
  ADD COLUMN IF NOT EXISTS district TEXT,
  ADD COLUMN IF NOT EXISTS rent_period TEXT DEFAULT 'year' CHECK (rent_period IN ('year','month','total')),
  ADD COLUMN IF NOT EXISTS inspection_fee NUMERIC NOT NULL DEFAULT 3000,
  ADD COLUMN IF NOT EXISTS is_marketplace BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS shielded_contact BOOLEAN NOT NULL DEFAULT true;

-- 2) Landlords can insert their own listings (created_by = self)
DROP POLICY IF EXISTS "landlords_insert_own" ON public.properties;
CREATE POLICY "landlords_insert_own" ON public.properties
  FOR INSERT TO authenticated
  WITH CHECK (created_by = auth.uid());

-- 3) Landlords can view their own listings (even before approval)
DROP POLICY IF EXISTS "landlords_select_own" ON public.properties;
CREATE POLICY "landlords_select_own" ON public.properties
  FOR SELECT TO authenticated
  USING (created_by = auth.uid());

-- 4) Landlords can update price/description of their own UNVERIFIED listings
DROP POLICY IF EXISTS "landlords_update_own_pending" ON public.properties;
CREATE POLICY "landlords_update_own_pending" ON public.properties
  FOR UPDATE TO authenticated
  USING (created_by = auth.uid() AND is_verified = false)
  WITH CHECK (created_by = auth.uid());
