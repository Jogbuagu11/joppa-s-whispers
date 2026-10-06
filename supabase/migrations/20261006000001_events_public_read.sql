-- Lets every player, signed in or not, read the events that are switched on.
-- (Before this only signed-in players could read events, and they could read
-- every event, including ones still being prepared.)
-- Events hold no personal data: a name, dates and the event's game settings.
-- Applied to the live project on 2026-10-06 with Jennifer's OK.

drop policy if exists "Authenticated users can read events" on events;

create policy "Anyone can read active events"
  on events for select
  to anon, authenticated
  using (is_active);
