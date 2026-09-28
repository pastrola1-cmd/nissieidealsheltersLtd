// Automated Bank Payouts via Paystack Transfers API
// POST { reference: string, amount: number, accountNumber: string, bankCode: string, accountName: string }
// -> { success: boolean, transferCode?: string, status?: string, message?: string }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  const secret = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
  if (!secret) {
    return new Response(
      JSON.stringify({ success: false, message: "Payment gateway credentials not configured on server" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseServiceRole);

  try {
    // 1. Authenticate Caller
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, message: "Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    const token = authHeader.replace(/^Bearer\s+/i, "");
    const { data: { user }, error: userError } = await supabase.auth.getUser(token);
    if (userError || !user) {
      return new Response(
        JSON.stringify({ success: false, message: "Unauthorized caller" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json().catch(() => ({}));
    const reference = body.reference as string | undefined;
    const amount = Number(body.amount ?? 0);
    const accountNumber = (body.accountNumber ?? body.account_number ?? "").toString().trim();
    const bankCode = (body.bankCode ?? body.bank_code ?? "").toString().trim();
    const accountName = (body.accountName ?? body.account_name ?? "").toString().trim();

    if (!reference || amount < 2000 || accountNumber.length !== 10 || !bankCode || !accountName) {
      return new Response(
        JSON.stringify({ success: false, message: "Invalid withdrawal parameters" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Create Paystack Transfer Recipient
    const recipientRes = await fetch("https://api.paystack.co/transferrecipient", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${secret}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        type: "nuban",
        name: accountName,
        account_number: accountNumber,
        bank_code: bankCode,
        currency: "NGN",
      }),
    });

    const recipientJson = await recipientRes.json().catch(() => null);
    const recipientCode = recipientJson?.data?.recipient_code;

    if (!recipientRes.ok || !recipientCode) {
      const errorMsg = recipientJson?.message ?? "Failed to create bank transfer recipient";
      console.error("Recipient creation failed:", recipientJson);

      // Refund the wallet since withdrawal RPC already deducted balance
      await supabase.rpc("fail_and_refund_withdrawal", {
        p_reference: reference,
        p_reason: `Recipient creation failed: ${errorMsg}`,
      });

      return new Response(
        JSON.stringify({ success: false, message: errorMsg }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Initiate Transfer
    const transferRes = await fetch("https://api.paystack.co/transfer", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${secret}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        source: "balance",
        amount: Math.round(amount * 100), // amount in kobo
        recipient: recipientCode,
        reason: `Nissie Agent Withdrawal (${reference})`,
        reference: reference,
      }),
    });

    const transferJson = await transferRes.json().catch(() => null);

    if (!transferRes.ok || transferJson?.status !== true) {
      const errorMsg = transferJson?.message ?? "Transfer rejected by payment provider";
      console.error("Transfer initiation failed:", transferJson);

      // Refund the wallet since transfer could not be initiated
      await supabase.rpc("fail_and_refund_withdrawal", {
        p_reference: reference,
        p_reason: `Transfer initiation failed: ${errorMsg}`,
      });

      return new Response(
        JSON.stringify({ success: false, message: errorMsg }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const transferData = transferJson.data;

    // 4. Update transaction metadata
    await supabase
      .from("wallet_transactions")
      .update({
        metadata: {
          recipient_code: recipientCode,
          transfer_code: transferData?.transfer_code,
          paystack_status: transferData?.status,
          bank_code: bankCode,
          account_number: accountNumber,
          account_name: accountName,
        },
      })
      .eq("reference", reference);

    if (transferData?.status === "success") {
      await supabase.rpc("complete_withdrawal", {
        p_reference: reference,
        p_paystack_transfer_id: transferData?.transfer_code ?? transferData?.id?.toString(),
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        reference: reference,
        transferCode: transferData?.transfer_code,
        status: transferData?.status ?? "pending",
        message: "Transfer initiated successfully",
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("paystack-payout error:", error);
    return new Response(
      JSON.stringify({ success: false, message: "Internal server error initiating payout" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
