-- Two first goal events (Milestone 32), so there is something to play: a
-- milestone event for five days and an energy event for two, from the
-- moment this is run. More are made in the admin panel. Safe to run more
-- than once. Builds older than 26 do not know these and pass them over.
insert into events (id, name, starts_at, ends_at, config, is_active)
values
  ('harvest_gathering_1', 'Harvest Gathering', now(), now() + interval '5 days',
   '{"type":"milestone","blurb":"Deliver orders: every Talent you earn counts toward the harvest.","token":"Talents earned","milestones":[{"points":60,"manna":10},{"points":150,"talents":30},{"points":300,"manna":15},{"points":400,"items":["hourglass_01"]},{"points":650,"talents":60},{"points":800,"pearls":3},{"points":1150,"manna":25},{"points":1350,"talents":100},{"points":1800,"items":["manna_jar_02"]},{"points":2100,"pearls":5}]}'::jsonb, true),
  ('lamps_of_joppa_1', 'Lamps of Joppa', now(), now() + interval '2 days',
   '{"type":"energy","blurb":"Keep the lamps burning: every Manna you spend counts.","token":"Manna spent","milestones":[{"points":30,"talents":20},{"points":80,"manna":10},{"points":150,"talents":50},{"points":250,"items":["hourglass_01"]},{"points":400,"talents":100},{"points":600,"pearls":3}]}'::jsonb, true)
on conflict (id) do nothing;
