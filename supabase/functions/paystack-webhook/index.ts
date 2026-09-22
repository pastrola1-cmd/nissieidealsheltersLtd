// Paystack webhook -> verify transaction -> credit wallet via RPC.
// Deploy: supabase functions deploy paystack-webhook --no-verify-jwt
// Env: PAYSTACK_SECRET_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// Paystack Dashboard -> Settings -> Webhook URL: https://<project>.supabase.co/functions/v1/paystack-webhook

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("ok", { status: 200 });
  const secret = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
  const event = await req.json().catch(() => null);
  const reference: string | undefined = event?.data?.reference;
  if (!reference) return new Response("missing reference", { status: 400 });

  // Verify with Paystack (source of truth — never trust webhook body alone)
  const verifyRes = await fetch(`https://api.paystack.co/transaction/verify/${reference}`, {
    headers: { Authorization: `Bearer ${secret}` },
  });
  const verifyJson = await verifyRes.json().catch(() => null);
  if (verifyJson?.data?.status !== "success") {
    return new Response("not successful", { status: 200 });
  }
  const amountNaira = (verifyJson.data.amount as number) / 100;
  const email: string | undefined = verifyJson.data.customer?.email;
  const meta = verifyJson.data.metadata ?? {};
  const userId: string | undefined = meta.user_id ?? meta.userId;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  // Resolve user by id (preferred) or email
  let uid = userId;
  if (!uid && email) {
    const { data } = await supabase.from("profiles").select("id").eq("email", email).maybeSingle();
    uid = data?.id;
  }
  if (!uid) return new Response("unknown user", { status: 200 });

  const { error } = await supabase.rpc("fund_wallet_with_reference", {
    p_user_id: uid,
    p_amount: amountNaira,
    p_reference: reference,
    p_description: `Wallet Deposit via Paystack (${email ?? ""})`,
    p_channel: "paystack",
  });
  if (error) {
    console.error("fund rpc failed", error);
    return new Response("rpc failed", { status: 500 });
  }
  return new Response("credited", { status: 200 });
});
