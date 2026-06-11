-- =============================================================================
-- DATABASE PATCH: Fix Profiles SELECT RLS Policy Recursion
-- =============================================================================
-- This patch drops the old profiles SELECT policy and creates a new one
-- that includes a short-circuit check 'id = auth.uid()'. This allows
-- authenticated users to read their own profiles without triggering
-- the company or role lookup functions, resolving the infinite recursion error.
-- Run this in your Supabase SQL Editor.
-- =============================================================================

-- Recreate the helper functions and explicitly set their owner to postgres
-- to ensure they bypass Row Level Security when querying the profiles table.
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

ALTER FUNCTION public.get_my_role() OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.get_my_company()
RETURNS UUID AS $$
  SELECT company_id FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

ALTER FUNCTION public.get_my_company() OWNER TO postgres;

-- Dynamically drop ALL existing policies on public.profiles to avoid duplicates
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN 
    SELECT policyname 
    FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'profiles'
  LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(pol.policyname) || ' ON public.profiles';
  END LOOP;
END
$$;

-- Create the correct, optimized SELECT policy with self-read short-circuit
CREATE POLICY profiles_select ON public.profiles
  FOR SELECT TO authenticated
  USING (
    id = auth.uid()
    OR company_id = public.get_my_company()
    OR public.get_my_role() = 'platform_admin'
  );

-- Create the correct UPDATE policy
CREATE POLICY profiles_update ON public.profiles
  FOR UPDATE TO authenticated
  USING (
    id = auth.uid()
    OR (public.get_my_role() = 'admin' AND company_id = public.get_my_company())
    OR public.get_my_role() = 'platform_admin'
  );

-- Double check that RLS is still enabled
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;


