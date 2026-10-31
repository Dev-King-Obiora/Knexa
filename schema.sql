-- KingMath-AI account, quota, payment and admin schema
-- Run once in Supabase SQL Editor as project owner.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active' check (status in ('active','expired','cancelled')),
  starts_at timestamptz not null default now(),
  expires_at timestamptz not null,
  source text not null default 'payment',
  created_at timestamptz not null default now()
);
create index if not exists subscriptions_user_expiry_idx on public.subscriptions(user_id, expires_at desc);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reference text not null unique,
  channel text not null check (channel in ('paystack','opay_manual')),
  amount_kobo bigint not null check (amount_kobo > 0),
  currency text not null default 'NGN' check (currency = 'NGN'),
  status text not null default 'pending' check (status in ('pending','pending_review','paid','failed','rejected')),
  payer_name text,
  transfer_reference text,
  customer_note text,
  admin_note text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists payments_user_created_idx on public.payments(user_id, created_at desc);
create index if not exists payments_status_created_idx on public.payments(status, created_at desc);

create table if not exists public.usage_daily (
  user_id uuid not null references auth.users(id) on delete cascade,
  feature text not null check (feature in ('ai_text','ai_image','practice','cbt')),
  usage_date date not null,
  used integer not null default 0 check (used >= 0),
  updated_at timestamptz not null default now(),
  primary key(user_id, feature, usage_date)
);

create table if not exists public.app_settings (
  id integer primary key check (id = 1),
  pro_price_ngn integer not null default 5000 check (pro_price_ngn between 100 and 1000000),
  free_ai_text_daily integer not null default 10 check (free_ai_text_daily between 1 and 1000),
  free_ai_image_daily integer not null default 3 check (free_ai_image_daily between 0 and 100),
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);
insert into public.app_settings(id) values (1) on conflict (id) do nothing;

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid not null references auth.users(id),
  action text not null,
  target_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists audit_logs_created_idx on public.audit_logs(created_at desc);

-- Automatically create a public profile after Supabase Auth creates a user.
create or replace function public.handle_new_kingmath_user()
returns trigger language plpgsql security definer set search_path = public, auth as $$
begin
  insert into public.profiles(id,email) values(new.id, lower(new.email))
  on conflict(id) do update set email=excluded.email, updated_at=now();
  return new;
end;
$$;
drop trigger if exists on_kingmath_auth_user_created on auth.users;
create trigger on_kingmath_auth_user_created after insert or update of email on auth.users
for each row execute procedure public.handle_new_kingmath_user();

-- Atomic daily quota consumption. Lagos-local date is supplied by the API.
create or replace function public.consume_daily_quota(
  p_user_id uuid, p_feature text, p_usage_date date, p_free_limit integer, p_pro_limit integer
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_limit integer; v_used integer;
begin
  if p_feature not in ('ai_text','ai_image','practice','cbt') then raise exception 'INVALID_FEATURE'; end if;
  if exists(select 1 from public.subscriptions s where s.user_id=p_user_id and s.status='active' and s.expires_at>now()) then
    v_limit := p_pro_limit;
  else
    v_limit := p_free_limit;
  end if;
  insert into public.usage_daily(user_id,feature,usage_date,used)
  select p_user_id,p_feature,p_usage_date,1 where v_limit > 0
  on conflict(user_id,feature,usage_date) do update
    set used=public.usage_daily.used+1, updated_at=now()
    where public.usage_daily.used < v_limit
  returning used into v_used;
  if v_used is null then return jsonb_build_object('allowed',false,'limit',v_limit); end if;
  return jsonb_build_object('allowed',true,'used',v_used,'limit',v_limit);
end;
$$;

-- Idempotent payment fulfilment. Duplicate webhook/callback cannot add another month.
create or replace function public.activate_pro_payment(p_reference text, p_channel text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare p public.payments%rowtype; v_start timestamptz; v_end timestamptz; v_sub uuid;
begin
  select * into p from public.payments where reference=p_reference for update;
  if not found then raise exception 'PAYMENT_NOT_FOUND'; end if;
  if p.channel <> p_channel then raise exception 'PAYMENT_CHANNEL_MISMATCH'; end if;
  if p.status='paid' then
    select id,starts_at,expires_at into v_sub,v_start,v_end from public.subscriptions
      where user_id=p.user_id order by created_at desc limit 1;
    return jsonb_build_object('activated',true,'duplicate',true,'subscription_id',v_sub,'expires_at',v_end);
  end if;
  if p.status not in ('pending','pending_review') then raise exception 'PAYMENT_NOT_PAYABLE'; end if;
  select greatest(now(), coalesce(max(expires_at),now())) into v_start
    from public.subscriptions where user_id=p.user_id and status='active' and expires_at>now();
  v_end := v_start + interval '1 month';
  update public.payments set status='paid',paid_at=now(),reviewed_at=case when p_channel='opay_manual' then now() else reviewed_at end
    where id=p.id;
  insert into public.subscriptions(user_id,status,starts_at,expires_at,source)
    values(p.user_id,'active',v_start,v_end,p_channel) returning id into v_sub;
  return jsonb_build_object('activated',true,'duplicate',false,'subscription_id',v_sub,'expires_at',v_end);
end;
$$;

create or replace function public.admin_grant_pro(p_user_id uuid, p_admin_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_start timestamptz; v_end timestamptz; v_id uuid;
begin
  if not exists(select 1 from auth.users where id=p_user_id) then raise exception 'USER_NOT_FOUND'; end if;
  select greatest(now(),coalesce(max(expires_at),now())) into v_start from public.subscriptions
    where user_id=p_user_id and status='active' and expires_at>now();
  v_end:=v_start+interval '1 month';
  insert into public.subscriptions(user_id,status,starts_at,expires_at,source)
    values(p_user_id,'active',v_start,v_end,'admin_grant') returning id into v_id;
  insert into public.audit_logs(admin_user_id,action,target_id,details)
    values(p_admin_id,'grant_pro',p_user_id::text,jsonb_build_object('subscription_id',v_id));
  return jsonb_build_object('subscription_id',v_id,'expires_at',v_end);
end;
$$;

-- Lock down all application tables. The backend service role is the only data writer.
alter table public.profiles enable row level security;
alter table public.subscriptions enable row level security;
alter table public.payments enable row level security;
alter table public.usage_daily enable row level security;
alter table public.app_settings enable row level security;
alter table public.audit_logs enable row level security;
revoke all on public.profiles,public.subscriptions,public.payments,public.usage_daily,public.app_settings,public.audit_logs from anon,authenticated;
grant all on public.profiles,public.subscriptions,public.payments,public.usage_daily,public.app_settings,public.audit_logs to service_role;
grant execute on function public.consume_daily_quota(uuid,text,date,integer,integer) to service_role;
grant execute on function public.activate_pro_payment(text,text) to service_role;
grant execute on function public.admin_grant_pro(uuid,uuid) to service_role;

create or replace function public.admin_revoke_pro(p_user_id uuid, p_admin_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_count integer;
begin
  update public.subscriptions set status='cancelled'
    where user_id=p_user_id and status='active' and expires_at>now();
  get diagnostics v_count = row_count;
  insert into public.audit_logs(admin_user_id,action,target_id,details)
    values(p_admin_id,'revoke_pro',p_user_id::text,jsonb_build_object('subscriptions_cancelled',v_count));
  return jsonb_build_object('cancelled',v_count);
end;
$$;
grant execute on function public.admin_revoke_pro(uuid,uuid) to service_role;

-- Prevent the same manual bank-transfer reference being submitted twice.
create unique index if not exists payments_transfer_reference_unique
  on public.payments(transfer_reference) where transfer_reference is not null and transfer_reference <> '';

-- Do not expose SECURITY DEFINER RPCs to anonymous/authenticated clients.
revoke execute on function public.consume_daily_quota(uuid,text,date,integer,integer) from public, anon, authenticated;
revoke execute on function public.activate_pro_payment(text,text) from public, anon, authenticated;
revoke execute on function public.admin_grant_pro(uuid,uuid) from public, anon, authenticated;
revoke execute on function public.admin_revoke_pro(uuid,uuid) from public, anon, authenticated;
grant execute on function public.consume_daily_quota(uuid,text,date,integer,integer) to service_role;
grant execute on function public.activate_pro_payment(text,text) to service_role;
grant execute on function public.admin_grant_pro(uuid,uuid) to service_role;
grant execute on function public.admin_revoke_pro(uuid,uuid) to service_role;
