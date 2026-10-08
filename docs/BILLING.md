# Bilonai — Faturação com Lemon Squeezy (desenho V1, 8 out 2026)

> Desenho feito em Opus e revisto por um segundo agente contra a documentação oficial do Lemon Squeezy.
> A construção (Sonnet) segue a ordem da secção 11. Preços e tetos: `docs/PRICING.md`.

## 0. Em linguagem simples
1. O cliente escolhe um plano no site, escreve o e-mail e vai para o checkout do Lemon Squeezy.
2. Mete o cartão. **Não paga nada durante 7 dias** (teste grátis). Ao 8.º dia o Lemon Squeezy cobra sozinho.
3. Assim que o Lemon Squeezy nos avisa, criamos a conta e enviamos um e-mail com o link de acesso.
4. Todos os meses o Lemon Squeezy cobra e avisa-nos. Se o cartão falhar, ele tenta de novo durante ~2 semanas.
5. Se um aviso se perder, um verificador automático vai perguntar ao Lemon Squeezy de 15 em 15 minutos e corrige.
   Ninguém precisa de ativar contas à mão.

## 1. Decisões
| # | Decisão | Porquê |
|---|---|---|
| D1 | Teste grátis **com cartão obrigatório** (modelo "Payment required") | Trava abusos e custos da Apify; conversão automática no 8.º dia; o público já tem Visa para anúncios. |
| D2 | **Um só produto "Bilonai" com 3 variantes com teste.** Quem já teve teste recebe o checkout com `skip_trial` (a confirmar em modo de teste; plano B: 2.º produto sem teste). | Menos IDs para configurar; o portal só mostra os 3 planos. |
| D3 | **Checkout criado pelo nosso servidor** (API `POST /v1/checkouts`): e-mail pré-preenchido, `ref` nosso, página de regresso, só a variante escolhida. | Controlo do teste e ligação segura pagamento → conta. |
| D4 | Conta criada **pelo aviso (webhook)**, não antes do pagamento. | Menos atrito. |
| D5 | **Fonte da verdade = a subscrição no Lemon Squeezy.** Em cada aviso relemos a subscrição pela API e gravamos esse estado. | Avisos fora de ordem ou repetidos deixam de importar. |
| D6 | **Verificador a cada 15 min** (pg_cron) que relê as subscrições recentes/ativas. | O Lemon Squeezy só repete um aviso falhado 3 vezes em ~2,5 min e depois desiste. |
| D7 | Pagamento falhado: acesso continua, **agentes param 3 dias depois** até o pagamento voltar. | Não pagamos Apify/Gemini a quem não paga. |
| D8 | Mudar de plano e cancelar: **portal de cliente do Lemon Squeezy**. **Pausa desligada.** | Zero código de cobrança nosso; menos estados. |
| D9 | Durante o teste: **só o Espião, 3 relatórios**, qualquer que seja o plano. Em `active` abre tudo o que o plano inclui. | Custo ≈ 1 US$ por teste. |
| D10 | **Uma subscrição viva por conta.** Se já tem uma não expirada, o botão "Assinar" leva ao portal. | Evita cobrar duas vezes a mesma pessoa. |
| D11 | Traduções **sem biblioteca**: dicionários `pt-BR` e `en-US`; o francês entra depois com mais um ficheiro. | Regra de não instalar pacotes sem necessidade. |

## 2. Configuração no Lemon Squeezy (o fundador faz, em **Test mode** primeiro; passo a passo na parte 2 da construção)
1. **Produto "Bilonai"** (subscrição mensal, US$) → variantes Alpha Node 19, Apex Trader 39, Syndicate 69, cada uma com **Free trial = 7 days**.
2. Esconder os links públicos de compra do produto (as vendas passam sempre pelo nosso checkout).
3. **Settings → Webhooks** → `https://agents.bilonai.com/api/webhooks/lemonsqueezy`, segredo forte, eventos:
   `subscription_created`, `subscription_updated`, `subscription_cancelled`, `subscription_resumed`, `subscription_expired`,
   `subscription_payment_success`, `subscription_payment_failed`, `subscription_payment_recovered`, `subscription_payment_refunded`, `order_refunded`.
4. **Settings → API** → chave só para o servidor.
5. **Settings → Customer portal** → ativo; mudar de plano entre as 3 variantes; cancelar sim; **pausar não**.
6. Anotar Store ID, os 3 IDs de variante, chave da API e segredo do webhook → variáveis (secção 9).
7. Testar com o cartão de teste. **Funciona antes da aprovação da conta.** No lançamento repetir em Live mode (IDs mudam).

## 3. Fluxos
**A. Novo cliente**
1. "Começar 7 dias grátis" (plano X) → página nossa pede só o e-mail.
2. `POST /api/billing/checkout {plan, email}`: se a conta tem subscrição não expirada → devolve o portal (D10).
   Teste permitido se o e-mail/conta nunca teve teste **e** `MAX_TRIALS_PER_MONTH` não foi atingido; senão `skip_trial`.
   Cria `checkout_sessions(ref)` e chama a API com `checkout_data.email`, `checkout_data.custom = {ref}`,
   `product_options.enabled_variants = [variante]`, `product_options.redirect_url = …/welcome?ref=…`, `expires_at = +24h`.
3. Paga → Lemon Squeezy redireciona para `/welcome?ref=…` e envia os avisos.
4. Webhook liga ao `ref`, cria a conta (secção 5) e envia o e-mail de boas-vindas.
5. `/welcome` pergunta a cada 3 s `GET /api/billing/status?ref=…`. Ao fim de 30 s ainda `pending` → o servidor procura a subscrição
   na API por esse `ref`/e-mail e processa-a ele próprio; ao fim de 2 min → mensagem calma + alerta ao admin.

**B. Entrar depois** — `/login`: e-mail → link mágico (Supabase gera, Resend envia). Resposta sempre igual, exista ou não a conta.

**C. Renovação** — avisos de pagamento + `subscription_updated` → relemos a subscrição → novo `renews_at`.

**D. Pagamento falhado** — `past_due` → faixa "Atualiza o cartão" (link pedido à API na hora). `past_due_since` marca o início; agentes param ao fim de 3 dias.
Recuperado → `active`, limpa `past_due_since`, agentes retomam. `unpaid` → só ecrã de faturação (pode ficar assim para sempre; não dependemos de `expired`).

**E. Cancelamento** — `cancelled` → acesso total até `ends_at`; faixa com "Retomar".

**F. Fim** — `expired` → só faturação e exportação; agentes desligados. Dados apagados 60 dias depois (a confirmar, ver secção 12).

**G. Mudar de plano** — portal → nova variante → novo plano; agentes que saem ficam bloqueados, não apagados.

**H. Reembolso** — `subscription_payment_refunded` / `order_refunded` total → cancelamos pela API, acesso acaba já, alerta ao admin.

**I. Cliente que volta** — fluxo A com `skip_trial`; reutiliza a conta existente.

## 4. Estado → acesso
| Estado | Entra no painel | Agentes correm | `access_until` |
|---|---|---|---|
| `on_trial` | sim | só Espião, até 3 relatórios | `trial_ends_at` + 72 h |
| `active` | sim | todos os do plano | `renews_at` + 72 h |
| `past_due` | sim (faixa) | só nos 3 dias após `past_due_since` | `renews_at` + 72 h |
| `cancelled` | sim (faixa) | sim | `ends_at` |
| `unpaid` / `expired` / `paused` | só faturação | não | agora |
As 72 h de folga evitam cortar quem está a pagar enquanto o aviso da renovação não chega.
Regras únicas no código: `canEnterApp(sub)`, `canUseAgents(sub)`; na BD `has_active_plan(uid)` e `can_use_agents(uid)` iguais.

## 5. Webhook `/api/webhooks/lemonsqueezy`
1. Corpo **cru** (máx. 256 KB); `X-Signature` = HMAC-SHA256 **hex** do corpo com `LEMONSQUEEZY_WEBHOOK_SECRET`, comparação em tempo constante. Falha → 401.
2. `data.attributes.test_mode` ≠ `LEMONSQUEEZY_TEST_MODE` → regista e ignora (200).
3. **Idempotência:** `event_id = sha256(corpo)`. Se já existe com `processed_at` preenchido → 200. Se existe sem `processed_at` → processa de novo.
4. **Estado real:** para `subscription_*` (e invoices, pelo `subscription_id`) → `GET /v1/subscriptions/{id}` e usa essa resposta.
5. **Quem é** (por esta ordem): `meta.custom_data.ref` → `checkout_sessions` (user_id/e-mail) → `user_id` de uma subscrição já gravada → `user_email`.
   E-mail diferente do da sessão → alerta. Sem conta → cria com **bloqueio** (advisory lock por e-mail): `auth.admin.createUser` (se "já existe", procura),
   `profiles` (língua do `ref`), 5 linhas em `agents` com nomes por defeito.
6. **Regras do teste no próprio webhook** (os links do Lemon Squeezy podiam ser usados sem passar por nós): `on_trial` sem `ref` válido, ou para conta/e-mail
   que já teve teste → acabar o teste pela API (`billing_anchor = 0`; confirmar em modo de teste) ou cancelar, e alertar. Senão grava `trial_used_at`.
7. **Plano** pela `variant_id` (3 variáveis). Desconhecida → alerta crítico + 200.
8. Upsert em `subscriptions` **pela `provider_subscription_id`**. Uma conta com outra subscrição viva → alerta (D10), não sobrepõe.
9. `checkout_sessions.status = ready`; 1.ª criação → e-mail de boas-vindas (falha no e-mail não falha o webhook).
10. Marca `processed_at`; responde 200. Exceção → guarda `error`, 500 (o Lemon Squeezy repete) + alerta.

**Verificador (pg_cron a cada 15 min → `/api/billing/reconcile`, protegido por `WORKER_SECRET`)**: lista na API as subscrições alteradas recentemente
e todas as não expiradas da nossa BD; aplica os passos 4–9. Apanha avisos perdidos e corrige `access_until`.

## 6. Base de dados — migração `0003_billing_lemonsqueezy` (`subscriptions` está vazia)
- `subscriptions` passa a ter **`provider_subscription_id` como chave** e `user_id` com índice (uma conta pode ter histórico).
  `status` → `text` com check (`on_trial, active, paused, past_due, unpaid, cancelled, expired`); apaga o tipo `sub_status`.
  `current_period_end → access_until`; `okanda_customer_id → provider_customer_id`; sai `okanda_subscription_id`.
  Novas: `provider` (default `lemonsqueezy`), `variant_id`, `plan`, `trial_ends_at`, `renews_at`, `ends_at`, `past_due_since`, `test_mode`, `created_at`.
  Índice único parcial: no máximo **uma subscrição não expirada por `user_id`**.
- `profiles`: `trial_used_at`, `last_magic_link_at` (limite 1 link/min).
- Nova `checkout_sessions(ref pk, email, plan, with_trial, locale, user_id null, status pending|ready, subscription_id null, created_at)`; sem leitura pública; limpa aos 7 dias.
- `payment_events.provider` default `lemonsqueezy`.
- `has_active_plan(uid)`, `can_use_agents(uid)` e `current_plan(uid)` com a regra da secção 4.
- `plan_limits` com os tetos: `spy_interval_days` 3/2/2, `ads_per_month` 600/2000/4000, `campaigns_per_month` 0/30/70,
  `brain_messages_per_month` 0/0/200; `trial` = `{agents:[spy], reports:3}`.
- Job pg_cron do verificador (com o worker na migração seguinte, usando Vault para o segredo).

## 7. Tetos, teste e travão de custos
- **Antes de cada tarefa** (worker): `can_use_agents` → teto do plano no mês (`usage_events`) → se `on_trial`, n.º de relatórios.
- **Travão Apify global:** gasto do mês ≥ `APIFY_MONTHLY_BUDGET_USD` (4,5 com a Apify grátis) → adia e alerta.
- Aviso ao cliente aos 80% de um teto; aos 100% o agente espera pelo mês seguinte (nunca cobra extra).
- `MAX_TRIALS_PER_MONTH` (5 com a Apify grátis) → acima disso, checkout com `skip_trial`.

## 8. Traduções
`src/i18n/pt-BR.ts`, `src/i18n/en-US.ts` (mesmas chaves; o TypeScript avisa se faltar uma), helper `t(locale, key)`.
Língua: `profiles.locale` → cookie → `Accept-Language` (pt-* → pt-BR, resto → en-US). E-mails na língua do perfil.

## 9. Variáveis de ambiente (Vercel, nunca no git)
`LEMONSQUEEZY_API_KEY`, `LEMONSQUEEZY_STORE_ID`, `LEMONSQUEEZY_WEBHOOK_SECRET`, `LEMONSQUEEZY_TEST_MODE` (`1` até ao lançamento),
`LS_VARIANT_ALPHA`, `LS_VARIANT_APEX`, `LS_VARIANT_SYNDICATE`, `APIFY_MONTHLY_BUDGET_USD`, `MAX_TRIALS_PER_MONTH`, `WORKER_SECRET`. Saem: `OKANDA_*`.

## 10. Segurança
- Webhook só com assinatura válida; nunca registar o segredo nem o corpo completo nos logs.
- Checkout e link mágico com limite por IP e por e-mail; respostas que não revelam se o e-mail existe.
- `/api/billing/status?ref` só devolve `pending|ready`; `ref` aleatório de 128 bits, expira em 24 h.
- Links do portal/cartão pedidos à API **na hora do clique** (expiram em 24 h); nunca guardados.
- Chave da API só no servidor; nenhum dado de cartão na nossa BD.

## 11. Ordem de construção (Sonnet; uma parte de cada vez, cada uma testável)
1. **Migração 0003** + `.env.example`. Teste: corre no SQL Editor; advisors limpos.
2. **Configuração do Lemon Squeezy** (guia para o fundador) + **webhook** + `lib/billing`. Teste: compra de teste cria `subscriptions` certa; repetir o aviso não duplica.
3. **Resend** (domínio, SPF/DKIM/DMARC) + e-mail de boas-vindas/link mágico + `/auth/confirm` + `/login`. Teste: o link chega e entra.
4. **Checkout** (página do e-mail, `/api/billing/checkout`, `/welcome`, `/api/billing/status`). Teste: compra ponta a ponta; 2.º teste com o mesmo e-mail recebe `skip_trial`.
5. **Verificador** (`/api/billing/reconcile` + pg_cron). Teste: desligar o webhook, comprar, e o verificador cria a conta em ≤ 15 min.
6. **Ecrã de faturação** (estado, faixas, "Gerir assinatura"). Teste: cancelar/retomar e mudar de plano no portal refletem no painel.
7. **Travões** (tetos, teste, Apify) — no worker, com o Espião. **i18n** base em paralelo com 4–6.

## 12. Em aberto (decisão do fundador)
- Dados apagados **60 dias** depois do fim da assinatura? (proposta)
- E-mail de aviso **2 dias antes do fim do teste**? (recomendado: reduz contestações de pagamento)
- A confirmar na construção (modo de teste): `skip_trial` no checkout e `billing_anchor = 0` para acabar um teste.
