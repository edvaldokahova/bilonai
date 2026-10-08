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
- **Apify** (Facebook Ads Library): 5,00 US$ por 1.000 anúncios (plano Starter, 19 US$/mês com 19 US$ de crédito).
- **Gemini** (preços de 2027, mais altos que os de hoje): Flash 1,50 in / 7,50 out por 1M tokens; Pro 2,00 / 12,00.
- **Fixos por fase:** ~22 US$/mês até ao 3.º cliente pagante (Apify Starter 19 + domínios ~3) · ~42 a partir do 3.º (+ Vercel Pro 20) · ~67 a partir do 6.º (+ Supabase Pro 25). Resend é grátis até 100 e-mails/dia (depois 20).
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
3. Contadores de consumo por cliente e aviso ao atingir 80% do teto.
4. Termos de uso com os tetos escritos (uso justo).
5. Rever tudo ao fim de 30 dias com o custo real do painel de consumos.
