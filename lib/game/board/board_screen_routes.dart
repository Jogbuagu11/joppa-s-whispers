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

  /// The event that is on now, if any.
  EventModel? _event;

  /// True while the event board is open over this one.
  bool _eventOpen = false;

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
          ),
        ),
      );
    } finally {
      _busy = false;
    }
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
