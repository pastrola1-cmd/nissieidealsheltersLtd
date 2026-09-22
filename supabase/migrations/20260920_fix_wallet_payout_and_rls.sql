-- Fix: payout PIN logic, inspection_bookings table, and least-privilege RLS
-- Apply AFTER add_marketplace_and_wallet.sql + 20260919_production_wallet_ledger.sql

-- 1) Correct payout function: OR logic, exact PIN match, correct table
CREATE OR REPLACE FUNCTION public.settle_inspection_pin_payout(
    p_booking_id UUID,
    p_pin TEXT,
    p_agent_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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

    -- Reject already-settled bookings (correct OR logic)
    IF v_booking.status = 'completed' OR v_booking.status = 'cancelled' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Booking already settled');
    END IF;

    -- Exact PIN match (no substring on notes)
    IF v_booking.completion_pin IS NULL OR v_booking.completion_pin <> p_pin THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invalid PIN');
    END IF;

    -- Free inspections: mark complete, no money moves
    IF COALESCE(v_booking.fee_amount, 0) <= 0 THEN
        UPDATE public.inspection_bookings
        SET status = 'completed', escrow_released_at = now(), updated_at = now()
        WHERE id = p_booking_id;
        RETURN jsonb_build_object('success', true, 'free', true);
    END IF;

    v_total := COALESCE(v_booking.fee_amount, 3000);
    v_renter_wallet := public.get_or_create_wallet(v_booking.renter_id);
    v_agent_wallet := public.get_or_create_wallet(p_agent_user_id);

    IF v_renter_wallet.ledger_balance >= v_total THEN
        UPDATE public.wallets SET ledger_balance = ledger_balance - v_total, updated_at = now()
        WHERE id = v_renter_wallet.id;
    END IF;

    UPDATE public.wallets SET balance = balance + v_booking.agent_payout_amount, updated_at = now()
    WHERE id = v_agent_wallet.id RETURNING * INTO v_agent_wallet;

    INSERT INTO public.wallet_transactions
        (wallet_id, user_id, amount, type, direction, reference, description, status, metadata)
    VALUES (
        v_agent_wallet.id, p_agent_user_id, v_booking.agent_payout_amount, 'commission', 'inflow',
        'PAYOUT_AGT_' || p_booking_id::text || '_' || floor(extract(epoch from now())),
        'Tour fee earned (booking ' || substr(p_booking_id::text, 1, 8) || ')',
        'completed', jsonb_build_object('booking_id', p_booking_id)
    );

    UPDATE public.inspection_bookings
    SET status = 'completed', escrow_released_at = now(), updated_at = now()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object('success', true, 'agent_credited', v_booking.agent_payout_amount);
END;
$$;

-- 2) Least-privilege RLS: drop permissive FOR ALL policies, replace with split policies
-- Wallets: no direct client UPDATE/INSERT/DELETE; only RPC (SECURITY DEFINER) mutates.
DROP POLICY IF EXISTS "wallets_user_policy" ON public.wallets;
DROP POLICY IF EXISTS "wallets_select_own" ON public.wallets;
CREATE POLICY "wallets_select_own" ON public.wallets
    FOR SELECT TO authenticated USING (user_id = auth.uid());

-- Transactions: read-only for owner
DROP POLICY IF EXISTS "wallet_tx_user_policy" ON public.wallet_transactions;
DROP POLICY IF EXISTS "wallet_tx_select_own" ON public.wallet_transactions;
CREATE POLICY "wallet_tx_select_own" ON public.wallet_transactions
    FOR SELECT TO authenticated USING (user_id = auth.uid());

-- Bookings: owner/agent read, owner insert, no client update of fee/pin/status
DROP POLICY IF EXISTS "inspection_bookings_policy" ON public.inspection_bookings;
DROP POLICY IF EXISTS "inspection_bookings_select" ON public.inspection_bookings;
DROP POLICY IF EXISTS "inspection_bookings_insert" ON public.inspection_bookings;
CREATE POLICY "inspection_bookings_select" ON public.inspection_bookings
    FOR SELECT TO authenticated
    USING (renter_id = auth.uid() OR agent_id = auth.uid());
CREATE POLICY "inspection_bookings_insert" ON public.inspection_bookings
    FOR INSERT TO authenticated
    WITH CHECK (renter_id = auth.uid());
-- Updates/deletes only via service role / RPC. No client UPDATE policy = denied by default.

-- 3) Public properties: match real status enum 'available' (not 'active')
DROP POLICY IF EXISTS "properties_public_marketplace_read" ON public.properties;
CREATE POLICY "properties_public_marketplace_read" ON public.properties
    FOR SELECT TO public USING (status = 'available');
