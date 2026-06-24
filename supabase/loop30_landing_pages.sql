-- =============================================================================
-- LOOP 30: Landing Pages & Ads Module Database Schema
-- Adds support for property listing landing pages and lead capture tracking.
-- =============================================================================

-- 1. Add landing page settings/tracking configuration to Companies
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS fb_pixel_id TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS fb_capi_token TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS lp_module_enabled BOOLEAN DEFAULT true;

-- 2. Create the landing_pages table
CREATE TABLE IF NOT EXISTS public.landing_pages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  property_id UUID REFERENCES public.properties(id) ON DELETE CASCADE NOT NULL,
  slug TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published', 'archived')),
  headline TEXT,
  cta_primary TEXT DEFAULT 'Book Free Site Inspection',
  cta_secondary TEXT DEFAULT 'Get Price List',
  testimonials JSONB DEFAULT '[]',
  landmark_notes TEXT,
  views_count INTEGER DEFAULT 0 NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(company_id, slug)
);

-- 3. Create the lp_consent_log table for NDPR/GDPR compliance
CREATE TABLE IF NOT EXISTS public.lp_consent_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  landing_page_id UUID REFERENCES public.landing_pages(id) ON DELETE SET NULL,
  lead_name TEXT NOT NULL,
  lead_phone TEXT NOT NULL,
  consent_text TEXT NOT NULL,
  ip_address TEXT,
  user_agent TEXT,
  consented_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Extend the leads table to reference the landing page source & consent
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS source_landing_page_id UUID REFERENCES public.landing_pages(id) ON DELETE SET NULL;
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS consent_timestamp TIMESTAMPTZ;
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS consent_text TEXT;

-- 5. Enable Row Level Security (RLS)
ALTER TABLE public.landing_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lp_consent_log ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies for landing_pages
DROP POLICY IF EXISTS landing_pages_select ON public.landing_pages;
DROP POLICY IF EXISTS landing_pages_insert ON public.landing_pages;
DROP POLICY IF EXISTS landing_pages_update ON public.landing_pages;
DROP POLICY IF EXISTS landing_pages_delete ON public.landing_pages;

-- Everyone (public leads) can view published landing pages
CREATE POLICY landing_pages_select ON public.landing_pages
  FOR SELECT
  USING (
    status = 'published' 
    OR (auth.uid() IS NOT NULL AND company_id = public.get_my_company())
  );

-- Admins/Managers/Marketers can create, update, and delete landing pages for their company
CREATE POLICY landing_pages_insert ON public.landing_pages
  FOR INSERT TO authenticated
  WITH CHECK (
    public.get_my_role() IN ('admin', 'platform_admin', 'manager', 'marketer') 
    AND company_id = public.get_my_company()
  );

CREATE POLICY landing_pages_update ON public.landing_pages
  FOR UPDATE TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin', 'manager', 'marketer') 
    AND company_id = public.get_my_company()
  );

CREATE POLICY landing_pages_delete ON public.landing_pages
  FOR DELETE TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin', 'manager') 
    AND company_id = public.get_my_company()
  );

-- 7. RLS Policies for lp_consent_log
DROP POLICY IF EXISTS lp_consent_log_select ON public.lp_consent_log;
DROP POLICY IF EXISTS lp_consent_log_insert ON public.lp_consent_log;

-- Admins/Managers/Marketers can view consent logs
CREATE POLICY lp_consent_log_select ON public.lp_consent_log
  FOR SELECT TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'platform_admin', 'manager') 
    AND company_id = public.get_my_company()
  );

-- Public form can insert consent logs
CREATE POLICY lp_consent_log_insert ON public.lp_consent_log
  FOR INSERT
  WITH CHECK (true);

-- 8. SECURITY DEFINER function to securely handle public lead creation
CREATE OR REPLACE FUNCTION public.create_public_lead(
  p_company_id UUID,
  p_property_id UUID,
  p_buyer_name TEXT,
  p_buyer_phone TEXT,
  p_buyer_email TEXT,
  p_notes TEXT,
  p_consent_text TEXT,
  p_ip_address TEXT,
  p_user_agent TEXT,
  p_source_landing_page_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_lead_id UUID;
  v_existing_lead_id UUID;
BEGIN
  -- 1. Check for existing lead with same phone in the company
  SELECT id INTO v_existing_lead_id 
  FROM public.leads 
  WHERE buyer_phone = p_buyer_phone AND company_id = p_company_id
  LIMIT 1;

  IF v_existing_lead_id IS NOT NULL THEN
    -- Update existing lead
    UPDATE public.leads 
    SET 
      buyer_name = p_buyer_name,
      buyer_email = COALESCE(p_buyer_email, buyer_email),
      source_landing_page_id = COALESCE(p_source_landing_page_id, source_landing_page_id),
      consent_timestamp = now(),
      consent_text = p_consent_text,
      notes = COALESCE(notes, '') || E'\nRepeat submission: ' || COALESCE(p_notes, ''),
      updated_at = now()
    WHERE id = v_existing_lead_id;
    
    v_lead_id := v_existing_lead_id;
  ELSE
    -- Insert new lead
    INSERT INTO public.leads (
      company_id,
      property_id,
      buyer_name,
      buyer_phone,
      buyer_email,
      source_channel,
      stage,
      notes,
      source_landing_page_id,
      consent_timestamp,
      consent_text
    ) VALUES (
      p_company_id,
      p_property_id,
      p_buyer_name,
      p_buyer_phone,
      p_buyer_email,
      'landing_page',
      'new',
      p_notes,
      p_source_landing_page_id,
      now(),
      p_consent_text
    ) RETURNING id INTO v_lead_id;
  END IF;

  -- 2. Log NDPR Consent
  INSERT INTO public.lp_consent_log (
    company_id,
    landing_page_id,
    lead_name,
    lead_phone,
    consent_text,
    ip_address,
    user_agent
  ) VALUES (
    p_company_id,
    p_source_landing_page_id,
    p_buyer_name,
    p_buyer_phone,
    p_consent_text,
    p_ip_address,
    p_user_agent
  );

  RETURN v_lead_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Function to increment landing page view count securely
CREATE OR REPLACE FUNCTION public.increment_landing_page_view(p_landing_page_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.landing_pages
  SET views_count = views_count + 1
  WHERE id = p_landing_page_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_landing_pages_slug ON public.landing_pages(company_id, slug);
CREATE INDEX IF NOT EXISTS idx_landing_pages_property ON public.landing_pages(property_id);
CREATE INDEX IF NOT EXISTS idx_leads_landing_page ON public.leads(source_landing_page_id);
