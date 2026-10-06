import type { Metadata } from "next";
import { Lock } from "lucide-react";
import { Logo, LogoMark } from "@/components/brand/Logo";
import { ThemeToggle } from "@/components/ui/ThemeToggle";

export const metadata: Metadata = { title: "Design", robots: { index: false, follow: false } };

const palette = [
  { name: "Fundo", cls: "bg-bg" },
  { name: "Texto", cls: "bg-fg" },
  { name: "Muted", cls: "bg-muted" },
  { name: "Ouro claro", cls: "bg-gold-light" },
  { name: "Ouro", cls: "bg-gold" },
  { name: "Ouro escuro", cls: "bg-gold-deep" },
  { name: "OK", cls: "bg-ok" },
  { name: "Aviso", cls: "bg-warn" },
  { name: "Erro", cls: "bg-danger" },
];

// Pré-visualização interna do sistema visual. Não é página pública do produto.
export default function DesignPage() {
  return (
    <main className="mx-auto max-w-3xl space-y-12 px-6 py-12">
      <header className="flex items-center justify-between">
        <Logo className="w-40 text-fg" />
        <ThemeToggle />
      </header>

      <section className="space-y-4">
        <h2 className="text-sm font-medium uppercase tracking-widest text-muted">Cores</h2>
        <div className="grid grid-cols-3 gap-3 sm:grid-cols-5">
          {palette.map((c) => (
            <div key={c.name} className="space-y-2">
              <div className={`h-14 rounded-xl border border-line/15 ${c.cls}`} />
              <p className="text-xs text-muted">{c.name}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="space-y-4">
        <h2 className="text-sm font-medium uppercase tracking-widest text-muted">Botões e etiquetas</h2>
        <div className="flex flex-wrap items-center gap-3">
          <button className="btn btn-gold">Ação principal</button>
          <button className="btn btn-ghost">Secundário</button>
          <span className="chip">Etiqueta</span>
        </div>
      </section>

      <section className="space-y-4">
        <h2 className="text-sm font-medium uppercase tracking-widest text-muted">Vidro</h2>
        <div className="glass rounded-2xl p-6">
          <div className="flex items-center gap-4">
            <LogoMark className="h-12 w-12 text-fg" />
            <div>
              <p className="font-medium">Espião</p>
              <p className="text-sm text-muted">Próximo relatório em 2 dias</p>
            </div>
          </div>
        </div>
      </section>

      <section className="space-y-4">
        <h2 className="text-sm font-medium uppercase tracking-widest text-muted">Módulo bloqueado (paywall visual)</h2>
        <div className="glass relative overflow-hidden rounded-2xl p-6">
          <div className="select-none space-y-2 blur-sm" aria-hidden="true">
            <p className="font-medium">Gestor</p>
            <p className="text-sm text-muted">ROAS 3,4 · CPA 2.150 Kz · Recomendação: escalar</p>
          </div>
          <div className="absolute inset-0 flex items-center justify-center gap-2 text-sm font-medium">
            <Lock className="h-4 w-4 text-gold" aria-hidden="true" />
            Disponível no plano Syndicate
          </div>
        </div>
      </section>
    </main>
  );
}
