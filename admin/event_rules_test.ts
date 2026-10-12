// Run with: deno test --allow-read admin/event_rules_test.ts
// Keeps the panel's event checks in step with the game's
// (lib/data/event_validator.dart) on the cases that matter.
import { assertEquals } from 'https://deno.land/std@0.177.0/testing/asserts.ts';

const source = Deno.readTextFileSync(new URL('./event_rules.js', import.meta.url));
const { eventProblems, TEMPLATE, GOAL_TEMPLATES } = new Function(
  `${source}; return { eventProblems, TEMPLATE, GOAL_TEMPLATES };`,
)() as {
  eventProblems: (ev: unknown) => string[];
  // deno-lint-ignore no-explicit-any
  GOAL_TEMPLATES: Record<string, any>;
  // deno-lint-ignore no-explicit-any
  TEMPLATE: any;
};

// deno-lint-ignore no-explicit-any
const real = (): any =>
  JSON.parse(Deno.readTextFileSync(new URL('../content/events.json', import.meta.url)))[0];
// deno-lint-ignore no-explicit-any
const fresh = (): any => ({
  id: 'my_event',
  name: 'My event',
  starts_at: '2026-10-06T00:00:00Z',
  ends_at: '2026-10-27T00:00:00Z',
  config: structuredClone(TEMPLATE),
});

Deno.test('the real Boat Festival passes', () => {
  assertEquals(eventProblems(real()), []);
});

Deno.test('the "new event" template passes once it has an id, name and dates', () => {
  assertEquals(eventProblems(fresh()), []);
});

Deno.test('id, name and dates are checked', () => {
  assertEquals(eventProblems({ ...fresh(), id: 'My Event' }).length, 1);
  assertEquals(eventProblems({ ...fresh(), name: 'x'.repeat(41) }).length, 1);
  assertEquals(eventProblems({ ...fresh(), ends_at: '2026-10-01T00:00:00Z' }).length, 1);
  assertEquals(eventProblems({ ...fresh(), starts_at: '' }).length, 1);
});

Deno.test('numbers written with a decimal point are refused', () => {
  const ev = fresh();
  ev.config.chain.tiers[1].tier = 2.5;
  assertEquals(eventProblems(ev).length, 1);
});

Deno.test('art must be a short path inside the item art folder', () => {
  const ev = fresh();
  ev.config.chain.tiers[0].asset = 'assets/items/item_boat_01.jpg';
  assertEquals(eventProblems(ev), []);
  ev.config.chain.tiers[0].asset = '../secret.png';
  assertEquals(eventProblems(ev).length, 1);
  ev.config.chain.tiers[0].asset = ['assets/items/a.png'];
  assertEquals(eventProblems(ev).length, 1);
  ev.config.chain.tiers[0].asset = 'assets/items/' + 'a'.repeat(120);
  assertEquals(eventProblems(ev).length, 1);
});

Deno.test('generator: on the board, right chain, odds for real tiers adding to 1', () => {
  let ev = fresh();
  ev.config.generator.col = 5;
  assertEquals(eventProblems(ev).length, 1);
  ev = fresh();
  ev.config.generator.chain_id = 'bakery';
  assertEquals(eventProblems(ev).length, 1);
  ev = fresh();
  ev.config.generator.levels = [{ level: 1, odds: { '1': 0.5, '9': 0.5 } }];
  assertEquals(eventProblems(ev).length, 1);
  ev = fresh();
  ev.config.generator.levels = [{ level: 1, odds: { '1': 0.4 } }];
  assertEquals(eventProblems(ev).length, 1);
  ev = fresh();
  ev.config.generator.levels = [{ level: 1, odds: { '1.5': 1 } }];
  assertEquals(eventProblems(ev).length, 1);
  ev = fresh();
  ev.config.generator.levels = [{ level: 1, odds: {} }];
  assertEquals(eventProblems(ev).length, 1);
});

Deno.test('reward steps must rise and give something sensible', () => {
  let ev = fresh();
  ev.config.milestones = [{ points: 5, manna: 10 }, { points: 5, manna: 10 }];
  assertEquals(eventProblems(ev).length, 1);
  ev = fresh();
  ev.config.milestones = [{ points: 5 }];
  assertEquals(eventProblems(ev).length, 1);
  ev = fresh();
  ev.config.milestones = [{ points: 5, manna: 100000 }];
  assertEquals(eventProblems(ev).length, 1);
  ev = fresh();
  ev.config.milestones = [{ points: 5, manna: false, talents: 10 }];
  assertEquals(eventProblems(ev).length, 1);
  ev = fresh();
  ev.config.milestones = [];
  assertEquals(eventProblems(ev).length, 1);
});

// deno-lint-ignore no-explicit-any
const goal = (kind: string, over: Record<string, unknown> = {}): any => ({
  id: 'my_goal',
  name: 'My goal event',
  starts_at: '2026-10-06T00:00:00Z',
  ends_at: '2026-10-09T00:00:00Z',
  config: { ...structuredClone(GOAL_TEMPLATES[kind]), ...over },
});

Deno.test('each kind of goal event passes as the panel starts it', () => {
  for (const kind of Object.keys(GOAL_TEMPLATES)) {
    assertEquals(eventProblems(goal(kind)), [], kind);
  }
});

Deno.test('mistakes in a goal event are caught', () => {
  assertEquals(eventProblems(goal('energy', { type: 'party' })).length, 1);
  assertEquals(eventProblems(goal('energy', { blurb: '' })).length, 1);
  assertEquals(eventProblems(goal('collect', { drop_percent: 0 })).length, 1);
  assertEquals(eventProblems(goal('order', { per_order: 99 })).length, 1);
  assertEquals(eventProblems(goal('energy', { milestones: [] })).length, 1);
  assertEquals(
    eventProblems(goal('energy', { milestones: [{ points: 5 }] })).length,
    1,
  );
  assertEquals(
    eventProblems(goal('energy', { milestones: [{ points: 5, pearls: 500 }] })).length,
    1,
  );
  assertEquals(
    eventProblems(
      goal('energy', { milestones: [{ points: 5, manna: 5 }, { points: 5, manna: 5 }] }),
    ).length,
    1,
  );
});

Deno.test('a free Manna code is checked before it is saved', () => {
  const { mannaLinkProblems } = new Function(
    `${source}; return { mannaLinkProblems };`,
  )() as { mannaLinkProblems: (c: unknown, m: unknown, d: unknown) => string[] };
  assertEquals(mannaLinkProblems('joppa25', '25', '3'), []);
  assertEquals(mannaLinkProblems('ab', '25', '3').length, 1);
  assertEquals(mannaLinkProblems('has space', '25', '3').length, 1);
  assertEquals(mannaLinkProblems('JOPPA25', '500', '3').length, 1);
  assertEquals(mannaLinkProblems('JOPPA25', '2.5', '0').length, 2);
});
