// The decisions verify-purchase makes, kept free of network and database
// calls so they can be tested (see rules_test.ts).

export interface ProductGrant {
  consumable: boolean;
  pearls?: number;
  manna?: number;
  generator_level?: number;
}

// Product catalog — must match content/products.json in the app.
export const PRODUCTS: Record<string, ProductGrant> = {
  pearls_tier1: { consumable: true, pearls: 50 },
  pearls_tier2: { consumable: true, pearls: 270 },
  pearls_tier3: { consumable: true, pearls: 560 },
  pearls_tier4: { consumable: true, pearls: 1200 },
  pearls_tier5: { consumable: true, pearls: 3200 },
  pearls_tier6: { consumable: true, pearls: 7000 },
  starter_pack: { consumable: false, pearls: 100, manna: 100, generator_level: 2 },
};

export type Check =
  | { ok: true; transactionId: string }
  | { ok: false; reason: string };

/** base64url without padding, as JWTs require. */
export function b64url(input: string | Uint8Array): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** The JSON payload of a JWS (header.payload.signature), or null. */
export function decodeJwsPayload(jws: unknown): Record<string, unknown> | null {
  if (typeof jws !== 'string') return null;
  const parts = jws.split('.');
  if (parts.length !== 3) return null;
  try {
    const b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = b64 + '='.repeat((4 - (b64.length % 4)) % 4);
    const bytes = Uint8Array.from(atob(padded), (c) => c.charCodeAt(0));
    const payload = JSON.parse(new TextDecoder().decode(bytes));
    return payload && typeof payload === 'object' ? payload : null;
  } catch {
    return null;
  }
}

const sameId = (a: unknown, b: string) =>
  typeof a === 'string' && a.toLowerCase() === b.toLowerCase();

/**
 * Checks a transaction as Apple reports it (the decoded signedTransactionInfo
 * from Get Transaction Info) against what the app claims.
 */
export function checkAppleTransaction(
  tx: Record<string, unknown> | null,
  claim: { bundleId: string; productId: string; transactionId: string; userId: string },
): Check {
  if (!tx) return { ok: false, reason: 'Apple returned no transaction' };
  if (tx.bundleId !== claim.bundleId) return { ok: false, reason: 'wrong app' };
  if (tx.productId !== claim.productId) return { ok: false, reason: 'wrong product' };
  if (String(tx.transactionId) !== claim.transactionId) {
    return { ok: false, reason: 'wrong transaction' };
  }
  if (tx.revocationDate != null) return { ok: false, reason: 'refunded or revoked' };
  // The app attaches the buyer's account id to every purchase; without it a
  // transaction id could be claimed by whichever account asks first.
  if (!sameId(tx.appAccountToken, claim.userId)) {
    return { ok: false, reason: 'bought by a different account' };
  }
  return { ok: true, transactionId: String(tx.transactionId) };
}

/**
 * Checks a purchase as Google reports it (purchases.products.get) against
 * what the app claims. The transaction id is Google's order id: the app's
 * own claim about the id is never used.
 */
export function checkGooglePurchase(
  purchase: Record<string, unknown> | null,
  claim: { userId: string },
): Check {
  if (!purchase) return { ok: false, reason: 'Google returned no purchase' };
  // purchaseState: 0 purchased, 1 cancelled, 2 pending.
  if (purchase.purchaseState !== 0) return { ok: false, reason: 'not paid' };
  const orderId = purchase.orderId;
  if (typeof orderId !== 'string' || orderId.length === 0) {
    return { ok: false, reason: 'no order id' };
  }
  if (!sameId(purchase.obfuscatedExternalAccountId, claim.userId)) {
    return { ok: false, reason: 'bought by a different account' };
  }
  return { ok: true, transactionId: orderId };
}

/**
 * Decides what to do once the store has confirmed a purchase, given any
 * record already held for that transaction.
 */
export function decideGrant(
  existing: { user_id: string; status: string } | null,
  args: { userId: string; consumable: boolean; consumedAtStore: boolean },
): 'grant' | 'already_granted' | 'reject' {
  if (existing) {
    // Recorded before: fine if it is this player's and still stands.
    return existing.user_id === args.userId && existing.status === 'granted'
      ? 'already_granted'
      : 'reject';
  }
  // A pack that the store says is already used up, with no record here, was
  // never delivered by us: it must not be granted now.
  if (args.consumable && args.consumedAtStore) return 'reject';
  return 'grant';
}
