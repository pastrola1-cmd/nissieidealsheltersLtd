-- =============================================================================
-- LOOP 15: Expanded Agency Role System (Manager + Marketer/Agent)
-- =============================================================================
-- This migration expands the role system to include Manager and Marketer roles.
-- Run this in the Supabase SQL Editor.
-- =============================================================================

-- 1. Expand role CHECK constraint on profiles table
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('admin', 'manager', 'marketer', 'partner', 'buyer', 'platform_admin'));

-- 2. Add manager_id to profiles (which manager supervises this user)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS manager_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- 3. Add assigned_agent_id to leads (which marketer/agent owns this lead)
ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS assigned_agent_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- 4. Update the handle_new_user() trigger function to support new roles
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, role, full_name, status, company_id)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'role', 'buyer'),
    COALESCE(new.raw_user_meta_data->>'full_name', ''),
    'approved',
    CASE
      WHEN new.raw_user_meta_data->>'company_id' IS NOT NULL
        AND new.raw_user_meta_data->>'company_id' != ''
      THEN (new.raw_user_meta_data->>'company_id')::UUID
      ELSE NULL
    END
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RLS policies for manager role
-- Managers can read all profiles within their company
DROP POLICY IF EXISTS manager_read_company_profiles ON public.profiles;
CREATE POLICY manager_read_company_profiles ON public.profiles
  FOR SELECT
  USING (
    company_id = (
      SELECT company_id FROM public.profiles WHERE id = auth.uid()
    )
    AND (
      SELECT role FROM public.profiles WHERE id = auth.uid()
    ) IN ('admin', 'manager', 'platform_admin')
  );

-- 6. RLS policies for marketer role (read only assigned leads)
-- Note: This adds a new policy; existing admin policies remain unchanged.
DROP POLICY IF EXISTS marketer_read_own_leads ON public.leads;
CREATE POLICY marketer_read_own_leads ON public.leads
  FOR SELECT
  USING (
    assigned_agent_id = auth.uid()
    AND (
      SELECT role FROM public.profiles WHERE id = auth.uid()
    ) = 'marketer'
  );

DROP POLICY IF EXISTS marketer_update_own_leads ON public.leads;
CREATE POLICY marketer_update_own_leads ON public.leads
  FOR UPDATE
  USING (
    assigned_agent_id = auth.uid()
    AND (
      SELECT role FROM public.profiles WHERE id = auth.uid()
    ) = 'marketer'
  );

-- 7. Secure staff invitation function
-- Allows Admins/Managers to create auth users directly in postgres
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE OR REPLACE FUNCTION public.invite_staff_member(
  p_email TEXT,
  p_phone TEXT,
  p_name TEXT,
  p_role TEXT,
  p_company_id UUID,
  p_password TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_user_id UUID;
  v_hashed_password TEXT;
BEGIN
  -- Check if user already exists
  SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;
  
  IF v_user_id IS NOT NULL THEN
    RAISE EXCEPTION 'A user with this email already exists';
  END IF;

  -- Generate a random user ID
  v_user_id := gen_random_uuid();
  -- Hash the provided password, or generate a random one if none given
  IF p_password IS NOT NULL AND p_password != '' THEN
    v_hashed_password := crypt(p_password, gen_salt('bf'));
  ELSE
    v_hashed_password := crypt(gen_random_uuid()::text, gen_salt('bf'));
  END IF;

  INSERT INTO auth.users (
    id,
    instance_id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    role,
    phone,
    phone_confirmed_at,
    aud,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token,
    email_change_token_current,
    phone_change,
    phone_change_token,
    reauthentication_token
  )
  VALUES (
    v_user_id,
    '00000000-0000-0000-0000-000000000000',
    p_email,
    v_hashed_password,
    now(),
    jsonb_build_object('provider', 'email', 'providers', array['email']),
    jsonb_build_object('full_name', p_name, 'role', p_role, 'company_id', p_company_id),
    now(),
    now(),
    'authenticated',
    p_phone,
    now(),
    'authenticated',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    ''
  );

  -- Insert into auth.identities to enable GoTrue login
  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  )
  VALUES (
    gen_random_uuid(),
    v_user_id,
    jsonb_build_object('sub', v_user_id, 'email', p_email),
    'email',
    v_user_id::text,
    now(),
    now(),
    now()
  );

  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

