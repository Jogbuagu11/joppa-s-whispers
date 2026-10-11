-- The Boat Festival's season pass (Milestone 31): a Premium reward beside
-- each milestone, and Premium Plus (bonus points, an endless track). The same
-- block as in content/events.json. Safe to run more than once.
--
-- Only if the live event still has the 20 milestones the pass was written
-- for: a pass that does not match its milestones would hide the event.
update events
set config = config || jsonb_build_object('pass', '{"premium":[{"manna":15},{"talents":60},{"pearls":5},{"items":["hourglass_01"]},{"manna":20},{"pearls":10},{"manna":25},{"items":["manna_jar_02"]},{"pearls":10},{"talents":140},{"manna":30},{"pearls":15},{"items":["knife_01"]},{"talents":180},{"pearls":20},{"talents":200},{"items":["thread_01"]},{"pearls":30},{"manna":40},{"pearls":50,"talents":300}],"plus":{"bonus_percent":20,"endless":{"every":400,"talents":60,"manna":15}}}'::jsonb)
where id = 'boat_festival_2026'
  and not (config ? 'pass')
  and jsonb_array_length(config -> 'milestones') = 20;
