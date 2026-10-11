// Run with: deno test --allow-read supabase/functions/verify-purchase/pass_rules_test.ts
import { assertEquals } from 'https://deno.land/std@0.177.0/testing/asserts.ts';
import {
  choosePassEvent,
  type EventRow,
  isPassProduct,
  PASS_PRODUCTS,
  passGrantFor,
} from './pass_rules.ts';

const NOW = new Date('2026-10-12T09:00:00Z');
const PASS = { pass: { premium: [{ manna: 5 }] } };
const event = (
  id: string,
  starts: string,
  ends: string,
  over: Partial<EventRow> = {},
): EventRow => ({
  id,
  starts_at: `${starts}T00:00:00Z`,
  ends_at: `${ends}T00:00:00Z`,
  is_active: true,
  config: PASS,
  ...over,
});
const boat = event('boat', '2026-10-06', '2026-10-27');
const harvest = event('harvest', '2026-10-10', '2026-10-15');
const past = event('past', '2026-09-01', '2026-09-20');
const coming = event('coming', '2026-11-01', '2026-11-20');
const later = event('later', '2026-12-01', '2026-12-20');
const plain = event('plain', '2026-10-06', '2026-10-13', { config: { milestones: [] } });
const off = event('off', '2026-10-06', '2026-10-27', { is_active: false });

const pick = (claimedEventId: unknown, events: EventRow[], lastShownEventId?: unknown) =>
  choosePassEvent({ claimedEventId, lastShownEventId, events, now: NOW });

Deno.test('only the two pass products are pass products, as content names them', async () => {
  assertEquals(isPassProduct('pass_premium'), true);
  assertEquals(isPassProduct('pass_premium_plus'), true);
  assertEquals(isPassProduct('offer_499'), false);
  assertEquals(isPassProduct('toString'), false);
  assertEquals(isPassProduct(null), false);
  const offers = JSON.parse(
    await Deno.readTextFile(new URL('../../../content/offers.json', import.meta.url)),
  );
  assertEquals(PASS_PRODUCTS[offers.season_pass.premium_product], 'premium');
  assertEquals(PASS_PRODUCTS[offers.season_pass.plus_product], 'plus');
});

Deno.test('the pass is for the event the app showed, while that event is on', () => {
  assertEquals(pick('harvest', [boat, harvest, past]), 'harvest');
  assertEquals(pick('boat', [boat, harvest]), 'boat');
});

Deno.test('the app closed mid-payment: the event it last noted as shown is used', () => {
  assertEquals(pick(undefined, [harvest, boat], 'boat'), 'boat');
  // What the app says now comes first.
  assertEquals(pick('harvest', [harvest, boat], 'boat'), 'harvest');
});

Deno.test('a pass never goes to an event that has no pass', () => {
  assertEquals(pick('plain', [plain, boat]), 'boat');
  assertEquals(pick(undefined, [plain, boat]), 'boat');
});

Deno.test('a pass for an event that is over goes to one still to be played', () => {
  // On now: the one that ends soonest, which is the one the game shows.
  assertEquals(pick('past', [past, boat, harvest]), 'harvest');
  assertEquals(pick(undefined, [boat, harvest]), 'harvest');
  assertEquals(pick('no_such', [boat, harvest]), 'harvest');
  // None on now: the next to start.
  assertEquals(pick('past', [past, later, coming]), 'coming');
  // A switched-off event is not one to be played.
  assertEquals(pick('past', [past, off, coming]), 'coming');
  assertEquals(pick('off', [off, boat]), 'boat');
});

Deno.test('with nothing to play it stays with the event named, known or not', () => {
  assertEquals(pick('past', [past]), 'past');
  // The game can play an event from its own files that the table lacks.
  assertEquals(pick('boat_festival_2026', []), 'boat_festival_2026');
  assertEquals(pick(undefined, [], 'boat_festival_2026'), 'boat_festival_2026');
  // An id that is not an event id is not recorded.
  assertEquals(pick('Robert\'); drop', []), null);
  assertEquals(pick(undefined, [past, event('older', '2026-08-01', '2026-08-20')]), 'past');
  assertEquals(pick(undefined, []), null);
  // A row with unreadable dates is left out.
  assertEquals(
    pick(undefined, [{ id: 'odd', starts_at: 'x', ends_at: 'y', is_active: true, config: PASS }]),
    null,
  );
});

Deno.test('a pass purchase records its tier and its event', () => {
  assertEquals(passGrantFor('pass_premium', 'boat'), { tier: 'premium', event_id: 'boat' });
  assertEquals(passGrantFor('pass_premium_plus', 'boat'), { tier: 'plus', event_id: 'boat' });
});
