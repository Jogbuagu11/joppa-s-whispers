-- The first set of offers. Safe to run more than once: rows that already
-- exist (and may have been edited since) are left as they are.
--
-- Every one is better value than the Pearl shop at the same price
-- ($0.99 = 25 Pearls, $4.99 = 140), and says exactly what it gives.
-- A "_more" row is what is offered next time if the first is turned down.

insert into offers
  (id, kind, product_id, title, subtitle, contents, audience, min_level,
   duration_seconds, priority, is_active)
values
  ('welcome_more', 'session_start', 'offer_099', 'Harbor Welcome',
   'A little more, for a little while',
   '{"pearls": 50, "manna": 50, "items": ["manna_jar_02"]}',
   'non_payer', 3, 86400, 0, true),
  ('market_more', 'session_start', 'offer_299', 'Market Day',
   'A little more, for a little while',
   '{"pearls": 130, "manna": 100, "items": ["hourglass_02", "manna_jar_02"]}',
   'payer', 3, 86400, 0, true),
  ('manna_more', 'out_of_manna', 'offer_099', 'Bread for the Road',
   'A little more, for a little while',
   '{"pearls": 25, "manna": 120}',
   'any', 3, 3600, 0, true)
on conflict (id) do nothing;

insert into offers
  (id, kind, product_id, title, subtitle, contents, audience, min_level,
   next_offer_id, duration_seconds, priority, is_active)
values
  ('welcome', 'session_start', 'offer_099', 'Harbor Welcome',
   'A gift to start your day in Joppa',
   '{"pearls": 40, "manna": 50}',
   'non_payer', 3, 'welcome_more', 86400, 1, true),
  ('market', 'session_start', 'offer_299', 'Market Day',
   'Fresh from the harbor market',
   '{"pearls": 110, "manna": 100, "items": ["hourglass_02"]}',
   'payer', 3, 'market_more', 86400, 2, true),
  ('manna', 'out_of_manna', 'offer_099', 'Bread for the Road',
   'Manna to keep you going',
   '{"pearls": 20, "manna": 100}',
   'any', 3, 'manna_more', 3600, 1, true),
  ('level', 'level_up', 'offer_299', 'A Good Day''s Work',
   'For reaching a new level',
   '{"pearls": 100, "talents": 300, "items": ["hourglass_02"]}',
   'any', 5, null, 86400, 1, true),
  ('chapter', 'chapter_complete', 'offer_499', 'Chapter''s End',
   'For the road ahead',
   '{"pearls": 180, "manna": 200, "items": ["knife_01", "thread_01"]}',
   'any', 1, null, 86400, 1, true)
on conflict (id) do nothing;
