// The decisions the refund notification functions make, kept free of
// network and database calls so they can be tested (refund_rules_test.ts).
import { decodeJwsPayload, PRODUCTS } from '../verify-purchase/rules.ts';

/**
 * The transaction id an App Store Server Notification (V2) says was refunded
 * or revoked, or null for any other notification. The notification is only a
 * hint: the caller must confirm the refund with Apple before acting.
 */
export function appleRefundCandidate(body: unknown): string | null {
  if (!body || typeof body !== 'object') return null;
  const payload = decodeJwsPayload((body as Record<string, unknown>).signedPayload);
  if (!payload) return null;
  if (payload.notificationType !== 'REFUND' && payload.notificationType !== 'REVOKE') {
    return null;
  }
  const data = payload.data;
  if (!data || typeof data !== 'object') return null;
  const tx = decodeJwsPayload((data as Record<string, unknown>).signedTransactionInfo);
  const id = tx?.transactionId;
  if (typeof id === 'string' && id.length > 0) return id;
  return typeof id === 'number' ? String(id) : null;
}

/** Whether Apple itself reports this transaction of our app as taken back. */
export function isAppleRevoked(
  tx: Record<string, unknown> | null,
  claim: { bundleId: string; transactionId: string },
): boolean {
  if (!tx) return false;
  if (tx.bundleId !== claim.bundleId) return false;
  if (String(tx.transactionId) !== claim.transactionId) return false;
  return tx.revocationDate != null;
}

/**
 * Whether an HTTP status from Apple's Get Transaction Info means "no such
 * transaction here" (so the other environment, or nothing, has it). Any
 * other failure means Apple could not answer and must be asked again.
 */
export function isAppleNotFound(status: number): boolean {
  return status === 404;
}

/**
 * What a Google Pub/Sub push is about: 'voided' when a purchase of our app
 * was refunded or charged back, otherwise 'other'. Like Apple's, it is only
 * a hint to go and ask Google.
 */
export function googleNotificationKind(
  body: unknown,
  packageName: string,
): 'voided' | 'other' {
  try {
    const data = (body as { message?: { data?: unknown } })?.message?.data;
    if (typeof data !== 'string') return 'other';
    const note = JSON.parse(atob(data)) as Record<string, unknown>;
    if (note.packageName !== packageName) return 'other';
    return note.voidedPurchaseNotification ? 'voided' : 'other';
  } catch {
    return 'other';
  }
}

/** The order ids in one page of Google's Voided Purchases list. */
export function voidedOrderIds(reply: unknown): string[] {
  const list = (reply as { voidedPurchases?: unknown })?.voidedPurchases;
  if (!Array.isArray(list)) return [];
  const ids = new Set<string>();
  for (const entry of list) {
    const id = (entry as { orderId?: unknown })?.orderId;
    if (typeof id === 'string' && id.length > 0) ids.add(id);
  }
  return [...ids];
}

/** The Pearls a refund of [productId] takes back (0 for unknown products). */
export function refundPearls(productId: string): number {
  return PRODUCTS[productId]?.pearls ?? 0;
}

/** Compares two secrets without stopping at the first difference. */
export function sameSecret(given: string | null, expected: string | undefined): boolean {
  if (!given || !expected || given.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < given.length; i++) {
    diff |= given.charCodeAt(i) ^ expected.charCodeAt(i);
  }
  return diff === 0;
}
