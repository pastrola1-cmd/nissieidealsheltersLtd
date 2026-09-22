// Initialize Paystack transaction (server holds SECRET).
// POST {email, amountNaira, reference?, userId?, callbackUrl?}
// -> {authorization_url, reference}
// Deploy: supabase functions deploy paystack-initialize --no-verify-jwt=false
// Env: PAYSTACK_SECRET_KEY
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("ok", { status: 200 });
  const secret = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
  if (!secret) return new Response("missing secret", { status: 500 });
  const body = await req.json().catch(() => ({}));
  const email = body.email as string | undefined;
  const amountNaira = Number(body.amountNaira ?? 0);
  const userId = (body.userId as string | undefined) ?? undefined;
  let reference = body.reference as string | undefined;
  if (!email || !amountNaira || amountNaira <= 0) {
    return new Response("invalid email/amount", { status: 400 });
  }
  if (!reference) reference = `NISSIE_${Date.now()}`;
  const initRes = await fetch("https://api.paystack.co/transaction/initialize", {
    method: "POST",
    headers: { Authorization: `Bearer ${secret}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      email,
      amount: Math.round(amountNaira * 100),
      reference,
      metadata: { user_id: userId ?? null },
      callback_url: body.callbackUrl ?? undefined,
    }),
  });
  const initJson = await initRes.json().catch(() => null);
  if (!initRes.ok || !initJson?.data?.authorization_url) {
    console.error("init failed", initJson);
    return new Response(JSON.stringify(initJson ?? { error: "init failed" }), { status: 502 });
  }
  return new Response(
    JSON.stringify({ authorization_url: initJson.data.authorization_url, reference }),
    { headers: { "Content-Type": "application/json" } },
  );
});
