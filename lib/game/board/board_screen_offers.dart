// The board screen's part in timed offers (EXPANSION section 21): asking
// which one fits the moment, showing it, and noting how it ended.
part of 'board_screen.dart';

const _newSessionAfter = Duration(minutes: 30);

mixin _BoardOffers on _BoardWheel {
  void _wireTreasure(BoardSession session);

  /// The store's prices for the offer products, read once a session.
  Future<Map<String, String>>? _offerPrices;

  /// True while an offer is being got ready or is on the screen.
  bool _offering = false;

  /// When the game was last put in the background.
  DateTime? _leftAt;

  /// Coming back after a good while away counts as opening the game again:
  /// a new session, with a greeting offer of its own.
  void _offersOnLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _leftAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left == null || DateTime.now().difference(left) < _newSessionAfter) {
        return;
      }
      _offers?.newSession();
      unawaited(_greetAfterReturn());
    }
  }

  /// The greeting offer for a player who has come back, once the check of
  /// their account (which starts at the same moment) is out of the way.
  Future<void> _greetAfterReturn() async {
    for (int i = 0; i < 20 && _syncing && mounted; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    await _maybeOffer(OfferTrigger.sessionStart);
  }

  /// Starts offers for [session]: none where there is no shop or no source
  /// of offers (tests), and none in a game played from memory only.
  void _wireOffers(BoardSession session) {
    // The Treasure Jar is started with them (see the treasure part).
    _wireTreasure(session);
    final source = widget.offers;
    final shop = widget.shop;
    final before = _offers;
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
      // The same run of the app: the session's count of offers goes on.
      carryOn: before,
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
    if (!identical(offers, _offers)) return;
    await _maybeOffer(OfferTrigger.sessionStart);
  }

  /// After a story task: one offer at most, for the chapter it finished
  /// or, failing that, the level it reached.
  Future<void> _offerAfterTask({
    required bool ended,
    required int fromLevel,
  }) async {
    final level = _session?.levels.level ?? fromLevel;
    if (ended &&
        await _maybeOffer(OfferTrigger.chapterComplete, inTask: true)) {
      return;
    }
    if (level > fromLevel) {
      await _maybeOffer(
        OfferTrigger.levelUp,
        inTask: true,
        fromLevel: fromLevel,
      );
    }
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
          amount: '${gives.pearls}',
          icon: Icons.circle,
          color: GamePalette.offerPearls,
        ),
      if (gives.manna > 0)
        OfferGift(
          words: say('offer_manna', gives.manna),
          amount: '${gives.manna}',
          icon: Icons.bolt,
          color: GamePalette.manna,
        ),
      if (gives.talents > 0)
        OfferGift(
          words: say('offer_talents', gives.talents),
          amount: '${gives.talents}',
          icon: Icons.paid,
          color: GamePalette.talents,
        ),
      for (final id in gives.items)
        if (session.game.itemCatalog[id] case final ItemModel item)
          OfferGift(
            words: item.name,
            icon: Icons.card_giftcard,
            color: GamePalette.offerItem,
            asset: item.asset.isEmpty ? null : item.asset,
          ),
    ];
  }

  /// Whether an offer may open at this very moment: the board itself is
  /// showing, with nothing over it and nothing being done on it. [inTask]
  /// is for the offers that close a story task (which is busy on purpose).
  bool _quietForOffer(BoardSession session, {required bool inTask}) =>
      mounted &&
      identical(session, _session) &&
      session.tutorial.isOver &&
      !_popupOpen &&
      !_syncing &&
      !_eventOpen &&
      (inTask || !_busy) &&
      !session.game.isDragging &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  /// The store's prices for the products that carry only a price (offers,
  /// the Treasure Jar), read once a session (once the store answers).
  Future<Map<String, String>> _reusablePrices(PurchaseCoordinator shop) =>
      _offerPrices ??= shop.loadProducts(offers: true).then((list) {
        // A store that could not be reached is asked again next time.
        if (list.isEmpty) _offerPrices = null;
        return {for (final p in list) p.id: p.price};
      });

  /// Shows the offer for [trigger], if one fits this player and the rules
  /// allow another now. Never in the tutorial (no purchase is ever offered
  /// in it), never over a story scene, another screen or pop-up, or an item
  /// being moved, and only to a signed-in player (a purchase belongs to an
  /// account). Returns whether one was shown.
  Future<bool> _maybeOffer(
    OfferTrigger trigger, {
    bool inTask = false,
    int? fromLevel,
  }) async {
    final session = _session;
    final offers = _offers;
    final shop = widget.shop;
    if (session == null || offers == null || shop == null) return false;
    if (_offering || !shop.backend.signedIn) return false;
    if (!_quietForOffer(session, inTask: inTask)) return false;
    _offering = true;
    try {
      // The server's present offers and the store's prices, before deciding.
      await offers.refreshIfStale();
      final prices = await _reusablePrices(shop);
      // Things may have changed while those were being read.
      if (!identical(offers, _offers)) return false;
      if (!_quietForOffer(session, inTask: inTask)) return false;
      final offer = offers.next(
        trigger,
        level: session.levels.level,
        hasPaid: session.purchases.appliedTransactions.isNotEmpty,
        fromLevel: fromLevel,
      );
      if (offer == null) return false;
      final price = prices[offer.productId];
      final gifts = _giftsOf(offer, session);
      // Only what the store really sells, and only if every gift is known.
      final gives = offer.contents;
      final known =
          gifts.length ==
          gives.items.length +
              (gives.pearls > 0 ? 1 : 0) +
              (gives.manna > 0 ? 1 : 0) +
              (gives.talents > 0 ? 1 : 0);
      if (price == null || !known || !mounted) return false;
      final endsAt = offers.shown(offer, trigger);
      final had = session.purchases.appliedTransactions.length;
      _popupOpen = true;
      final asked = await showOfferPopup(
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
      _popupOpen = false;
      if (!identical(offers, _offers)) return true;
      if (session.purchases.appliedTransactions.length > had) {
        offers.bought(offer);
      } else if (!asked) {
        // (Asked for but not yet delivered is neither bought nor refused.)
        offers.declined(offer);
      }
      return true;
    } finally {
      _offering = false;
    }
  }
}
