-- RPC AUTHORIZATION + LEAST-PRIVILEGE HARDENING
-- Run after 20260924_security_hardening.sql
-- Closes: anon/param-tampering on financial RPCs, self role-elevation,
-- PII enumeration, member-wide secret reads, admin company-update breakage.

-- ══ 1) Financial RPCs bound to caller (auth.uid), PUBLIC/anon revoked ══

CREATE OR REPLACE FUNCTION public.reserve_inspection_deposit(
  p_user_id UUID, p_amount NUMERIC, p_booking_id TEXT, p_property_title TEXT
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_wallet public.wallets;
  v_ref TEXT;
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Sign-in required');
  END IF;
  v_wallet := public.get_or_create_wallet(v_caller);
  IF v_wallet.balance < p_amount THEN
    RETURN jsonb_build_object('success', false, 'message', 'Insufficient wallet balance');
  END IF;
  v_ref := 'HOLD_' || p_booking_id || '_' || floor(extract(epoch from now()));
  UPDATE public.wallets
  SET balance = balance - p_amount,
      ledger_balance = ledger_balance + p_amount,
      updated_at = now()
  WHERE id = v_wallet.id
  RETURNING * INTO v_wallet;
  INSERT INTO public.wallet_transactions (
      wallet_id, user_id, amount, type, direction, reference, description, channel, status, metadata
  )
  VALUES (
      v_wallet.id, v_caller, p_amount, 'escrow_hold', 'outflow', v_ref,
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
$$;

CREATE OR REPLACE FUNCTION public.request_agent_withdrawal(
  p_agent_user_id UUID, p_amount NUMERIC,
  p_bank_code TEXT, p_bank_name TEXT, p_account_number TEXT, p_account_name TEXT
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_wallet public.wallets;
  v_ref TEXT;
  v_tx public.wallet_transactions;
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Sign-in required');
  END IF;
  IF p_amount < 2000.00 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Minimum withdrawal amount is 2000.00');
  END IF;
  v_wallet := public.get_or_create_wallet(v_caller);
  IF v_wallet.balance < p_amount THEN
    RETURN jsonb_build_object('success', false, 'message', 'Insufficient available balance for withdrawal');
  END IF;
  v_ref := 'WTH_' || floor(extract(epoch from now())) || '_' || substr(p_account_number, 7, 4);
  UPDATE public.wallets
  SET balance = balance - p_amount,
      updated_at = now()
  WHERE id = v_wallet.id
  RETURNING * INTO v_wallet;
  INSERT INTO public.wallet_transactions (
      wallet_id, user_id, amount, type, direction, reference, description, channel, status, metadata
  )
  VALUES (
      v_wallet.id, v_caller, p_amount, 'withdrawal', 'outflow',
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
$$;

-- Settle: staff-only caller gate (buyers can no longer self-release escrow).
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
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Sign-in required');
  END IF;
  SELECT role INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
  IF v_caller_role IS NULL OR v_caller_role NOT IN ('partner','manager','marketer','admin','platform_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'Staff sign-in required');
  END IF;

  SELECT * INTO v_booking FROM public.inspection_bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Booking not found');
  END IF;
  IF v_booking.status = 'completed' OR v_booking.status = 'cancelled' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Booking already settled');
  END IF;
  IF v_booking.pin_locked_until IS NOT NULL AND v_booking.pin_locked_until > now() THEN
    RETURN jsonb_build_object('success', false, 'message', 'Too many attempts. Try again later.');
  END IF;
  IF v_booking.pin_expires_at IS NOT NULL AND v_booking.pin_expires_at < now() THEN
    RETURN jsonb_build_object('success', false, 'message', 'PIN expired. Ask renter to rebook.');
  END IF;
  IF v_booking.completion_pin IS NULL OR v_booking.completion_pin <> p_pin THEN
    UPDATE public.inspection_bookings
    SET pin_attempts = COALESCE(pin_attempts, 0) + 1,
        pin_locked_until = CASE WHEN COALESCE(pin_attempts, 0) + 1 >= 5 THEN now() + interval '15 minutes' ELSE pin_locked_until END,
        updated_at = now()
    WHERE id = p_booking_id;
    RETURN jsonb_build_object('success', false, 'message', 'Invalid PIN');
  END IF;
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

-- ══ 2) Invite: single gated canonical (drop ungated + ambiguous overload) ══
DROP FUNCTION IF EXISTS public.invite_staff_member(text, text, text, text, uuid, text);
DROP FUNCTION IF EXISTS public.invite_staff_member(text, text, text, text, text, uuid);

CREATE OR REPLACE FUNCTION public.invite_staff_member(
  p_email TEXT, p_phone TEXT, p_name TEXT, p_role TEXT, p_company_id UUID, p_password TEXT DEFAULT NULL
)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user_id UUID;
  v_hashed_password TEXT;
  v_status TEXT;
BEGIN
  IF NOT public.is_admin_or_manager() THEN
    RAISE EXCEPTION 'Forbidden: only admins and managers can invite staff';
  END IF;
  IF p_role NOT IN ('manager', 'marketer', 'admin', 'partner') THEN
    RAISE EXCEPTION 'Forbidden: invalid invite role';
  END IF;
  SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;
  IF v_user_id IS NOT NULL THEN
    RAISE EXCEPTION 'A user with this email already exists';
  END IF;
  v_user_id := gen_random_uuid();
  IF p_password IS NOT NULL AND p_password != '' THEN
    v_hashed_password := crypt(p_password, gen_salt('bf'));
  ELSE
    v_hashed_password := crypt(gen_random_uuid()::text, gen_salt('bf'));
  END IF;
  INSERT INTO auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    role, phone, phone_confirmed_at, aud, confirmation_token,
    email_change, email_change_token_new, recovery_token,
    email_change_token_current, phone_change, phone_change_token, reauthentication_token
  )
  VALUES (
    v_user_id, '00000000-0000-0000-0000-000000000000', p_email, v_hashed_password, now(),
    jsonb_build_object('provider', 'email', 'providers', array['email']),
    jsonb_build_object('full_name', p_name, 'role', p_role, 'company_id', p_company_id),
    now(), now(), 'authenticated', p_phone, now(), 'authenticated', '', '', '', '', '', '', '', ''
  );
  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
  )
  VALUES (
    gen_random_uuid(), v_user_id, jsonb_build_object('sub', v_user_id, 'email', p_email), 'email', v_user_id::text, now(), now(), now()
  );
  -- Pin the intended role: the signup trigger allowlists self-service roles only.
  IF p_role = 'partner' THEN v_status := 'pending'; ELSE v_status := 'approved'; END IF;
  INSERT INTO public.profiles (id, company_id, full_name, email, phone, role, status)
  VALUES (v_user_id, p_company_id, p_name, p_email, p_phone, p_role, v_status)
  ON CONFLICT (id) DO UPDATE SET
    role = EXCLUDED.role,
    status = EXCLUDED.status,
    company_id = EXCLUDED.company_id,
    full_name = EXCLUDED.full_name;
  RETURN v_user_id;
END;
$$;

-- ══ 3) Execute grants: no anon/PUBLIC on money + identity RPCs ══
REVOKE ALL ON FUNCTION public.fund_wallet_with_reference(uuid, numeric, text, text, text, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reserve_inspection_deposit(uuid, numeric, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.request_agent_withdrawal(uuid, numeric, text, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.settle_inspection_pin_payout(uuid, text, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.lookup_booking_by_pin(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_or_create_wallet(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.invite_staff_member(text, text, text, text, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reserve_inspection_deposit(uuid, numeric, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_agent_withdrawal(uuid, numeric, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.settle_inspection_pin_payout(uuid, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_booking_by_pin(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_wallet(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.invite_staff_member(text, text, text, text, uuid, text) TO authenticated;
-- fund stays service_role-only: only the Paystack webhook may mint.
-- Future functions: no public execute by default.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon;

-- ══ 4) Profiles: kill member-wide read; block privilege self-edits ══
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.profiles;

CREATE OR REPLACE FUNCTION public.protect_profile_privilege()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_role TEXT;
BEGIN
  IF current_user IN ('service_role', 'postgres') THEN
    RETURN NEW;
  END IF;
  IF OLD.role IS DISTINCT FROM NEW.role
     OR OLD.status IS DISTINCT FROM NEW.status
     OR OLD.company_id IS DISTINCT FROM NEW.company_id THEN
    SELECT role INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'manager', 'platform_admin') THEN
      RAISE EXCEPTION 'Forbidden: only admins may change role, status, or company';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_protect_profile_privilege ON public.profiles;
CREATE TRIGGER trg_protect_profile_privilege
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.protect_profile_privilege();

-- ══ 5) Companies: staff-only base reads, safe view for everyone else ══
DROP POLICY IF EXISTS companies_select ON public.companies;
CREATE POLICY companies_staff_select ON public.companies
  FOR SELECT TO authenticated
  USING (
    public.get_my_role() = 'platform_admin'
    OR (id = public.get_my_company() AND public.get_my_role() IN ('admin', 'manager', 'marketer'))
  );

DROP POLICY IF EXISTS companies_write ON public.companies;
CREATE POLICY companies_write ON public.companies
  FOR ALL TO authenticated
  USING (
    (public.get_my_role() = 'admin' AND id = public.get_my_company())
    OR public.get_my_role() = 'platform_admin'
  )
  WITH CHECK (
    (public.get_my_role() = 'admin' AND id = public.get_my_company())
    OR public.get_my_role() = 'platform_admin'
  );

CREATE OR REPLACE VIEW public.companies_safe AS
SELECT id, name, logo_url, phone, address, is_hidden,
  subscription_tier, subscription_status, subscription_expires_at,
  fb_pixel_id, lp_module_enabled,
  whatsapp_phone_number_id, whatsapp_waba_id, whatsapp_enabled, whatsapp_template_name,
  created_at, email, termii_sender_id,
  updated_at, email_provider,
  smtp_sender_name, smtp_sender_email,
  brevo_sender_name, brevo_sender_email,
  office_lat, office_lng, office_radius_meters
FROM public.companies;
GRANT SELECT ON public.companies_safe TO anon, authenticated;
