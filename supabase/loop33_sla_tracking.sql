-- =============================================================================
-- LOOP 33: Agent SLA Tracking
-- Adds support for tracking response times and SLA metrics on leads.
-- =============================================================================

-- 1. Add Columns to leads table
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS first_response_at TIMESTAMPTZ;

-- 2. Create trigger function to log lead first response timestamp
CREATE OR REPLACE FUNCTION public.log_lead_first_response()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.stage = 'new' AND NEW.stage <> 'new' AND NEW.first_response_at IS NULL THEN
    NEW.first_response_at := now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Create the trigger
DROP TRIGGER IF EXISTS trg_lead_first_response ON public.leads;
CREATE TRIGGER trg_lead_first_response
  BEFORE UPDATE ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION public.log_lead_first_response();

-- 4. Create the view for dynamic SLA calculation
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

-- 5. Create view for per-agent performance
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

-- 6. Create RPC function to get SLA stats for a company
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
  -- Total metrics
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

  -- Overdue leads sorted by how overdue
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

  -- Agent breakdown
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
