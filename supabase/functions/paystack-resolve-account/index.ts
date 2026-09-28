// Secure bank account resolution proxy via Paystack.
// POST { accountNumber: string, bankCode: string }
// -> { success: boolean, accountName: string, accountNumber: string }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
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

  try {
    const body = await req.json().catch(() => ({}));
    const accountNumber = (body.accountNumber ?? body.account_number ?? "").toString().trim();
    const bankCode = (body.bankCode ?? body.bank_code ?? "").toString().trim();

    if (!accountNumber || accountNumber.length !== 10 || !/^\d+$/.test(accountNumber)) {
      return new Response(
        JSON.stringify({ success: false, message: "Account number must be exactly 10 digits" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!bankCode) {
      return new Response(
        JSON.stringify({ success: false, message: "Bank code is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const paystackUrl = `https://api.paystack.co/bank/resolve?account_number=${encodeURIComponent(accountNumber)}&bank_code=${encodeURIComponent(bankCode)}`;
    const psRes = await fetch(paystackUrl, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${secret}`,
        "Content-Type": "application/json",
      },
    });

    const psJson = await psRes.json().catch(() => null);

    if (psRes.ok && psJson?.status === true && psJson?.data?.account_name) {
      return new Response(
        JSON.stringify({
          success: true,
          accountName: psJson.data.account_name,
          accountNumber: psJson.data.account_number ?? accountNumber,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: false,
        message: psJson?.message ?? "Could not resolve account name. Verify bank and account number.",
      }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("paystack-resolve-account error:", error);
    return new Response(
      JSON.stringify({ success: false, message: "Internal server error resolving account" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
