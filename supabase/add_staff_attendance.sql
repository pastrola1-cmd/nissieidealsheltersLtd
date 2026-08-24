-- =============================================================================
-- NISSIE IDEAL SHELTERS - STAFF ATTENDANCE & ANTI-CHEAT CLOCK-IN SYSTEM
-- Run this in your Supabase SQL Editor (https://supabase.com)
-- =============================================================================

-- 1. Create staff_attendance table
CREATE TABLE IF NOT EXISTS public.staff_attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  work_date DATE NOT NULL DEFAULT CURRENT_DATE,
  clock_in_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  clock_out_at TIMESTAMPTZ,
  work_mode TEXT NOT NULL DEFAULT 'office' CHECK (work_mode IN ('office', 'field', 'remote')),
  status TEXT NOT NULL DEFAULT 'clocked_in' CHECK (status IN ('clocked_in', 'clocked_out', 'on_break')),
  is_late BOOLEAN NOT NULL DEFAULT false,
  location_lat NUMERIC,
  location_lng NUMERIC,
  location_name TEXT,
  clock_out_lat NUMERIC,
  clock_out_lng NUMERIC,
  clock_out_location_name TEXT,
  property_id UUID REFERENCES public.properties(id) ON DELETE SET NULL,
  property_name TEXT,
  notes TEXT,
  total_minutes INT DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT unique_staff_work_session UNIQUE (user_id, work_date, clock_in_at)
);

-- 2. Create performance indexes
CREATE INDEX IF NOT EXISTS idx_staff_attendance_company_date ON public.staff_attendance(company_id, work_date);
CREATE INDEX IF NOT EXISTS idx_staff_attendance_user_date ON public.staff_attendance(user_id, work_date);
CREATE INDEX IF NOT EXISTS idx_staff_attendance_status ON public.staff_attendance(company_id, status);

-- 3. Trigger to auto-calculate total_minutes and is_late upon insert/update
CREATE OR REPLACE FUNCTION public.handle_staff_attendance_calc()
RETURNS TRIGGER AS $$
DECLARE
  clock_in_time_only TIME;
BEGIN
  -- Extract local time of clock_in (default office start cutoff is 08:30:00 WAT / UTC+1)
  -- If clocking in after 08:30:00 WAT, flag as late
  clock_in_time_only := (NEW.clock_in_at AT TIME ZONE 'Africa/Lagos')::TIME;
  IF clock_in_time_only > '08:30:00'::TIME THEN
    NEW.is_late := true;
  ELSE
    NEW.is_late := false;
  END IF;

  -- If clock_out_at is provided, compute total_minutes and set status to clocked_out
  IF NEW.clock_out_at IS NOT NULL THEN
    NEW.total_minutes := GREATEST(0, ROUND(EXTRACT(EPOCH FROM (NEW.clock_out_at - NEW.clock_in_at)) / 60)::INT);
    NEW.status := 'clocked_out';
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_staff_attendance_calc ON public.staff_attendance;
CREATE TRIGGER trigger_staff_attendance_calc
  BEFORE INSERT OR UPDATE ON public.staff_attendance
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_staff_attendance_calc();

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.staff_attendance ENABLE ROW LEVEL SECURITY;

-- 5. Create RLS Policies
-- SELECT: Users can view their own records; Company Admin, Manager, and Platform Admin can view all company records
DROP POLICY IF EXISTS "staff_attendance_select_policy" ON public.staff_attendance;
CREATE POLICY "staff_attendance_select_policy" ON public.staff_attendance
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR (
      company_id = public.get_my_company()
      AND public.get_my_role() IN ('admin', 'manager', 'platform_admin')
    )
  );

-- INSERT: Authenticated users can insert their own clock-in session for their company
DROP POLICY IF EXISTS "staff_attendance_insert_policy" ON public.staff_attendance;
CREATE POLICY "staff_attendance_insert_policy" ON public.staff_attendance
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND company_id = public.get_my_company()
  );

-- UPDATE: Users can update (clock out) their own active session; Admins/Managers can edit records in their company
DROP POLICY IF EXISTS "staff_attendance_update_policy" ON public.staff_attendance;
CREATE POLICY "staff_attendance_update_policy" ON public.staff_attendance
  FOR UPDATE TO authenticated
  USING (
    user_id = auth.uid()
    OR (
      company_id = public.get_my_company()
      AND public.get_my_role() IN ('admin', 'manager', 'platform_admin')
    )
  );

-- DELETE: Admins and Platform Admins only
DROP POLICY IF EXISTS "staff_attendance_delete_policy" ON public.staff_attendance;
CREATE POLICY "staff_attendance_delete_policy" ON public.staff_attendance
  FOR DELETE TO authenticated
  USING (
    company_id = public.get_my_company()
    AND public.get_my_role() IN ('admin', 'platform_admin')
  );
