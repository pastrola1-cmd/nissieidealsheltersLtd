-- =============================================================================
-- LOOP 26: Performance Evolution Loop
-- =============================================================================
-- This migration establishes the campaign block performance statistics table.
-- Run this in the Supabase SQL Editor.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.campaign_block_stats (
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  block_id TEXT NOT NULL,
  times_used INTEGER DEFAULT 0,
  leads_attributed INTEGER DEFAULT 0,
  conversions_attributed INTEGER DEFAULT 0,
  performance_score NUMERIC DEFAULT 1.0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (company_id, block_id)
);

-- Enable RLS
ALTER TABLE public.campaign_block_stats ENABLE ROW LEVEL SECURITY;

-- Establish RLS Policies
CREATE POLICY campaign_block_stats_isolation ON public.campaign_block_stats
  FOR ALL USING (company_id = (SELECT company_id FROM profiles WHERE id = auth.uid()));
