-- =============================================================================
-- LOOP 37: Module Usage & Adoption Analytics
-- Creates database views for super admin dashboard summaries.
-- =============================================================================

-- Database view summarizing landing page adoption and performance stats per company
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

-- Database view summarizing landing page performance rankings across the platform
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
