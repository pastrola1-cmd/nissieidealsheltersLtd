-- =============================================================================
-- LOOP 36: A/B Testing
-- Adds landing page variants table and variant analytics tracking functions.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.landing_page_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  landing_page_id UUID REFERENCES public.landing_pages(id) ON DELETE CASCADE NOT NULL,
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  variant_code TEXT NOT NULL CHECK (variant_code IN ('A', 'B', 'C')),
  headline TEXT NOT NULL,
  cta_primary TEXT NOT NULL DEFAULT 'Book Free Site Inspection',
  cta_secondary TEXT NOT NULL DEFAULT 'Get Price List',
  views_count INTEGER DEFAULT 0 NOT NULL,
  leads_count INTEGER DEFAULT 0 NOT NULL,
  is_active BOOLEAN DEFAULT true NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(landing_page_id, variant_code)
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.landing_page_variants ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS variants_select ON public.landing_page_variants;
DROP POLICY IF EXISTS variants_insert ON public.landing_page_variants;
DROP POLICY IF EXISTS variants_update ON public.landing_page_variants;
DROP POLICY IF EXISTS variants_delete ON public.landing_page_variants;

-- Policy: Anyone can view variants (public pages need to fetch variant config)
CREATE POLICY variants_select ON public.landing_page_variants
  FOR SELECT
  USING (true);

-- Policy: Authenticated managers/admins/marketers can insert, update, and delete variants for their company
CREATE POLICY variants_insert ON public.landing_page_variants
  FOR INSERT TO authenticated
  WITH CHECK (
    public.get_my_role() IN ('admin', 'platform_admin', 'manager', 'marketer') 
    AND company_id = public.get_my_company()
  );

CREATE POLICY variants_update ON public.landing_page_variants
  FOR UPDATE TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin', 'manager', 'marketer') 
    AND company_id = public.get_my_company()
  );

CREATE POLICY variants_delete ON public.landing_page_variants
  FOR DELETE TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin', 'manager') 
    AND company_id = public.get_my_company()
  );

-- Create function to record variant engagement (views / leads) securely from client
CREATE OR REPLACE FUNCTION public.record_variant_engagement(
  p_variant_id UUID,
  p_is_lead BOOLEAN
)
RETURNS VOID AS $$
BEGIN
  IF p_is_lead THEN
    UPDATE public.landing_page_variants
    SET leads_count = leads_count + 1
    WHERE id = p_variant_id;
  ELSE
    UPDATE public.landing_page_variants
    SET views_count = views_count + 1
    WHERE id = p_variant_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_variants_landing_page ON public.landing_page_variants(landing_page_id);
CREATE INDEX IF NOT EXISTS idx_variants_company ON public.landing_page_variants(company_id);
