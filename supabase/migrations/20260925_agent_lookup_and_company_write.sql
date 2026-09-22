-- Cross-device agent verification + companies INSERT hardening
-- Run after 20260924_security_hardening.sql

-- 1) Staff-only booking lookup by PIN (agents on another device).
--    Never exposes PIN lists; single-row lookup, staff roles only.
CREATE OR REPLACE FUNCTION public.lookup_booking_by_pin(p_pin TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_booking public.inspection_bookings%ROWTYPE;
  v_prop_title TEXT;
BEGIN
  SELECT role INTO v_role FROM public.profiles WHERE id = auth.uid();
  IF v_role IS NULL OR v_role NOT IN ('partner','manager','marketer','admin','platform_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'Staff sign-in required');
  END IF;

  IF p_pin IS NULL OR length(p_pin) <> 4 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Invalid PIN format');
  END IF;

  SELECT * INTO v_booking
  FROM public.inspection_bookings
  WHERE completion_pin = p_pin
    AND status IN ('paid_escrow', 'agent_assigned')
    AND (pin_locked_until IS NULL OR pin_locked_until <= now())
    AND (pin_expires_at IS NULL OR pin_expires_at > now())
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'No active booking for this PIN');
  END IF;

  SELECT title INTO v_prop_title FROM public.properties WHERE id = v_booking.property_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', v_booking.id,
    'property_id', v_booking.property_id,
    'marketplace_property_id', v_booking.marketplace_property_id,
    'property_title', COALESCE(v_prop_title, 'Property inspection'),
    'renter_name', v_booking.renter_name,
    'fee_amount', v_booking.fee_amount,
    'agent_payout_amount', v_booking.agent_payout_amount,
    'platform_fee_amount', v_booking.platform_fee_amount,
    'scheduled_date', v_booking.scheduled_date,
    'scheduled_time', v_booking.scheduled_time
  );
END;
$$;

-- 2) Companies INSERT: previously any authenticated user could insert (no WITH CHECK).
DROP POLICY IF EXISTS companies_write ON public.companies;
CREATE POLICY companies_write ON public.companies
  FOR ALL TO authenticated
  USING (
    (public.get_my_role() = 'admin' AND id = public.get_my_company())
    OR public.get_my_role() = 'platform_admin'
  )
  WITH CHECK (
    public.get_my_role() = 'platform_admin'
  );
