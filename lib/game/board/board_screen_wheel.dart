// The board screen's part in the Blessing Wheel (EXPANSION 20.4): its
// button in the row above the board, and opening it.
part of 'board_screen.dart';

mixin _BoardWheel on _BoardItems {
  /// The jars sold under the wheel (see the jars part of this screen).
  Widget? _jarShop(BoardSession session);

  /// content/chance.json as it is being played, or null if it is not there.
  Map<String, dynamic>? get _chance =>
      switch (_session?.contentBundle.files['chance']) {
        final Map<String, dynamic> json => json,
        _ => null,
      };

  Map<String, String> get _chanceText => {
    if (_chance?['text'] case final Map<String, dynamic> text)
      for (final e in text.entries)
        if (e.value case final String words) e.key: words,
  };

  /// The lucky boost's list, or null if this content has none.
  LuckyBoost? get _luckyBoost => switch (_chance?['lucky_boost']) {
    final Map<String, dynamic> json => LuckyBoost.fromJson(json),
    _ => null,
  };

  /// Mystery bubbles' list; null if this content has none, or where
  /// buying random rewards is forbidden (a mystery bubble is one).
  MysteryBubble? get _mysteryBubble => switch (_chance?['mystery_bubble']) {
    final Map<String, dynamic> json when _paidChanceAllowed =>
      MysteryBubble.fromJson(json),
    _ => null,
  };

  String _luckyName(int times) => times <= 1
      ? _chanceText['lucky_plain'] ?? ''
      : (_chanceText['lucky_step'] ?? '').replaceAll('{times}', '$times');

  /// Names a mystery bubble's outcomes for the item called [name] (or for
  /// any item, in the general list of chances).
  String Function(int tiers) _mysteryStep([String? name]) =>
      (tiers) =>
          (_chanceText[tiers <= 0 ? 'mystery_same' : 'mystery_step'] ?? '')
              .replaceAll('{name}', name ?? _chanceText['mystery_any'] ?? '')
              .replaceAll('{tiers}', '$tiers');

  /// A boosted tap is now and then lucky; the player is told when it was.
  void _wireLuck(BoardSession session) {
    final lucky = _luckyBoost;
    if (lucky == null) return;
    session.game
      ..luckyTimes = (() => lucky.draw(random: widget.luck))
      ..onLucky = (times) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: const Key('lucky_toast'),
              duration: const Duration(seconds: 2),
              backgroundColor: GamePalette.panel,
              content: Text(
                (_chanceText['lucky_toast'] ?? '').replaceAll(
                  '{times}',
                  '$times',
                ),
                style: const TextStyle(color: GamePalette.talents),
              ),
            ),
          );
      };
  }

  /// The wheel's rules, or null while the wheel is not open to this
  /// player: before its level, in the tutorial, or in a game played from
  /// memory only (older content), whose prizes could not be kept.
  WheelRules? _wheelRules(BoardSession session) {
    final unlock = session.levels.config.unlock('blessing_wheel');
    final wheel = _chance?['wheel'];
    if (unlock == null || wheel is! Map<String, dynamic>) return null;
    if (!session.tutorial.isOver || session.downgraded) return null;
    if (session.levels.level < unlock.level) return null;
    return WheelRules.fromJson(wheel);
  }

  /// The banner ad under the board. A fixed height is kept for it whenever
  /// it may show, so the board does not jump when an ad arrives; players
  /// who have bought anything never see it, nor does anyone in the tutorial.
  Widget _bannerStrip(BoardSession session) => ListenableBuilder(
    listenable: Listenable.merge([session.tutorial, session.purchases]),
    builder: (context, _) {
      final banner = widget.ads?.banner();
      final allowed = bannerAllowed(
        tutorialOver: session.tutorial.isOver,
        hasPaid:
            session.purchases.appliedTransactions.isNotEmpty ||
            session.purchases.ownedProducts.isNotEmpty,
        downgraded: session.downgraded,
      );
      if (banner == null || !allowed) return const SizedBox.shrink();
      return Container(
        key: const Key('banner_strip'),
        height: bannerHeight + bannerGap,
        width: double.infinity,
        padding: const EdgeInsets.only(top: bannerGap),
        // No ad is kept loading where it cannot be seen: while the shop, a
        // story scene or another whole screen covers the board, the room
        // for it stays but the banner itself is put away.
        child: TickerMode.valuesOf(context).enabled
            ? Center(child: banner)
            : null,
      );
    },
  );

  /// The Joppa Special, or null where it is not offered: no shop here, in
  /// the tutorial (no purchase is ever offered in it), or in a game played
  /// from memory only.
  SpecialOffer? _special(BoardSession session) {
    if (widget.shop == null || !session.tutorial.isOver || session.downgraded) {
      return null;
    }
    return switch (session.contentBundle.files['offers']) {
      {'special': final Object special} => SpecialOffer.fromJson(special),
      _ => null,
    };
  }

  Future<void> _openSpecial() async {
    final session = _session;
    final shop = widget.shop;
    if (session == null || shop == null) return;
    final offer = _special(session);
    if (offer == null || _busy || _syncing || _popupOpen || !mounted) return;
    _popupOpen = true;
    try {
      await showSpecialOffer(
        context,
        offer: offer,
        shop: shop,
        onBuy: _events?.purchaseStarted,
      );
    } finally {
      _popupOpen = false;
    }
  }

  /// The wheel's round button (gold while a free spin is waiting), or
  /// nothing while the wheel is not open to this player.
  List<Widget> _wheelButton(BoardSession session) {
    final special = _special(session) == null
        ? null
        : StripButton(
            buttonKey: const Key('special_button'),
            icon: Icons.local_offer,
            tooltip: switch (session.contentBundle.files['offers']) {
              {'special': {'button': final String words}} => words,
              _ => '',
            },
            onTap: _openSpecial,
            lit: true,
          );
    final rules = _wheelRules(session);
    if (rules == null) return [?special];
    final tally = WheelTally.fromJson(session.extras.read(wheelRecord));
    return [
      ?special,
      StripButton(
        buttonKey: const Key('wheel_button'),
        icon: Icons.album,
        tooltip: _chanceText['wheel_button'] ?? '',
        onTap: _openWheel,
        lit: freeSpinsLeft(rules, tally, DateTime.now()) > 0,
      ),
    ];
  }

  /// Whether random rewards may be bought with Pearls where this phone is
  /// set to be.
  bool get _paidChanceAllowed {
    final blocked = _chance?['paid_blocked_countries'];
    return paidChanceAllowed(
      widget.country ??
          WidgetsBinding.instance.platformDispatcher.locale.countryCode,
      {
        if (blocked is List<dynamic>)
          for (final code in blocked)
            if (code is String) code,
      },
    );
  }

  Future<void> _openWheel() async {
    final session = _session;
    if (session == null || _busy || _syncing || !mounted) return;
    final rules = _wheelRules(session);
    if (rules == null) return;
    _busy = true;
    final wheel = WheelController(
      rules: rules,
      extras: session.extras,
      paidAllowed: _paidChanceAllowed,
      pearls: () => session.purchases.pearls,
      spendPearls: session.purchases.spendPearls,
      grant: (prize) => _givePrize(session, prize),
      adReady: () => session.ads.rewardAdReady,
      watchAd: session.ads.watchForReward,
      random: widget.luck,
    );
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WheelScreen(
            controller: wheel,
            text: _chanceText,
            below: _jarShop(session),
            pearlsChanged: session.purchases,
            moreOdds: [
              if (_luckyBoost case final lucky?)
                (
                  title: _chanceText['lucky_title'] ?? '',
                  odds: lucky.odds(_luckyName),
                ),
              if (_mysteryBubble case final mystery?)
                (
                  title: _chanceText['mystery_title'] ?? '',
                  odds: mystery.odds(_mysteryStep()),
                ),
            ],
          ),
        ),
      );
    } finally {
      wheel.dispose();
      _busy = false;
    }
  }

  /// Hands over everything a prize holds. Items and generators wait for
  /// room on the board if there is none.
  void _givePrize(BoardSession session, Prize prize) {
    if (prize.manna > 0) session.manna.add(prize.manna);
    if (prize.talents > 0) session.orders.addTalents(prize.talents);
    if (prize.pearls > 0) session.purchases.earnPearls(prize.pearls);
    session.grants.give(itemIds: prize.items, generatorIds: prize.generators);
    widget.comfort?.cue(GameCue.reward);
  }
}
