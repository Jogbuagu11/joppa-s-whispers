// The board screen's part in Jars of Clay (EXPANSION 20.4): a jar given
// with orders, opening a jar on the board, and the jars sold under the
// wheel.
part of 'board_screen.dart';

mixin _BoardJars on _BoardBubbles {
  /// Starts everything left to chance for [session], which must already
  /// be the game in play: bubbles, jars with orders, the lucky boost.
  void _wireChance(BoardSession session) {
    assert(identical(session, _session), 'wire the game in play');
    _wireBubbles(session);
    _wireJars(session);
    _wireLuck(session);
  }

  /// The jars' rules, or null if this content has none.
  JarsConfig? get _jars => switch (_chance?['jars']) {
    final Map<String, dynamic> json => JarsConfig.fromJson(json),
    _ => null,
  };

  /// jar kind -> the name of its item on the board.
  Map<String, String> _jarNames(BoardSession session, JarsConfig jars) => {
    for (final kind in jars.kinds.values)
      kind.id: session.game.itemCatalog[kind.itemId]?.name ?? '',
  };

  /// A jar comes with every so many orders delivered (never in the
  /// tutorial, nor in a game played from memory only).
  void _wireJars(BoardSession session) {
    final jars = _jars;
    if (jars == null) return;
    final onDelivered = session.orders.onDelivered;
    session.orders.onDelivered = (id) {
      onDelivered?.call(id);
      if (!session.tutorial.isOver || session.downgraded) return;
      final jar = jars.jarForOrder(session.orders.completedOrders.length);
      if (jar != null) session.grants.give(itemIds: [jar]);
    };
  }

  /// The jars that can be bought, for under the wheel; nothing where
  /// buying random rewards is forbidden.
  @override
  Widget? _jarShop(BoardSession session) {
    final jars = _jars;
    if (jars == null || !_paidChanceAllowed || jars.forSale.isEmpty) {
      return null;
    }
    return JarShop(
      jars: jars.forSale,
      names: _jarNames(session, jars),
      text: _chanceText,
      pearls: session.purchases.pearlsListenable,
      onBuy: (jar) {
        final price = jar.pearlPrice;
        if (price == null || !session.purchases.spendPearls(price)) {
          return false;
        }
        // It goes to the board (or waits for room), to be opened there.
        session.grants.give(itemIds: [jar.itemId]);
        widget.comfort?.cue(GameCue.reward);
        return true;
      },
    );
  }

  /// A Jar of Clay on the board was tapped: what it may hold is shown, and
  /// it is opened only if the player says so.
  @override
  Future<void> _askAboutJar(
    ItemModel item, {
    bool Function()? use,
    bool Function()? sell,
  }) async {
    final session = _session;
    final jar = _jars?.kinds[item.use?.jar];
    if (session == null || jar == null || use == null) return;
    if (_busy || _syncing || _popupOpen || !mounted) return;
    final text = _chanceText;
    final board = _boardText;
    _popupOpen = true;
    try {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => GameDialog(
          key: const Key('jar_dialog'),
          icon: Icons.inventory_2,
          title: Text(
            item.name,
            style: const TextStyle(color: GamePalette.gold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OddsList(title: text['jar_holds'] ?? '', odds: jar.odds),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('use_item_keep'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                board['keep'] ?? '',
                style: const TextStyle(color: Color(0xFFF3E5C8)),
              ),
            ),
            if (sell != null)
              TextButton(
                key: const Key('use_item_sell'),
                onPressed: () => Navigator.of(context).pop('sell'),
                child: Text(
                  (board['sell'] ?? '').replaceAll('{talents}', '${item.sell}'),
                  style: const TextStyle(color: GamePalette.talents),
                ),
              ),
            FilledButton(
              key: const Key('jar_open'),
              onPressed: () => Navigator.of(context).pop('open'),
              child: Text(text['jar_open'] ?? ''),
            ),
          ],
        ),
      );
      // The game may have been swapped for the cloud's meanwhile.
      if (!identical(session, _session) || !mounted) return;
      if (choice == 'sell') sell?.call();
      // The jar leaves the board first; only then is its prize drawn.
      if (choice == 'open' && use()) {
        final prize = jar.open(random: widget.luck);
        if (prize == null) return;
        _givePrize(session, prize);
        await showPrize(context, text: text, prize: prize);
      }
    } finally {
      _popupOpen = false;
    }
  }
}
