// What a purchase gives, decided on the server and kept free of network and
// database calls so it can be tested (see offer_rules_test.ts).
import type { ProductGrant } from './rules.ts';

/** Exactly what one purchase gives. Written onto the purchase record. */
export interface Grant {
  pearls: number;
  manna: number;
  talents: number;
  items: string[];
  generator_level?: number;
}

/** A row of the `offers` table, as far as these rules need it. */
export interface OfferRow {
  id: string;
  product_id: string;
  contents: unknown;
  is_active: boolean;
  is_fallback: boolean;
  starts_at?: string | null;
  ends_at?: string | null;
  /** 'any', 'non_payer' or 'payer'. */
  audience?: string | null;
  /** When the row was last changed (set by the database). */
  updated_at?: string | null;
}

/** The reusable store products whose contents the `offers` table sets. */
export const OFFER_PRODUCTS = [
  'offer_099',
  'offer_199',
  'offer_299',
  'offer_499',
  'offer_999',
  'offer_1999',
  'offer_4999',
];

export const isOfferProduct = (productId: unknown): productId is string =>
  typeof productId === 'string' && OFFER_PRODUCTS.includes(productId);

// A purchase may reach the server after its offer has ended or been switched
// off (the app was closed mid-payment, the phone was offline, or the player
// was still looking at it). The player still paid for what they were shown,
// for this long afterwards.
export const OFFER_GRACE_MS = 7 * 24 * 60 * 60 * 1000;

// No single purchase gives more than this, whatever a row says: a slip of
// the finger in the admin panel must not hand out a fortune.
const MOST = { pearls: 20000, manna: 5000, talents: 100000, items: 20 };

const amount = (value: unknown, most: number): number =>
  typeof value === 'number' && Number.isInteger(value) && value > 0
    ? Math.min(value, most)
    : 0;

/** A row's contents as a grant: whole, non-negative, capped amounts only. */
export function contentsToGrant(contents: unknown): Grant {
  const c = contents && typeof contents === 'object'
    ? contents as Record<string, unknown>
    : {};
  const items = Array.isArray(c.items)
    ? c.items.filter((id): id is string =>
      typeof id === 'string' && /^[a-z][a-z0-9_]{0,40}$/.test(id)
    ).slice(0, MOST.items)
    : [];
  return {
    pearls: amount(c.pearls, MOST.pearls),
    manna: amount(c.manna, MOST.manna),
    talents: amount(c.talents, MOST.talents),
    items,
  };
}

export const grantIsEmpty = (g: Grant): boolean =>
  g.pearls === 0 && g.manna === 0 && g.talents === 0 && g.items.length === 0 &&
  g.generator_level == null;

/** Whether [offer] may be paid for at [now] (with the grace after its end). */
export function offerCanBePaidFor(offer: OfferRow, now: Date): boolean {
  if (offer.is_fallback) return true;
  if (!offer.is_active) {
    // Switched off: still honoured for the grace after that change.
    const changed = offer.updated_at ? Date.parse(offer.updated_at) : NaN;
    if (Number.isNaN(changed) || now.getTime() > changed + OFFER_GRACE_MS) return false;
  }
  const starts = offer.starts_at ? Date.parse(offer.starts_at) : null;
  const ends = offer.ends_at ? Date.parse(offer.ends_at) : null;
  if (starts != null && !Number.isNaN(starts) && now.getTime() < starts) return false;
  if (ends != null && !Number.isNaN(ends) && now.getTime() > ends + OFFER_GRACE_MS) {
    return false;
  }
  return true;
}

/** Whether [offer] is meant for a player who has, or has not, paid before. */
function forAudience(offer: OfferRow, hasPaid: boolean | undefined): boolean {
  if (hasPaid == null || !offer.audience || offer.audience === 'any') return true;
  return (offer.audience === 'payer') === hasPaid;
}

/**
 * Which offer a confirmed payment for [productId] was for.
 *
 * The store only says which price was paid. The app says which offer it
 * showed ([claimedOfferId]); that is believed only if it is a real, current
 * offer AT THAT PRICE and meant for this kind of player ([hasPaid]), so the
 * most a tampered app can do is pick another live offer for its own kind
 * that costs the same. Failing that: the offer this player was
 * last shown at that price, then the price's fallback. Null only if the
 * table has no fallback (a set-up mistake: nothing is granted and the
 * purchase is retried later, never lost).
 */
export function chooseOffer(args: {
  productId: string;
  claimedOfferId?: unknown;
  lastShownOfferId?: unknown;
  offers: OfferRow[];
  now: Date;
  /** Whether this player had bought anything before this purchase. */
  hasPaid?: boolean;
}): OfferRow | null {
  const atPrice = args.offers.filter((o) => o.product_id === args.productId);
  const usable = (id: unknown) =>
    typeof id === 'string'
      ? atPrice.find((o) =>
        o.id === id && !o.is_fallback && offerCanBePaidFor(o, args.now) &&
        forAudience(o, args.hasPaid) &&
        !grantIsEmpty(contentsToGrant(o.contents))
      )
      : undefined;
  return usable(args.claimedOfferId) ?? usable(args.lastShownOfferId) ??
    atPrice.find((o) => o.is_fallback && !grantIsEmpty(contentsToGrant(o.contents))) ??
    null;
}

/**
 * What an ordinary shop product gives. A player's very first purchase of a
 * Pearl pack gives double Pearls (EXPANSION 21.1, first-purchase bonus);
 * the starter pack and the Treasure Jar are bargains of their own and are
 * not doubled.
 */
export function grantForProduct(
  product: ProductGrant,
  opts: { firstPurchase: boolean },
): Grant {
  const pearls = product.pearls ?? 0;
  const doubled = earnsFirstBonus(product, opts.firstPurchase);
  const grant: Grant = {
    pearls: doubled ? pearls * 2 : pearls,
    manna: product.manna ?? 0,
    talents: 0,
    items: [],
  };
  if (product.generator_level != null) grant.generator_level = product.generator_level;
  return grant;
}

/** Whether this purchase is the one that gets the first-purchase bonus. */
export const earnsFirstBonus = (product: ProductGrant, firstPurchase: boolean): boolean =>
  firstPurchase && product.consumable && !product.no_first_bonus &&
  (product.pearls ?? 0) > 0;

/** The Pearls recorded on a purchase's grant, or null if it has none. */
export function recordedPearls(grantContents: unknown): number | null {
  if (!grantContents || typeof grantContents !== 'object') return null;
  const pearls = (grantContents as Record<string, unknown>).pearls;
  return typeof pearls === 'number' && Number.isInteger(pearls) && pearls >= 0
    ? pearls
    : null;
}
