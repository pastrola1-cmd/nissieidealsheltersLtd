-- Add geotagged on-site verification columns to inspections table
ALTER TABLE public.inspections
  ADD COLUMN IF NOT EXISTS photo_url TEXT,
  ADD COLUMN IF NOT EXISTS inspection_lat NUMERIC,
  ADD COLUMN IF NOT EXISTS inspection_lng NUMERIC,
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS client_feedback TEXT,
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false;
