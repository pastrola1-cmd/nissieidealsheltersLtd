-- =============================================================================
-- LOOP 18: City Intelligence & Audience Registry
-- =============================================================================

-- 1. Add target_audience column to properties table
ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS target_audience TEXT;
