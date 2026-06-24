-- =====================================================================
-- PPN: ADD SUBSCRIPTION COLUMNS & UPDATE TRIGGERS
-- Run this script in the Supabase SQL Editor of your project
-- =====================================================================

-- 1. Add subscription columns to the companies table
ALTER TABLE public.companies 
  ADD COLUMN IF NOT EXISTS subscription_tier TEXT NOT NULL DEFAULT 'basic' CHECK (subscription_tier IN ('basic', 'growth', 'enterprise')),
  ADD COLUMN IF NOT EXISTS subscription_status TEXT NOT NULL DEFAULT 'trialing' CHECK (subscription_status IN ('active', 'trialing', 'past_due', 'suspended')),
  ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMPTZ DEFAULT (now() + interval '14 days');

-- 2. Update handle_new_user() trigger function to auto-confirm new users, and default to 14 days trial
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_company_id UUID;
  v_company_name TEXT;
  v_subscription_tier TEXT;
BEGIN
  -- Check if they want to create a new company
  v_company_name := new.raw_user_meta_data->>'create_company_name';
  v_subscription_tier := COALESCE(new.raw_user_meta_data->>'create_subscription_tier', 'basic');
  
  IF v_company_name IS NOT NULL AND v_company_name <> '' THEN
    -- Create the new company and get its ID (7 days trial for free tier, 14 days for paid tiers)
    INSERT INTO public.companies (name, subscription_tier, subscription_status, subscription_expires_at)
    VALUES (
      v_company_name, 
      v_subscription_tier, 
      'trialing', 
      CASE WHEN v_subscription_tier = 'free' THEN now() + interval '7 days' ELSE now() + interval '14 days' END
    )
    RETURNING id INTO v_company_id;
  ELSIF (new.raw_user_meta_data->>'company_id') IS NOT NULL AND (new.raw_user_meta_data->>'company_id') <> '' THEN
    -- Use the provided company ID
    v_company_id := (new.raw_user_meta_data->>'company_id')::UUID;
  ELSE
    -- Fallback to the first company (default)
    SELECT id INTO v_company_id FROM public.companies ORDER BY created_at ASC LIMIT 1;
  END IF;

  -- Insert profile
  INSERT INTO public.profiles (id, company_id, full_name, email, phone, role, status)
  VALUES (
    new.id,
    v_company_id,
    COALESCE(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    new.phone,
    COALESCE(new.raw_user_meta_data->>'role', 'buyer'),
    'approved'
  );

  -- Auto-confirm the email of the user on the database level (failsafe)
  UPDATE auth.users 
  SET email_confirmed_at = COALESCE(email_confirmed_at, now()),
      last_sign_in_at = COALESCE(last_sign_in_at, now())
  WHERE id = new.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
