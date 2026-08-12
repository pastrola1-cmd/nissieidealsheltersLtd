-- =============================================================================
-- FIX: Add missing updated_at column to companies table & resolve 42703 trigger error
-- Run this script in your Supabase SQL Editor (https://supabase.com)
-- =============================================================================

-- 1. Ensure updated_at and Termii/Gemini columns exist on companies table
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS termii_api_key TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS termii_sender_id TEXT DEFAULT 'Nissie';
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS gemini_api_key TEXT;

-- 2. Drop any erroneous or leftover triggers if present
DROP TRIGGER IF EXISTS set_updated_at ON public.companies;
DROP TRIGGER IF EXISTS update_companies_updated_at ON public.companies;
