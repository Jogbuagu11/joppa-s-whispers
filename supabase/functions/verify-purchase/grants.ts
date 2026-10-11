// Works out what a confirmed purchase gives, reading what it needs from the
// database. The decisions themselves are in offer_rules.ts (tested).
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  chooseOffer,
  contentsToGrant,
  type Grant,
  grantForProduct,
  type OfferRow,
} from './offer_rules.ts';
import { PRODUCTS } from './rules.ts';

// deno-lint-ignore no-explicit-any
type Db = SupabaseClient<any, any, any>;

/** What an ordinary shop product gives this player (see grantForProduct). */
export async function productGrant(
  supabase: Db,
  userId: string,
  product: (typeof PRODUCTS)[string],
): Promise<Grant> {
  const { count, error } = await supabase
    .from('purchases')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId);
  if (error) throw error;
  return grantForProduct(product, { firstPurchase: (count ?? 0) === 0 });
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
    .select('id, product_id, contents, is_active, is_fallback, starts_at, ends_at')
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
  });
  if (!offer) throw new Error(`No offer or fallback for ${productId}`);
  return { grant: contentsToGrant(offer.contents), offerId: offer.id };
}
