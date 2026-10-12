// The board screen's part in the Treasure Jar (EXPANSION 13 and 21.1): it
// fills as the player plays, has a button in the row above the board, and
// says so once when it is full.
part of 'board_screen.dart';

mixin _BoardTreasure on _BoardOffers, _BoardDaily {
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
    _wireDaily(session);
    final rules = TreasureJarRules.fromJson(_treasureJson(session));
    final jar = _treasure = rules == null
        ? null
        : TreasureJarController(
            rules: rules,
            extras: session.extras,
            level: session.levels.level,
          );
    // The season passes held are read from every list the server sends.
    session.purchases.onServerRecords = EventPass.reader(session.extras);
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
    session.levels.addListener(
      () => jar.levelIs(session.levels.level, open: _treasureOpen(session)),
    );
  }

  /// The season pass for the event screen: none in a game played from
  /// memory only, or with content that has no pass.
  @override
  EventPass? _eventPass(BoardSession session) {
    final json = switch (session.contentBundle.files['offers']) {
      {'season_pass': final Map<String, dynamic> pass} => pass,
      _ => null,
    };
    final shop = widget.shop;
    if (session.downgraded) return null;
    if (json case {
      'premium_product': final String premium,
      'plus_product': final String plus,
      'text': final Map<String, dynamic> text,
    }) {
      return EventPass(
        extras: session.extras,
        shop: shop,
        prices: () async => shop == null || !shop.backend.signedIn
            ? const {}
            : _reusablePrices(shop),
        text: {
          for (final e in text.entries)
            if (e.value case final String words) e.key: words,
        },
        premiumProduct: premium,
        plusProduct: plus,
        earnPearls: session.purchases.earnPearls,
        giveItems: (ids) => session.grants.give(itemIds: ids),
        itemName: (id) => session.game.itemCatalog[id]?.name ?? '',
        onBuy: _events?.purchaseStarted,
      );
    }
    return null;
  }

  /// The jar's round button (gold when the jar is full), or nothing while
  /// the jar is not open to this player.
  @override
  Widget? _treasureButton(BoardSession session) {
    final jar = _treasure;
    if (jar == null || !_treasureOpen(session)) return null;
    return StripButton(
      buttonKey: const Key('treasure_jar_button'),
      icon: Icons.diamond,
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

  /// Whether the jar's pop-up may open at this moment.
  bool _treasureCanOpen(BoardSession session) =>
      mounted &&
      identical(session, _session) &&
      _treasureOpen(session) &&
      !(_busy || _syncing || _popupOpen || _offering) &&
      !session.game.isDragging &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  Future<void> _openTreasure() async {
    final session = _session;
    final jar = _treasure;
    if (session == null || jar == null || !_treasureCanOpen(session)) return;
    final shop = widget.shop;
    // The store's price for this jar, if the store can be asked.
    final prices = shop == null || !jar.isFull || !shop.backend.signedIn
        ? const <String, String>{}
        : await _reusablePrices(shop);
    // Things may have changed while the store was being asked.
    if (!_treasureCanOpen(session) || !mounted) return;
    _popupOpen = true;
    try {
      jar.toldFull();
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

/// The board screen's part in daily tasks: counting what the player does
/// and the button that shows today's.
mixin _BoardDaily on _BoardEvents {
  DailyTasksController? _daily;

  Map<String, String> _dailyText(BoardSession session) => {
    if (session.contentBundle.files['daily_tasks'] case {
      'text': final Map<String, dynamic> text,
    })
      for (final e in text.entries)
        if (e.value case final String words) e.key: words,
  };

  /// Starts daily tasks for [session], which must be the game in play.
  void _wireDaily(BoardSession session) {
    _daily?.dispose();
    final config = DailyTasksConfig.fromJson(
      session.contentBundle.files['daily_tasks'],
    );
    final unlock = session.levels.config.unlock('daily_tasks');
    if (config == null || unlock == null) return _daily = null;
    final daily = _daily = DailyTasksController(
      config: config,
      extras: session.extras,
      open: () =>
          session.tutorial.isOver &&
          !session.downgraded &&
          session.levels.level >= unlock.level,
      grant: (reward) {
        if (reward.manna > 0) session.manna.add(reward.manna);
        if (reward.talents > 0) session.orders.addTalents(reward.talents);
        if (reward.pearls > 0) session.purchases.earnPearls(reward.pearls);
        if (reward.items.isNotEmpty) session.grants.give(itemIds: reward.items);
      },
    );
    final onDelivered = session.orders.onDelivered;
    session.orders.onDelivered = (id) {
      onDelivered?.call(id);
      daily.orderDelivered(session.orders.talentsFor(id));
    };
    final onMerge = session.game.onMerge;
    session.game.onMerge = () {
      onMerge?.call();
      daily.merged();
    };
    final onSpent = session.manna.onSpent;
    session.manna.onSpent = (amount) {
      onSpent?.call(amount);
      daily.mannaSpent(amount);
    };
    daily.justPaid.addListener(() {
      if (!mounted || !identical(session, _session)) return;
      final text = _dailyText(session);
      const keys = {
        DailyPrize.task: 'toast_task',
        DailyPrize.chest: 'toast_chest',
        DailyPrize.weekly: 'toast_weekly',
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            key: const Key('daily_toast'),
            duration: const Duration(seconds: 3),
            backgroundColor: GamePalette.panel,
            content: Text(
              [
                for (final paid in daily.justPaid.value)
                  (text[keys[paid.prize]] ?? '').replaceAll(
                    '{reward}',
                    _rewardWords(session, paid.reward),
                  ),
              ].join('\n'),
              style: const TextStyle(color: GamePalette.talents),
            ),
          ),
        );
    });
  }

  String _rewardWords(BoardSession session, PassReward reward) =>
      goalRewardWords(reward, _boardText, (id) => _itemName(session, id));

  /// The daily tasks' round button, once they are open to this player.
  Widget? _dailyButton(BoardSession session) {
    final daily = _daily;
    if (daily == null || !daily.open()) return null;
    return StripButton(
      buttonKey: const Key('daily_tasks_button'),
      icon: Icons.checklist,
      tooltip: _dailyText(session)['button'] ?? '',
      onTap: () async {
        if (_busy || _syncing || _popupOpen || !mounted) return;
        _popupOpen = true;
        try {
          await showDailyTasks(
            context,
            controller: daily,
            text: _dailyText(session),
            rewardWords: (reward) => _rewardWords(session, reward),
          );
        } finally {
          _popupOpen = false;
        }
      },
      lit: !daily.state.chest,
    );
  }
}
