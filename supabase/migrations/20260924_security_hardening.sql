-- SECURITY HARDENING (run after all prior marketplace/wallet migrations)
-- 1) Self-signup can no longer mint staff/admin roles or auto-confirm email.
--    Staff roles (manager/marketer/admin) are granted via invite_staff_member RPC only.
-- 2) Companies table no longer world-readable (held Termii/Gemini/Brevo/SMTP secrets).
-- 3) inspection_bookings supports marketplace listings (non-UUID property ids).

-- ── 1) Role allowlist on profiles ──
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('admin','manager','marketer','partner','buyer','landlord','platform_admin'));

-- ── 2) Hardened handle_new_user: ignore privileged client roles, no auto-confirm ──
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_company_id UUID;
  v_company_name TEXT;
  v_subscription_tier TEXT;
  v_requested_role TEXT;
  v_role TEXT;
  v_status TEXT;
BEGIN
  v_company_name := new.raw_user_meta_data->>'create_company_name';
  v_subscription_tier := COALESCE(new.raw_user_meta_data->>'create_subscription_tier', 'basic');

  IF v_company_name IS NOT NULL AND v_company_name <> '' THEN
    INSERT INTO public.companies (name, subscription_tier, subscription_status, subscription_expires_at)
    VALUES (
      v_company_name,
      v_subscription_tier,
      'trialing',
      CASE WHEN v_subscription_tier = 'free' THEN now() + interval '7 days' ELSE now() + interval '14 days' END
    )
    RETURNING id INTO v_company_id;
  ELSIF (new.raw_user_meta_data->>'company_id') IS NOT NULL AND (new.raw_user_meta_data->>'company_id') <> '' THEN
    v_company_id := (new.raw_user_meta_data->>'company_id')::UUID;
  ELSE
    SELECT id INTO v_company_id FROM public.companies ORDER BY created_at ASC LIMIT 1;
  END IF;

  -- Self-service allowlist ONLY. Privileged roles via invite_staff_member RPC.
  v_requested_role := COALESCE(new.raw_user_meta_data->>'role', 'buyer');
  IF v_requested_role IN ('buyer', 'landlord', 'partner') THEN
    v_role := v_requested_role;
  ELSE
    v_role := 'buyer';
  END IF;

  IF v_role = 'partner' THEN
    v_status := 'pending';
  ELSE
    v_status := 'approved';
  END IF;

  INSERT INTO public.profiles (id, company_id, full_name, email, phone, role, status)
  VALUES (
    new.id,
    v_company_id,
    COALESCE(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    new.phone,
    v_role,
    v_status
  )
  ON CONFLICT (id) DO NOTHING;

  -- NOTE: no email auto-confirm here. Controlled by Supabase Auth settings.
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── 3) Companies: drop world-readable policy (leaked API secrets) ──
-- NOTE: properties stay publicly readable (public marketplace needs it).
DROP POLICY IF EXISTS companies_public_select ON public.companies;
-- companies_select (authenticated members + platform_admin) already covers legit reads.
-- If some public page needs company name/logo, expose via companies_public view instead:
CREATE OR REPLACE VIEW public.companies_public AS
SELECT id, name, logo_url FROM public.companies;
GRANT SELECT ON public.companies_public TO anon, authenticated;

-- ── 4) Bookings: allow marketplace (non-UUID) listings ──
ALTER TABLE public.inspection_bookings
  ALTER COLUMN property_id DROP NOT NULL;
ALTER TABLE public.inspection_bookings
  ADD COLUMN IF NOT EXISTS marketplace_property_id TEXT;
