// The board screen's part in levels and usable items: the level-up message,
// and asking before a Manna jar is used.
part of 'board_screen.dart';

mixin _BoardItems on _BoardRoutes {
  /// A Jar of Clay was tapped (see the jars part of this screen).
  Future<void> _askAboutJar(
    ItemModel item, {
    bool Function()? use,
    bool Function()? sell,
  });

  /// Pays for any level just reached (a full Manna bar, Talents, perhaps a
  /// gift) and tells the player.
  Future<void> _showLevelUp() async {
    final session = _session;
    final up = session?.levels.collect();
    if (session == null || up == null || !mounted) return;
    widget.comfort?.cue(GameCue.reward);
    await showLevelUp(
      context,
      session.levels.config.text,
      up,
      giftNames: [
        for (final id in up.items) ?session.game.itemCatalog[id]?.name,
        for (final id in up.generators) ?session.grants.generators[id]?.name,
      ],
    );
  }

  /// The small wording used on the board, from the content being played.
  Map<String, String> get _boardText {
    final json = _session?.contentBundle.files['board_text'];
    return {
      if (json is Map<String, dynamic>)
        for (final e in json.entries)
          if (e.value case final String words) e.key: words,
    };
  }

  /// character_id -> their colour and portrait framing, from the content
  /// being played.
  Map<String, CharacterLook> get _characterLooks =>
      characterLooks(_session?.contentBundle.files['characters']);

  /// The order cards, with a little room round them (the harbor picture
  /// behind the whole top of the screen shows between them).
  Widget _ordersBackdrop({required Widget child}) => Padding(
    // The row has its own gutters at both edges.
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: child,
  );

  /// A picture for the story card: what the next task restores, as it
  /// looks now; failing that, the first part of the place. Null if the
  /// art is not there.
  String? get _storyPicture {
    final session = _session;
    final chapter = session?.story.chapter;
    final areas = session?.locations[chapter?.locationId]?.areas;
    if (session == null || areas == null || areas.isEmpty) return null;
    final restored = session.story.restoredAreaIds;
    final next = session.story.next?.restoresArea;
    final area = areas.where((a) => a.id == next).firstOrNull ?? areas.first;
    return locationAssetFor(
      area.imageId(restored: restored.contains(area.id)),
      session.assetPaths,
    );
  }

  /// Connects the board to the screen: asking before an item is used or
  /// sold, paying for a sale, and the generator boosts that open at their
  /// levels (EXPANSION 19.2).
  void _wireBoard(BoardSession session) {
    final boosts = session.levels.config.boosts;
    session.game
      ..onItemAsked = _askAboutItem
      ..onSold = ((item) => session.orders.addTalents(item.sell))
      ..onJarOpened = ((_) => widget.comfort?.cue(GameCue.reward))
      ..wantedByOrder = ((id) => session.orders.activeOrders.any(
        (order) => order.items.any((wanted) => wanted.itemId == id),
      ))
      ..boosts = [for (final u in boosts) ?u.boost]
      ..boostUnlocked = (i) =>
          i < boosts.length && session.levels.level >= boosts[i].level;
  }

  /// The line that says what a usable item does.
  String _whatItDoes(ItemUse effect) {
    final text = _boardText;
    if (effect.givesManna) {
      return (text['use_manna'] ?? '').replaceAll('{manna}', '${effect.manna}');
    }
    if (effect.isSealed) {
      final chains = _session?.contentBundle.files['chains'];
      final name = [
        if (chains is List<dynamic>)
          for (final chain in chains)
            if (chain case {
              'id': final String id,
              'name': final String name,
            } when id == effect.opensWith)
              name,
      ].firstOrNull;
      return (text['sealed_hint'] ?? '').replaceAll('{chain}', name ?? '');
    }
    return text[effect.split
            ? 'knife_hint'
            : effect.wild
            ? 'thread_hint'
            : 'hourglass_hint'] ??
        '';
  }

  /// An item that can be used or sold was tapped. Nothing happens unless
  /// the player says so: a Manna jar can be kept for later, and a sale
  /// cannot be undone. An hourglass explains itself.
  Future<void> _askAboutItem(
    ItemModel item, {
    bool Function()? use,
    bool Function()? sell,
  }) async {
    if (item.use?.jar != null) return _askAboutJar(item, use: use, sell: sell);
    final session = _session;
    if (_busy || _syncing || _popupOpen || !mounted) return;
    final effect = item.use;
    final text = _boardText;
    String fill(String key, String name, int value) =>
        (text[key] ?? '').replaceAll('{$name}', '$value');
    _popupOpen = true;
    try {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('use_item'),
          backgroundColor: const Color(0xFF2A1F08),
          title: Text(
            item.name,
            style: const TextStyle(color: Color(0xFFD4802A)),
          ),
          content: effect == null
              ? null
              : Text(
                  _whatItDoes(effect),
                  key: const Key('use_item_effect'),
                  style: const TextStyle(color: Color(0xFFF3E5C8)),
                ),
          actionsOverflowAlignment: OverflowBarAlignment.end,
          actions: [
            TextButton(
              key: const Key('use_item_keep'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                (use == null && sell == null ? text['ok'] : text['keep']) ?? '',
                style: const TextStyle(color: Color(0xFFF3E5C8)),
              ),
            ),
            if (sell != null)
              TextButton(
                key: const Key('use_item_sell'),
                onPressed: () => Navigator.of(context).pop('sell'),
                child: Text(
                  fill('sell', 'talents', item.sell),
                  style: const TextStyle(color: Color(0xFFE9B44C)),
                ),
              ),
            if (use != null)
              TextButton(
                key: const Key('use_item_use'),
                onPressed: () => Navigator.of(context).pop('use'),
                child: Text(
                  text['use'] ?? '',
                  style: const TextStyle(color: Color(0xFFD4802A)),
                ),
              ),
          ],
        ),
      );
      // The game may have been swapped for the cloud's meanwhile.
      if (!identical(session, _session)) return;
      if (choice == 'use') use?.call();
      if (choice == 'sell') sell?.call();
    } finally {
      _popupOpen = false;
    }
  }
}
