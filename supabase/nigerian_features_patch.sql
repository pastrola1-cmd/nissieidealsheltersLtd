-- =====================================================================
-- NISSIE IDEAL SHELTERS — NIGERIAN FEATURES SCHEMA PATCH
-- Run this in your Supabase SQL Editor.
-- =====================================================================

-- Add columns for Title Documents and Installment Configurations
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS documents TEXT[];
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS payment_plans JSONB;
