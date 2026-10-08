-- =====================================================================
-- BILONAI — Migração 0003: faturação com Lemon Squeezy (desenho: docs/BILLING.md §4 e §6)
-- `subscriptions` e `profiles` estão vazias neste momento, por isso recriamos a tabela em vez de a remendar.
-- =====================================================================

-- ---------- Limpeza do que era da Okanda ----------
delete from public.payment_events where provider = 'okanda';   -- 2 linhas de teste
alter table public.payment_events alter column provider set default 'lemonsqueezy';

drop function if exists public.has_active_plan(uuid);
drop table if exists public.subscriptions;
drop type if exists public.sub_status;

-- ---------- Subscrições (chave = id da subscrição no Lemon Squeezy) ----------
create table public.subscriptions (
  provider_subscription_id text primary key,
  user_id                  uuid not null references public.profiles(id) on delete cascade,
  provider                 text not null default 'lemonsqueezy',
  provider_customer_id     text,
  variant_id               text,
  plan                     public.plan_tier not null,
  status                   text not null check (status in
                             ('on_trial','active','paused','past_due','unpaid','cancelled','expired')),
  trial_ends_at            timestamptz,
  renews_at                timestamptz,
  ends_at                  timestamptz,
  past_due_since           timestamptz,
  access_until             timestamptz not null,          -- fim do acesso, já com as 72 h de folga
  test_mode                boolean not null default false,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);
create index subscriptions_user_idx on public.subscriptions(user_id);
-- No máximo UMA subscrição não expirada por conta (nunca cobrar duas vezes a mesma pessoa)
create unique index subscriptions_one_live_per_user on public.subscriptions(user_id) where status <> 'expired';

create trigger subscriptions_touch before update on public.subscriptions
  for each row execute function public.touch_updated_at();
alter table public.subscriptions enable row level security;
create policy subscriptions_owner_read on public.subscriptions for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));

-- ---------- Perfis ----------
alter table public.profiles
  add column trial_used_at       timestamptz,   -- já teve o teste grátis (um por conta)
  add column last_magic_link_at  timestamptz;   -- limite de 1 link por minuto

-- ---------- Sessões de checkout (ligam a compra ao e-mail e à língua) ----------
create table public.checkout_sessions (
  ref              text primary key,            -- aleatório, 128 bits
  email            text not null,
  plan             public.plan_tier not null,
  with_trial       boolean not null default true,
  locale           text not null default 'pt-BR' check (locale in ('pt-BR','en-US')),
  user_id          uuid references public.profiles(id) on delete set null,
  status           text not null default 'pending' check (status in ('pending','ready')),
  subscription_id  text,
  created_at       timestamptz not null default now()
);
create index checkout_sessions_email_idx on public.checkout_sessions(lower(email));
create index checkout_sessions_created_idx on public.checkout_sessions(created_at);
create index checkout_sessions_user_idx on public.checkout_sessions(user_id);
alter table public.checkout_sessions enable row level security;
create policy checkout_sessions_admin_read on public.checkout_sessions for select to authenticated
  using ((select public.is_admin()));

-- ---------- Regras de acesso (iguais às do código: BILLING.md §4) ----------
-- Entra no painel: tudo menos unpaid / expired / paused, e dentro do prazo.
create or replace function public.has_active_plan(uid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.subscriptions
    where user_id = uid
      and status in ('on_trial','active','past_due','cancelled')
      and access_until > now()
  )
$$;

-- Agentes correm: trial/active/cancelled dentro do prazo; past_due só nos 3 dias após past_due_since.
create or replace function public.can_use_agents(uid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.subscriptions
    where user_id = uid
      and access_until > now()
      and (
        status in ('on_trial','active','cancelled')
        or (status = 'past_due' and now() < coalesce(past_due_since, now()) + interval '3 days')
      )
  )
$$;

-- Plano da subscrição em vigor (null se não houver)
create or replace function public.current_plan(uid uuid)
returns public.plan_tier language sql stable security definer set search_path = '' as $$
  select plan from public.subscriptions
  where user_id = uid
    and status in ('on_trial','active','past_due','cancelled')
    and access_until > now()
  order by created_at desc
  limit 1
$$;

-- Só o servidor (service role) usa estas funções
revoke execute on function public.has_active_plan(uuid) from public, anon, authenticated;
revoke execute on function public.can_use_agents(uuid)  from public, anon, authenticated;
revoke execute on function public.current_plan(uuid)    from public, anon, authenticated;

-- ---------- Tetos por plano (PRICING.md) ----------
create or replace function public.plan_limits(p public.plan_tier)
returns jsonb language sql immutable set search_path = '' as $$
  select case p
    when 'alpha'     then '{"products":1,"countries":1,"spy_interval_days":3,"ads_per_month":600,"campaigns_per_month":0,"brain_messages_per_month":0}'::jsonb
    when 'apex'      then '{"products":2,"countries":2,"spy_interval_days":2,"ads_per_month":2000,"campaigns_per_month":30,"brain_messages_per_month":0}'::jsonb
    when 'syndicate' then '{"products":5,"countries":4,"spy_interval_days":2,"ads_per_month":4000,"campaigns_per_month":70,"brain_messages_per_month":200}'::jsonb
  end
$$;

-- Limites do teste grátis (qualquer plano): só o Espião, 3 relatórios
create or replace function public.trial_limits()
returns jsonb language sql immutable set search_path = '' as $$
  select '{"agents":["spy"],"reports":3}'::jsonb
$$;

-- ---------- Manutenção: passa a limpar também as sessões de checkout com mais de 7 dias ----------
create or replace function public.run_retention()
returns void language plpgsql security definer set search_path = '' as $$
begin
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

  delete from public.payment_events    where created_at < now() - interval '30 days' and processed_at is not null;
  delete from public.checkout_sessions where created_at < now() - interval '7 days';
  delete from public.notifications     where read_at is not null and read_at < now() - interval '60 days';
  delete from public.tickets           where read_at is not null and read_at < now() - interval '15 days';
  delete from public.market_scans      where expires_at < now() - interval '7 days';
  delete from public.agent_jobs        where status in ('done','failed') and updated_at < now() - interval '14 days';
  delete from public.system_alerts     where resolved_at is not null and resolved_at < now() - interval '30 days';
end $$;
revoke execute on function public.run_retention() from public, anon, authenticated;
