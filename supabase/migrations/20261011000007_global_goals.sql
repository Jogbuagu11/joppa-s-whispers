-- The global feast goal (EXPANSION section 22): one total for all players.
-- Safe to run more than once.
create table if not exists global_goals (
  event_id text primary key references events(id) on delete cascade,
  total bigint not null default 0,
  updated_at timestamptz not null default now()
);
alter table global_goals enable row level security;
-- A total holds no personal data.
drop policy if exists "Anyone can read global goals" on global_goals;
create policy "Anyone can read global goals"
  on global_goals for select to anon, authenticated using (true);

-- What each player has added (so one player cannot fill the goal alone).
create table if not exists global_goal_parts (
  event_id text not null references events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  amount integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (event_id, user_id)
);
alter table global_goal_parts enable row level security;
drop policy if exists "Players read their own part" on global_goal_parts;
create policy "Players read their own part"
  on global_goal_parts for select to authenticated using (auth.uid() = user_id);

-- A signed-in player says how many orders they have delivered in all
-- (p_mine) in a goal that is on; gives the new total. Saying the same
-- number twice adds nothing. One player's part rises by at most 20 at a
-- time, no more often than every 10 seconds, to 3000 at most in one goal.
create or replace function public.add_to_global_goal(p_event_id text, p_mine integer)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_have integer;
  v_last timestamptz;
  v_new integer;
  v_total bigint;
begin
  if v_user is null then
    raise exception 'Sign in first';
  end if;
  if exists (
    select 1 from public.events e
    where e.id = p_event_id and e.is_active
      and e.config->>'type' = 'global'
      and now() >= e.starts_at and now() < e.ends_at
  ) then
    insert into public.global_goal_parts (event_id, user_id, amount, updated_at)
      values (p_event_id, v_user, 0, now() - interval '1 minute')
      on conflict (event_id, user_id) do nothing;
    -- Locked, so two calls at once cannot both pass the limits.
    select amount, updated_at into v_have, v_last
      from public.global_goal_parts
      where event_id = p_event_id and user_id = v_user
      for update;
    v_new := least(greatest(coalesce(p_mine, 0), 0), 3000, v_have + 20);
    if v_new > v_have and v_last <= now() - interval '10 seconds' then
      update public.global_goal_parts
        set amount = v_new, updated_at = now()
        where event_id = p_event_id and user_id = v_user;
      insert into public.global_goals (event_id, total)
        values (p_event_id, v_new - v_have)
        on conflict (event_id)
        do update set total = public.global_goals.total + excluded.total,
                      updated_at = now();
    end if;
  end if;
  select total into v_total from public.global_goals where event_id = p_event_id;
  return coalesce(v_total, 0);
end;
$$;

revoke all on function public.add_to_global_goal(text, integer) from public, anon;
grant execute on function public.add_to_global_goal(text, integer) to authenticated;
