-- =============================================================================
-- PPN CONSOLIDATED MIGRATION CATCH-UP (LOOPS 31 - 37)
-- Run this script in your Supabase SQL Editor to sync the remote schema!
-- =============================================================================

-- 1. ADD NEW COLUMNS TO COMPANIES TABLE
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS whatsapp_phone_number_id TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS whatsapp_waba_id TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS whatsapp_access_token TEXT;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS whatsapp_enabled BOOLEAN DEFAULT false;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS whatsapp_template_name TEXT DEFAULT 'property_inquiry_auto';
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS custom_domain TEXT UNIQUE;

CREATE INDEX IF NOT EXISTS idx_companies_custom_domain ON public.companies(custom_domain);


-- 2. ADD NEW COLUMNS TO LEADS TABLE
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS intent_score TEXT DEFAULT 'Cold' CHECK (intent_score IN ('Cold', 'Warm', 'Hot'));
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS engagement_signals JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS first_response_at TIMESTAMPTZ;


-- 3. CREATE WHATSAPP_MESSAGES LOG TABLE
CREATE TABLE IF NOT EXISTS public.whatsapp_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  lead_id UUID REFERENCES public.leads(id) ON DELETE CASCADE NOT NULL,
  message_sid TEXT UNIQUE,
  recipient_phone TEXT NOT NULL,
  template_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'read', 'failed')),
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.whatsapp_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS whatsapp_messages_select ON public.whatsapp_messages;
CREATE POLICY whatsapp_messages_select ON public.whatsapp_messages
  FOR SELECT TO authenticated
  USING (company_id = public.get_my_company());


-- 4. CREATE LEAD FIRST RESPONSE TRIGGER
CREATE OR REPLACE FUNCTION public.log_lead_first_response()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.stage = 'new' AND NEW.stage <> 'new' AND NEW.first_response_at IS NULL THEN
    NEW.first_response_at := now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_lead_first_response ON public.leads;
CREATE TRIGGER trg_lead_first_response
  BEFORE UPDATE ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION public.log_lead_first_response();


-- 5. CREATE SLA TRACKING VIEWS & RPC FUNCTIONS
CREATE OR REPLACE VIEW public.lead_sla_metrics AS
SELECT
  l.id AS lead_id,
  l.company_id,
  l.assigned_agent_id,
  l.intent_score,
  l.created_at,
  l.first_response_at,
  l.stage,
  CASE
    WHEN l.intent_score = 'Hot' THEN INTERVAL '15 minutes'
    WHEN l.intent_score = 'Warm' THEN INTERVAL '2 hours'
    ELSE INTERVAL '24 hours'
  END AS sla_threshold,
  (l.first_response_at IS NOT NULL) AS is_responded,
  CASE
    WHEN l.first_response_at IS NOT NULL THEN EXTRACT(EPOCH FROM (l.first_response_at - l.created_at))
    ELSE NULL
  END AS response_time_seconds,
  CASE
    WHEN l.first_response_at IS NOT NULL THEN
      (l.first_response_at - l.created_at) <= 
        CASE
          WHEN l.intent_score = 'Hot' THEN INTERVAL '15 minutes'
          WHEN l.intent_score = 'Warm' THEN INTERVAL '2 hours'
          ELSE INTERVAL '24 hours'
        END
    ELSE
      (now() - l.created_at) <= 
        CASE
          WHEN l.intent_score = 'Hot' THEN INTERVAL '15 minutes'
          WHEN l.intent_score = 'Warm' THEN INTERVAL '2 hours'
          ELSE INTERVAL '24 hours'
        END
  END AS is_sla_compliant,
  (l.first_response_at IS NULL AND (now() - l.created_at) > 
    CASE
      WHEN l.intent_score = 'Hot' THEN INTERVAL '15 minutes'
      WHEN l.intent_score = 'Warm' THEN INTERVAL '2 hours'
      ELSE INTERVAL '24 hours'
    END) AS is_overdue,
  CASE
    WHEN l.first_response_at IS NULL AND (now() - l.created_at) > 
      CASE
        WHEN l.intent_score = 'Hot' THEN INTERVAL '15 minutes'
        WHEN l.intent_score = 'Warm' THEN INTERVAL '2 hours'
        ELSE INTERVAL '24 hours'
      END
    THEN EXTRACT(EPOCH FROM (now() - (l.created_at + 
      CASE
        WHEN l.intent_score = 'Hot' THEN INTERVAL '15 minutes'
        WHEN l.intent_score = 'Warm' THEN INTERVAL '2 hours'
        ELSE INTERVAL '24 hours'
      END)))
    ELSE 0
  END AS overdue_by_seconds
FROM public.leads l;

CREATE OR REPLACE VIEW public.agent_sla_performance AS
SELECT
  m.company_id,
  m.assigned_agent_id,
  p.full_name AS agent_name,
  COUNT(m.lead_id) AS total_leads,
  COUNT(CASE WHEN m.is_responded THEN 1 END) AS responded_leads,
  COUNT(CASE WHEN m.is_sla_compliant THEN 1 END) AS compliant_leads,
  ROUND(
    (COUNT(CASE WHEN m.is_sla_compliant THEN 1 END)::numeric / COUNT(m.lead_id)::numeric) * 100, 
    2
  ) AS compliance_rate,
  AVG(m.response_time_seconds) AS avg_response_time_seconds
FROM public.lead_sla_metrics m
LEFT JOIN public.profiles p ON p.id = m.assigned_agent_id
GROUP BY m.company_id, m.assigned_agent_id, p.full_name;

CREATE OR REPLACE FUNCTION public.get_company_sla_stats(p_company_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_total_leads INTEGER;
  v_compliant_leads INTEGER;
  v_compliance_rate NUMERIC;
  v_avg_response_time DOUBLE PRECISION;
  v_overdue_leads JSONB;
  v_agent_breakdown JSONB;
BEGIN
  SELECT 
    COUNT(*),
    COUNT(CASE WHEN is_sla_compliant THEN 1 END),
    AVG(response_time_seconds)
  INTO v_total_leads, v_compliant_leads, v_avg_response_time
  FROM public.lead_sla_metrics
  WHERE company_id = p_company_id;

  IF v_total_leads > 0 THEN
    v_compliance_rate := ROUND((v_compliant_leads::numeric / v_total_leads::numeric) * 100, 2);
  ELSE
    v_compliance_rate := 100.00;
  END IF;

  SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO v_overdue_leads
  FROM (
    SELECT 
      lead_id,
      (SELECT buyer_name FROM public.leads WHERE id = lead_id) AS buyer_name,
      intent_score,
      created_at,
      overdue_by_seconds
    FROM public.lead_sla_metrics
    WHERE company_id = p_company_id AND is_overdue = true
    ORDER BY overdue_by_seconds DESC
    LIMIT 10
  ) t;

  SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO v_agent_breakdown
  FROM (
    SELECT 
      assigned_agent_id,
      agent_name,
      total_leads,
      compliance_rate,
      avg_response_time_seconds
    FROM public.agent_sla_performance
    WHERE company_id = p_company_id
  ) t;

  RETURN jsonb_build_object(
    'total_leads', v_total_leads,
    'compliant_leads', v_compliant_leads,
    'compliance_rate', v_compliance_rate,
    'avg_response_time_seconds', COALESCE(v_avg_response_time, 0),
    'overdue_leads', v_overdue_leads,
    'agent_breakdown', v_agent_breakdown
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 6. CREATE INTENT SCORING FUNCTIONS
CREATE OR REPLACE FUNCTION public.recalculate_lead_intent_score(p_lead_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_buyer_phone TEXT;
  v_company_id UUID;
  v_property_count INTEGER;
  v_signals JSONB;
  v_score TEXT := 'Cold';
  v_video_progress INTEGER := 0;
  v_scroll_depth INTEGER := 0;
  v_time_on_page INTEGER := 0;
  v_visit_count INTEGER := 1;
  v_created_at TIMESTAMPTZ;
  v_last_visit_at TIMESTAMPTZ;
BEGIN
  SELECT buyer_phone, company_id, engagement_signals, created_at
  INTO v_buyer_phone, v_company_id, v_signals, v_created_at
  FROM public.leads
  WHERE id = p_lead_id;

  IF v_buyer_phone IS NULL THEN
    RETURN 'Cold';
  END IF;

  SELECT COUNT(DISTINCT property_id) INTO v_property_count
  FROM public.leads
  WHERE buyer_phone = v_buyer_phone AND company_id = v_company_id;

  v_video_progress := COALESCE((v_signals->>'max_video_progress')::integer, 0);
  v_scroll_depth := COALESCE((v_signals->>'max_scroll_depth')::integer, 0);
  v_time_on_page := COALESCE((v_signals->>'time_on_page_seconds')::integer, 0);
  v_visit_count := COALESCE((v_signals->>'visit_count')::integer, 1);
  IF v_signals->>'last_visit_at' IS NOT NULL THEN
    v_last_visit_at := (v_signals->>'last_visit_at')::timestamptz;
  END IF;

  IF v_property_count >= 2 THEN
    v_score := 'Hot';
  ELSIF v_video_progress >= 75 AND v_time_on_page >= 60 THEN
    v_score := 'Hot';
  ELSIF v_visit_count >= 2 AND v_last_visit_at IS NOT NULL AND (v_last_visit_at - v_created_at) <= INTERVAL '48 hours' AND (v_video_progress > 25 OR v_scroll_depth > 50) THEN
    v_score := 'Hot';
  ELSIF v_video_progress >= 50 OR v_scroll_depth >= 75 OR v_time_on_page >= 60 OR v_visit_count >= 2 THEN
    v_score := 'Warm';
  ELSE
    v_score := 'Cold';
  END IF;

  UPDATE public.leads
  SET intent_score = v_score,
      updated_at = now()
  WHERE id = p_lead_id;

  IF v_property_count >= 2 AND v_score = 'Hot' THEN
    UPDATE public.leads
    SET intent_score = 'Hot',
        updated_at = now()
    WHERE buyer_phone = v_buyer_phone AND company_id = v_company_id AND intent_score <> 'Hot';
  END IF;

  RETURN v_score;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.log_lead_engagement(
  p_lead_id UUID,
  p_signal_type TEXT,
  p_signal_value TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_signals JSONB;
BEGIN
  SELECT COALESCE(engagement_signals, '{}'::jsonb) INTO v_signals
  FROM public.leads
  WHERE id = p_lead_id;

  IF p_signal_type = 'video_progress' THEN
    v_signals := jsonb_set(
      v_signals,
      '{max_video_progress}',
      to_jsonb(GREATEST(COALESCE((v_signals->>'max_video_progress')::integer, 0), p_signal_value::integer))
    );
  ELSIF p_signal_type = 'scroll_depth' THEN
    v_signals := jsonb_set(
      v_signals,
      '{max_scroll_depth}',
      to_jsonb(GREATEST(COALESCE((v_signals->>'max_scroll_depth')::integer, 0), p_signal_value::integer))
    );
  ELSIF p_signal_type = 'time_on_page' THEN
    v_signals := jsonb_set(
      v_signals,
      '{time_on_page_seconds}',
      to_jsonb(GREATEST(COALESCE((v_signals->>'time_on_page_seconds')::integer, 0), p_signal_value::integer))
    );
  ELSIF p_signal_type = 'page_visit' THEN
    v_signals := jsonb_set(
      v_signals,
      '{visit_count}',
      to_jsonb(COALESCE((v_signals->>'visit_count')::integer, 0) + 1)
    );
    v_signals := jsonb_set(
      v_signals,
      '{last_visit_at}',
      to_jsonb(p_signal_value)
    );
  END IF;

  UPDATE public.leads
  SET engagement_signals = v_signals,
      updated_at = now()
  WHERE id = p_lead_id;

  PERFORM public.recalculate_lead_intent_score(p_lead_id);

  RETURN v_signals;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 7. CREATE BULK LANDING PAGE GENERATION ENGINE
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
    v_base_slug := lower(regexp_replace(v_property.title, '[^a-zA-Z0-9]+', '-', 'g'));
    v_base_slug := trim(both '-' from v_base_slug);
    
    v_slug := v_base_slug;
    v_counter := 1;
    
    WHILE EXISTS (SELECT 1 FROM public.landing_pages WHERE company_id = p_company_id AND slug = v_slug) LOOP
      v_counter := v_counter + 1;
      v_slug := v_base_slug || '-' || v_counter;
    END LOOP;
    
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


-- 8. CREATE LANDING PAGE VARIANTS TABLE (A/B TESTING)
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

ALTER TABLE public.landing_page_variants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS variants_select ON public.landing_page_variants;
DROP POLICY IF EXISTS variants_insert ON public.landing_page_variants;
DROP POLICY IF EXISTS variants_update ON public.landing_page_variants;
DROP POLICY IF EXISTS variants_delete ON public.landing_page_variants;

CREATE POLICY variants_select ON public.landing_page_variants FOR SELECT USING (true);

CREATE POLICY variants_insert ON public.landing_page_variants FOR INSERT TO authenticated
  WITH CHECK (public.get_my_role() IN ('admin', 'platform_admin', 'manager', 'marketer') AND company_id = public.get_my_company());

CREATE POLICY variants_update ON public.landing_page_variants FOR UPDATE TO authenticated
  USING (public.get_my_role() IN ('admin', 'platform_admin', 'manager', 'marketer') AND company_id = public.get_my_company());

CREATE POLICY variants_delete ON public.landing_page_variants FOR DELETE TO authenticated
  USING (public.get_my_role() IN ('admin', 'platform_admin', 'manager') AND company_id = public.get_my_company());

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

CREATE INDEX IF NOT EXISTS idx_variants_landing_page ON public.landing_page_variants(landing_page_id);
CREATE INDEX IF NOT EXISTS idx_variants_company ON public.landing_page_variants(company_id);


-- 9. CREATE USAGE ANALYTICS VIEWS
CREATE OR REPLACE VIEW public.platform_lp_adoption_summary AS
SELECT
  c.id AS company_id,
  c.name AS company_name,
  c.subscription_tier,
  COUNT(lp.id) AS total_landing_pages,
  COALESCE(SUM(lp.views_count), 0) AS total_views,
  (SELECT COUNT(*) FROM public.leads l WHERE l.company_id = c.id AND l.source_channel = 'landing_page') AS total_leads
FROM public.companies c
LEFT JOIN public.landing_pages lp ON lp.company_id = c.id
GROUP BY c.id, c.name, c.subscription_tier;

ALTER VIEW public.platform_lp_adoption_summary OWNER TO postgres;
GRANT SELECT ON public.platform_lp_adoption_summary TO authenticated;

CREATE OR REPLACE VIEW public.platform_lp_performance_ranking AS
SELECT
  lp.id AS landing_page_id,
  lp.slug,
  lp.views_count,
  c.name AS company_name,
  p.title AS property_title,
  COUNT(l.id) AS leads_count,
  CASE 
    WHEN lp.views_count > 0 THEN (COUNT(l.id)::double precision / lp.views_count::double precision * 100.0)
    ELSE 0.0
  END AS conversion_rate
FROM public.landing_pages lp
JOIN public.companies c ON c.id = lp.company_id
JOIN public.properties p ON p.id = lp.property_id
LEFT JOIN public.leads l ON l.source_landing_page_id = lp.id
GROUP BY lp.id, lp.slug, lp.views_count, c.name, p.title;

ALTER VIEW public.platform_lp_performance_ranking OWNER TO postgres;
GRANT SELECT ON public.platform_lp_performance_ranking TO authenticated;
