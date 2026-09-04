-- =============================================================================
-- PUBLIC PROPERTY MARKETPLACE, SHIELDED INSPECTIONS & WALLET SYSTEM
-- =============================================================================

-- 1. Extend Properties Table for Rent / Sale Marketplace
ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS listing_type TEXT NOT NULL DEFAULT 'sale' CHECK (listing_type IN ('rent', 'sale', 'shortlet')),
  ADD COLUMN IF NOT EXISTS property_category TEXT NOT NULL DEFAULT 'apartment' CHECK (property_category IN ('apartment', 'flat', 'duplex', 'bungalow', 'self_contain', 'land', 'commercial')),
  ADD COLUMN IF NOT EXISTS bedrooms INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS bathrooms INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS city TEXT DEFAULT 'Abuja',
  ADD COLUMN IF NOT EXISTS state TEXT DEFAULT 'FCT',
  ADD COLUMN IF NOT EXISTS district TEXT,
  ADD COLUMN IF NOT EXISTS rent_period TEXT DEFAULT 'year' CHECK (rent_period IN ('year', 'month', 'total')),
  ADD COLUMN IF NOT EXISTS inspection_fee NUMERIC NOT NULL DEFAULT 3000,
  ADD COLUMN IF NOT EXISTS is_marketplace BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS shielded_contact BOOLEAN NOT NULL DEFAULT true;

-- Indexes for lightning fast marketplace filtering
CREATE INDEX IF NOT EXISTS idx_properties_marketplace ON public.properties(is_marketplace, status);
CREATE INDEX IF NOT EXISTS idx_properties_listing_type ON public.properties(listing_type, city);
CREATE INDEX IF NOT EXISTS idx_properties_price_city ON public.properties(city, price);

-- 2. Wallets Table
CREATE TABLE IF NOT EXISTS public.wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
  balance NUMERIC NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
  ledger_balance NUMERIC NOT NULL DEFAULT 0.00,
  currency TEXT NOT NULL DEFAULT 'NGN',
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'frozen', 'restricted')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Wallet Transactions Ledger
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID REFERENCES public.wallets(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  amount NUMERIC NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('credit', 'debit', 'escrow_hold', 'escrow_release', 'withdrawal', 'inspection_fee', 'commission')),
  direction TEXT NOT NULL CHECK (direction IN ('inflow', 'outflow')),
  reference TEXT NOT NULL UNIQUE,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wallet_tx_wallet ON public.wallet_transactions(wallet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_user ON public.wallet_transactions(user_id);

-- 4. Shielded Inspection Bookings with 4-Digit Escrow PIN
CREATE TABLE IF NOT EXISTS public.inspection_bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID REFERENCES public.properties(id) ON DELETE CASCADE NOT NULL,
  renter_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  renter_name TEXT NOT NULL,
  renter_phone TEXT NOT NULL,
  renter_email TEXT,
  agent_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  scheduled_date DATE NOT NULL,
  scheduled_time TEXT NOT NULL,
  fee_amount NUMERIC NOT NULL DEFAULT 3000,
  agent_payout_amount NUMERIC NOT NULL DEFAULT 2000,
  platform_fee_amount NUMERIC NOT NULL DEFAULT 1000,
  completion_pin VARCHAR(4) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending_payment' CHECK (status IN ('pending_payment', 'paid_escrow', 'agent_assigned', 'completed', 'cancelled', 'disputed')),
  escrow_released_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inspection_bookings_property ON public.inspection_bookings(property_id);
CREATE INDEX IF NOT EXISTS idx_inspection_bookings_renter ON public.inspection_bookings(renter_id);
CREATE INDEX IF NOT EXISTS idx_inspection_bookings_agent ON public.inspection_bookings(agent_id);

-- 5. Row Level Security
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_bookings ENABLE ROW LEVEL SECURITY;

-- Wallets: Users can view their own wallet
DROP POLICY IF EXISTS "wallets_user_policy" ON public.wallets;
CREATE POLICY "wallets_user_policy" ON public.wallets
  FOR ALL TO authenticated
  USING (user_id = auth.uid());

-- Transactions: Users can view their own transactions
DROP POLICY IF EXISTS "wallet_tx_user_policy" ON public.wallet_transactions;
CREATE POLICY "wallet_tx_user_policy" ON public.wallet_transactions
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Inspections: Renters and assigned agents can view their bookings
DROP POLICY IF EXISTS "inspection_bookings_policy" ON public.inspection_bookings;
CREATE POLICY "inspection_bookings_policy" ON public.inspection_bookings
  FOR ALL TO authenticated
  USING (renter_id = auth.uid() OR agent_id = auth.uid() OR public.get_my_role() IN ('admin', 'platform_admin'));

-- Public marketplace read policy for properties: anyone (even unauthenticated) can view active properties
DROP POLICY IF EXISTS "properties_public_marketplace_read" ON public.properties;
CREATE POLICY "properties_public_marketplace_read" ON public.properties
  FOR SELECT TO public
  USING (status = 'active');
