// Paystack Webhook Handler
// Verifies HMAC SHA512 signature, processes deposits (charge.success) and payouts (transfer.success / failed / reversed)
// Deploy: supabase functions deploy paystack-webhook --no-verify-jwt
// Env: PAYSTACK_SECRET_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

async function verifyPaystackSignature(rawBody: string, signature: string | null, secret: string): Promise<boolean> {
  if (!signature || !secret) return false;
  try {
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      encoder.encode(secret),
      { name: "HMAC", hash: "SHA-512" },
      false,
      ["sign"]
    );
    const sigBuffer = await crypto.subtle.sign("HMAC", key, encoder.encode(rawBody));
    const hashArray = Array.from(new Uint8Array(sigBuffer));
    const hexSig = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
    return hexSig.toLowerCase() === signature.toLowerCase();
  } catch (e) {
    console.error("HMAC verification error:", e);
    return false;
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("ok", { status: 200, headers: corsHeaders });
  }

  const secret = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
  const signature = req.headers.get("x-paystack-signature");
  const rawBody = await req.text();

  // Enforce HMAC signature check when secret is configured
  if (secret) {
    const isValid = await verifyPaystackSignature(rawBody, signature, secret);
    if (!isValid) {
      console.warn("Invalid Paystack webhook HMAC signature");
      return new Response("Invalid signature", { status: 401, headers: corsHeaders });
    }
  }

  let event: any = null;
  try {
    event = JSON.parse(rawBody);
  } catch (_) {
    return new Response("Invalid JSON payload", { status: 400, headers: corsHeaders });
  }

  const eventType: string = event?.event ?? "";
  const eventData = event?.data ?? {};
  const reference: string | undefined = eventData?.reference;

  if (!reference) {
    return new Response("Missing reference", { status: 400, headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseServiceRole);

  // ── Handle Deposits (charge.success) ──
  if (eventType === "charge.success") {
    // Secondary verification with Paystack API as source of truth
    if (secret) {
      const verifyRes = await fetch(`https://api.paystack.co/transaction/verify/${reference}`, {
        headers: { Authorization: `Bearer ${secret}` },
      });
      const verifyJson = await verifyRes.json().catch(() => null);
      if (verifyJson?.data?.status !== "success") {
        return new Response("Verification failed", { status: 200, headers: corsHeaders });
      }
    }

    const amountNaira = (eventData.amount as number) / 100;
    const email: string | undefined = eventData.customer?.email;
    const meta = eventData.metadata ?? {};
    let userId: string | undefined = meta.user_id ?? meta.userId;

    if (!userId && email) {
      const { data } = await supabase.from("profiles").select("id").eq("email", email).maybeSingle();
      userId = data?.id;
    }

    if (!userId) {
      console.warn(`Webhook: user not found for reference ${reference}, email ${email}`);
      return new Response("User not found", { status: 200, headers: corsHeaders });
    }

    const { error } = await supabase.rpc("fund_wallet_with_reference", {
      p_user_id: userId,
      p_amount: amountNaira,
      p_reference: reference,
      p_description: `Wallet Deposit via Paystack (${email ?? ""})`,
      p_channel: "paystack",
    });

    if (error) {
      console.error("fund_wallet_with_reference error:", error);
      return new Response("RPC failed", { status: 500, headers: corsHeaders });
    }

    return new Response(JSON.stringify({ received: true, action: "funded" }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── Handle Successful Payouts (transfer.success) ──
  if (eventType === "transfer.success") {
    const transferCode = eventData.transfer_code ?? eventData.id?.toString();
    const { data, error } = await supabase.rpc("complete_withdrawal", {
      p_reference: reference,
      p_paystack_transfer_id: transferCode,
    });

    if (error) {
      console.error("complete_withdrawal error:", error);
      return new Response("RPC failed", { status: 500, headers: corsHeaders });
    }

    return new Response(JSON.stringify({ received: true, action: "withdrawal_completed", data }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── Handle Failed / Reversed Payouts (transfer.failed / transfer.reversed) ──
  if (eventType === "transfer.failed" || eventType === "transfer.reversed") {
    const reason = eventData.reason ?? eventData.message ?? `Transfer status: ${eventType}`;
    const { data, error } = await supabase.rpc("fail_and_refund_withdrawal", {
      p_reference: reference,
      p_reason: reason,
    });

    if (error) {
      console.error("fail_and_refund_withdrawal error:", error);
      return new Response("RPC failed", { status: 500, headers: corsHeaders });
    }

    return new Response(JSON.stringify({ received: true, action: "withdrawal_refunded", data }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Fallthrough for unhandled events
  return new Response(JSON.stringify({ received: true, status: "ignored" }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
