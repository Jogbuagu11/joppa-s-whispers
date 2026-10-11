// The board screen's shared state, and the screens opened from the board:
// the location, Esther's letters and the Pearl shop.
part of 'board_screen.dart';

/// The state every part of the board screen works with.
mixin _BoardState on State<BoardScreen> {
  BoardSession? _session;
  bool _popupOpen = false;
  bool _busy = false;
  bool _syncing = false;
  AppLifecycleListener? _lifecycle;
  String? _error;

  /// Reports what happens in the game; null where analytics is not set up.
  GameAnalytics? _events;

  /// The bubbles afloat over the board; null until a game is loaded.
  BubbleController? _bubbles;

  /// The event that is on now, if any.
  EventModel? _event;

  /// True while the event board is open over this one.
  bool _eventOpen = false;

  /// Fires when the row above the board is slid.
  final ValueNotifier<int> _stripMoved = ValueNotifier<int>(0);

  /// Marks the board, so the picture above it knows where to stop.
  final GlobalKey _boardKey = GlobalKey();

  /// Stops this game's sounds and vibrations; null when there are none.
  VoidCallback? _quiet;
}

mixin _BoardRoutes on _BoardState {
  /// The location button: shows the current chapter's location.
  Future<void> _openLocation() async {
    if (_busy) return;
    _busy = true;
    try {
      await _showLocation(_session?.story.chapter?.locationId);
    } finally {
      _busy = false;
    }
  }

  /// The Pearls count: opens the Pearl shop.
  Future<void> _openShop() async {
    final session = _session;
    final shop = widget.shop;
    if (session == null || shop == null || _busy || !mounted) return;
    _busy = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ShopScreen(
            shop: shop,
            purchases: session.purchases,
            onBuy: _events?.purchaseStarted,
            top: _dailyDeals(session),
            text: _offersText(session),
          ),
        ),
      );
    } finally {
      _busy = false;
    }
  }

  /// The wording of the shop and its deals, from the content being played.
  Map<String, String> _offersText(BoardSession session) => {
    if (session.contentBundle.files['offers'] case {
      'text': final Map<String, dynamic> text,
    })
      for (final e in text.entries)
        if (e.value case final String words) e.key: words,
  };

  /// Today's deals, for the top of the shop; nothing if this content has
  /// none, or in a game played from memory only (older content).
  Widget? _dailyDeals(BoardSession session) {
    final offers = session.contentBundle.files['offers'];
    if (offers is! Map<String, dynamic> || session.downgraded) return null;
    final deals = offers['daily_deals'];
    if (deals is! Map<String, dynamic>) return null;
    return DailyDeals(
      config: DealsConfig.fromJson(deals),
      extras: session.extras,
      text: _offersText(session),
      pearls: session.purchases.pearlsListenable,
      spendPearls: session.purchases.spendPearls,
      give: (deal) {
        if (deal.manna > 0) session.manna.add(deal.manna);
        if (deal.talents > 0) session.orders.addTalents(deal.talents);
        session.grants.give(itemIds: deal.items);
        widget.comfort?.cue(GameCue.reward);
      },
    );
  }

  /// Connects the shop to this game and delivers anything already paid for
  /// but not yet in it (an interrupted purchase, or a new phone).
  void _attachShop(BoardSession session) {
    final shop = widget.shop;
    if (shop == null) return;
    shop
      ..products = session.purchases.products
      ..target = PurchaseTarget(
        applyConfirmed:
            _events?.reportingPurchases(session.purchases) ??
            session.purchases.applyConfirmed,
        hasApplied: session.purchases.hasApplied,
        applyRefunds: session.purchases.applyRefunds,
        saveNow: session.saver.saveNow,
      )
      ..start();
    unawaited(shop.resume());
  }

  /// Sounds and vibrations for this game, and its tier numbers.
  void _attachComfort(BoardSession session) {
    final comfort = widget.comfort;
    if (comfort == null) return;
    _quiet?.call();
    _quiet = attachFeedback(
      comfort,
      session.game,
      orders: session.orders,
      story: session.story,
      rewards: session.ads.tallyChanged,
    );
    unawaited(comfort.load());
  }

  /// The letters button: opens the keepsake book.
  Future<void> _openLetters() async {
    final session = _session;
    if (session == null || _busy || !mounted) return;
    _busy = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LettersScreen(
            letters: session.letters,
            foundLetterIds: session.story.foundLetterIds,
            onOpened: _events?.letterOpened,
          ),
        ),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _showLocation(String? locationId, {String? justRestored}) async {
    final session = _session;
    final location = session?.locations[locationId];
    if (session == null || location == null) {
      _log.warning('No location to show for "$locationId"');
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocationScreen(
          location: location,
          restoredAreaIds: session.story.restoredAreaIds,
          availableAssets: session.assetPaths,
          justRestoredAreaId: justRestored,
        ),
      ),
    );
  }
}
