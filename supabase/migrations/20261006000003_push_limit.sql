-- Tightening after review of the admin panel. Safe to run more than once.

-- 1. "At most one push a day", made airtight: the record of a push is
--    written BEFORE it is sent, under a lock, and only if nothing was sent
--    in the last 24 hours. Two requests at the same moment cannot both pass,
--    and a push can never go out without a record. Returns the new row's id,
--    or null when a push has already gone out today. Server use only.
create or replace function public.reserve_push(
  p_type text,
  p_audience text,
  p_title text,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_id uuid;
begin
  perform pg_advisory_xact_lock(74201);
  if exists (
    select 1 from public.notifications_log
    where sent_at > now() - interval '24 hours'
  ) then
    return null;
  end if;
  insert into public.notifications_log
    (notification_type, audience, title, body, sent_count)
  values (p_type, p_audience, p_title, p_body, 0)
  returning id into new_id;
  return new_id;
end;
$$;

revoke all on function public.reserve_push(text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.reserve_push(text, text, text, text)
  to service_role;

-- 2. is_admin(): no search path at all (every name in it is written in full).
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- 3. A content version number can be released only once.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'content_versions_version_unique'
  ) then
    alter table public.content_versions
      add constraint content_versions_version_unique unique (version);
  end if;
end;
$$;
