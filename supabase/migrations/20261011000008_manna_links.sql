-- Free Manna links (EXPANSION section 25): a code posted on Facebook or
-- Instagram gives a little Manna, once to each player.
-- Safe to run more than once.
create table if not exists manna_links (
  code text primary key check (code ~ '^[A-Z0-9]{4,20}$'),
  manna integer not null check (manna between 1 and 100),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
alter table manna_links enable row level security;
-- Only admins see or change the list; players go through the function.
drop policy if exists "Admins manage manna links" on manna_links;
create policy "Admins manage manna links"
  on manna_links for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create table if not exists manna_link_claims (
  code text not null references manna_links(code) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  claimed_at timestamptz not null default now(),
  primary key (code, user_id)
);
alter table manna_link_claims enable row level security;
drop policy if exists "Players read their own claims" on manna_link_claims;
create policy "Players read their own claims"
  on manna_link_claims for select to authenticated using (auth.uid() = user_id);

-- A signed-in player claims a code. Gives {"status": ..., "manna": n}:
-- "ok" (with the Manna to give), "used" (this player had it already),
-- "over" (not started yet or ended) or "unknown". Never gives twice: the
-- claim row is the proof, and it can be written only once.
create or replace function public.claim_manna_link(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_code text := upper(trim(coalesce(p_code, '')));
  v_link public.manna_links%rowtype;
  v_rows integer;
begin
  if v_user is null then
    raise exception 'Sign in first';
  end if;
  select * into v_link from public.manna_links where code = v_code;
  if not found then
    return jsonb_build_object('status', 'unknown', 'manna', 0);
  end if;
  if now() < v_link.starts_at or now() >= v_link.ends_at then
    return jsonb_build_object('status', 'over', 'manna', 0);
  end if;
  insert into public.manna_link_claims (code, user_id)
    values (v_code, v_user)
    on conflict (code, user_id) do nothing;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    return jsonb_build_object('status', 'used', 'manna', 0);
  end if;
  return jsonb_build_object('status', 'ok', 'manna', v_link.manna);
end;
$$;

revoke all on function public.claim_manna_link(text) from public, anon;
grant execute on function public.claim_manna_link(text) to authenticated;
