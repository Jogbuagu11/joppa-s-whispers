// The board screen's part in the Blessing Wheel (EXPANSION 20.4): its
// button in the row above the board, and opening it.
part of 'board_screen.dart';

mixin _BoardWheel on _BoardItems {
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

  /// The wheel's round button (gold while a free spin is waiting), or
  /// nothing while the wheel is not open to this player.
  List<Widget> _wheelButton(BoardSession session) {
    final rules = _wheelRules(session);
    if (rules == null) return const [];
    final tally = WheelTally.fromJson(session.extras.read(wheelRecord));
    return [
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
          builder: (_) => WheelScreen(controller: wheel, text: _chanceText),
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
