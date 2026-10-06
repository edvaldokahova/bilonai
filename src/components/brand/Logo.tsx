import { useId } from "react";

// Geometria oficial do logo novo da Bilonai (olho: anéis abertos + pupila).
// O texto usa "currentColor", por isso muda sozinho entre tema escuro (creme) e claro (escuro).

function GoldGradient({ id }: { id: string }) {
  return (
    <linearGradient id={id} gradientUnits="userSpaceOnUse" x1="-43" y1="-43" x2="43" y2="43">
      <stop offset="0" stopColor="#F3D77A" />
      <stop offset="0.5" stopColor="#D4A936" />
      <stop offset="1" stopColor="#A67C1A" />
    </linearGradient>
  );
}

function Eye({ gold }: { gold: string }) {
  return (
    <>
      <circle r="40" stroke={`url(#${gold})`} strokeWidth="6" strokeLinecap="round" strokeDasharray="205 46.33" transform="rotate(-60)" />
      <circle r="25" stroke={`url(#${gold})`} strokeWidth="5" strokeLinecap="round" strokeDasharray="120 37.08" transform="rotate(120)" />
      <circle r="9" fill="currentColor" />
    </>
  );
}

/** Só o símbolo (olho). Bom para cabeçalhos pequenos, ícones e estados vazios. */
export function LogoMark({ className }: { className?: string }) {
  const gold = `g${useId().replace(/:/g, "")}`;
  return (
    <svg viewBox="10 10 100 100" fill="none" role="img" aria-label="Bilonai" className={className}>
      <defs>
        <GoldGradient id={gold} />
      </defs>
      <g transform="translate(60 60)">
        <Eye gold={gold} />
      </g>
    </svg>
  );
}

/** Logótipo horizontal: BIL(olho)NAI. Com `tagline`, mostra "autonomous agents". */
export function Logo({ className, tagline = false }: { className?: string; tagline?: boolean }) {
  const uid = useId().replace(/:/g, "");
  const gold = `g${uid}`;
  const cap = `c${uid}`;
  return (
    <svg
      viewBox={tagline ? "50 22 500 140" : "50 22 500 100"}
      fill="none"
      role="img"
      aria-label="Bilonai"
      className={className}
    >
      <defs>
        <GoldGradient id={gold} />
        <clipPath id={cap}>
          <rect x="0" y="40" width="600" height="64" />
        </clipPath>
      </defs>

      <g transform="translate(300 72)">
        <Eye gold={gold} />
      </g>

      <g stroke="currentColor" strokeWidth="6" strokeLinejoin="miter" strokeMiterlimit="10" fill="none">
        <path d="M64.5 40V104" />
        <path d="M64.5 43H91.5A14.5 14.5 0 0 1 91.5 72H64.5" />
        <path d="M64.5 72H94.5A14.5 14.5 0 0 1 94.5 101H64.5" />
        <path d="M147 40V104" />
        <path d="M185 40V101H225" />
        <g clipPath={`url(#${cap})`}>
          <path d="M378 104V40L424 104V40" />
        </g>
        <g clipPath={`url(#${cap})`}>
          <path d="M454 104L481 40L508 104" />
          <path d="M461 88H501" strokeWidth="4.5" />
        </g>
        <path d="M535.5 40V104" />
      </g>

      {tagline ? (
        <g stroke="rgb(var(--muted))" strokeWidth="1.5" strokeLinecap="butt" strokeLinejoin="round" fill="none">
          <circle cx="201.6" cy="143" r="4.5" />
          <path d="M206.1 138V148" />
          <path d="M209.5 138V143.5A4.5 4.5 0 0 0 218.5 143.5" />
          <path d="M218.5 138V148" />
          <path d="M224.9 135V145A3 3 0 0 0 228.4 148" />
          <path d="M221.9 138H228.9" />
          <circle cx="236.8" cy="143" r="4.5" />
          <path d="M244.7 148V138" />
          <path d="M244.7 142.5A4.5 4.5 0 0 1 253.7 142.5V148" />
          <circle cx="261.6" cy="143" r="4.5" />
          <path d="M269.5 148V138" />
          <path d="M269.5 142A4 4 0 0 1 277.5 142V148" />
          <path d="M277.5 142A4 4 0 0 1 285.5 142V148" />
          <circle cx="293.4" cy="143" r="4.5" />
          <path d="M301.3 138V143.5A4.5 4.5 0 0 0 310.3 143.5" />
          <path d="M310.3 138V148" />
          <path d="M321.3 139.4C320.7 138.2 319.5 138 317.9 138C315.7 138 314.5 139 314.5 140.4C314.5 142.2 316.2 142.7 317.9 143C319.9 143.4 321.9 143.9 321.9 145.6C321.9 147.2 320.2 148 317.9 148C315.9 148 314.5 147.2 314.1 146" />
          <circle cx="339" cy="143" r="4.5" />
          <path d="M343.5 138V148" />
          <circle cx="351.4" cy="143" r="4.5" />
          <path d="M355.9 138V148A4.5 4.5 0 0 1 351.4 152.5H348.9" />
          <path d="M359.3 143H368.3" />
          <path d="M368.3 143A4.5 4.5 0 1 0 367.25 145.9" />
          <path d="M371.7 148V138" />
          <path d="M371.7 142.5A4.5 4.5 0 0 1 380.7 142.5V148" />
          <path d="M387.1 135V145A3 3 0 0 0 390.6 148" />
          <path d="M384.1 138H391.1" />
          <path d="M402.1 139.4C401.5 138.2 400.3 138 398.7 138C396.5 138 395.3 139 395.3 140.4C395.3 142.2 397 142.7 398.7 143C400.7 143.4 402.7 143.9 402.7 145.6C402.7 147.2 401 148 398.7 148C396.7 148 395.3 147.2 394.9 146" />
        </g>
      ) : null}
    </svg>
  );
}
