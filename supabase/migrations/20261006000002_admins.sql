-- The admin panel: who may use it and what they may change.
-- An admin is an account listed in `admins`. Nobody can add themselves:
-- rows are added only from the server side (Supabase dashboard or CLI).
-- Safe to run more than once.

create table if not exists admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table admins enable row level security;

-- An account can see whether it is an admin; nothing else, and no writes.
drop policy if exists "Admins can see their own row" on admins;
create policy "Admins can see their own row"
  on admins for select to authenticated
  using (user_id = auth.uid());

-- True when the caller is an admin. Runs with the table owner's rights so
-- the policies below can use it without opening `admins` to anyone.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- Events: an admin can see every event (switched on or not) and create,
-- change, switch and delete them. Players still only read switched-on ones.
drop policy if exists "Admins manage events" on events;
create policy "Admins manage events"
  on events for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Content releases: an admin can add a release and upload its bundle file.
-- (Releases are never edited or deleted from the panel.)
drop policy if exists "Admins publish content versions" on content_versions;
create policy "Admins publish content versions"
  on content_versions for insert to authenticated
  with check (public.is_admin());

drop policy if exists "Admins upload content bundles" on storage.objects;
create policy "Admins upload content bundles"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'content' and public.is_admin());

-- The record of pushes sent: an admin can read it. (Rows are written only by
-- the send-push function.)
drop policy if exists "Admins read the notification log" on notifications_log;
create policy "Admins read the notification log"
  on notifications_log for select to authenticated
  using (public.is_admin());
