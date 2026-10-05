# BILONAI — Fonte da verdade do projeto

> Lê este ficheiro inteiro antes de qualquer trabalho. Em caso de conflito com documentos antigos
> (Bizao, bizaodigital.com, preços antigos, "O Cérebro" como upsell), **este ficheiro ganha**.
> Arquitetura detalhada: `docs/ARCHITECTURE.md`. Esquema da BD: `supabase/migrations/`.

## 1. O produto
- **Bilonai** (Bil = bilhões, On = conectado, AI). Antes chamava-se Bizao Digital.
- SaaS de **agentes autónomos de IA para tráfego pago** (Ad Intelligence / Competitive Intelligence).
- Mercados: Angola (principal), Moçambique, Brasil; ~1 utilizador dos EUA por cada 50.
- Público: empresários que **já** vendem com tráfego e querem estrutura automática — não iniciantes.
- Frase que molda tudo: **"Humano define direção, agentes executam rotina."**
- Posicionamento: software empresarial premium. Nunca linguagem de infoproduto ("bónus", "hack").

## 2. Planos (preços de outubro de 2026 — os únicos válidos)
| Plano | Kz | R$ | US$ | MT | Agentes | Afiliado |
|---|---|---|---|---|---|---|
| Alpha Node | 24.997 | 139 | 27 | 1.750 | Espião | 35% |
| Apex Trader | 39.997 | 229 | 44 | 2.800 | Espião + Ofertas | 30% |
| **Syndicate** (centro da oferta) | 59.997 | 339 | 65 | 4.200 | Espião, Ofertas, Gestor, O Cérebro, Suporte | 40% |

- Tudo é **assinatura mensal na Okanda Pay** (suporta os 3 países e cobrança recorrente de SaaS).
- **Não existe** Quantum Vault nem O Cérebro como produto avulso. Não existe "bónus".
- Limites por plano (decisão do CTO, confirmar com o fundador): Alpha 1 produto / 1 país;
  Apex 2 produtos / 2 países; Syndicate 5 produtos / 4 países.
- Card do Apex Trader pode ter o selo "Escolha de 8 em cada 10".

## 3. Os agentes (nomes internos → função)
- `spy` — **Espião**: varre a Meta Ad Library via **Apify** (nicho + país), encontra ofertas escaladas,
  analisa anúncios e funil, relatório a cada 2 dias (painel + e-mail + Google Drive do cliente).
- `offers` — **Ofertas**: cruza relatórios do Espião + DNA do negócio + criativos do cliente e gera
  **até 5 campanhas estruturadas por produto por semana**. Só gera um novo pacote depois de feedback
  do utilizador sobre o anterior. Copy de nível imbatível, localizada por país.
- `manager` — **Gestor** (Syndicate): lê métricas e vendas, recomenda escalar/manter/pausar/encerrar
  segundo o ROAS/CPA definidos pelo utilizador. Calcula lucro líquido, CAC e ROI reais.
- `brain` — **O Cérebro** (Syndicate): memória operacional do negócio, metas curto/médio/longo prazo,
  coordena e dá feedback aos agentes, responde a perguntas, lembretes (incl. renovação 5 dias antes e
  no dia), playbooks. Conhece os nomes personalizados dos agentes.
- `support` — **Suporte** (Syndicate): canal público de suporte para os clientes do utilizador → **V1.1**.
- O utilizador pode **renomear** cada agente (só o nome visível) e **pausar** qualquer agente.

## 4. Decisões fechadas (5 out 2026)
- **Sem Meta Marketing API na V1.** O agente estrutura a campanha completa; o utilizador cria-a
  manualmente no Gerenciador, marca **"Publicado"** e envia desempenho por **print** (Gemini visão
  extrai os números, o utilizador confirma; o print não é guardado), por 3 campos manuais ou CSV.
- Cada campanha tem um **código único** (`bil-xxxxx`) para o nome da campanha e os UTMs → liga vendas a campanhas.
- **Vendas** entram por webhook por utilizador (Okanda Pay, **UTMfy**, genérico) → tabela `sales`.
- Quem já fatura: passo "Importar o que já funciona" no wizard (prints + relatório de vendas →
  "DNA vencedor" condensado em texto).
- **Login:** magic link (e-mail via Resend), palavra-passe opcional, 2FA TOTP (MFA nativo do Supabase).
  Nunca mostrar palavras-passe geradas numa página.
- Webhook de pagamento: **`/api/webhooks/okanda`** (plural).
- Supabase **Free até 5 utilizadores**; o fundador muda para Pro quando o 6.º assinar (alerta no admin aos 4).
- Ficheiros pesados (relatórios, criativos) vão para o **Google Drive do cliente** (scope `drive.file`).
  A BD só guarda texto, números e IDs.

## 5. Escopo
**V1 (sprint de 5 dias):** webhook + callback Okanda, conta automática, magic link, planos e paywall
visual, Setup Wizard (Drive, DNA, produtos, custos, importar estrutura — tudo com "Deixar para depois"),
Espião, Ofertas (pacote semanal, "Publicado", feedback por print), Gestor e Cérebro em versão *lite*,
pausar/renomear agentes, webhooks de vendas (Okanda/UTMfy), tickets de suporte, admin (utilizadores,
consumos, saúde, alertas), páginas `/privacy` `/terms`, e-mails com boa entregabilidade.

**V1.1 (depois do lançamento):** Meta Marketing API (só leitura primeiro, depois criação em PAUSED e
"Assume o Comando"), Pixel Bilonai, Agente de Suporte público, página de afiliados, voz, tour guiado,
geração de imagens. Na UI aparecem como **"Em breve"**, nunca vendidos como prontos.

## 6. Domínios
- `bilonai.com` — landing (construída no fim, calibrada com o produto real).
- `agents.bilonai.com` — a plataforma (também serve as rotas `/api/*`).
- `admin.bilonai.com` — painel do fundador.
- Uma única app Next.js; o `middleware` encaminha por domínio.

## 7. Identidade visual
- Logo novo: símbolo "olho" (anéis abertos dourados + pupila creme) + wordmark BILONAI + "autonomous agents".
- Ouro: `#F3D77A → #D4A936 → #A67C1A`. Creme: `#F4EFE6`. Cinza do descritor: `#A9A396`. Fundo: quase preto `#0A0B0D`.
- Tema escuro por defeito, efeito de vidro discreto, tema claro opcional. Nível "SaaS de 1 milhão".
- Ícones: `public/favicon.png`, `public/android-chrome-512x512.png`. SVGs oficiais nos documentos do projeto.

## 8. E-mail (Resend)
- Login/segurança: `login@bilonai.com`. Suporte: `suporte@bilonai.com`. Também `parceria@`, `agentes@`.
- Agentes: `spy@agents.bilonai.com`, `offers@…`, `manager@…`, `brain@…`; o nome visível é o nome
  personalizado pelo utilizador. SPF + DKIM + DMARC obrigatórios. Supabase Auth não envia e-mails.

## 9. Regras de trabalho (obrigatórias)
- **Passo a passo.** Uma parte de cada vez; no fim de cada parte: o que foi feito, ficheiros, como
  testar, problemas — e **parar** para aprovação.
- **Poupança de tokens:** edições pequenas, sem reescrever ficheiros inteiros, sem pacotes desnecessários.
- O fundador **não é programador**: instruções exatas (onde clicar, o que escrever, o que esperar).
- **Segredos nunca no código nem no git.** Só em variáveis de ambiente (Vercel + `.env.local`).
  As chaves que estiveram em texto nos documentos do projeto **devem ser rodadas** antes do lançamento.
- Modelo: planeamento profundo → Opus; construção prática → Sonnet. Avisar o fundador quando mudar.
- Língua da UI na V1: **pt-BR** e **en-US**. Moedas: Kz, MT, R$, US$.
- Pensar como CTO: discordar quando necessário, proteger custos, segurança e a promessa do produto.

## 10. Lembretes pendentes para o fundador
- Colocar as URLs `/privacy` e `/terms` no Google Cloud (ecrã de consentimento OAuth) quando estiverem online.
- V1.1: URL de exclusão de dados na Meta + publicar a app Meta (ID 2000340507331758).
- Corrigir o redirect URI do Google com typo (`bilionai.vercel.app`) e adicionar `https://agents.bilonai.com/api/auth/google/callback`.
- Rodar todas as chaves de API expostas nos documentos.
- Mudar o Supabase para Pro ao 6.º utilizador.
