-- A first race (Milestone 32), for two days from the moment this is run.
-- The four rivals are townsfolk played by the game, not other players.
-- Safe to run more than once. Builds older than 27 pass it over.
insert into events (id, name, starts_at, ends_at, config, is_active)
values
  ('race_to_the_harbor_1', 'Race to the Harbor', now(), now() + interval '2 days',
   '{"type":"race","blurb":"Deliver orders faster than the townsfolk. The first three home win a prize.","token":"Orders delivered","goal":12,"rivals":[{"name":"Miriam","hours":5},{"name":"Old Tobias","hours":9},{"name":"Lydia","hours":16},{"name":"Young Reuben","hours":30}],"prizes":[{"pearls":5,"manna":30,"items":["hourglass_02"]},{"manna":30,"talents":60},{"talents":60}]}'::jsonb, true)
on conflict (id) do nothing;
