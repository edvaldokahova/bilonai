# Bilonai — Preços e custos (8 out 2026)

Cobrança: assinatura mensal em US$ no Lemon Squeezy (5% + 0,50 US$ por venda). **Sem afiliados na 1.ª fase.**

## Preços decididos
| Plano | US$/mês | ≈ Kz* | Agentes | Teto de uso mensal (a implementar) |
|---|---|---|---|---|
| Alpha Node | **19** | 17,5 mil | Espião | 1 produto/1 país · ~600 anúncios lidos |
| Apex Trader | **39** | 36 mil | Espião + Ofertas | 2 produtos/2 países · ~2.000 anúncios · 30 campanhas |
| Syndicate | **69** | 64 mil | Espião, Ofertas, Gestor, O Cérebro | 5 produtos/4 países · ~4.000 anúncios · 70 campanhas · ~200 mensagens ao Cérebro |

**Frequência do Espião:** Alpha Node a cada **3 dias**; Apex Trader e Syndicate a cada **2 dias** (decisão do fundador, 8 out).

*câmbio de referência ~923 Kz/US$ (o do CLAUDE.md anterior). O Lemon Squeezy converte sozinho para a moeda do cliente.

Referência de mercado (preço de tabela, ferramentas que só espiam anúncios): AdSpy 149 · BigSpy Pro 99 · PowerAdSpy 69–179 · Adligator Pro 32.
O Bilonai fica abaixo das de gama média e entrega agentes que executam, não só consulta.

## Custos usados (valores de 8 out 2026)
- **Apify** (Facebook Ads Library): plano **Free** = 5 US$ de crédito/mês a 5,80 US$ por 1.000 anúncios (~860 anúncios/mês, para todos os clientes e testes juntos). Plano Starter = 19 US$/mês **que são crédito de uso** (3.800 anúncios a 5,00 US$ por 1.000), por isso só é custo fixo se o crédito sobrar.
- **Gemini** (preços de 2027, mais altos que os de hoje): Flash 1,50 in / 7,50 out por 1M tokens; Pro 2,00 / 12,00.
- **Fixos por fase:** ~3 US$/mês (domínios) com Apify Free · + Vercel Pro 20 a partir do 3.º cliente pagante · + Supabase Pro 25 a partir do 6.º · Apify passa a Starter quando o gasto do mês chegar a ~4 US$ (o gatilho é o crédito, não o n.º de clientes). Resend é grátis até 100 e-mails/dia (depois 20).
- **O crédito grátis da Apify chega para pouco:** ~860 anúncios/mês. Um Alpha típico gasta ~400 (2,3 US$), por isso o crédito cobre uns 2 clientes Alpha, ou cerca de meio Apex. Cada teste grátis gasta ~0,70 US$.
- **Vercel Pro no 3.º cliente pagante** (decisão do fundador, fase de validação). Risco conhecido: o plano grátis (Hobby) só permite uso **não comercial** pelos termos da Vercel, por isso a Vercel pode pausar o projeto. Pro mensal, sem fidelização (pode voltar ao grátis).
- Taxas: 5% + 0,50 + 3% de reserva (levantamento/câmbio, reembolsos).

## Margem por cliente (já depois de API e taxas)
| Plano | Preço | Uso típico | Uso máximo dentro dos tetos |
|---|---|---|---|
| Alpha | 19 | 72% | ~67% |
| Apex | 39 | 56% | ~42% |
| Syndicate | 69 | 49% | ~11% |

Sem tetos, o Syndicate em uso máximo custa ~84 US$ de API e dá prejuízo a qualquer preço razoável. Por isso os tetos são parte do produto, não detalhe.
Os custos fixos cobrem-se com 3 a 4 clientes pagantes.

## Teste grátis de 7 dias
Só o Espião, 3 relatórios, sem Ofertas. Custo ≈ 1 US$ por teste. Um teste por e-mail (e por cartão, se o Lemon Squeezy permitir exigi-lo).

## Para o desenho (Opus)
1. Leitura incremental: só os anúncios novos desde a última corrida (o Apify cobra por anúncio).
2. Analisar com IA só os melhores anúncios de cada relatório.
3. Contadores de consumo por cliente e aviso ao atingir 80% do teto. Travão de orçamento da Apify: se o crédito do mês acabar, o Espião adia a corrida e avisa o admin (nunca falha em silêncio). Aviso no admin aos 4 US$ gastos.
3b. Enquanto a Apify estiver no plano grátis, limitar os testes grátis a ~5 por mês.
4. Termos de uso com os tetos escritos (uso justo).
5. Rever tudo ao fim de 30 dias com o custo real do painel de consumos.
