// Run with: deno test supabase/functions/_shared/refund_rules_test.ts
import { assertEquals } from 'https://deno.land/std@0.177.0/testing/asserts.ts';
import { b64url } from '../verify-purchase/rules.ts';
import {
  appleRefundCandidate,
  googleNotificationKind,
  isAppleNotFound,
  isAppleRevoked,
  refundPearls,
  sameSecret,
  voidedOrderIds,
} from './refund_rules.ts';

const BUNDLE = 'com.whispersofjoppa.game';
const jws = (payload: unknown) => `${b64url('{}')}.${b64url(JSON.stringify(payload))}.sig`;
const appleNote = (type: string, tx: unknown = { transactionId: '2000000123' }) => ({
  signedPayload: jws({ notificationType: type, data: { signedTransactionInfo: jws(tx) } }),
});
const pubsub = (note: unknown) => ({ message: { data: btoa(JSON.stringify(note)) } });

Deno.test('Apple: a refund notification names its transaction', () => {
  assertEquals(appleRefundCandidate(appleNote('REFUND')), '2000000123');
  assertEquals(appleRefundCandidate(appleNote('REVOKE')), '2000000123');
});

Deno.test('Apple: other notifications and junk name nothing', () => {
  assertEquals(appleRefundCandidate(appleNote('TEST')), null);
  assertEquals(appleRefundCandidate(appleNote('CONSUMPTION_REQUEST')), null);
  assertEquals(appleRefundCandidate(appleNote('REFUND', {})), null);
  assertEquals(appleRefundCandidate({ signedPayload: 'not-a-jws' }), null);
  assertEquals(appleRefundCandidate({}), null);
  assertEquals(appleRefundCandidate(null), null);
  assertEquals(appleRefundCandidate('REFUND'), null);
});

Deno.test('Apple: only a transaction Apple reports revoked counts', () => {
  const claim = { bundleId: BUNDLE, transactionId: '2000000123' };
  const tx = { bundleId: BUNDLE, transactionId: '2000000123', revocationDate: 1760000000000 };
  assertEquals(isAppleRevoked(tx, claim), true);
  // A forged notification about a purchase that still stands changes nothing.
  assertEquals(isAppleRevoked({ ...tx, revocationDate: undefined }, claim), false);
  assertEquals(isAppleRevoked({ ...tx, bundleId: 'com.other.app' }, claim), false);
  assertEquals(isAppleRevoked({ ...tx, transactionId: '999' }, claim), false);
  assertEquals(isAppleRevoked(null, claim), false);
});

Deno.test('Google: a voided-purchase notification for our app is recognised', () => {
  const note = { packageName: BUNDLE, voidedPurchaseNotification: { orderId: 'GPA.1' } };
  assertEquals(googleNotificationKind(pubsub(note), BUNDLE), 'voided');
});

Deno.test('Google: other apps, other notifications and junk are not', () => {
  const voided = { voidedPurchaseNotification: { orderId: 'GPA.1' } };
  assertEquals(googleNotificationKind(pubsub({ packageName: 'com.other', ...voided }), BUNDLE), 'other');
  assertEquals(
    googleNotificationKind(
      pubsub({ packageName: BUNDLE, oneTimeProductNotification: { notificationType: 1 } }),
      BUNDLE,
    ),
    'other',
  );
  assertEquals(googleNotificationKind(pubsub({ packageName: BUNDLE, testNotification: {} }), BUNDLE), 'other');
  assertEquals(googleNotificationKind({ message: { data: '%%%' } }, BUNDLE), 'other');
  assertEquals(googleNotificationKind({}, BUNDLE), 'other');
  assertEquals(googleNotificationKind(null, BUNDLE), 'other');
});

Deno.test('Google: order ids are read from the voided list, each once', () => {
  assertEquals(
    voidedOrderIds({
      voidedPurchases: [
        { orderId: 'GPA.1', purchaseToken: 'a' },
        { orderId: 'GPA.2' },
        { orderId: 'GPA.1' },
        { purchaseToken: 'no-order' },
        { orderId: '' },
      ],
    }),
    ['GPA.1', 'GPA.2'],
  );
  assertEquals(voidedOrderIds({}), []);
  assertEquals(voidedOrderIds(null), []);
});

Deno.test('a refund takes back the Pearls the product gave', () => {
  assertEquals(refundPearls('pearls_tier1'), 25);
  assertEquals(refundPearls('pearls_tier6'), 3750);
  assertEquals(refundPearls('starter_pack'), 100);
  assertEquals(refundPearls('mystery_box'), 0);
});

Deno.test('the shared secret must match exactly and must be set', () => {
  assertEquals(sameSecret('abc123', 'abc123'), true);
  assertEquals(sameSecret('abc124', 'abc123'), false);
  assertEquals(sameSecret('abc', 'abc123'), false);
  assertEquals(sameSecret(null, 'abc123'), false);
  assertEquals(sameSecret('', ''), false);
  assertEquals(sameSecret('abc123', undefined), false);
});

Deno.test('Apple: only "not found" counts as an answer; outages do not', () => {
  assertEquals(isAppleNotFound(404), true);
  for (const status of [401, 403, 429, 500, 503]) {
    assertEquals(isAppleNotFound(status), false);
  }
});
