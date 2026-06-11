-- =============================================================================
-- LOOP 22: Daily Automated Reporting System Table
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.daily_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  report_date DATE NOT NULL,
  new_leads INTEGER DEFAULT 0,
  follow_ups INTEGER DEFAULT 0,
  inspections_booked INTEGER DEFAULT 0,
  inspections_completed INTEGER DEFAULT 0,
  closed_deals INTEGER DEFAULT 0,
  revenue_today NUMERIC DEFAULT 0,
  top_staff JSONB DEFAULT '[]'::jsonb,
  leads_by_stage JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(company_id, report_date)
);

-- Index for date-based retrieval
CREATE INDEX IF NOT EXISTS idx_daily_reports_date ON public.daily_reports(company_id, report_date);

-- Enable RLS
ALTER TABLE public.daily_reports ENABLE ROW LEVEL SECURITY;

-- Company Isolation Policy
DROP POLICY IF EXISTS daily_reports_company_isolation ON public.daily_reports;

CREATE POLICY daily_reports_company_isolation ON public.daily_reports
  FOR ALL USING (company_id = (SELECT company_id FROM profiles WHERE id = auth.uid()));

-- =============================================================================
-- Automated Daily Aggregator SQL
-- =============================================================================
-- This function aggregates metrics for a company on a specific date.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.generate_daily_report_for_company(p_company_id UUID, p_date DATE)
RETURNS VOID AS $$
DECLARE
  v_new_leads INTEGER;
  v_follow_ups INTEGER;
  v_inspections_booked INTEGER;
  v_inspections_completed INTEGER;
  v_closed_deals INTEGER;
  v_revenue NUMERIC;
  v_top_staff JSONB;
  v_stage_snapshot JSONB;
BEGIN
  -- 1. New Leads
  SELECT COUNT(*)::INTEGER INTO v_new_leads
  FROM public.leads
  WHERE company_id = p_company_id
    AND created_at::DATE = p_date;

  -- 2. Follow-ups (leads updated or touched on p_date)
  SELECT COUNT(*)::INTEGER INTO v_follow_ups
  FROM public.leads
  WHERE company_id = p_company_id
    AND updated_at::DATE = p_date;

  -- 3. Inspections Booked
  SELECT COUNT(*)::INTEGER INTO v_inspections_booked
  FROM public.inspections i
  JOIN public.properties p ON i.property_id = p.id
  WHERE p.company_id = p_company_id
    AND i.created_at::DATE = p_date;

  -- 4. Inspections Completed
  SELECT COUNT(*)::INTEGER INTO v_inspections_completed
  FROM public.inspections i
  JOIN public.properties p ON i.property_id = p.id
  WHERE p.company_id = p_company_id
    AND i.status = 'completed'
    AND i.updated_at::DATE = p_date;

  -- 5. Closed Deals (Commissions approved/paid today)
  SELECT COUNT(*)::INTEGER, COALESCE(SUM(sale_price), 0) INTO v_closed_deals, v_revenue
  FROM public.commissions
  WHERE company_id = p_company_id
    AND status = 'approved'
    AND updated_at::DATE = p_date;

  -- 6. Top Staff performance json
  SELECT json_agg(t)::JSONB INTO v_top_staff
  FROM (
    SELECT 
      p.id as profile_id,
      p.full_name as name,
      COUNT(l.id)::INTEGER as leads_handled,
      COUNT(CASE WHEN l.stage = 'closed' THEN 1 END)::INTEGER as conversions,
      CASE 
        WHEN COUNT(l.id) > 0 THEN (COUNT(CASE WHEN l.stage = 'closed' THEN 1 END)::DOUBLE PRECISION / COUNT(l.id) * 100)
        ELSE 0.0
      END as conversion_rate
    FROM public.profiles p
    LEFT JOIN public.leads l ON l.assigned_agent_id = p.id
    WHERE p.company_id = p_company_id
      AND p.role IN ('manager', 'marketer')
    GROUP BY p.id, p.full_name
    ORDER BY leads_handled DESC
    LIMIT 5
  ) t;

  -- 7. Stage distribution snapshot
  SELECT json_object_agg(stage, cnt)::JSONB INTO v_stage_snapshot
  FROM (
    SELECT stage, COUNT(*)::INTEGER as cnt
    FROM public.leads
    WHERE company_id = p_company_id
    GROUP BY stage
  ) s;

  -- 8. Insert or overwrite report
  INSERT INTO public.daily_reports (
    company_id,
    report_date,
    new_leads,
    follow_ups,
    inspections_booked,
    inspections_completed,
    closed_deals,
    revenue_today,
    top_staff,
    leads_by_stage
  ) VALUES (
    p_company_id,
    p_date,
    v_new_leads,
    v_follow_ups,
    v_inspections_booked,
    v_inspections_completed,
    v_closed_deals,
    v_revenue,
    COALESCE(v_top_staff, '[]'::jsonb),
    COALESCE(v_stage_snapshot, '{}'::jsonb)
  )
  ON CONFLICT (company_id, report_date) 
  DO UPDATE SET
    new_leads = EXCLUDED.new_leads,
    follow_ups = EXCLUDED.follow_ups,
    inspections_booked = EXCLUDED.inspections_booked,
    inspections_completed = EXCLUDED.inspections_completed,
    closed_deals = EXCLUDED.closed_deals,
    revenue_today = EXCLUDED.revenue_today,
    top_staff = EXCLUDED.top_staff,
    leads_by_stage = EXCLUDED.leads_by_stage,
    created_at = now();
END;
$$ LANGUAGE plpgsql;
