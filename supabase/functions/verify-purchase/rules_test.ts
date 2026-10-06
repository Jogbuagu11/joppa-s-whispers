// Run with: deno test supabase/functions/verify-purchase/rules_test.ts
import { assertEquals } from 'https://deno.land/std@0.177.0/testing/asserts.ts';
import {
  b64url,
  checkAppleTransaction,
  checkGooglePurchase,
  decideGrant,
  decodeJwsPayload,
  PRODUCTS,
} from './rules.ts';

const USER = '3f2b1c9e-0000-4000-8000-00000000abcd';
const OTHER = '11111111-2222-4333-8444-555555555555';
const BUNDLE = 'com.whispersofjoppa.game';

const appleTx = (over: Record<string, unknown> = {}) => ({
  bundleId: BUNDLE,
  productId: 'pearls_tier1',
  transactionId: '2000000123456789',
  appAccountToken: USER,
  ...over,
});
const appleClaim = (over: Record<string, string> = {}) => ({
  bundleId: BUNDLE,
  productId: 'pearls_tier1',
  transactionId: '2000000123456789',
  userId: USER,
  ...over,
});

Deno.test('apple: a genuine purchase by this player is accepted', () => {
  assertEquals(checkAppleTransaction(appleTx(), appleClaim()), {
    ok: true,
    transactionId: '2000000123456789',
  });
});

Deno.test('apple: account id comparison ignores letter case', () => {
  const r = checkAppleTransaction(
    appleTx({ appAccountToken: USER.toUpperCase() }),
    appleClaim(),
  );
  assertEquals(r.ok, true);
});

Deno.test('apple: a cheap purchase cannot be claimed as an expensive product', () => {
  const r = checkAppleTransaction(appleTx(), appleClaim({ productId: 'pearls_tier6' }));
  assertEquals(r, { ok: false, reason: 'wrong product' });
});

Deno.test('apple: a purchase from another app is rejected', () => {
  const r = checkAppleTransaction(appleTx({ bundleId: 'com.other.app' }), appleClaim());
  assertEquals(r, { ok: false, reason: 'wrong app' });
});

Deno.test('apple: someone else\'s purchase cannot be claimed', () => {
  assertEquals(
    checkAppleTransaction(appleTx({ appAccountToken: OTHER }), appleClaim()),
    { ok: false, reason: 'bought by a different account' },
  );
  assertEquals(
    checkAppleTransaction(appleTx({ appAccountToken: undefined }), appleClaim()),
    { ok: false, reason: 'bought by a different account' },
  );
});

Deno.test('apple: a refunded purchase is rejected', () => {
  const r = checkAppleTransaction(appleTx({ revocationDate: 1790000000000 }), appleClaim());
  assertEquals(r, { ok: false, reason: 'refunded or revoked' });
});

Deno.test('apple: a mismatched transaction id or empty reply is rejected', () => {
  assertEquals(
    checkAppleTransaction(appleTx({ transactionId: '999' }), appleClaim()),
    { ok: false, reason: 'wrong transaction' },
  );
  assertEquals(checkAppleTransaction(null, appleClaim()).ok, false);
});

const googlePurchase = (over: Record<string, unknown> = {}) => ({
  purchaseState: 0,
  consumptionState: 0,
  orderId: 'GPA.3345-1234-5678-90123',
  obfuscatedExternalAccountId: USER,
  ...over,
});

Deno.test('google: a genuine purchase is accepted and keyed by Google\'s order id', () => {
  assertEquals(checkGooglePurchase(googlePurchase(), { userId: USER }), {
    ok: true,
    transactionId: 'GPA.3345-1234-5678-90123',
  });
});

Deno.test('google: cancelled or pending purchases are rejected', () => {
  assertEquals(checkGooglePurchase(googlePurchase({ purchaseState: 1 }), { userId: USER }).ok, false);
  assertEquals(checkGooglePurchase(googlePurchase({ purchaseState: 2 }), { userId: USER }).ok, false);
});

Deno.test('google: a purchase with no order id is rejected', () => {
  assertEquals(checkGooglePurchase(googlePurchase({ orderId: '' }), { userId: USER }).ok, false);
  assertEquals(checkGooglePurchase(googlePurchase({ orderId: undefined }), { userId: USER }).ok, false);
});

Deno.test('google: someone else\'s purchase token cannot be claimed', () => {
  assertEquals(
    checkGooglePurchase(googlePurchase({ obfuscatedExternalAccountId: OTHER }), { userId: USER }),
    { ok: false, reason: 'bought by a different account' },
  );
  assertEquals(
    checkGooglePurchase(googlePurchase({ obfuscatedExternalAccountId: undefined }), { userId: USER }).ok,
    false,
  );
});

Deno.test('grant: a new confirmed purchase is granted', () => {
  assertEquals(
    decideGrant(null, { userId: USER, consumable: true, consumedAtStore: false }),
    'grant',
  );
});

Deno.test('grant: the same transaction again is "already granted", never a second grant', () => {
  assertEquals(
    decideGrant({ user_id: USER, status: 'granted' }, {
      userId: USER,
      consumable: true,
      consumedAtStore: true,
    }),
    'already_granted',
  );
});

Deno.test('grant: a transaction recorded for another player is rejected', () => {
  assertEquals(
    decideGrant({ user_id: OTHER, status: 'granted' }, {
      userId: USER,
      consumable: true,
      consumedAtStore: false,
    }),
    'reject',
  );
});

Deno.test('grant: a refunded transaction is rejected', () => {
  assertEquals(
    decideGrant({ user_id: USER, status: 'refunded' }, {
      userId: USER,
      consumable: true,
      consumedAtStore: false,
    }),
    'reject',
  );
});

Deno.test('grant: replaying a used-up Google token with no record gives nothing', () => {
  assertEquals(
    decideGrant(null, { userId: USER, consumable: true, consumedAtStore: true }),
    'reject',
  );
});

Deno.test('grant: a one-time product is granted whatever its consumption state', () => {
  assertEquals(
    decideGrant(null, { userId: USER, consumable: false, consumedAtStore: false }),
    'grant',
  );
});

Deno.test('jws: payload is decoded; rubbish gives null', () => {
  const jws = `${b64url('{"alg":"ES256"}')}.${b64url(JSON.stringify(appleTx()))}.sig`;
  assertEquals(decodeJwsPayload(jws)?.productId, 'pearls_tier1');
  assertEquals(decodeJwsPayload('not-a-jws'), null);
  assertEquals(decodeJwsPayload('a.%%%.c'), null);
  assertEquals(decodeJwsPayload(42), null);
});

Deno.test('b64url has no +, / or = (required for JWTs)', () => {
  const out = b64url(new Uint8Array([251, 255, 254, 62, 63]));
  assertEquals(/[+/=]/.test(out), false);
});

Deno.test('products match the app\'s content/products.json', async () => {
  const content = JSON.parse(
    await Deno.readTextFile(new URL('../../../content/products.json', import.meta.url)),
  ) as Array<Record<string, unknown>>;
  assertEquals(Object.keys(PRODUCTS).sort(), content.map((p) => p.id as string).sort());
  for (const p of content) {
    const server = PRODUCTS[p.id as string];
    assertEquals(server.consumable, p.type === 'consumable', `${p.id} type`);
    assertEquals(server.pearls ?? 0, (p.pearls as number) ?? 0, `${p.id} pearls`);
    assertEquals(server.manna ?? 0, (p.manna as number) ?? 0, `${p.id} manna`);
    assertEquals(server.generator_level, p.generator_level, `${p.id} generator_level`);
  }
});
