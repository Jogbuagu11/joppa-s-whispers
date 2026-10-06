// Run with: deno test --allow-read admin/event_rules_test.ts
// Keeps the panel's event checks in step with the game's
// (lib/data/event_validator.dart) on the cases that matter.
import { assertEquals } from 'https://deno.land/std@0.177.0/testing/asserts.ts';

const source = Deno.readTextFileSync(new URL('./event_rules.js', import.meta.url));
const { eventProblems, TEMPLATE } = new Function(
  `${source}; return { eventProblems, TEMPLATE };`,
)() as {
  eventProblems: (ev: unknown) => string[];
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
