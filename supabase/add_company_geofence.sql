-- Add office geolocation columns to companies table
ALTER TABLE public.companies
  ADD COLUMN IF NOT EXISTS office_lat NUMERIC,
  ADD COLUMN IF NOT EXISTS office_lng NUMERIC,
  ADD COLUMN IF NOT EXISTS office_radius_meters NUMERIC DEFAULT 300.0;
