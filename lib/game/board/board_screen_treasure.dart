// The board screen's part in the Treasure Jar (EXPANSION 13 and 21.1): it
// fills as the player plays, has a button in the row above the board, and
// says so once when it is full.
part of 'board_screen.dart';

mixin _BoardTreasure on _BoardOffers {
  TreasureJarController? _treasure;

  Map<String, dynamic>? _treasureJson(BoardSession session) =>
      switch (session.contentBundle.files['offers']) {
        {'treasure_jar': final Map<String, dynamic> json} => json,
        _ => null,
      };

  Map<String, String> _treasureText(BoardSession session) => {
    if (_treasureJson(session)?['text'] case final Map<String, dynamic> text)
      for (final e in text.entries)
        if (e.value case final String words) e.key: words,
  };

  /// Whether the jar is open to this player: from its level on, after the
  /// tutorial, and not in a game played from memory only.
  bool _treasureOpen(BoardSession session) {
    final unlock = session.levels.config.unlock('treasure_jar');
    return unlock != null &&
        _treasure != null &&
        session.tutorial.isOver &&
        !session.downgraded &&
        session.levels.level >= unlock.level;
  }

  /// Starts the jar for [session], which must be the game in play.
  @override
  void _wireTreasure(BoardSession session) {
    final rules = TreasureJarRules.fromJson(_treasureJson(session));
    final jar = _treasure = rules == null
        ? null
        : TreasureJarController(
            rules: rules,
            extras: session.extras,
            level: session.levels.level,
          );
    // Always listening: a purchase that opened a jar is never left waiting.
    session.purchases.onApplied = (applied) => jar?.purchasesApplied(applied);
    if (jar == null) return;
    final onDelivered = session.orders.onDelivered;
    session.orders.onDelivered = (id) {
      onDelivered?.call(id);
      if (_treasureOpen(session)) jar.orderDelivered();
      unawaited(_tellJarFull(session));
    };
    final onTaskDone = session.story.onTaskDone;
    session.story.onTaskDone = (id) {
      onTaskDone?.call(id);
      if (_treasureOpen(session)) jar.taskDone();
    };
    session.levels.addListener(() {
      if (_treasureOpen(session)) jar.levelIs(session.levels.level);
    });
  }

  /// The jar's round button (gold when the jar is full), or nothing while
  /// the jar is not open to this player.
  @override
  Widget? _treasureButton(BoardSession session) {
    final jar = _treasure;
    if (jar == null || !_treasureOpen(session)) return null;
    return StripButton(
      buttonKey: const Key('treasure_jar_button'),
      icon: Icons.savings,
      tooltip: _treasureText(session)['button'] ?? '',
      onTap: _openTreasure,
      lit: jar.isFull,
    );
  }

  /// Says, once for each jar, that it is full: a moment after the order
  /// that filled it, and only if nothing else is on the screen (the gold
  /// button says so in any case).
  Future<void> _tellJarFull(BoardSession session) async {
    if (_treasure?.newlyFull != true) return;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted || !identical(session, _session)) return;
    if (_treasure?.newlyFull != true) return;
    if (!_quietForOffer(session, inTask: false)) return;
    await _openTreasure();
  }

  Future<void> _openTreasure() async {
    final session = _session;
    final jar = _treasure;
    if (session == null || jar == null || !_treasureOpen(session)) return;
    if (_busy || _syncing || _popupOpen || _offering || !mounted) return;
    final shop = widget.shop;
    _popupOpen = true;
    try {
      jar.toldFull();
      // The store's price for this jar, if the store can be asked.
      final prices = shop == null || !jar.isFull || !shop.backend.signedIn
          ? const <String, String>{}
          : await _reusablePrices(shop);
      if (!mounted || !identical(session, _session)) return;
      await showTreasureJar(
        context,
        rules: jar.rules,
        state: () => jar.state,
        changes: session.extras,
        text: _treasureText(session),
        shop: shop,
        price: prices[jar.size.productId],
        onBuy: _events?.purchaseStarted,
      );
    } finally {
      _popupOpen = false;
    }
  }
}
