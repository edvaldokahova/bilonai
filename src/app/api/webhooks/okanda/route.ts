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
  // Primeira linha: prova que o pedido chegou ao nosso código (mesmo que depois algo falhe).
  console.log("okanda-webhook: recebido", req.method, req.headers.get("content-type"), req.headers.get("content-length"));

  let body = "";
  try {
    body = (await req.text()).slice(0, MAX_BODY);
  } catch (err) {
    console.error("okanda-webhook: erro a ler o corpo", err instanceof Error ? err.message : err);
  }

  // Não guardamos cabeçalhos internos da Vercel (contêm tokens) nem credenciais.
  const headers: Record<string, string> = {};
  req.headers.forEach((value, key) => {
    const k = key.toLowerCase();
    if (k === "authorization" || k === "cookie" || k === "forwarded" || k.startsWith("x-vercel-")) return;
    headers[k] = value;
  });

  // Nesta fase de captura aceitamos também pedidos sem X-Okanda-* (ex.: o "ping" do botão Conectar),
  // mas ficam marcados para os distinguir. O handler definitivo recusa tudo o que não vier assinado.
  const hasOkandaHeaders = Object.keys(headers).some((k) => k.startsWith("x-okanda-"));

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
    event_type: hasOkandaHeaders ? "capture" : "capture_unsigned",
    processed_at: new Date().toISOString(), // para a limpeza automática apagar em 30 dias
    payload: {
      headers,
      body,
      json,
      signature_checks: secret ? signatureChecks(secret, body, headers) : "no_secret_configured",
    },
  };

  try {
    const res = await fetch(`${url.replace(/\/+$/, "")}/rest/v1/payment_events`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: key,
        ...(key.startsWith("eyJ") ? { Authorization: `Bearer ${key}` } : {}),
        Prefer: "return=minimal",
      },
      body: JSON.stringify(row),
      signal: AbortSignal.timeout(5000), // nunca deixa a Okanda à espera
    });
    if (!res.ok) {
      console.error("okanda-webhook: falha ao guardar", res.status, (await res.text()).slice(0, 300));
      return Response.json({ ok: false, stage: "db" }, { status: 500 });
    }
  } catch (err) {
    console.error("okanda-webhook: erro ao guardar", err instanceof Error ? err.message : err);
    return Response.json({ ok: false, stage: "db_timeout_or_network" }, { status: 500 });
  }
  console.log("okanda-webhook: guardado", row.event_id, "cabeçalhos:", Object.keys(headers).filter((k) => k.startsWith("x-okanda-")).join(","));
  return Response.json({ ok: true });
}

// Verificações de ligação (GET/HEAD) respondem 200 sem guardar nada.
export async function GET() {
  return Response.json({ ok: true, service: "bilonai-webhook" });
}

export async function HEAD() {
  return new Response(null, { status: 200 });
}
