import type { Config } from "tailwindcss";

// As cores vêm de variáveis CSS (ver src/app/globals.css) para o tema escuro/claro
// mudar sem duplicar classes. O formato "R G B" permite usar opacidade (bg-gold/20).
const config: Config = {
  darkMode: "class",
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        bg: "rgb(var(--bg) / <alpha-value>)",
        fg: "rgb(var(--fg) / <alpha-value>)",
        muted: "rgb(var(--muted) / <alpha-value>)",
        line: "rgb(var(--line) / <alpha-value>)",
        surface: "rgb(var(--surface) / <alpha-value>)",
        gold: {
          DEFAULT: "rgb(var(--gold) / <alpha-value>)",
          light: "rgb(var(--gold-light) / <alpha-value>)",
          deep: "rgb(var(--gold-deep) / <alpha-value>)",
        },
        ok: "rgb(var(--ok) / <alpha-value>)",
        warn: "rgb(var(--warn) / <alpha-value>)",
        danger: "rgb(var(--danger) / <alpha-value>)",
      },
      fontFamily: {
        sans: ["var(--font-geist-sans)", "system-ui", "sans-serif"],
        mono: ["var(--font-geist-mono)", "ui-monospace", "monospace"],
      },
    },
  },
  plugins: [],
};

export default config;
