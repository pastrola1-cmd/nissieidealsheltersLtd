-- =============================================================================
-- LOOP 23: Goal Tracking System Tables & RLS Policies
-- =============================================================================
-- Run this migration in the Supabase SQL Editor.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.goals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  metric TEXT NOT NULL CHECK (metric IN ('leads', 'closings', 'revenue')),
  horizon TEXT NOT NULL CHECK (horizon IN ('monthly', 'quarterly', '6month', 'yearly')),
  target_value NUMERIC NOT NULL CHECK (target_value >= 0),
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT check_dates CHECK (period_start <= period_end),
  UNIQUE(company_id, metric, horizon, period_start)
);

-- Index for querying active goals
CREATE INDEX IF NOT EXISTS idx_goals_company_period ON public.goals(company_id, period_start, period_end);

-- Enable RLS
ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;

-- Select policy: Admins and Managers in the company can view goals
DROP POLICY IF EXISTS goals_select ON public.goals;
CREATE POLICY goals_select ON public.goals
  FOR SELECT TO authenticated
  USING (company_id = public.get_my_company());

-- Write policy: Only Admins can set or modify goals
DROP POLICY IF EXISTS goals_write ON public.goals;
CREATE POLICY goals_write ON public.goals
  FOR ALL TO authenticated
  USING (
    public.get_my_role() = 'admin' 
    AND company_id = public.get_my_company()
  );
