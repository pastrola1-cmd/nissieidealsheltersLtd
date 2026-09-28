-- Migration: 20260928_update_inspection_fee_to_10k.sql
-- Update standard inspection fee from 3,000 to 10,000 Naira across database defaults and functions

-- 1) Update column defaults in properties
ALTER TABLE public.properties ALTER COLUMN inspection_fee SET DEFAULT 10000;

-- 2) Update column defaults in inspection_bookings
ALTER TABLE public.inspection_bookings ALTER COLUMN fee_amount SET DEFAULT 10000;
ALTER TABLE public.inspection_bookings ALTER COLUMN agent_payout_amount SET DEFAULT 7000;
ALTER TABLE public.inspection_bookings ALTER COLUMN platform_fee_amount SET DEFAULT 3000;

-- 3) Update existing properties that had the default 3000 fee to 10000
UPDATE public.properties 
SET inspection_fee = 10000 
WHERE inspection_fee = 3000 OR inspection_fee IS NULL;

-- 4) Update settle_inspection_pin_payout to use 10000 as fallback
CREATE OR REPLACE FUNCTION public.settle_inspection_pin_payout(
  p_booking_id UUID, p_pin TEXT, p_agent_user_id UUID
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_booking public.inspection_bookings%ROWTYPE;
  v_renter_wallet public.wallets%ROWTYPE;
  v_agent_wallet public.wallets%ROWTYPE;
  v_total NUMERIC;
  v_caller_role TEXT;
BEGIN
  -- Restrict execution to staff/agent roles or service_role
  SELECT role INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
  IF auth.role() <> 'service_role' AND (v_caller_role IS NULL OR v_caller_role NOT IN ('marketer', 'partner', 'admin', 'manager', 'platform_admin')) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Forbidden: staff role required');
  END IF;

  SELECT * INTO v_booking FROM public.inspection_bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
  END IF;

  IF v_booking.status = 'completed' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking already completed and settled');
  END IF;

  IF v_booking.completion_pin <> p_pin THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid PIN');
  END IF;

  IF COALESCE(v_booking.fee_amount, 0) <= 0 THEN
    UPDATE public.inspection_bookings
    SET status='completed', escrow_released_at=now(), updated_at=now()
    WHERE id = p_booking_id;
    RETURN jsonb_build_object('success', true, 'free', true);
  END IF;

  v_total := COALESCE(v_booking.fee_amount, 10000);
  v_renter_wallet := public.get_or_create_wallet(v_booking.renter_id);
  v_agent_wallet := public.get_or_create_wallet(p_agent_user_id);

  IF v_renter_wallet.ledger_balance >= v_total THEN
    UPDATE public.wallets SET ledger_balance = ledger_balance - v_total, updated_at=now()
    WHERE id = v_renter_wallet.id;
  END IF;

  UPDATE public.wallets SET balance = balance + COALESCE(v_booking.agent_payout_amount, 7000), updated_at=now()
  WHERE id = v_agent_wallet.id RETURNING * INTO v_agent_wallet;

  INSERT INTO public.wallet_transactions
    (wallet_id, user_id, amount, type, direction, reference, description, status, metadata)
  VALUES (
    v_agent_wallet.id, p_agent_user_id, COALESCE(v_booking.agent_payout_amount, 7000), 'commission', 'inflow',
    'PAYOUT_AGT_' || p_booking_id::text || '_' || floor(extract(epoch from now())),
    'Tour fee earned (booking ' || substr(p_booking_id::text,1,8) || ')',
    'completed', jsonb_build_object('booking_id', p_booking_id)
  );

  UPDATE public.inspection_bookings
  SET status='completed', escrow_released_at=now(), updated_at=now()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object('success', true, 'agent_credited', COALESCE(v_booking.agent_payout_amount, 7000));
END;
$$;
