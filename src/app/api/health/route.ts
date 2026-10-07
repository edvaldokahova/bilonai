export const dynamic = "force-dynamic";

// Verificação simples de que a aplicação está no ar. Não expõe nenhum segredo.
// "?deep=1" (temporário, para a montagem dos webhooks) diz só SE as variáveis existem, de que TIPO é
// a chave do Supabase e se a base de dados responde. Nunca devolve valores.
export async function GET(req: Request) {
  const base = { ok: true, service: "bilonai", time: new Date().toISOString() };
  const headers = { "Cache-Control": "no-store" };

  if (!new URL(req.url).searchParams.has("deep")) return Response.json(base, { headers });

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

  let keyKind = "ausente";
  if (key) {
    if (key.startsWith("sb_secret_")) keyKind = "secret";
    else if (key.startsWith("sb_publishable_")) keyKind = "ERRADA: publishable";
    else if (key.startsWith("eyJ")) {
      try {
        const role = JSON.parse(Buffer.from(key.split(".")[1], "base64url").toString()).role;
        keyKind = role === "service_role" ? "service_role" : `ERRADA: jwt ${String(role)}`;
      } catch {
        keyKind = "jwt ilegível";
      }
    } else keyKind = "formato desconhecido";
  }

  let db: unknown = "não testado";
  if (url && key) {
    try {
      const res = await fetch(`${url.replace(/\/+$/, "")}/rest/v1/payment_events?select=id&limit=1`, {
        headers: { apikey: key, ...(key.startsWith("eyJ") ? { Authorization: `Bearer ${key}` } : {}) },
        signal: AbortSignal.timeout(4000),
      });
      db = { http: res.status };
    } catch (err) {
      db = { erro: err instanceof Error ? err.message : "desconhecido" };
    }
  }

  return Response.json(
    {
      ...base,
      env: {
        NEXT_PUBLIC_SUPABASE_URL: Boolean(url),
        SUPABASE_SERVICE_ROLE_KEY: keyKind,
        OKANDA_WEBHOOK_SECRET: Boolean(process.env.OKANDA_WEBHOOK_SECRET),
      },
      db,
    },
    { headers },
  );
}
