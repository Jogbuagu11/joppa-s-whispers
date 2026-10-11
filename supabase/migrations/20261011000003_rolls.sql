-- A record of every prize drawn on the server (the `roll` function): paid
-- tries at the Blessing Wheel and bought Jars of Clay. Safe to run twice.
create table if not exists rolls (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  -- 'wheel', or 'jar:<kind>'.
  kind text not null,
  paid boolean not null,
  prize_id text not null,
  -- The content version whose odds table was drawn from.
  content_version integer not null,
  created_at timestamptz not null default now()
);

create index if not exists rolls_user_recent on rolls (user_id, created_at desc);

alter table rolls enable row level security;

-- Written only by the roll function (service role). A player may see their
-- own draws; an admin all of them.
drop policy if exists "Players read their own rolls" on rolls;
create policy "Players read their own rolls"
  on rolls for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Admins read rolls" on rolls;
create policy "Admins read rolls"
  on rolls for select to authenticated
  using (public.is_admin());
