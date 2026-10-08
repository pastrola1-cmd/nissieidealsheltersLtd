-- =============================================================================
-- FIX: invite_staff_member pgcrypto gen_salt resolution in Supabase
-- =============================================================================
-- Problem:
-- When an Admin tries to invite a staff member via RPC `invite_staff_member`,
-- PostgreSQL throws:
-- "function gen_salt(unknown) does not exist, code: 42883"
--
-- Cause:
-- The function was defined with `SET search_path = public`, but in Supabase,
-- `pgcrypto` functions (`crypt`, `gen_salt`) are installed in the `extensions`
-- schema. Restricting search_path to `public` hides `gen_salt` from the planner.
--
-- Solution:
-- 1. Ensure `pgcrypto` is enabled in `extensions` schema.
-- 2. Grant USAGE on schema `extensions` to authenticated role.
-- 3. Redefine `public.invite_staff_member` with `SET search_path = public, extensions, auth`
--    and explicit `extensions.` schema qualification on `crypt` and `gen_salt`.
-- 4. Grant EXECUTE to authenticated users.
-- =============================================================================

-- 1. Ensure pgcrypto extension is installed in extensions schema
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- 2. Grant usage on extensions schema
GRANT USAGE ON SCHEMA extensions TO authenticated, service_role, anon;

-- 3. Redefine invite_staff_member function with proper search_path and error safety
CREATE OR REPLACE FUNCTION public.invite_staff_member(
  p_email TEXT,
  p_phone TEXT,
  p_name TEXT,
  p_role TEXT,
  p_company_id UUID,
  p_password TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, auth
AS $$
DECLARE
  v_user_id UUID;
  v_hashed_password TEXT;
  v_status TEXT;
BEGIN
  -- 1) Access check: Admins, Platform Admins, and Managers only
  IF NOT (
    public.is_admin_or_manager()
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'manager', 'platform_admin', 'platformAdmin')
    )
  ) THEN
    RAISE EXCEPTION 'Forbidden: only admins and managers can invite staff';
  END IF;

  -- 2) Role validation
  IF p_role NOT IN ('manager', 'marketer', 'admin', 'partner') THEN
    RAISE EXCEPTION 'Forbidden: invalid invite role';
  END IF;

  -- 3) Prevent duplicate email registration
  SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;
  IF v_user_id IS NOT NULL THEN
    RAISE EXCEPTION 'A user with this email already exists';
  END IF;

  -- 4) Generate user UUID
  v_user_id := gen_random_uuid();

  -- 5) Hash password using pgcrypto (works with either extensions.crypt or search_path)
  IF p_password IS NOT NULL AND p_password != '' THEN
    v_hashed_password := extensions.crypt(p_password, extensions.gen_salt('bf'));
  ELSE
    v_hashed_password := extensions.crypt(gen_random_uuid()::text, extensions.gen_salt('bf'));
  END IF;

  -- 6) Create auth record in auth.users
  INSERT INTO auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    role, phone, phone_confirmed_at, aud, confirmation_token,
    email_change, email_change_token_new, recovery_token,
    email_change_token_current, phone_change, phone_change_token, reauthentication_token
  )
  VALUES (
    v_user_id, '00000000-0000-0000-0000-000000000000', p_email, v_hashed_password, now(),
    jsonb_build_object('provider', 'email', 'providers', array['email']),
    jsonb_build_object('full_name', p_name, 'role', p_role, 'company_id', p_company_id),
    now(), now(), 'authenticated', p_phone, now(), 'authenticated', '', '', '', '', '', '', '', ''
  );

  -- 7) Create identity in auth.identities for GoTrue login
  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
  )
  VALUES (
    gen_random_uuid(), v_user_id, jsonb_build_object('sub', v_user_id, 'email', p_email), 'email', v_user_id::text, now(), now(), now()
  );

  -- 8) Create or update profile in public.profiles
  IF p_role = 'partner' THEN v_status := 'pending'; ELSE v_status := 'approved'; END IF;
  INSERT INTO public.profiles (id, company_id, full_name, email, phone, role, status)
  VALUES (v_user_id, p_company_id, p_name, p_email, p_phone, p_role, v_status)
  ON CONFLICT (id) DO UPDATE SET
    role = EXCLUDED.role,
    status = EXCLUDED.status,
    company_id = EXCLUDED.company_id,
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone;

  RETURN v_user_id;
END;
$$;

-- 4. Revoke from anon/PUBLIC, grant to authenticated users
REVOKE ALL ON FUNCTION public.invite_staff_member(text, text, text, text, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.invite_staff_member(text, text, text, text, uuid, text) TO authenticated;
