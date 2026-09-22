-- PIN hardening: expiry (48h), attempt counter, lockout (5 fails -> 15 min)
-- Run after 20260920_fix_wallet_payout_and_rls.sql

ALTER TABLE public.inspection_bookings
  ADD COLUMN IF NOT EXISTS pin_expires_at TIMESTAMPTZ DEFAULT now() + interval '48 hours',
  ADD COLUMN IF NOT EXISTS pin_attempts INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pin_locked_until TIMESTAMPTZ;

-- Backfill existing rows
UPDATE public.inspection_bookings
SET pin_expires_at = COALESCE(pin_expires_at, created_at + interval '48 hours')
WHERE pin_expires_at IS NULL;

CREATE OR REPLACE FUNCTION public.settle_inspection_pin_payout(
  p_booking_id UUID, p_pin TEXT, p_agent_user_id UUID
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_booking public.inspection_bookings%ROWTYPE;
  v_renter_wallet public.wallets%ROWTYPE;
  v_agent_wallet public.wallets%ROWTYPE;
  v_total NUMERIC;
BEGIN
  SELECT * INTO v_booking FROM public.inspection_bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Booking not found');
  END IF;
  IF v_booking.status = 'completed' OR v_booking.status = 'cancelled' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Booking already settled');
  END IF;
  -- Lockout check
  IF v_booking.pin_locked_until IS NOT NULL AND v_booking.pin_locked_until > now() THEN
    RETURN jsonb_build_object('success', false, 'message', 'Too many attempts. Try again later.');
  END IF;
  -- Expiry check
  IF v_booking.pin_expires_at IS NOT NULL AND v_booking.pin_expires_at < now() THEN
    RETURN jsonb_build_object('success', false, 'message', 'PIN expired. Ask renter to rebook.');
  END IF;
  -- Exact PIN match; count failures
  IF v_booking.completion_pin IS NULL OR v_booking.completion_pin <> p_pin THEN
    UPDATE public.inspection_bookings
    SET pin_attempts = COALESCE(pin_attempts, 0) + 1,
        pin_locked_until = CASE WHEN COALESCE(pin_attempts, 0) + 1 >= 5 THEN now() + interval '15 minutes' ELSE pin_locked_until END,
        updated_at = now()
    WHERE id = p_booking_id;
    RETURN jsonb_build_object('success', false, 'message', 'Invalid PIN');
  END IF;
  -- Reset counters on success
  UPDATE public.inspection_bookings
  SET pin_attempts = 0, pin_locked_until = NULL, updated_at = now()
  WHERE id = p_booking_id;

  IF COALESCE(v_booking.fee_amount, 0) <= 0 THEN
    UPDATE public.inspection_bookings
    SET status='completed', escrow_released_at=now(), updated_at=now()
    WHERE id = p_booking_id;
    RETURN jsonb_build_object('success', true, 'free', true);
  END IF;
  v_total := COALESCE(v_booking.fee_amount, 3000);
  v_renter_wallet := public.get_or_create_wallet(v_booking.renter_id);
  v_agent_wallet := public.get_or_create_wallet(p_agent_user_id);
  IF v_renter_wallet.ledger_balance >= v_total THEN
    UPDATE public.wallets SET ledger_balance = ledger_balance - v_total, updated_at=now()
    WHERE id = v_renter_wallet.id;
  END IF;
  UPDATE public.wallets SET balance = balance + v_booking.agent_payout_amount, updated_at=now()
  WHERE id = v_agent_wallet.id RETURNING * INTO v_agent_wallet;
  INSERT INTO public.wallet_transactions
    (wallet_id, user_id, amount, type, direction, reference, description, status, metadata)
  VALUES (
    v_agent_wallet.id, p_agent_user_id, v_booking.agent_payout_amount, 'commission', 'inflow',
    'PAYOUT_AGT_' || p_booking_id::text || '_' || floor(extract(epoch from now())),
    'Tour fee earned (booking ' || substr(p_booking_id::text,1,8) || ')',
    'completed', jsonb_build_object('booking_id', p_booking_id)
  );
  UPDATE public.inspection_bookings
  SET status='completed', escrow_released_at=now(), updated_at=now()
  WHERE id = p_booking_id;
  RETURN jsonb_build_object('success', true, 'agent_credited', v_booking.agent_payout_amount);
END;
$$;
