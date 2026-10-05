-- =====================================================================
-- BILONAI — Migração inicial (V1)
-- Regras: só texto/números/IDs na BD; ficheiros vão para o Drive do cliente.
-- RLS em todas as tabelas: utilizadores só LEEM o que é seu; escritas via servidor (service role).
-- =====================================================================

-- ---------- Tipos ----------
create type public.plan_tier       as enum ('alpha', 'apex', 'syndicate');
create type public.sub_status      as enum ('active', 'past_due', 'canceled', 'expired');
create type public.agent_key       as enum ('spy', 'offers', 'manager', 'brain', 'support');
create type public.app_role        as enum ('user', 'admin');
create type public.job_status      as enum ('queued', 'running', 'waiting_external', 'done', 'failed');
create type public.campaign_status as enum ('draft', 'published', 'paused', 'archived');
create type public.metric_source   as enum ('screenshot', 'manual', 'csv', 'meta_api');
create type public.sales_source    as enum ('okanda', 'utmfy', 'generic');
create type public.ticket_status   as enum ('open', 'read', 'answered', 'closed');

-- ---------- Utilitário: updated_at ----------
create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- =====================================================================
-- CONTAS E PLANOS
-- =====================================================================
create table public.profiles (
  id             uuid primary key references auth.users(id) on delete cascade,
  email          text not null unique,
  full_name      text,
  business_name  text,
  country        text not null default 'AO' check (country in ('AO','MZ','BR','US')),
  locale         text not null default 'pt-BR' check (locale in ('pt-BR','en-US')),
  currency       text not null default 'AOA' check (currency in ('AOA','MZN','BRL','USD')),
  role           public.app_role not null default 'user',
  onboarding     jsonb not null default '{}'::jsonb,  -- passos concluídos/adiados + lembretes
  last_seen_at   timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table public.subscriptions (
  user_id                 uuid primary key references public.profiles(id) on delete cascade,
  plan                    public.plan_tier not null,
  status                  public.sub_status not null default 'active',
  current_period_end      timestamptz not null,
  okanda_customer_id      text,
  okanda_subscription_id  text unique,
  updated_at              timestamptz not null default now()
);

create table public.payment_events (
  id            bigint generated always as identity primary key,
  provider      text not null default 'okanda',
  event_id      text not null,
  event_type    text not null,
  email         text,
  payload       jsonb not null,
  processed_at  timestamptz,
  error         text,
  created_at    timestamptz not null default now(),
  unique (provider, event_id)
);

-- Quais agentes cada plano inclui (fonte única para front e back)
create or replace function public.plan_agents(p public.plan_tier)
returns public.agent_key[] language sql immutable set search_path = '' as $$
  select case p
    when 'alpha'     then array['spy']::public.agent_key[]
    when 'apex'      then array['spy','offers']::public.agent_key[]
    when 'syndicate' then array['spy','offers','manager','brain','support']::public.agent_key[]
  end
$$;

-- Limites por plano
create or replace function public.plan_limits(p public.plan_tier)
returns jsonb language sql immutable set search_path = '' as $$
  select case p
    when 'alpha'     then '{"products":1,"countries":1}'::jsonb
    when 'apex'      then '{"products":2,"countries":2}'::jsonb
    when 'syndicate' then '{"products":5,"countries":4}'::jsonb
  end
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  )
$$;

-- Subscrição em vigor (ativa e dentro do período)
create or replace function public.has_active_plan(uid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.subscriptions
    where user_id = uid and status = 'active' and current_period_end > now()
  )
$$;

-- =====================================================================
-- DNA DO NEGÓCIO E AGENTES
-- =====================================================================
create table public.business_dna (
  user_id          uuid primary key references public.profiles(id) on delete cascade,
  niche            text,
  countries        text[] not null default '{}',
  regions          text[] not null default '{}',
  tone             text,
  goals            jsonb not null default '{}'::jsonb,   -- {short, mid, long}
  weekly_ad_budget numeric(14,2),
  budget_currency  text,
  target_roas      numeric(8,2),
  target_cpa       numeric(14,2),
  winning_dna      text,     -- resumo condensado do que já funciona
  updated_at       timestamptz not null default now()
);

create table public.agents (
  user_id       uuid not null references public.profiles(id) on delete cascade,
  agent_key     public.agent_key not null,
  display_name  text not null,
  is_paused     boolean not null default false,
  settings      jsonb not null default '{}'::jsonb,
  last_run_at   timestamptz,
  primary key (user_id, agent_key)
);

-- =====================================================================
-- PRODUTOS E CRIATIVOS (só metadados)
-- =====================================================================
create table public.products (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles(id) on delete cascade,
  name             text not null,
  description      text,
  price            numeric(14,2),
  currency         text,
  destination_url  text,
  whatsapp         text,
  facebook_page    text,
  offer            jsonb not null default '{}'::jsonb,  -- order bump, upsell, downsell
  keywords         text[] not null default '{}',        -- termos para o Espião
  drive_folder_id  text,
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index products_user_idx on public.products(user_id);

create table public.creatives (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  product_id     uuid not null references public.products(id) on delete cascade,
  kind           text not null check (kind in ('image','video')),
  drive_file_id  text not null,
  description    text,
  objective      text,
  audience       text,
  created_at     timestamptz not null default now()
);
create index creatives_product_idx on public.creatives(product_id);

-- =====================================================================
-- INTEGRAÇÕES
-- =====================================================================
create table public.google_connections (
  user_id             uuid primary key references public.profiles(id) on delete cascade,
  refresh_token_enc   text not null,      -- AES-256-GCM, chave só no servidor
  root_folder_id      text,
  folders             jsonb not null default '{}'::jsonb,
  scope               text not null,
  connected_at        timestamptz not null default now(),
  last_error          text
);

create table public.sales_integrations (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  source      public.sales_source not null,
  token_hash  text not null unique,       -- só o hash do token da URL
  created_at  timestamptz not null default now(),
  last_event_at timestamptz,
  unique (user_id, source)
);

-- =====================================================================
-- ESPIÃO
-- =====================================================================
-- Varreduras partilhadas entre utilizadores do mesmo nicho/país (cache 48 h)
create table public.market_scans (
  id            uuid primary key default gen_random_uuid(),
  cache_key     text not null,
  country       text not null,
  query         jsonb not null,
  status        public.job_status not null default 'queued',
  apify_run_id  text,
  summary       jsonb,                    -- top anúncios reduzidos; dados brutos não ficam
  error         text,
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null default now() + interval '48 hours'
);
create index market_scans_cache_idx on public.market_scans(cache_key, expires_at desc);

create table public.spy_reports (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  product_id     uuid references public.products(id) on delete set null,
  scan_ids       uuid[] not null default '{}',
  summary        jsonb not null,          -- destaques curtos para o painel
  drive_file_id  text,                    -- relatório completo no Drive
  emailed_at     timestamptz,
  created_at     timestamptz not null default now()
);
create index spy_reports_user_idx on public.spy_reports(user_id, created_at desc);

-- =====================================================================
-- OFERTAS → CAMPANHAS → MÉTRICAS
-- =====================================================================
create table public.campaign_packs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  product_id  uuid not null references public.products(id) on delete cascade,
  week_start  date not null,
  status      text not null default 'awaiting_feedback'
              check (status in ('generating','awaiting_feedback','complete')),
  rationale   text,                       -- porquê: base no Espião, DNA, métricas
  created_at  timestamptz not null default now(),
  unique (product_id, week_start)
);

create table public.campaigns (
  id            uuid primary key default gen_random_uuid(),
  pack_id       uuid not null references public.campaign_packs(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  product_id    uuid not null references public.products(id) on delete cascade,
  code          text not null unique,     -- bil-xxxxx (nome da campanha + utm_campaign)
  name          text not null,
  structure     jsonb not null,           -- público, conjuntos, anúncios, copies, orçamento, UTMs
  status        public.campaign_status not null default 'draft',
  published_at  timestamptz,
  daily_budget  numeric(14,2),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index campaigns_user_idx on public.campaigns(user_id, status);

create table public.campaign_metrics (
  id            uuid primary key default gen_random_uuid(),
  campaign_id   uuid not null references public.campaigns(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  period_start  date not null,
  period_end    date not null,
  spend         numeric(14,2),
  impressions   integer,
  clicks        integer,
  results       integer,
  ctr           numeric(8,4),
  cpc           numeric(14,4),
  cpa           numeric(14,4),
  currency      text,
  source        public.metric_source not null,
  created_at    timestamptz not null default now(),
  check (period_end >= period_start)
);
create index campaign_metrics_campaign_idx on public.campaign_metrics(campaign_id, period_end desc);

-- =====================================================================
-- FINANÇAS
-- =====================================================================
create table public.sales (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  source         public.sales_source not null,
  external_id    text not null,
  product_name   text,
  amount         numeric(14,2) not null,
  currency       text not null,
  status         text not null default 'approved' check (status in ('approved','refunded','chargeback')),
  utm            jsonb not null default '{}'::jsonb,
  campaign_code  text,                    -- bil-xxxxx extraído do utm_campaign
  occurred_at    timestamptz not null,
  created_at     timestamptz not null default now(),
  unique (user_id, source, external_id)
);
create index sales_user_time_idx on public.sales(user_id, occurred_at desc);
create index sales_campaign_idx on public.sales(campaign_code) where campaign_code is not null;

create table public.operating_costs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  name        text not null,
  amount      numeric(14,2) not null check (amount >= 0),
  currency    text not null,
  frequency   text not null default 'monthly' check (frequency in ('monthly','yearly','one_off')),
  created_at  timestamptz not null default now()
);

-- =====================================================================
-- O CÉREBRO
-- =====================================================================
create table public.brain_memory (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  kind        text not null check (kind in ('insight','reminder','playbook','decision','note')),
  content     text not null,
  due_at      timestamptz,                -- lembretes
  done        boolean not null default false,
  drive_file_id text,                     -- versão longa no Drive
  created_at  timestamptz not null default now()
);
create index brain_memory_due_idx on public.brain_memory(user_id, due_at) where kind = 'reminder' and not done;

-- =====================================================================
-- FILA DE AGENTES
-- =====================================================================
create table public.agent_jobs (
  id          bigint generated always as identity primary key,
  user_id     uuid references public.profiles(id) on delete cascade,  -- null = job do sistema
  agent_key   public.agent_key,
  kind        text not null,              -- spy.scan, spy.ingest, spy.analyze, offers.pack, ...
  status      public.job_status not null default 'queued',
  run_after   timestamptz not null default now(),
  attempts    smallint not null default 0,
  max_attempts smallint not null default 3,
  payload     jsonb not null default '{}'::jsonb,
  result      jsonb,
  error       text,
  locked_at   timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index agent_jobs_ready_idx on public.agent_jobs(run_after) where status = 'queued';
create index agent_jobs_user_idx on public.agent_jobs(user_id, created_at desc);
-- impede jobs duplicados ativos do mesmo tipo para o mesmo utilizador
create unique index agent_jobs_one_active_idx on public.agent_jobs(user_id, kind)
  where status in ('queued','running','waiting_external') and user_id is not null;

-- Reserva o próximo job pronto (seguro com vários workers em paralelo).
-- Jobs presos em 'running' há > 10 min voltam a ser elegíveis.
create or replace function public.claim_next_job()
returns setof public.agent_jobs language plpgsql security definer set search_path = '' as $$
begin
  return query
  update public.agent_jobs j
     set status = 'running', locked_at = now(), attempts = j.attempts + 1, updated_at = now()
   where j.id = (
     select q.id from public.agent_jobs q
      where ((q.status = 'queued' and q.run_after <= now())
          or (q.status = 'running' and q.locked_at < now() - interval '10 minutes'))
        and q.attempts < q.max_attempts
        and (q.user_id is null or not exists (
              select 1 from public.agents a
               where a.user_id = q.user_id and a.agent_key = q.agent_key and a.is_paused))
      order by q.run_after
      limit 1
      for update skip locked)
  returning j.*;
end $$;

-- =====================================================================
-- NOTIFICAÇÕES E SUPORTE
-- =====================================================================
create table public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  agent_key   public.agent_key,
  title       text not null,
  body        text,
  link        text,
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);
create index notifications_user_idx on public.notifications(user_id, created_at desc);

create table public.tickets (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  category        text not null check (category in ('technical','billing','other')),
  priority        text not null default 'medium' check (priority in ('low','medium','high')),
  subject         text not null,
  description     text not null,
  screenshot_path text,                   -- Supabase Storage (bucket privado, apagado com o ticket)
  status          public.ticket_status not null default 'open',
  read_at         timestamptz,            -- marcado pelo admin → apagado 15 dias depois
  created_at      timestamptz not null default now()
);

create table public.ticket_messages (
  id          uuid primary key default gen_random_uuid(),
  ticket_id   uuid not null references public.tickets(id) on delete cascade,
  author      text not null check (author in ('user','admin')),
  body        text not null,
  created_at  timestamptz not null default now()
);

-- =====================================================================
-- CONSUMO E SAÚDE (admin)
-- =====================================================================
create table public.usage_events (
  id           bigint generated always as identity primary key,
  user_id      uuid references public.profiles(id) on delete set null,
  provider     text not null check (provider in ('gemini_text','gemini_vision','apify','resend','drive')),
  units        numeric(14,2) not null default 1,   -- tokens, runs, e-mails, chamadas
  cost_usd     numeric(12,6) not null default 0,
  meta         jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);
create index usage_events_time_idx on public.usage_events(created_at);

create table public.usage_daily (
  day        date not null,
  user_id    uuid references public.profiles(id) on delete cascade,
  provider   text not null,
  units      numeric(16,2) not null default 0,
  cost_usd   numeric(14,6) not null default 0,
  events     integer not null default 0
);
create unique index usage_daily_key on public.usage_daily(day, coalesce(user_id, '00000000-0000-0000-0000-000000000000'::uuid), provider);

create table public.system_alerts (
  id          bigint generated always as identity primary key,
  severity    text not null check (severity in ('info','warning','critical')),
  source      text not null,              -- webhook_okanda, apify, gemini, resend, db_size, worker...
  message     text not null,
  meta        jsonb not null default '{}'::jsonb,
  resolved_at timestamptz,
  created_at  timestamptz not null default now()
);

-- =====================================================================
-- TRIGGERS updated_at
-- =====================================================================
create trigger profiles_touch      before update on public.profiles      for each row execute function public.touch_updated_at();
create trigger subscriptions_touch before update on public.subscriptions for each row execute function public.touch_updated_at();
create trigger business_dna_touch  before update on public.business_dna  for each row execute function public.touch_updated_at();
create trigger products_touch      before update on public.products      for each row execute function public.touch_updated_at();
create trigger campaigns_touch     before update on public.campaigns     for each row execute function public.touch_updated_at();
create trigger agent_jobs_touch    before update on public.agent_jobs    for each row execute function public.touch_updated_at();

-- =====================================================================
-- RLS — leitura do próprio dono (+ admin). Escritas só pelo servidor.
-- =====================================================================
do $$
declare t text;
begin
  -- tabelas com coluna user_id
  foreach t in array array[
    'subscriptions','business_dna','agents','products','creatives','spy_reports',
    'campaign_packs','campaigns','campaign_metrics','sales','operating_costs',
    'brain_memory','agent_jobs','notifications','tickets'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy %I on public.%I for select to authenticated using (user_id = (select auth.uid()) or (select public.is_admin()))',
      t || '_owner_read', t);
  end loop;

  -- tabelas sem acesso direto do cliente (só servidor/admin)
  foreach t in array array[
    'payment_events','google_connections','sales_integrations','market_scans',
    'usage_events','usage_daily','system_alerts'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy %I on public.%I for select to authenticated using ((select public.is_admin()))',
      t || '_admin_read', t);
  end loop;
end $$;

alter table public.profiles enable row level security;
create policy profiles_owner_read on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));

alter table public.ticket_messages enable row level security;
create policy ticket_messages_owner_read on public.ticket_messages for select to authenticated
  using (exists (select 1 from public.tickets t
                  where t.id = ticket_id
                    and (t.user_id = (select auth.uid()) or (select public.is_admin()))));

-- Funções internas não ficam expostas ao público
revoke execute on function public.claim_next_job() from public, anon, authenticated;
revoke execute on function public.has_active_plan(uuid) from public, anon;

-- =====================================================================
-- MANUTENÇÃO (chamada diariamente pelo pg_cron — agendado na migração 0002)
-- =====================================================================
create or replace function public.run_retention()
returns void language plpgsql security definer set search_path = '' as $$
begin
  -- agrega consumo antes de apagar o detalhe
  insert into public.usage_daily (day, user_id, provider, units, cost_usd, events)
  select created_at::date, user_id, provider, sum(units), sum(cost_usd), count(*)
    from public.usage_events
   where created_at < date_trunc('day', now())
   group by 1, 2, 3
  on conflict (day, coalesce(user_id, '00000000-0000-0000-0000-000000000000'::uuid), provider)
  do update set units = public.usage_daily.units + excluded.units,
                cost_usd = public.usage_daily.cost_usd + excluded.cost_usd,
                events = public.usage_daily.events + excluded.events;
  delete from public.usage_events   where created_at < date_trunc('day', now());

  delete from public.payment_events where created_at < now() - interval '30 days' and processed_at is not null;
  delete from public.notifications  where read_at is not null and read_at < now() - interval '60 days';
  delete from public.tickets        where read_at is not null and read_at < now() - interval '15 days';
  delete from public.market_scans   where expires_at < now() - interval '7 days';
  delete from public.agent_jobs     where status in ('done','failed') and updated_at < now() - interval '14 days';
  delete from public.system_alerts  where resolved_at is not null and resolved_at < now() - interval '30 days';
end $$;
revoke execute on function public.run_retention() from public, anon, authenticated;
