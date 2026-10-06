import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Bilonai",
    short_name: "Bilonai",
    description: "Agentes autónomos de inteligência artificial para tráfego pago.",
    start_url: "/",
    display: "standalone",
    background_color: "#0A0B0D",
    theme_color: "#0A0B0D",
    icons: [{ src: "/android-chrome-512x512.png", sizes: "512x512", type: "image/png", purpose: "any" }],
  };
}
