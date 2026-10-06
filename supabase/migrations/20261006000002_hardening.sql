-- =====================================================================
-- BILONAI — Endurecimento (resultado do verificador de segurança/desempenho do Supabase)
-- =====================================================================

-- is_admin(): só utilizadores com sessão precisam dela (as políticas RLS usam-na); anónimos não.
revoke execute on function public.is_admin() from public, anon;

-- has_active_plan(uid): só o servidor (service role) a usa. Evita que um utilizador
-- consulte o estado de subscrição de outro através da API.
revoke execute on function public.has_active_plan(uuid) from public, anon, authenticated;

-- Índices em chaves estrangeiras (apagar um utilizador/produto/campanha fica rápido
-- e as consultas por utilizador não varrem a tabela toda).
create index if not exists campaign_metrics_user_idx   on public.campaign_metrics(user_id);
create index if not exists campaign_packs_user_idx     on public.campaign_packs(user_id);
create index if not exists campaigns_pack_idx          on public.campaigns(pack_id);
create index if not exists campaigns_product_idx       on public.campaigns(product_id);
create index if not exists creatives_user_idx          on public.creatives(user_id);
create index if not exists operating_costs_user_idx    on public.operating_costs(user_id);
create index if not exists spy_reports_product_idx     on public.spy_reports(product_id);
create index if not exists ticket_messages_ticket_idx  on public.ticket_messages(ticket_id);
create index if not exists tickets_user_idx            on public.tickets(user_id);
create index if not exists usage_events_user_idx       on public.usage_events(user_id);
-- usage_daily já tem o índice único (day, user, provider) mas o user_id sozinho não é o primeiro campo
create index if not exists usage_daily_user_idx        on public.usage_daily(user_id);
