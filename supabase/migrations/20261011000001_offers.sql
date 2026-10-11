-- Offers (EXPANSION section 21). Safe to run more than once.
--
-- An offer is something sold through one of the reusable store products
-- (offer_099 … offer_4999). The store only knows the price; what the player
-- receives is decided here, on the server, and written onto the purchase.

-- =====================
-- offers
-- =====================
create table if not exists offers (
  id text primary key,
  -- When it is shown: session_start, out_of_manna, level_up,
  -- chapter_complete, flash_sale, themed. 'fallback' rows are never shown.
  kind text not null check (kind in (
    'session_start', 'out_of_manna', 'level_up', 'chapter_complete',
    'flash_sale', 'themed', 'fallback'
  )),
  -- The store product that carries its price.
  product_id text not null check (product_id in (
    'offer_099', 'offer_199', 'offer_299', 'offer_499',
    'offer_999', 'offer_1999', 'offer_4999'
  )),
  title text not null default '',
  subtitle text not null default '',
  -- Exactly what the player receives:
  -- {"pearls": 0, "manna": 0, "talents": 0, "items": ["item_id", …]}
  contents jsonb not null default '{}'::jsonb,
  -- Who sees it: anyone, players who have never bought, or players who have.
  audience text not null default 'any'
    check (audience in ('any', 'non_payer', 'payer')),
  min_level integer not null default 1,
  -- Shown next time if this one is turned down (cheaper or bigger).
  next_offer_id text references offers(id) on delete set null,
  -- How long the countdown runs once it is first shown.
  duration_seconds integer not null default 86400 check (duration_seconds >= 60),
  -- Optional window (a flash sale, a feast).
  starts_at timestamptz,
  ends_at timestamptz,
  priority integer not null default 0,
  is_active boolean not null default false,
  -- What a payment for this product gives when the offer it was for cannot
  -- be told. Exactly one per product; never shown to players.
  is_fallback boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists offers_one_fallback_per_product
  on offers (product_id) where is_fallback;

alter table offers enable row level security;

-- Offers hold no personal data. Players see only the ones switched on.
-- Not ones still waiting for their day.
drop policy if exists "Anyone can read active offers" on offers;
create policy "Anyone can read active offers"
  on offers for select
  to anon, authenticated
  using (is_active and not is_fallback and (starts_at is null or starts_at <= now()));

-- When a row was last changed. verify-purchase uses it: an offer switched
-- off a moment ago can still be paid for by a player who is looking at it.
create or replace function public.touch_offer()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists offers_touch on offers;
create trigger offers_touch
  before update on offers
  for each row execute function public.touch_offer();

drop policy if exists "Admins manage offers" on offers;
create policy "Admins manage offers"
  on offers for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- =====================
-- offer_impressions
-- =====================
-- Each time an offer is shown to a signed-in player, and how it ended.
create table if not exists offer_impressions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  offer_id text not null,
  product_id text not null,
  outcome text not null default 'shown'
    check (outcome in ('shown', 'dismissed', 'bought')),
  created_at timestamptz not null default now()
);

create index if not exists offer_impressions_user_recent
  on offer_impressions (user_id, product_id, created_at desc);

alter table offer_impressions enable row level security;

drop policy if exists "Players record their own impressions" on offer_impressions;
create policy "Players record their own impressions"
  on offer_impressions for insert to authenticated
  -- 'bought' is written only by verify-purchase.
  with check (auth.uid() = user_id and outcome in ('shown', 'dismissed'));

drop policy if exists "Players read their own impressions" on offer_impressions;
create policy "Players read their own impressions"
  on offer_impressions for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Admins read impressions" on offer_impressions;
create policy "Admins read impressions"
  on offer_impressions for select to authenticated
  using (public.is_admin());

-- =====================
-- purchases: what was granted
-- =====================
-- Written by verify-purchase. The game gives the player exactly this, so an
-- offer changed later never changes what an earlier payment gave.
alter table purchases add column if not exists offer_id text;
alter table purchases add column if not exists grant_contents jsonb;

-- The first-purchase bonus (double Pearls on a player's first Pearl pack)
-- can be given once per player: the database itself refuses a second, so
-- two purchases arriving at the same moment cannot both be doubled.
alter table purchases add column if not exists first_bonus boolean not null default false;
create unique index if not exists purchases_one_first_bonus
  on purchases (user_id) where first_bonus;

-- =====================
-- The safety net: one fallback per price
-- =====================
insert into offers (id, kind, product_id, title, contents, is_active, is_fallback)
values
  ('fallback_099',  'fallback', 'offer_099',  'Special Offer', '{"pearls": 30}',   false, true),
  ('fallback_199',  'fallback', 'offer_199',  'Special Offer', '{"pearls": 60}',   false, true),
  ('fallback_299',  'fallback', 'offer_299',  'Special Offer', '{"pearls": 95}',   false, true),
  ('fallback_499',  'fallback', 'offer_499',  'Special Offer', '{"pearls": 160}',  false, true),
  ('fallback_999',  'fallback', 'offer_999',  'Special Offer', '{"pearls": 340}',  false, true),
  ('fallback_1999', 'fallback', 'offer_1999', 'Special Offer', '{"pearls": 720}',  false, true),
  ('fallback_4999', 'fallback', 'offer_4999', 'Special Offer', '{"pearls": 1900}', false, true)
on conflict (id) do nothing;
