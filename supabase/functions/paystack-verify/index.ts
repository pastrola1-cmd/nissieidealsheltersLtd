// Verify Paystack transaction by reference (server holds SECRET).
// POST {reference} -> {status, amountNaira, email, userId}
// Deploy: supabase functions deploy paystack-verify
// Env: PAYSTACK_SECRET_KEY
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("ok", { status: 200 });
  const secret = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
  if (!secret) return new Response("missing secret", { status: 500 });
  const body = await req.json().catch(() => ({}));
  const reference = body.reference as string | undefined;
  if (!reference) return new Response("missing reference", { status: 400 });
  const res = await fetch(`https://api.paystack.co/transaction/verify/${reference}`, {
    headers: { Authorization: `Bearer ${secret}` },
  });
  const json = await res.json().catch(() => null);
  const ok = json?.data?.status === "success";
  return new Response(
    JSON.stringify({
      success: ok,
      status: json?.data?.status ?? "unknown",
      amountNaira: json?.data?.amount != null ? json.data.amount / 100 : null,
      email: json?.data?.customer?.email ?? null,
      userId: json?.data?.metadata?.user_id ?? null,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
