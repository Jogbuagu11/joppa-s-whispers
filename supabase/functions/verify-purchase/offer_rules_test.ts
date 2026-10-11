// Run with: deno test supabase/functions/verify-purchase/offer_rules_test.ts
import { assertEquals } from 'https://deno.land/std@0.177.0/testing/asserts.ts';
import {
  chooseOffer,
  contentsToGrant,
  earnsFirstBonus,
  grantForProduct,
  grantIsEmpty,
  isOfferProduct,
  OFFER_GRACE_MS,
  offerCanBePaidFor,
  type OfferRow,
  recordedPearls,
} from './offer_rules.ts';
import { PRODUCTS } from './rules.ts';

const NOW = new Date('2026-10-12T09:00:00Z');
const offer = (over: Partial<OfferRow> = {}): OfferRow => ({
  id: 'small',
  product_id: 'offer_099',
  contents: { pearls: 40, manna: 50 },
  is_active: true,
  is_fallback: false,
  ...over,
});
const fallback = offer({
  id: 'fallback_099',
  contents: { pearls: 30 },
  is_active: false,
  is_fallback: true,
});

Deno.test('only the seven offer products are offer products', () => {
  assertEquals(isOfferProduct('offer_099'), true);
  assertEquals(isOfferProduct('offer_4999'), true);
  assertEquals(isOfferProduct('pearls_tier1'), false);
  assertEquals(isOfferProduct('offer_123'), false);
  assertEquals(isOfferProduct(null), false);
});

Deno.test('contents become a grant of whole, non-negative amounts', () => {
  assertEquals(
    contentsToGrant({ pearls: 40, manna: 50, talents: 10, items: ['manna_jar_02'] }),
    { pearls: 40, manna: 50, talents: 10, items: ['manna_jar_02'] },
  );
  // Nonsense counts as nothing; nothing is ever negative.
  assertEquals(
    contentsToGrant({ pearls: -5, manna: 1.5, talents: '9', items: 'jar' }),
    { pearls: 0, manna: 0, talents: 0, items: [] },
  );
  assertEquals(grantIsEmpty(contentsToGrant(null)), true);
  assertEquals(grantIsEmpty(contentsToGrant('x')), true);
});

Deno.test('a slip in the table cannot hand out a fortune or odd item ids', () => {
  const grant = contentsToGrant({
    pearls: 99999999,
    manna: 99999999,
    items: ['ok_item', 'Bad Id', 7, '../x', ...Array(50).fill('jar_01')],
  });
  assertEquals(grant.pearls, 20000);
  assertEquals(grant.manna, 5000);
  assertEquals(grant.items.length, 20);
  assertEquals(grant.items.includes('Bad Id'), false);
  assertEquals(grant.items.includes('../x'), false);
});

Deno.test('an offer can be paid for while live, and for a while after it ends', () => {
  assertEquals(offerCanBePaidFor(offer(), NOW), true);
  assertEquals(offerCanBePaidFor(offer({ is_active: false }), NOW), false);
  assertEquals(
    offerCanBePaidFor(offer({ starts_at: '2026-10-13T00:00:00Z' }), NOW),
    false,
  );
  const ended = new Date(NOW.getTime() - 60_000).toISOString();
  assertEquals(offerCanBePaidFor(offer({ ends_at: ended }), NOW), true);
  const longAgo = new Date(NOW.getTime() - OFFER_GRACE_MS - 60_000).toISOString();
  assertEquals(offerCanBePaidFor(offer({ ends_at: longAgo }), NOW), false);
  // The fallback always can.
  assertEquals(offerCanBePaidFor(fallback, NOW), true);
});

Deno.test('the offer the app names is used when it is real and at that price', () => {
  const offers = [offer(), offer({ id: 'other', contents: { pearls: 45 } }), fallback];
  assertEquals(
    chooseOffer({ productId: 'offer_099', claimedOfferId: 'other', offers, now: NOW })?.id,
    'other',
  );
});

Deno.test('an app cannot claim a dearer offer for a cheaper payment', () => {
  const rich = offer({ id: 'rich', product_id: 'offer_4999', contents: { pearls: 2500 } });
  const offers = [offer(), rich, fallback];
  // Paid $0.99, claims the $49.99 offer: that claim is ignored.
  const chosen = chooseOffer({
    productId: 'offer_099',
    claimedOfferId: 'rich',
    lastShownOfferId: 'small',
    offers,
    now: NOW,
  });
  assertEquals(chosen?.id, 'small');
});

Deno.test('without a usable claim: the offer last shown, then the fallback', () => {
  const offers = [offer(), fallback];
  assertEquals(
    chooseOffer({ productId: 'offer_099', lastShownOfferId: 'small', offers, now: NOW })?.id,
    'small',
  );
  assertEquals(
    chooseOffer({ productId: 'offer_099', claimedOfferId: 'gone', offers, now: NOW })?.id,
    'fallback_099',
  );
  // A switched-off or empty offer is never chosen.
  const off = [offer({ is_active: false }), fallback];
  assertEquals(
    chooseOffer({ productId: 'offer_099', claimedOfferId: 'small', offers: off, now: NOW })?.id,
    'fallback_099',
  );
  const empty = [offer({ contents: {} }), fallback];
  assertEquals(
    chooseOffer({ productId: 'offer_099', claimedOfferId: 'small', offers: empty, now: NOW })
      ?.id,
    'fallback_099',
  );
});

Deno.test('a fallback row cannot be claimed by name, and none means nothing', () => {
  assertEquals(
    chooseOffer({
      productId: 'offer_099',
      claimedOfferId: 'fallback_099',
      offers: [fallback],
      now: NOW,
    })?.id,
    'fallback_099',
  );
  assertEquals(
    chooseOffer({ productId: 'offer_099', claimedOfferId: 'small', offers: [], now: NOW }),
    null,
  );
  // A fallback for another price is no use.
  assertEquals(
    chooseOffer({ productId: 'offer_199', offers: [fallback], now: NOW }),
    null,
  );
});

Deno.test('a first Pearl pack gives double Pearls; the starter pack does not', () => {
  assertEquals(
    grantForProduct(PRODUCTS.pearls_tier1, { firstPurchase: true }),
    { pearls: 50, manna: 0, talents: 0, items: [] },
  );
  assertEquals(
    grantForProduct(PRODUCTS.pearls_tier1, { firstPurchase: false }),
    { pearls: 25, manna: 0, talents: 0, items: [] },
  );
  assertEquals(
    grantForProduct(PRODUCTS.starter_pack, { firstPurchase: true }),
    { pearls: 100, manna: 100, talents: 0, items: [], generator_level: 2 },
  );
});

Deno.test('the Pearls recorded on a purchase are read back, or null', () => {
  assertEquals(recordedPearls({ pearls: 50 }), 50);
  assertEquals(recordedPearls({ pearls: 0 }), 0);
  assertEquals(recordedPearls(null), null);
  assertEquals(recordedPearls({ pearls: '50' }), null);
  assertEquals(recordedPearls({}), null);
});

Deno.test('an offer switched off is still honoured for a while, then not', () => {
  const justNow = new Date(NOW.getTime() - 60_000).toISOString();
  const longAgo = new Date(NOW.getTime() - OFFER_GRACE_MS - 60_000).toISOString();
  assertEquals(
    offerCanBePaidFor(offer({ is_active: false, updated_at: justNow }), NOW),
    true,
  );
  assertEquals(
    offerCanBePaidFor(offer({ is_active: false, updated_at: longAgo }), NOW),
    false,
  );
  const offers = [offer({ is_active: false, updated_at: justNow }), fallback];
  assertEquals(
    chooseOffer({ productId: 'offer_099', claimedOfferId: 'small', offers, now: NOW })?.id,
    'small',
  );
});

Deno.test('an offer for one kind of player cannot be claimed by the other', () => {
  const offers = [
    offer({ id: 'new_friends', audience: 'non_payer' }),
    offer({ id: 'regulars', audience: 'payer' }),
    offer({ id: 'everyone', audience: 'any' }),
    fallback,
  ];
  const pick = (claimedOfferId: string, hasPaid: boolean) =>
    chooseOffer({ productId: 'offer_099', claimedOfferId, offers, now: NOW, hasPaid })?.id;
  assertEquals(pick('new_friends', false), 'new_friends');
  assertEquals(pick('new_friends', true), 'fallback_099');
  assertEquals(pick('regulars', true), 'regulars');
  assertEquals(pick('regulars', false), 'fallback_099');
  assertEquals(pick('everyone', true), 'everyone');
});

Deno.test('only a first Pearl pack earns the first-purchase bonus', () => {
  assertEquals(earnsFirstBonus(PRODUCTS.pearls_tier1, true), true);
  assertEquals(earnsFirstBonus(PRODUCTS.pearls_tier1, false), false);
  assertEquals(earnsFirstBonus(PRODUCTS.starter_pack, true), false);
});

Deno.test('opening a Treasure Jar gives what it holds, never doubled', () => {
  assertEquals(earnsFirstBonus(PRODUCTS.treasure_jar_small, true), false);
  assertEquals(
    grantForProduct(PRODUCTS.treasure_jar_small, { firstPurchase: true }),
    { pearls: 150, manna: 0, talents: 0, items: [] },
  );
  assertEquals(
    grantForProduct(PRODUCTS.treasure_jar_large, { firstPurchase: false }).pearls,
    560,
  );
  assertEquals(isOfferProduct('treasure_jar_small'), false);
});
