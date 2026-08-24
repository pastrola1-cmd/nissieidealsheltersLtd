-- =============================================================================
-- PAYMENT PLANS & MILESTONE RECOVERY ENGINE
-- =============================================================================

-- 1. Payment Plans Table
CREATE TABLE IF NOT EXISTS public.payment_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  lead_id UUID REFERENCES public.leads(id) ON DELETE SET NULL,
  buyer_name TEXT NOT NULL,
  buyer_phone TEXT NOT NULL,
  buyer_email TEXT,
  property_id UUID REFERENCES public.properties(id) ON DELETE SET NULL,
  property_name TEXT NOT NULL,
  plot_number TEXT,
  total_amount NUMERIC NOT NULL,
  initial_deposit NUMERIC NOT NULL DEFAULT 0,
  balance_amount NUMERIC NOT NULL DEFAULT 0,
  duration_months INT NOT NULL DEFAULT 1,
  start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'defaulted', 'cancelled')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Payment Milestones Table
CREATE TABLE IF NOT EXISTS public.payment_milestones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_plan_id UUID REFERENCES public.payment_plans(id) ON DELETE CASCADE NOT NULL,
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  milestone_number INT NOT NULL,
  due_date DATE NOT NULL,
  expected_amount NUMERIC NOT NULL,
  paid_amount NUMERIC NOT NULL DEFAULT 0,
  paid_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue', 'partial')),
  receipt_number TEXT,
  payment_method TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_payment_plans_company ON public.payment_plans(company_id, status);
CREATE INDEX IF NOT EXISTS idx_payment_plans_lead ON public.payment_plans(lead_id);
CREATE INDEX IF NOT EXISTS idx_payment_milestones_plan ON public.payment_milestones(payment_plan_id, due_date);
CREATE INDEX IF NOT EXISTS idx_payment_milestones_status ON public.payment_milestones(company_id, status, due_date);

-- 4. Trigger to Auto-Update Payment Plan Balance & Milestone Status
CREATE OR REPLACE FUNCTION public.handle_payment_milestone_update()
RETURNS TRIGGER AS $$
DECLARE
  v_total_paid NUMERIC;
  v_plan_total NUMERIC;
  v_deposit NUMERIC;
BEGIN
  -- Determine milestone status based on payment
  IF NEW.paid_amount >= NEW.expected_amount THEN
    NEW.status := 'paid';
    IF NEW.paid_at IS NULL THEN
      NEW.paid_at := now();
    END IF;
  ELSIF NEW.paid_amount > 0 THEN
    NEW.status := 'partial';
  ELSIF NEW.due_date < CURRENT_DATE THEN
    NEW.status := 'overdue';
  ELSE
    NEW.status := 'pending';
  END IF;

  NEW.updated_at := now();

  -- Recalculate parent payment plan balance
  SELECT COALESCE(SUM(paid_amount), 0) INTO v_total_paid
  FROM public.payment_milestones
  WHERE payment_plan_id = NEW.payment_plan_id
    AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::UUID);

  v_total_paid := v_total_paid + NEW.paid_amount;

  SELECT total_amount, initial_deposit INTO v_plan_total, v_deposit
  FROM public.payment_plans
  WHERE id = NEW.payment_plan_id;

  UPDATE public.payment_plans
  SET 
    balance_amount = GREATEST(0, v_plan_total - (v_deposit + v_total_paid)),
    status = CASE 
      WHEN (v_deposit + v_total_paid) >= v_plan_total THEN 'completed'
      ELSE 'active'
    END,
    updated_at = now()
  WHERE id = NEW.payment_plan_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_payment_milestone_update ON public.payment_milestones;
CREATE TRIGGER trigger_payment_milestone_update
  BEFORE INSERT OR UPDATE ON public.payment_milestones
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_payment_milestone_update();

-- 5. Enable RLS
ALTER TABLE public.payment_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_milestones ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies
DROP POLICY IF EXISTS "payment_plans_company_policy" ON public.payment_plans;
CREATE POLICY "payment_plans_company_policy" ON public.payment_plans
  FOR ALL TO authenticated
  USING (company_id = public.get_my_company());

DROP POLICY IF EXISTS "payment_milestones_company_policy" ON public.payment_milestones;
CREATE POLICY "payment_milestones_company_policy" ON public.payment_milestones
  FOR ALL TO authenticated
  USING (company_id = public.get_my_company());
