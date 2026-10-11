// The board screen's part in timed offers (EXPANSION section 21): asking
// which one fits the moment, showing it, and noting how it ended.
part of 'board_screen.dart';

mixin _BoardOffers on _BoardWheel {
  /// The store's prices for the offer products, read once a session.
  Future<Map<String, String>>? _offerPrices;

  /// Starts offers for [session]: none where there is no shop or no source
  /// of offers (tests), and none in a game played from memory only.
  void _wireOffers(BoardSession session) {
    final source = widget.offers;
    final shop = widget.shop;
    _offers = null;
    _offerPrices = null;
    if (source == null || shop == null || session.downgraded) return;
    final offersJson = session.contentBundle.files['offers'];
    _offers = OffersController(
      source: source,
      rules: OfferRules.fromJson(switch (offersJson) {
        {'rules': final Object rules} => rules,
        _ => null,
      }),
      extras: session.extras,
      note: (offer, outcome) => unawaited(
        shop.backend.noteOffer(
          offerId: offer.id,
          productId: offer.productId,
          outcome: outcome,
        ),
      ),
    );
  }

  /// Reads the offers, then shows the one for opening the game, if any
  /// fits and nothing else is on the screen.
  Future<void> _offerAtStart() async {
    final offers = _offers;
    if (offers == null) return;
    await offers.load();
    if (!identical(offers, _offers) || _busy || _eventOpen || !mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    await _maybeOffer(OfferTrigger.sessionStart);
  }

  /// What [offer] gives, one line each, in the game's own words.
  List<OfferGift> _giftsOf(Offer offer, BoardSession session) {
    final text = _offersText(session);
    String say(String key, int n) => (text[key] ?? '').replaceAll('{n}', '$n');
    final gives = offer.contents;
    return [
      if (gives.pearls > 0)
        OfferGift(
          words: say('offer_pearls', gives.pearls),
          icon: Icons.circle,
          color: GamePalette.pearls,
        ),
      if (gives.manna > 0)
        OfferGift(
          words: say('offer_manna', gives.manna),
          icon: Icons.bolt,
          color: GamePalette.manna,
        ),
      if (gives.talents > 0)
        OfferGift(
          words: say('offer_talents', gives.talents),
          icon: Icons.paid,
          color: GamePalette.talents,
        ),
      for (final id in gives.items)
        if (session.game.itemCatalog[id] case final ItemModel item)
          OfferGift(
            words: item.name,
            icon: Icons.card_giftcard,
            color: GamePalette.gold,
            asset: item.asset.isEmpty ? null : item.asset,
          ),
    ];
  }

  /// Shows the offer for [trigger], if one fits this player and the rules
  /// allow another now. Never in the tutorial (no purchase is ever offered
  /// in it), never over another pop-up, and only to a signed-in player
  /// (a purchase belongs to an account).
  Future<void> _maybeOffer(OfferTrigger trigger) async {
    final session = _session;
    final offers = _offers;
    final shop = widget.shop;
    if (session == null || offers == null || shop == null) return;
    if (!session.tutorial.isOver || _popupOpen || _syncing || !mounted) return;
    if (!shop.backend.signedIn) return;
    final offer = offers.next(
      trigger,
      level: session.levels.level,
      hasPaid: session.purchases.appliedTransactions.isNotEmpty,
    );
    if (offer == null) return;
    // Something else may open while the store is being asked its price.
    _popupOpen = true;
    try {
      final prices = await (_offerPrices ??= shop
          .loadProducts(offers: true)
          .then((list) => {for (final p in list) p.id: p.price}));
      final price = prices[offer.productId];
      final gifts = _giftsOf(offer, session);
      // Only what the store really sells, and only if every gift is known.
      final known =
          gifts.length ==
          offer.contents.items.length +
              (offer.contents.pearls > 0 ? 1 : 0) +
              (offer.contents.manna > 0 ? 1 : 0) +
              (offer.contents.talents > 0 ? 1 : 0);
      if (price == null || !known || !mounted) return;
      if (!identical(session, _session) || !identical(offers, _offers)) return;
      final endsAt = offers.shown(offer, trigger);
      final bought = await showOfferPopup(
        context,
        offer: offer,
        price: price,
        endsAt: endsAt,
        shop: shop,
        text: _offersText(session),
        picture: switch (session.contentBundle.files['offers']) {
          {'special': {'picture': final String picture}} => picture,
          _ => '',
        },
        gifts: gifts,
        onBuy: _events?.purchaseStarted,
      );
      if (!bought && identical(offers, _offers)) offers.declined(offer);
    } finally {
      _popupOpen = false;
    }
  }
}
