// The season pass, as far as a purchase goes: which event a pass that was
// paid for belongs to. Free of network and database calls so it can be
// tested (see pass_rules_test.ts).

/** The store products that are a pass, and the tier each one is. */
export const PASS_PRODUCTS: Record<string, 'premium' | 'plus'> = {
  pass_premium: 'premium',
  pass_premium_plus: 'plus',
};

export const isPassProduct = (productId: unknown): productId is string =>
  typeof productId === 'string' && Object.hasOwn(PASS_PRODUCTS, productId);

/** A row of the `events` table, as far as these rules need it. */
export interface EventRow {
  id: string;
  starts_at: string;
  ends_at: string;
  is_active: boolean;
}

/** What a pass purchase records: its tier, and the event it is for. */
export interface PassGrant {
  tier: 'premium' | 'plus';
  event_id: string;
}

const isLive = (e: EventRow, now: number) =>
  e.is_active && Date.parse(e.starts_at) <= now && now < Date.parse(e.ends_at);

/**
 * Which event a confirmed pass payment is for.
 *
 * The app says which event's pass it showed ([claimedEventId]); that is
 * used if that event is on now. A payment that arrives after its event has
 * ended (the phone was offline, the app was closed mid-payment) would be
 * worth nothing there, so it goes to an event the player can still play:
 * the one on now that ends last, or else the next one to start. Only with
 * no such event does it stay with the event it was bought for (or the most
 * recent one). Null only if there are no events at all: nothing is
 * recorded and the purchase is retried later, never lost.
 */
export function choosePassEvent(args: {
  claimedEventId?: unknown;
  events: EventRow[];
  now: Date;
}): EventRow | null {
  const now = args.now.getTime();
  const sound = args.events.filter((e) =>
    !Number.isNaN(Date.parse(e.starts_at)) && !Number.isNaN(Date.parse(e.ends_at))
  );
  const claimed = typeof args.claimedEventId === 'string'
    ? sound.find((e) => e.id === args.claimedEventId)
    : undefined;
  if (claimed && isLive(claimed, now)) return claimed;
  const byEnd = (a: EventRow, b: EventRow) => Date.parse(b.ends_at) - Date.parse(a.ends_at);
  const live = sound.filter((e) => isLive(e, now)).sort(byEnd);
  if (live.length > 0) return live[0];
  const coming = sound
    .filter((e) => e.is_active && Date.parse(e.starts_at) > now)
    .sort((a, b) => Date.parse(a.starts_at) - Date.parse(b.starts_at));
  if (coming.length > 0) return coming[0];
  return claimed ?? [...sound].sort(byEnd)[0] ?? null;
}

/** What a pass purchase records for [productId] and [event]. */
export const passGrantFor = (productId: string, event: EventRow): PassGrant => ({
  tier: PASS_PRODUCTS[productId],
  event_id: event.id,
});
