import type { Metadata, Viewport } from "next";
import { GeistSans } from "geist/font/sans";
import { GeistMono } from "geist/font/mono";
import "./globals.css";

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "https://bilonai.com";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: { default: "Bilonai — autonomous agents", template: "%s · Bilonai" },
  description: "Agentes autónomos de inteligência artificial para quem já investe em tráfego pago.",
  icons: { icon: "/favicon.png", apple: "/android-chrome-512x512.png" },
  openGraph: {
    type: "website",
    siteName: "Bilonai",
    title: "Bilonai — autonomous agents",
    description: "Humano define direção, agentes executam rotina.",
  },
  // Provisório: sem indexação até ao lançamento. Remover esta linha no dia de lançar.
  robots: { index: false, follow: false },
};

export const viewport: Viewport = {
  themeColor: "#0A0B0D",
  colorScheme: "dark light",
  width: "device-width",
  initialScale: 1,
};

// Aplica o tema guardado antes de pintar (evita "piscar"). Escuro é o padrão.
const themeScript = `(function(){try{var t=localStorage.getItem('bilonai-theme');document.documentElement.classList.toggle('dark',t!=='light');}catch(e){}})();`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR" className={`dark ${GeistSans.variable} ${GeistMono.variable}`} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
      </head>
      <body>{children}</body>
    </html>
  );
}
