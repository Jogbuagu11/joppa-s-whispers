// Run with: deno test --allow-read supabase/functions/roll/rules_test.ts
import { assertEquals } from 'https://deno.land/std@0.177.0/testing/asserts.ts';
import { openPrizes, pickPrize, type Prize, secureRandom, tableFor } from './rules.ts';
import { CONTENT_VERSION, TABLES } from './tables.ts';

const prizes: Prize[] = [
  { id: 'a', name: 'A', weight: 50 },
  { id: 'b', name: 'B', weight: 30 },
  { id: 'pearl', name: '1 Pearl', weight: 20, pearls: 1, free_only: true },
];

Deno.test('a paid try can never give a free-only prize (no Pearls for Pearls)', () => {
  assertEquals(openPrizes(prizes, true).map((p) => p.id), ['a', 'b']);
  assertEquals(openPrizes(prizes, false).map((p) => p.id), ['a', 'b', 'pearl']);
  for (let i = 0; i < 1000; i++) {
    assertEquals(pickPrize(prizes, true, i / 1000)?.free_only ?? false, false);
  }
});

Deno.test('prizes come by their weight', () => {
  // Free: a is 0–0.5, b 0.5–0.8, pearl 0.8–1.
  assertEquals(pickPrize(prizes, false, 0)?.id, 'a');
  assertEquals(pickPrize(prizes, false, 0.49)?.id, 'a');
  assertEquals(pickPrize(prizes, false, 0.51)?.id, 'b');
  assertEquals(pickPrize(prizes, false, 0.81)?.id, 'pearl');
  assertEquals(pickPrize(prizes, false, 0.999999)?.id, 'pearl');
  // Paid: a is 0–0.625, b the rest.
  assertEquals(pickPrize(prizes, true, 0.62)?.id, 'a');
  assertEquals(pickPrize(prizes, true, 0.63)?.id, 'b');
  const counts: Record<string, number> = {};
  for (let i = 0; i < 10000; i++) {
    const id = pickPrize(prizes, false, (i + 0.5) / 10000)?.id ?? '';
    counts[id] = (counts[id] ?? 0) + 1;
  }
  assertEquals(counts, { a: 5000, b: 3000, pearl: 2000 });
});

Deno.test('nothing to draw gives nothing', () => {
  assertEquals(pickPrize([], false, 0.5), null);
  assertEquals(pickPrize([{ id: 'x', name: 'X', weight: 0 }], false, 0.5), null);
  assertEquals(pickPrize([prizes[2]], true, 0.5), null);
});

Deno.test('a request names the wheel or a kind of jar; anything else is refused', () => {
  assertEquals(tableFor(TABLES, { kind: 'wheel' }), TABLES.wheel);
  assertEquals(tableFor(TABLES, { kind: 'jar', jar: 'treasure' }), TABLES.jars.treasure);
  assertEquals(tableFor(TABLES, { kind: 'jar', jar: 'no_such' }), null);
  assertEquals(tableFor(TABLES, { kind: 'jar', jar: 'constructor' }), null);
  assertEquals(tableFor(TABLES, { kind: 'jar' }), null);
  assertEquals(tableFor(TABLES, { kind: 'bubble' }), null);
  assertEquals(tableFor(TABLES, {}), null);
});

Deno.test('the secure random number is always 0 up to, not including, 1', () => {
  for (let i = 0; i < 1000; i++) {
    const r = secureRandom();
    assertEquals(r >= 0 && r < 1, true);
  }
});

Deno.test('the server\'s tables are the game\'s own (content/chance.json)', async () => {
  const read = async (name: string) =>
    JSON.parse(
      await Deno.readTextFile(new URL(`../../../content/${name}.json`, import.meta.url)),
    );
  const chance = await read('chance');
  assertEquals(CONTENT_VERSION, (await read('version')).version);
  assertEquals(TABLES.wheel, chance.wheel.prizes);
  assertEquals(Object.keys(TABLES.jars).sort(), Object.keys(chance.jars.kinds).sort());
  for (const [kind, jar] of Object.entries(chance.jars.kinds)) {
    assertEquals(TABLES.jars[kind], (jar as { prizes: unknown }).prizes);
  }
});

Deno.test('no sold jar holds Pearls for a paid try', () => {
  for (const [kind, table] of Object.entries(TABLES.jars)) {
    const paid = openPrizes(table, true);
    assertEquals(paid.some((p) => (p.pearls ?? 0) > 0), false, kind);
  }
  assertEquals(
    openPrizes(TABLES.wheel, true).some((p) => (p.pearls ?? 0) > 0),
    false,
  );
});
