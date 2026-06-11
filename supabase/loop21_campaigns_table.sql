-- =============================================================================
-- LOOP 21: Marketing Campaign History Table & RLS
-- =============================================================================
-- This table stores generated campaigns for various social media platforms.
-- Run this script in the Supabase SQL Editor.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  property_id UUID REFERENCES public.properties(id) ON DELETE SET NULL,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  input_data JSONB NOT NULL,
  output_data JSONB NOT NULL,
  platform TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if any
DROP POLICY IF EXISTS campaigns_company_isolation ON public.campaigns;

-- Policy: Company Isolation (Users can only see campaigns within their own agency)
CREATE POLICY campaigns_company_isolation ON public.campaigns
  FOR ALL USING (company_id = (SELECT company_id FROM profiles WHERE id = auth.uid()));
