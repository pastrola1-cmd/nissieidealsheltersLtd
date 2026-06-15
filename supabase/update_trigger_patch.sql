-- =====================================================================
-- PPN: UPDATE AUTH SIGNUP TRIGGER TO SUPPORT MULTI-TENANCY
-- Run this script in the Supabase SQL Editor to update the trigger
-- =====================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_company_id UUID;
  v_company_name TEXT;
BEGIN
  -- Check if they want to create a new company
  v_company_name := new.raw_user_meta_data->>'create_company_name';
  
  IF v_company_name IS NOT NULL AND v_company_name <> '' THEN
    -- Create the new company and get its ID
    INSERT INTO public.companies (name)
    VALUES (v_company_name)
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
    CASE 
      WHEN COALESCE(new.raw_user_meta_data->>'role', 'buyer') = 'admin' THEN 'approved'
      WHEN COALESCE(new.raw_user_meta_data->>'role', 'buyer') = 'partner' THEN 'pending'
      WHEN COALESCE(new.raw_user_meta_data->>'role', 'buyer') = 'platform_admin' THEN 'approved'
      ELSE 'approved'
    END
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
