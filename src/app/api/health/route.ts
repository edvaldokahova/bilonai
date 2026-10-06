export const dynamic = "force-dynamic";

// Verificação simples de que a aplicação está no ar. Não expõe nenhum segredo.
export function GET() {
  return Response.json(
    { ok: true, service: "bilonai", time: new Date().toISOString() },
    { headers: { "Cache-Control": "no-store" } },
  );
}
