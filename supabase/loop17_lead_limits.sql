-- =============================================================================
-- LOOP 17: Monthly Lead Creation Limits
-- =============================================================================

-- 1. Add custom_lead_limit column to companies table
ALTER TABLE public.companies
  ADD COLUMN IF NOT EXISTS custom_lead_limit INTEGER;

-- 2. Define the RPC function to count monthly leads
CREATE OR REPLACE FUNCTION public.get_monthly_lead_count(p_company_id UUID)
RETURNS INTEGER AS $$
  SELECT COUNT(*)::INTEGER
  FROM public.leads
  WHERE company_id = p_company_id
    AND created_at >= date_trunc('month', now());
$$ LANGUAGE sql SECURITY DEFINER STABLE;
