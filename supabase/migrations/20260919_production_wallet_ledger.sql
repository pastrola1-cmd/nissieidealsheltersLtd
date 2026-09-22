-- =====================================================================
-- NISSIE IDEAL SHELTERS - PRODUCTION WALLET & FINTECH LEDGER MIGRATION
-- =====================================================================
-- This migration establishes an ACID-compliant digital wallet ledger with
-- atomic stored procedures for inspection deposits, PIN settlements, and
-- automated agent withdrawals.
-- =====================================================================

-- 1. WALLETS TABLE
CREATE TABLE IF NOT EXISTS public.wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    balance NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    ledger_balance NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    currency VARCHAR(5) NOT NULL DEFAULT 'NGN',
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_wallet_balance_positive CHECK (balance >= 0),
    CONSTRAINT chk_wallet_ledger_positive CHECK (ledger_balance >= 0),
    CONSTRAINT uq_user_wallet UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON public.wallets(user_id);

-- 2. WALLET TRANSACTIONS TABLE (Double-entry audit trail)
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
    type VARCHAR(30) NOT NULL, -- 'credit', 'debit', 'escrow_hold', 'payout', 'withdrawal', 'platform_fee'
    direction VARCHAR(10) NOT NULL, -- 'inflow', 'outflow'
    reference VARCHAR(100) NOT NULL UNIQUE,
    description TEXT NOT NULL,
    channel VARCHAR(50) DEFAULT 'paystack', -- 'paystack', 'bank_transfer', 'internal'
    status VARCHAR(20) NOT NULL DEFAULT 'completed', -- 'pending', 'completed', 'failed', 'reversed'
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wallet_tx_user_id ON public.wallet_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_wallet_id ON public.wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_reference ON public.wallet_transactions(reference);

-- 3. ENABLE ROW LEVEL SECURITY (RLS)
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

-- Users can only read their own wallet
DROP POLICY IF EXISTS "Users can view own wallet" ON public.wallets;
CREATE POLICY "Users can view own wallet" ON public.wallets
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id OR public.is_admin_or_manager());

-- Users can only read their own transactions
DROP POLICY IF EXISTS "Users can view own transactions" ON public.wallet_transactions;
CREATE POLICY "Users can view own transactions" ON public.wallet_transactions
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id OR public.is_admin_or_manager());

-- Prevent direct client-side balance tampering: Updates and Inserts must run via SECURITY DEFINER functions
DROP POLICY IF EXISTS "Direct wallet updates forbidden" ON public.wallets;
CREATE POLICY "Direct wallet updates forbidden" ON public.wallets
    FOR ALL TO authenticated
    USING (public.is_admin_or_manager());

-- =====================================================================
-- 4. ATOMIC STORED PROCEDURES (SECURITY DEFINER)
-- =====================================================================

-- Helper: Get or safely provision wallet
CREATE OR REPLACE FUNCTION public.get_or_create_wallet(p_user_id UUID)
RETURNS public.wallets AS $$
DECLARE
    v_wallet public.wallets;
BEGIN
    SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id;
    IF NOT FOUND THEN
        INSERT INTO public.wallets (user_id, balance, ledger_balance, currency, status)
        VALUES (p_user_id, 0.00, 0.00, 'NGN', 'active')
        RETURNING * INTO v_wallet;
    END IF;
    RETURN v_wallet;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Procedure: Fund Wallet with verified gateway payment reference
CREATE OR REPLACE FUNCTION public.fund_wallet_with_reference(
    p_user_id UUID,
    p_amount NUMERIC,
    p_reference TEXT,
    p_description TEXT DEFAULT 'Wallet Funding via Paystack',
    p_channel TEXT DEFAULT 'paystack',
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB AS $$
DECLARE
    v_wallet public.wallets;
    v_tx public.wallet_transactions;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Funding amount must be greater than zero';
    END IF;

    -- Check if reference was already processed (idempotency guarantee)
    IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE reference = p_reference) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Payment reference already processed');
    END IF;

    -- Fetch or create wallet
    v_wallet := public.get_or_create_wallet(p_user_id);

    -- Credit wallet balance
    UPDATE public.wallets
    SET balance = balance + p_amount,
        updated_at = now()
    WHERE id = v_wallet.id
    RETURNING * INTO v_wallet;

    -- Record transaction
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, amount, type, direction, reference, description, channel, status, metadata
    )
    VALUES (
        v_wallet.id, p_user_id, p_amount, 'credit', 'inflow', p_reference, p_description, p_channel, 'completed', p_metadata
    )
    RETURNING * INTO v_tx;

    RETURN jsonb_build_object(
        'success', true,
        'new_balance', v_wallet.balance,
        'transaction_id', v_tx.id,
        'reference', p_reference
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Procedure: Reserve Inspection Deposit (Moves funds from balance to ledger_balance hold)
CREATE OR REPLACE FUNCTION public.reserve_inspection_deposit(
    p_user_id UUID,
    p_amount NUMERIC,
    p_booking_id TEXT,
    p_property_title TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_wallet public.wallets;
    v_ref TEXT;
BEGIN
    v_wallet := public.get_or_create_wallet(p_user_id);

    IF v_wallet.balance < p_amount THEN
        RETURN jsonb_build_object('success', false, 'message', 'Insufficient wallet balance');
    END IF;

    v_ref := 'HOLD_' || p_booking_id || '_' || floor(extract(epoch from now()));

    -- Deduct available balance and hold in ledger_balance
    UPDATE public.wallets
    SET balance = balance - p_amount,
        ledger_balance = ledger_balance + p_amount,
        updated_at = now()
    WHERE id = v_wallet.id
    RETURNING * INTO v_wallet;

    -- Record transaction hold
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, amount, type, direction, reference, description, channel, status, metadata
    )
    VALUES (
        v_wallet.id, p_user_id, p_amount, 'escrow_hold', 'outflow', v_ref,
        'Inspection Deposit Reserved: ' || p_property_title,
        'internal', 'completed',
        jsonb_build_object('booking_id', p_booking_id, 'property_title', p_property_title)
    );

    RETURN jsonb_build_object(
        'success', true,
        'new_balance', v_wallet.balance,
        'ledger_balance', v_wallet.ledger_balance,
        'reference', v_ref
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Procedure: Settle Inspection PIN Payout (Atomic ₦2,000 to Agent, ₦1,000 to Platform)
CREATE OR REPLACE FUNCTION public.settle_inspection_pin_payout(
    p_booking_id TEXT,
    p_pin TEXT,
    p_agent_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_inspection public.inspections;
    v_renter_wallet public.wallets;
    v_agent_wallet public.wallets;
    v_payout_amount NUMERIC := 2000.00;
    v_platform_fee NUMERIC := 1000.00;
    v_total_deposit NUMERIC := 3000.00;
    v_ref_agent TEXT;
    v_ref_fee TEXT;
BEGIN
    -- 1. Find and validate booking
    SELECT * INTO v_inspection
    FROM public.inspections
    WHERE id = p_booking_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Inspection booking not found');
    END IF;

    -- Validate PIN against stored metadata or booking record
    IF (v_inspection.notes NOT LIKE '%' || p_pin || '%') AND 
       (COALESCE(v_inspection.status, '') = 'completed') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invalid PIN or booking already settled');
    END IF;

    -- 2. Fetch wallets
    v_renter_wallet := public.get_or_create_wallet(v_inspection.buyer_id);
    v_agent_wallet := public.get_or_create_wallet(p_agent_user_id);

    -- 3. Release renter escrow hold
    IF v_renter_wallet.ledger_balance >= v_total_deposit THEN
        UPDATE public.wallets
        SET ledger_balance = ledger_balance - v_total_deposit,
            updated_at = now()
        WHERE id = v_renter_wallet.id;
    END IF;

    -- 4. Credit Agent Wallet ₦2,000
    UPDATE public.wallets
    SET balance = balance + v_payout_amount,
        updated_at = now()
    WHERE id = v_agent_wallet.id
    RETURNING * INTO v_agent_wallet;

    v_ref_agent := 'PAYOUT_AGT_' || p_booking_id || '_' || floor(extract(epoch from now()));
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, amount, type, direction, reference, description, channel, status, metadata
    )
    VALUES (
        v_agent_wallet.id, p_agent_user_id, v_payout_amount, 'payout', 'inflow',
        v_ref_agent, 'Tour Inspection Fee Earned (Booking #' || substr(p_booking_id, 1, 8) || ')',
        'internal', 'completed',
        jsonb_build_object('booking_id', p_booking_id, 'pin_verified', p_pin)
    );

    -- 5. Record Platform Revenue ₦1,000
    v_ref_fee := 'FEE_PLAT_' || p_booking_id || '_' || floor(extract(epoch from now()));
    INSERT INTO public.transactions (
        type, amount, status, description, reference
    )
    VALUES (
        'platform_fee', v_platform_fee, 'completed',
        'Nissie Platform Fee: Inspection Tour #' || substr(p_booking_id, 1, 8),
        v_ref_fee
    );

    -- 6. Mark inspection completed
    UPDATE public.inspections
    SET status = 'completed',
        updated_at = now()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'agent_credited', v_payout_amount,
        'platform_fee', v_platform_fee,
        'agent_new_balance', v_agent_wallet.balance,
        'reference', v_ref_agent
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Procedure: Request Agent Bank Withdrawal
CREATE OR REPLACE FUNCTION public.request_agent_withdrawal(
    p_agent_user_id UUID,
    p_amount NUMERIC,
    p_bank_code TEXT,
    p_bank_name TEXT,
    p_account_number TEXT,
    p_account_name TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_wallet public.wallets;
    v_ref TEXT;
    v_tx public.wallet_transactions;
BEGIN
    IF p_amount < 2000.00 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Minimum withdrawal amount is ₦2,000');
    END IF;

    v_wallet := public.get_or_create_wallet(p_agent_user_id);

    IF v_wallet.balance < p_amount THEN
        RETURN jsonb_build_object('success', false, 'message', 'Insufficient available balance for withdrawal');
    END IF;

    v_ref := 'WTH_' || floor(extract(epoch from now())) || '_' || substr(p_account_number, 7, 4);

    -- Deduct balance atomically
    UPDATE public.wallets
    SET balance = balance - p_amount,
        updated_at = now()
    WHERE id = v_wallet.id
    RETURNING * INTO v_wallet;

    -- Record withdrawal transaction
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, amount, type, direction, reference, description, channel, status, metadata
    )
    VALUES (
        v_wallet.id, p_agent_user_id, p_amount, 'withdrawal', 'outflow',
        v_ref,
        'Bank Withdrawal to ' || p_bank_name || ' (' || p_account_number || ') - ' || p_account_name,
        'paystack', 'pending',
        jsonb_build_object(
            'bank_code', p_bank_code,
            'bank_name', p_bank_name,
            'account_number', p_account_number,
            'account_name', p_account_name
        )
    )
    RETURNING * INTO v_tx;

    RETURN jsonb_build_object(
        'success', true,
        'reference', v_ref,
        'amount', p_amount,
        'new_balance', v_wallet.balance,
        'status', 'pending'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
