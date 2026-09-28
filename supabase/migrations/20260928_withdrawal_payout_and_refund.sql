-- Migration: Automated Withdrawal Payouts & Server-side Refund Safety
-- Creates complete_withdrawal and fail_and_refund_withdrawal RPCs for Paystack integration

CREATE OR REPLACE FUNCTION public.complete_withdrawal(
  p_reference TEXT,
  p_paystack_transfer_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx public.wallet_transactions%ROWTYPE;
BEGIN
  SELECT * INTO v_tx FROM public.wallet_transactions
  WHERE reference = p_reference AND type = 'withdrawal'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Withdrawal transaction not found');
  END IF;

  UPDATE public.wallet_transactions
  SET status = 'completed',
      metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
        'paystack_transfer_id', p_paystack_transfer_id,
        'completed_at', now()
      )
  WHERE id = v_tx.id;

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.complete_withdrawal(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_withdrawal(text, text) TO service_role;


CREATE OR REPLACE FUNCTION public.fail_and_refund_withdrawal(
  p_reference TEXT,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx public.wallet_transactions%ROWTYPE;
  v_wallet public.wallets%ROWTYPE;
BEGIN
  SELECT * INTO v_tx FROM public.wallet_transactions
  WHERE reference = p_reference AND type = 'withdrawal'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Withdrawal transaction not found');
  END IF;

  IF v_tx.status = 'failed' OR v_tx.status = 'reversed' THEN
    RETURN jsonb_build_object('success', true, 'message', 'Already refunded');
  END IF;

  -- Update transaction to failed
  UPDATE public.wallet_transactions
  SET status = 'failed',
      metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
        'failure_reason', p_reason,
        'failed_at', now()
      )
  WHERE id = v_tx.id;

  -- Refund wallet balance
  UPDATE public.wallets
  SET balance = balance + v_tx.amount,
      updated_at = now()
  WHERE id = v_tx.wallet_id
  RETURNING * INTO v_wallet;

  -- Create refund transaction record
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, amount, type, direction, reference, description, channel, status, metadata
  )
  VALUES (
    v_wallet.id, v_tx.user_id, v_tx.amount, 'refund', 'inflow',
    'REF_' || p_reference,
    'Refund: Failed withdrawal to ' || COALESCE(v_tx.metadata->>'bank_name', 'Bank') || ' (' || COALESCE(p_reason, 'Transfer failed') || ')',
    'paystack', 'completed',
    jsonb_build_object('original_reference', p_reference, 'reason', p_reason)
  );

  RETURN jsonb_build_object(
    'success', true,
    'refunded_amount', v_tx.amount,
    'new_balance', v_wallet.balance
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fail_and_refund_withdrawal(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fail_and_refund_withdrawal(text, text) TO service_role;
