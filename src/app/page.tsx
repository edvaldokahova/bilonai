import { Logo } from "@/components/brand/Logo";
import { ThemeToggle } from "@/components/ui/ThemeToggle";

// Página provisória. A landing real (bilonai.com) é construída no fim do projeto.
export default function Home() {
  return (
    <main className="relative flex min-h-[100dvh] flex-col items-center justify-center px-6 py-16 text-center">
      <div className="absolute right-5 top-5">
        <ThemeToggle />
      </div>

      <Logo tagline className="w-full max-w-md text-fg" />

      <p className="mt-12 max-w-xl text-balance text-xl font-medium tracking-tight sm:text-2xl">
        Humano define a direção. <span className="gold-text">Agentes executam a rotina.</span>
      </p>

      <span className="chip mt-8">
        <span className="h-1.5 w-1.5 rounded-full bg-gold" aria-hidden="true" />
        Plataforma em construção
      </span>
    </main>
  );
}
