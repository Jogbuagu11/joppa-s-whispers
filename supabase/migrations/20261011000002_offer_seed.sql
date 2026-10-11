-- The first set of offers. Safe to run more than once: rows that already
-- exist (and may have been edited since) are left as they are.
--
-- Every one is better value than the Pearl shop at the same price
-- ($0.99 = 25 Pearls, $1.99 has no shop pack, $4.99 = 140), says exactly
-- what it gives, and holds nothing left to chance (no Jars of Clay).
-- A "_more" row is what is offered next if the first is turned down.
-- A badge is a plain, true comparison with the shop at that price.

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

-- Shown at their own moments.
insert into offers
  (id, kind, product_id, title, subtitle, contents, audience, min_level,
   next_offer_id, duration_seconds, priority, is_active)
values
  ('welcome', 'session_start', 'offer_099', 'Harbor Welcome',
   'A gift to start your day in Joppa',
   '{"pearls": 40, "manna": 50}',
   'non_payer', 3, 'welcome_more', 86400, 2, true),
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

-- The daily pool: after the day's first greeting, each further opening of
-- the game brings another of these, in an order that turns with the day.
-- Single items, small packs and larger ones.
insert into offers
  (id, kind, product_id, title, subtitle, contents, audience, min_level,
   duration_seconds, priority, is_active)
values
  ('daily_hourglass', 'session_start', 'offer_099', 'The Great Hourglass',
   'Every generator ready at once',
   '{"items": ["hourglass_03"]}',
   'any', 4, 14400, 1, true),
  ('daily_thread', 'session_start', 'offer_099', 'A Golden Thread',
   'Merges with anything',
   '{"items": ["thread_01"]}',
   'any', 4, 14400, 1, true),
  ('daily_potion', 'session_start', 'offer_099', 'Manna Potion',
   'A hundred Manna, kept for when you need it',
   '{"items": ["manna_jar_04"], "pearls": 10}',
   'any', 4, 14400, 1, true),
  ('daily_toolkit', 'session_start', 'offer_199', 'The Weaver''s Kit',
   'A knife, a thread and Pearls',
   '{"pearls": 30, "items": ["knife_01", "thread_01"]}',
   'any', 4, 14400, 1, true),
  ('daily_pouch', 'session_start', 'offer_199', 'A Pouch of Pearls',
   'Pearls and Manna for the day',
   '{"pearls": 60, "manna": 60}',
   'any', 4, 14400, 1, true),
  ('daily_basket', 'session_start', 'offer_499', 'The Merchant''s Basket',
   'A little of everything',
   '{"pearls": 170, "talents": 300, "items": ["hourglass_02", "thread_01", "manna_jar_03"]}',
   'any', 6, 14400, 1, true)
on conflict (id) do nothing;

-- Weekend sales (Friday, Saturday, Sunday): Pearls only, so the comparison
-- with the shop on the badge is exact. $0.99 buys 25 in the shop, $4.99 140.
insert into offers
  (id, kind, product_id, title, subtitle, badge, contents, audience, min_level,
   duration_seconds, priority, is_active, weekdays)
values
  ('weekend_pearls', 'session_start', 'offer_099', 'Weekend Market',
   'This weekend only', '80% more than the shop',
   '{"pearls": 45}',
   'any', 3, 14400, 1, true, '{5,6,7}'),
  ('weekend_chest', 'session_start', 'offer_499', 'Weekend Chest',
   'This weekend only', '50% more than the shop',
   '{"pearls": 210}',
   'any', 3, 14400, 1, true, '{5,6,7}')
on conflict (id) do nothing;
