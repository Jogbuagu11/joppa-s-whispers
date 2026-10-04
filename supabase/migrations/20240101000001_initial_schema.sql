-- Whispers of Joppa — Initial database schema
-- All tables have Row Level Security enabled.
-- Users can only read/write their own rows.

-- =====================
-- profiles
-- =====================
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "Users can view own profile"
  on profiles for select using (auth.uid() = id);

create policy "Users can update own profile"
  on profiles for update using (auth.uid() = id);

create policy "Users can insert own profile"
  on profiles for insert with check (auth.uid() = id);

-- Auto-create profile on new user sign-up.
create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', ''));
  return new;
end;
$$;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- =====================
-- saves
-- =====================
create table if not exists saves (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  save_data jsonb not null default '{}'::jsonb,
  save_version integer not null default 1,
  updated_at timestamptz not null default now(),
  constraint saves_user_unique unique (user_id)
);

alter table saves enable row level security;

create policy "Users can view own save"
  on saves for select using (auth.uid() = user_id);

create policy "Users can upsert own save"
  on saves for insert with check (auth.uid() = user_id);

create policy "Users can update own save"
  on saves for update using (auth.uid() = user_id);

-- =====================
-- content_versions
-- =====================
create table if not exists content_versions (
  id serial primary key,
  version integer not null,
  storage_path text not null,
  released_at timestamptz not null default now(),
  notes text
);

alter table content_versions enable row level security;

-- All authenticated users can read content versions.
create policy "Authenticated users can read content versions"
  on content_versions for select to authenticated using (true);

-- =====================
-- events
-- =====================
create table if not exists events (
  id text primary key,
  name text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  config jsonb not null default '{}'::jsonb,
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

alter table events enable row level security;

create policy "Authenticated users can read events"
  on events for select to authenticated using (true);

-- =====================
-- purchases
-- =====================
create table if not exists purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('ios', 'android')),
  product_id text not null,
  transaction_id text not null,
  status text not null check (status in ('granted', 'refunded', 'pending')),
  raw_verification jsonb,
  granted_at timestamptz,
  refunded_at timestamptz,
  created_at timestamptz not null default now(),
  -- Each transaction ID is unique — prevents duplicate grants.
  constraint purchases_transaction_unique unique (transaction_id)
);

alter table purchases enable row level security;

create policy "Users can view own purchases"
  on purchases for select using (auth.uid() = user_id);

-- Purchases are inserted only by the verify-purchase Edge Function (service role).
-- No user-facing insert policy.

-- =====================
-- wallet_grants
-- =====================
create table if not exists wallet_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  purchase_id uuid references purchases(id),
  grant_type text not null check (grant_type in ('purchase', 'refund', 'event', 'admin')),
  pearls_delta integer not null default 0,
  items_delta jsonb not null default '[]'::jsonb,
  note text,
  created_at timestamptz not null default now()
);

alter table wallet_grants enable row level security;

create policy "Users can view own wallet grants"
  on wallet_grants for select using (auth.uid() = user_id);

-- =====================
-- device_tokens
-- =====================
create table if not exists device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fcm_token text not null,
  platform text not null check (platform in ('ios', 'android')),
  notify_reminders boolean not null default true,
  notify_events boolean not null default true,
  notify_chapters boolean not null default true,
  updated_at timestamptz not null default now(),
  constraint device_tokens_user_token unique (user_id, fcm_token)
);

alter table device_tokens enable row level security;

create policy "Users can manage own device tokens"
  on device_tokens for all using (auth.uid() = user_id);

-- =====================
-- notifications_log
-- =====================
create table if not exists notifications_log (
  id uuid primary key default gen_random_uuid(),
  notification_type text not null,
  audience text not null,
  title text not null,
  body text not null,
  sent_at timestamptz not null default now(),
  sent_count integer not null default 0
);

alter table notifications_log enable row level security;

-- Only service role can read/write notification logs.
-- No user-facing policy needed.

-- =====================
-- Storage bucket for content bundles and art
-- =====================
insert into storage.buckets (id, name, public)
values ('content', 'content', false)
on conflict (id) do nothing;

-- Authenticated users can download content.
create policy "Authenticated users can read content"
  on storage.objects for select to authenticated
  using (bucket_id = 'content');
