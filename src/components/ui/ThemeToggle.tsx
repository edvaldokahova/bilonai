"use client";

import { useEffect, useState } from "react";
import { Moon, Sun } from "lucide-react";

const STORAGE_KEY = "bilonai-theme";

/** Alterna entre tema escuro (padrão) e claro. A escolha fica guardada no navegador. */
export function ThemeToggle() {
  const [dark, setDark] = useState(true);

  useEffect(() => {
    setDark(document.documentElement.classList.contains("dark"));
  }, []);

  function toggle() {
    const next = !dark;
    setDark(next);
    document.documentElement.classList.toggle("dark", next);
    try {
      localStorage.setItem(STORAGE_KEY, next ? "dark" : "light");
    } catch {
      // sem armazenamento (modo privado): o tema vale só nesta visita
    }
  }

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label={dark ? "Mudar para o tema claro" : "Mudar para o tema escuro"}
      className="glass inline-flex h-10 w-10 items-center justify-center rounded-xl text-muted transition hover:text-fg"
    >
      {dark ? <Sun className="h-4 w-4" aria-hidden="true" /> : <Moon className="h-4 w-4" aria-hidden="true" />}
    </button>
  );
}
