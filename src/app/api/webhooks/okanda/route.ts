import { createHmac, randomUUID, timingSafeEqual } from "crypto";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// MODO CAPTURA (temporário). Guarda o que a Okanda envia (cabeçalhos e corpo) para desenharmos
// a validação certa. NÃO cria contas nem ativa planos. Será substituído pelo handler definitivo.

const MAX_BODY = 100_000;

function safeEqual(a: string, b: string) {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}

// Testa os esquemas de assinatura mais comuns e devolve só verdadeiro/falso (o segredo nunca sai daqui).
function signatureChecks(secret: string, body: string, headers: Record<string, string>) {
  const checks: { header: string; scheme: string; match: boolean }[] = [];
  const ts = Object.entries(headers).find(([k]) => k.startsWith("x-okanda-") && k.includes("timestamp"))?.[1];
  for (const [name, raw] of Object.entries(headers)) {
    if (!name.startsWith("x-okanda-")) continue;
    // o valor pode vir como "abc", "sha256=abc" ou "t=123,v1=abc"
    const candidates = [raw, ...raw.split(",").map((p) => p.slice(p.indexOf("=") + 1).trim())];
    const variants: [string, string][] = [["body", body]];
    if (ts) variants.push(["timestamp.body", `${ts}.${body}`]);
    for (const [label, data] of variants) {
      for (const enc of ["hex", "base64"] as const) {
        const mac = createHmac("sha256", secret).update(data).digest(enc);
        checks.push({ header: name, scheme: `hmac-sha256/${enc}/${label}`, match: candidates.some((c) => safeEqual(c, mac)) });
      }
    }
    checks.push({ header: name, scheme: "secret-in-header", match: candidates.some((c) => safeEqual(c, secret)) });
  }
  return checks;
}

export async function POST(req: Request) {
  const body = (await req.text()).slice(0, MAX_BODY);

  const headers: Record<string, string> = {};
  req.headers.forEach((value, key) => {
    const k = key.toLowerCase();
    if (k !== "authorization" && k !== "cookie") headers[k] = value;
  });

  // Barreira simples contra lixo: a Okanda envia sempre cabeçalhos X-Okanda-*
  if (!Object.keys(headers).some((k) => k.startsWith("x-okanda-"))) {
    return Response.json({ ok: false }, { status: 400 });
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) return Response.json({ ok: false, error: "not_configured" }, { status: 503 });

  let json: unknown = null;
  try {
    json = JSON.parse(body);
  } catch {
    // corpo que não é JSON: fica só o texto
  }

  const secret = process.env.OKANDA_WEBHOOK_SECRET;
  const row = {
    provider: "okanda",
    event_id: `capture-${randomUUID()}`,
    event_type: "capture",
    processed_at: new Date().toISOString(), // para a limpeza automática apagar em 30 dias
    payload: {
      headers,
      body,
      json,
      signature_checks: secret ? signatureChecks(secret, body, headers) : "no_secret_configured",
    },
  };

  const res = await fetch(`${url}/rest/v1/payment_events`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: key,
      ...(key.startsWith("eyJ") ? { Authorization: `Bearer ${key}` } : {}),
      Prefer: "return=minimal",
    },
    body: JSON.stringify(row),
  });

  if (!res.ok) return Response.json({ ok: false }, { status: 500 });
  return Response.json({ ok: true });
}
