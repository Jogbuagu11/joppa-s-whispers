// Works out what a confirmed purchase gives, reading what it needs from the
// database. The decisions themselves are in offer_rules.ts (tested).
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  chooseOffer,
  contentsToGrant,
  type Grant,
  earnsFirstBonus,
  grantForProduct,
  type OfferRow,
} from './offer_rules.ts';
import { choosePassEvent, type EventRow, passGrantFor } from './pass_rules.ts';
import { PRODUCTS } from './rules.ts';

// deno-lint-ignore no-explicit-any
type Db = SupabaseClient<any, any, any>;

/** How many purchases (of any kind, standing or refunded) a player has. */
async function purchaseCount(supabase: Db, userId: string): Promise<number> {
  const { count, error } = await supabase
    .from('purchases')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId);
  if (error) throw error;
  return count ?? 0;
}

/**
 * What an ordinary shop product gives this player (see grantForProduct),
 * and whether that includes the once-only first-purchase bonus. With
 * [bonusTaken] the bonus is left out whatever the count says (the database
 * has just refused a second one).
 */
export async function productGrant(
  supabase: Db,
  userId: string,
  product: (typeof PRODUCTS)[string],
  bonusTaken = false,
): Promise<{ grant: Grant; firstBonus: boolean }> {
  const first = !bonusTaken && (await purchaseCount(supabase, userId)) === 0;
  return {
    grant: grantForProduct(product, { firstPurchase: first }),
    firstBonus: earnsFirstBonus(product, first),
  };
}

/**
 * What a payment for an offer product gives (see chooseOffer). Throws if the
 * offers table has nothing for that price: the purchase is then retried
 * later rather than granted wrongly or lost.
 */
export async function offerGrant(
  supabase: Db,
  userId: string,
  productId: string,
  claimedOfferId: unknown,
): Promise<{ grant: Grant; offerId: string }> {
  const { data: offers, error } = await supabase
    .from('offers')
    .select('id, product_id, contents, is_active, is_fallback, starts_at, ends_at, audience, updated_at')
    .eq('product_id', productId);
  if (error) throw error;
  const { data: shown, error: shownError } = await supabase
    .from('offer_impressions')
    .select('offer_id')
    .eq('user_id', userId)
    .eq('product_id', productId)
    .eq('outcome', 'shown')
    .order('created_at', { ascending: false })
    .limit(1);
  if (shownError) throw shownError;
  const offer = chooseOffer({
    productId,
    claimedOfferId,
    lastShownOfferId: shown?.[0]?.offer_id,
    offers: (offers ?? []) as OfferRow[],
    now: new Date(),
    hasPaid: (await purchaseCount(supabase, userId)) > 0,
  });
  if (!offer) throw new Error(`No offer or fallback for ${productId}`);
  return { grant: contentsToGrant(offer.contents), offerId: offer.id };
}

/**
 * What a payment for a season pass records: its tier and the event it is
 * for (see choosePassEvent). The pass itself gives nothing at once; the
 * game pays its rewards as the event is played. Throws if there are no
 * events at all: the purchase is then retried later, never lost.
 */
export async function passGrant(
  supabase: Db,
  productId: string,
  claimedEventId: unknown,
): Promise<{ grant: Grant }> {
  const { data: events, error } = await supabase
    .from('events')
    .select('id, starts_at, ends_at, is_active');
  if (error) throw error;
  const event = choosePassEvent({
    claimedEventId,
    events: (events ?? []) as EventRow[],
    now: new Date(),
  });
  if (!event) throw new Error(`No event for ${productId}`);
  return {
    grant: { pearls: 0, manna: 0, talents: 0, items: [], pass: passGrantFor(productId, event) },
  };
}
