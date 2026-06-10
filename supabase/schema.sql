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

CREATE POLICY companies_write ON public.companies
  FOR ALL TO authenticated
  USING (public.get_my_role() IN ('admin', 'platform_admin'));

-- Profiles Policies
CREATE POLICY profiles_select ON public.profiles
  FOR SELECT TO authenticated
  USING (company_id = public.get_my_company() OR public.get_my_role() = 'platform_admin');

CREATE POLICY profiles_update ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid() OR public.get_my_role() IN ('admin', 'platform_admin'));

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

CREATE POLICY leads_write ON public.leads
  FOR ALL TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company()
    OR partner_id = auth.uid()
    OR buyer_id = auth.uid()
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

CREATE POLICY inspections_write ON public.inspections
  FOR ALL TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company()
    OR partner_id = auth.uid()
    OR buyer_id = auth.uid()
  );

-- Transactions Policies
CREATE POLICY transactions_select ON public.transactions
  FOR SELECT TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company()
    OR partner_id = auth.uid()
  );

CREATE POLICY transactions_write ON public.transactions
  FOR ALL TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin') AND company_id = public.get_my_company()
    OR (partner_id = auth.uid() AND type = 'withdrawal')
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
BEGIN
  -- Assign to the first company in public.companies (if exists) as default
  SELECT id INTO v_company_id FROM public.companies LIMIT 1;

  INSERT INTO public.profiles (id, company_id, full_name, email, phone, role, status)
  VALUES (
    new.id,
    v_company_id,
    COALESCE(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    new.phone,
    COALESCE(new.raw_user_meta_data->>'role', 'buyer'),
    CASE WHEN COALESCE(new.raw_user_meta_data->>'role', 'buyer') = 'admin' THEN 'approved' ELSE 'pending' END
  );
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
