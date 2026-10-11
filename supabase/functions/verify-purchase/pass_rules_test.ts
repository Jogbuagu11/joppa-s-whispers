// Run with: deno test supabase/functions/verify-purchase/pass_rules_test.ts
import { assertEquals } from 'https://deno.land/std@0.177.0/testing/asserts.ts';
import {
  choosePassEvent,
  type EventRow,
  isPassProduct,
  passGrantFor,
} from './pass_rules.ts';

const NOW = new Date('2026-10-12T09:00:00Z');
const event = (id: string, starts: string, ends: string, active = true): EventRow => ({
  id,
  starts_at: `${starts}T00:00:00Z`,
  ends_at: `${ends}T00:00:00Z`,
  is_active: active,
});
const boat = event('boat', '2026-10-06', '2026-10-27');
const harvest = event('harvest', '2026-10-10', '2026-10-15');
const past = event('past', '2026-09-01', '2026-09-20');
const coming = event('coming', '2026-11-01', '2026-11-20');
const later = event('later', '2026-12-01', '2026-12-20');

const pick = (claimedEventId: unknown, events: EventRow[]) =>
  choosePassEvent({ claimedEventId, events, now: NOW })?.id;

Deno.test('only the two pass products are pass products', () => {
  assertEquals(isPassProduct('pass_premium'), true);
  assertEquals(isPassProduct('pass_premium_plus'), true);
  assertEquals(isPassProduct('offer_499'), false);
  assertEquals(isPassProduct('toString'), false);
  assertEquals(isPassProduct(null), false);
});

Deno.test('the pass is for the event the app showed, while that event is on', () => {
  assertEquals(pick('harvest', [boat, harvest, past]), 'harvest');
  assertEquals(pick('boat', [boat, harvest]), 'boat');
});

Deno.test('a pass for an event that is over goes to one still to be played', () => {
  // On now: the one that ends last.
  assertEquals(pick('past', [past, harvest, boat]), 'boat');
  assertEquals(pick(undefined, [harvest, boat]), 'boat');
  assertEquals(pick('no_such', [harvest, boat]), 'boat');
  // None on now: the next to start.
  assertEquals(pick('past', [past, later, coming]), 'coming');
  // A switched-off event is not one to be played.
  assertEquals(pick('past', [past, event('off', '2026-10-06', '2026-10-27', false), coming]), 'coming');
  assertEquals(pick('off', [event('off', '2026-10-06', '2026-10-27', false), boat]), 'boat');
});

Deno.test('with nothing to play it stays with its own event, or the latest', () => {
  assertEquals(pick('past', [past]), 'past');
  assertEquals(pick(undefined, [past, event('older', '2026-08-01', '2026-08-20')]), 'past');
  assertEquals(pick('past', []), undefined);
  // A row with unreadable dates is left out.
  assertEquals(pick('odd', [{ id: 'odd', starts_at: 'x', ends_at: 'y', is_active: true }]), undefined);
});

Deno.test('a pass purchase records its tier and its event', () => {
  assertEquals(passGrantFor('pass_premium', boat), { tier: 'premium', event_id: 'boat' });
  assertEquals(passGrantFor('pass_premium_plus', boat), { tier: 'plus', event_id: 'boat' });
});
