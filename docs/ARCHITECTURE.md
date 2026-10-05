# Bilonai — Blueprint de arquitetura (V1)

Escrito em 5 out 2026. Regras e decisões de negócio: `CLAUDE.md`.

## 1. Visão geral

```
 Okanda Pay ──webhook──▶ /api/webhooks/okanda ──▶ cria utilizador + subscrição
      │                                             │
      └──redirect──▶ /api/checkout/callback ──▶ magic link ──▶ Setup Wizard
                                                     │
 Utilizador ─▶ agents.bilonai.com (Next.js na Vercel) ─▶ Supabase (Postgres + Auth)
                     │            ▲                          │
                     │            └──── pg_cron (1/min) ─────┘  chama /api/worker
                     ├─▶ Apify (Ad Library, assíncrono) ──webhook──▶ /api/webhooks/apify
                     ├─▶ Gemini (texto + visão, saída JSON)
                     ├─▶ Google Drive do cliente (relatórios e criativos)
                     └─▶ Resend (login, relatórios, alertas)
 Vendas (Okanda / UTMfy) ──▶ /api/webhooks/sales/[token] ──▶ tabela sales
```

Uma única app Next.js serve os três domínios; o `middleware.ts` decide pelo host:
`agents.` → app do cliente, `admin.` → painel do fundador (só `role = admin`), raiz → landing.

## 2. Stack
- Next.js (App Router, TypeScript), Tailwind CSS, Lucide React. Sem bibliotecas de UI pesadas.
- Supabase: Postgres, Auth (magic link + MFA TOTP), Storage só para screenshots de tickets (temporárias).
- Vercel (Hobby), Resend, Gemini API, Apify, Google Drive API.
- **Versão do Next:** ver a decisão pendente na secção 12.

## 3. Pagamento → conta (zero fricção)
1. **Webhook** `/api/webhooks/okanda`
   - Valida a assinatura (o método exato depende da documentação da Okanda — pendente).
   - Idempotência: guarda `event_id` em `payment_events`; se já existe, responde 200 e não faz nada.
   - Mapeia o ID do produto Okanda → `plan` (`alpha` | `apex` | `syndicate`) por variáveis de ambiente.
   - Cria o utilizador (Supabase Admin API, e-mail já confirmado) se não existir, faz upsert de
     `subscriptions` (plano, estado, `current_period_end`) e cria as linhas de `agents` do plano.
   - Renovação → estende o período. Cancelamento/falha → `past_due`/`canceled`.
2. **Callback** `/api/checkout/callback`
   - Se a Okanda enviar um ID de transação verificável pela API dela → geramos o magic link no
     servidor e o cliente entra **já logado** no wizard.
   - Senão → página elegante "A preparar o teu escritório…" que espera o webhook e envia o magic link
     por e-mail. Nunca confiamos num e-mail que venha só na URL.
3. **Acesso:** o `middleware` lê a subscrição. Expirada → ecrã de renovação com o link da Okanda.
   Lembretes de renovação: 5 dias antes e no dia (e-mail + notificação).

## 4. Planos e paywall visual
- Fonte única: `subscriptions.plan`. As funções SQL `plan_agents(plan)` e `plan_limits(plan)`
  dizem quais os agentes e os limites; o front e o back usam sempre a mesma regra.
- Nada fica escondido: módulos não incluídos aparecem com prévia desfocada + cadeado + modal de
  upgrade com o link de checkout do plano certo.

## 5. Setup Wizard (pós-pagamento, nada é bloqueante)
1. **Escritório virtual** — conectar Google Drive (scope `drive.file`). Cria `Bilonai — <Nome do negócio>`
   com subpastas `Relatórios do Espião`, `Campanhas`, `Criativos — <Produto>`, `O Cérebro`.
2. **DNA do negócio** — nicho, países/regiões, tom de voz, metas curto/médio/longo prazo,
   orçamento semanal de tráfego (slider), ROAS/CPA alvo, língua.
3. **Produtos** — nome, descrição, preço, destino (link ou WhatsApp), oferta (order bump, upsell,
   downsell), página do Facebook usada, criativos com descrição/objetivo/público.
4. **Custos operacionais** — ferramentas, internet, espaço, etc.
5. **Importar o que já funciona** — prints de campanhas vencedoras e relatório de vendas.
- Cada passo tem "Deixar para depois" + "Lembrar-me daqui a X dias". Fim → animação
  "A ativar os teus agentes…" → painel.

## 6. Motor de agentes (fila na base de dados)
- **Porquê:** a Vercel Hobby limita a duração de cada função; e só permite cron diário.
- **Fila** `agent_jobs` (`queued → running → waiting_external → done | failed`), com `run_after`,
  tentativas e trancas (`FOR UPDATE SKIP LOCKED` via função `claim_next_job`).
- **Relógio:** `pg_cron` dentro do Supabase chama `/api/worker` a cada minuto via `pg_net`, com um
  segredo no cabeçalho (guardado no Supabase Vault). Cada chamada processa poucos passos curtos.
  Isto também mantém o projeto Free ativo.
- **Gatilho por acesso:** ao abrir o painel, se a última varredura tem > 48 h, cria o job dessa pessoa.
  O trabalho distribui-se pelo dia em vez de tudo às 00:00.
- Cada passo é desenhado para durar bem menos do que o limite da função; trabalho grande é partido em passos.

### 6.1 Espião (a cada 2 dias)
1. `spy.scan` → para cada (nicho, país, palavras-chave) calcula `cache_key`. Se existe uma
   `market_scans` com < 48 h → reutiliza (**scan partilhado** entre utilizadores do mesmo nicho/país).
2. Senão inicia o actor Apify **assíncrono** com webhook → `/api/webhooks/apify` → job `spy.ingest`.
3. `spy.ingest` → filtra e reduz (ex.: top 30 anúncios por longevidade/variações), guarda só o resumo.
4. `spy.analyze` → Gemini (JSON) analisa anúncios, ofertas e funis → relatório.
5. `spy.deliver` → ficheiro no Drive do cliente, notificação, e-mail `spy@agents.bilonai.com`.
- Orçamento Apify por utilizador/mês com alerta no admin.

### 6.2 Ofertas (pacote semanal)
- `offers.pack` → por produto, até 5 campanhas: objetivo, público, conjuntos, anúncios (copies,
  ganchos, criativo recomendado do Drive), orçamento sugerido dentro do orçamento semanal,
  **código `bil-xxxxx`** e URL com UTMs prontos.
- Novo pacote só quando o anterior recebeu feedback (ou o utilizador pede explicitamente).

### 6.3 Ciclo de feedback (substitui a Marketing API na V1)
- "Marcar como publicado" (data + orçamento).
- Desempenho: upload de print → Gemini visão → números → o utilizador confirma → `campaign_metrics`
  (`source = screenshot`). Alternativas: 3 campos manuais, CSV.
- Vendas por webhook com `utm_campaign = bil-xxxxx` → ligadas à campanha automaticamente.
- E-mail semanal "Como correram as tuas campanhas?" com link direto.
- `campaign_metrics.source` já prevê `meta_api` → a V1.1 encaixa sem refazer nada.

### 6.4 Gestor e Cérebro (versão lite na V1)
- Gestor: cruza métricas + vendas + custos → recomendações e painel financeiro
  (faturamento bruto, custos, lucro líquido, CAC real, ROAS, ROI).
- Cérebro: chat com contexto condensado (DNA, metas, nomes dos agentes, últimos relatórios,
  memória), lembretes e playbooks. Memória longa em ficheiros no Drive; na BD só o resumo.
- Modo "autonomia total" do Cérebro fica para quando houver ações automáticas (V1.1).

## 7. Gemini
- Sempre saída JSON com esquema (`responseMimeType: application/json`) → respostas curtas e validadas.
- Prompt de sistema montado a partir de: DNA do negócio, "DNA vencedor", nomes personalizados dos
  agentes, país e língua do utilizador.
- Cada chamada regista tokens em `usage_events`.

## 8. Google Drive
- OAuth com `access_type=offline`; o refresh token é guardado **encriptado** (AES-256-GCM, chave
  `ENCRYPTION_KEY` só no servidor) em `google_connections`.
- Scope `drive.file`: a Bilonai só vê o que ela própria cria → não exige verificação demorada do Google.

## 9. Vendas e custos
- Cada utilizador tem uma URL secreta `/api/webhooks/sales/<token>` (guardamos só o hash do token).
- Normalizadores por origem: Okanda Pay, UTMfy, genérico. Upsert idempotente por `(user_id, source, external_id)`.

## 10. Segurança
- RLS ativo em **todas** as tabelas. Utilizadores só **leem** as suas linhas; todas as escritas
  passam por rotas do servidor que validam sessão, plano e limites (service role só no servidor).
- Webhooks: assinatura/segredo + idempotência + limite de pedidos.
- MFA TOTP opcional; e-mail de segurança em cada alteração sensível.
- Nenhum segredo no código; `.env*` no `.gitignore`.

## 11. Limites do plano Free e retenção
- BD só com texto/números. Dados brutos da Apify apagados após o relatório.
- `pg_cron` diário: apaga `payment_events` > 30 dias, `usage_events` > 30 dias (após agregar em
  `usage_daily`), notificações lidas > 60 dias, tickets lidos > 15 dias, scans expirados > 7 dias.
- Admin mostra o tamanho da BD; alerta aos 350 MB e aos 4 utilizadores.
- Backup noturno das tabelas críticas para o Drive do fundador (o plano Free não tem backups).

## 12. Decisão pendente: versão do Next.js
A instrução original pedia compatibilidade com Node 16 porque o fundador corria o projeto no Windows 8.
Agora o código é construído na cloud e a Vercel compila com Node 20 — o Windows 8 deixou de ser
necessário para correr o projeto.
- **Recomendação:** Next.js 14.2 (estável, com correções de segurança) + Node 20 na Vercel.
- **Alternativa:** Next.js 13.5.x (corre em Node 16), mais antigo e com menos correções.

## 13. Pendências externas
- Documentação/exemplo do webhook da Okanda Pay (payload, assinatura, IDs de produto, URL de retorno).
- Documentação do webhook da UTMfy.
- DNS de `bilonai.com` (Vercel + Resend: SPF, DKIM, DMARC) e receção de e-mail (`suporte@` etc.).
- Actor da Apify escolhido para a Ad Library e limite de gasto mensal.
