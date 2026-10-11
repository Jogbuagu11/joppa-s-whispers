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
  /** The event's settings; it has a pass if `config.pass.premium` lists rewards. */
  config?: unknown;
}

/** What a pass purchase records: its tier, and the event it is for. */
export interface PassGrant {
  tier: 'premium' | 'plus';
  event_id: string;
}

const hasPass = (e: EventRow): boolean => {
  const config = e.config as { pass?: { premium?: unknown } } | null | undefined;
  const premium = config?.pass?.premium;
  return Array.isArray(premium) && premium.length > 0;
};

const isLive = (e: EventRow, now: number) =>
  e.is_active && Date.parse(e.starts_at) <= now && now < Date.parse(e.ends_at);

const wellFormed = (id: unknown): id is string =>
  typeof id === 'string' && /^[a-z0-9_]{1,40}$/.test(id);

/**
 * The id of the event a confirmed pass payment is for.
 *
 * The app says which event's pass it showed ([claimedEventId]); if the app
 * was closed mid-payment that is lost, so the event it last noted as shown
 * to this player ([lastShownEventId]) is tried next. Either is used if that
 * event is on now and has a pass.
 *
 * Otherwise the payment must still be worth something: it goes to an event
 * with a pass that the player can still play, the one on now that ends
 * SOONEST (the one the game shows), or else the next to start. With no such
 * event it stays with the event named (even one the table does not hold:
 * the game can play an event from its own files), or the most recent event
 * with a pass. Null only if nothing at all is known: nothing is recorded
 * and the purchase is retried later, never lost.
 */
export function choosePassEvent(args: {
  claimedEventId?: unknown;
  lastShownEventId?: unknown;
  events: EventRow[];
  now: Date;
}): string | null {
  const now = args.now.getTime();
  const withPass = args.events.filter((e) =>
    !Number.isNaN(Date.parse(e.starts_at)) && !Number.isNaN(Date.parse(e.ends_at)) &&
    hasPass(e)
  );
  const named = [args.claimedEventId, args.lastShownEventId].filter(wellFormed);
  for (const id of named) {
    const event = withPass.find((e) => e.id === id);
    if (event && isLive(event, now)) return event.id;
  }
  const live = withPass
    .filter((e) => isLive(e, now))
    .sort((a, b) => Date.parse(a.ends_at) - Date.parse(b.ends_at));
  if (live.length > 0) return live[0].id;
  const coming = withPass
    .filter((e) => e.is_active && Date.parse(e.starts_at) > now)
    .sort((a, b) => Date.parse(a.starts_at) - Date.parse(b.starts_at));
  if (coming.length > 0) return coming[0].id;
  if (named.length > 0) return named[0];
  const latest = [...withPass].sort((a, b) => Date.parse(b.ends_at) - Date.parse(a.ends_at));
  return latest[0]?.id ?? null;
}

/** What a pass purchase records for [productId] and the event [eventId]. */
export const passGrantFor = (productId: string, eventId: string): PassGrant => ({
  tier: PASS_PRODUCTS[productId],
  event_id: eventId,
});
