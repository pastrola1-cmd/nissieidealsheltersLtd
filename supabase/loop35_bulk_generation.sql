-- =============================================================================
-- LOOP 35: Bulk Landing Page Generation
-- Adds a database helper function to generate default landing page configs.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.generate_landing_pages_for_company(p_company_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_property RECORD;
  v_generated_count INTEGER := 0;
  v_slug TEXT;
  v_base_slug TEXT;
  v_counter INTEGER;
BEGIN
  FOR v_property IN 
    SELECT id, title FROM public.properties 
    WHERE company_id = p_company_id
      AND id NOT IN (SELECT property_id FROM public.landing_pages WHERE company_id = p_company_id)
  LOOP
    -- Generate base slug
    v_base_slug := lower(regexp_replace(v_property.title, '[^a-zA-Z0-9]+', '-', 'g'));
    -- Trim leading/trailing hyphens
    v_base_slug := trim(both '-' from v_base_slug);
    
    v_slug := v_base_slug;
    v_counter := 1;
    
    -- Ensure unique slug within the company
    WHILE EXISTS (SELECT 1 FROM public.landing_pages WHERE company_id = p_company_id AND slug = v_slug) LOOP
      v_counter := v_counter + 1;
      v_slug := v_base_slug || '-' || v_counter;
    END LOOP;
    
    -- Insert default landing page config
    INSERT INTO public.landing_pages (
      company_id,
      property_id,
      slug,
      status,
      headline,
      cta_primary,
      cta_secondary
    ) VALUES (
      p_company_id,
      v_property.id,
      v_slug,
      'published',
      v_property.title || ' — Premium Property Listing',
      'Book Free Site Inspection',
      'Get Price List'
    );
    
    v_generated_count := v_generated_count + 1;
  END LOOP;
  
  RETURN v_generated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
