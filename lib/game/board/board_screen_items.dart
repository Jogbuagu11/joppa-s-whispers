// The board screen's part in levels and usable items: the level-up message,
// and asking before a Manna jar is used.
part of 'board_screen.dart';

mixin _BoardItems on _BoardRoutes {
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

  /// A usable item was tapped. A Manna jar is used only if the player says
  /// so (it can be kept for later); an hourglass explains itself.
  Future<void> _askToUse(ItemModel item, bool Function() use) async {
    final effect = item.use;
    if (effect == null || _busy || _popupOpen || !mounted) return;
    final text = _boardText;
    _popupOpen = true;
    try {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('use_item'),
          backgroundColor: const Color(0xFF2A1F08),
          title: Text(
            item.name,
            style: const TextStyle(color: Color(0xFFD4802A)),
          ),
          content: Text(
            effect.givesManna
                ? (text['use_manna'] ?? '').replaceAll(
                    '{manna}',
                    '${effect.manna}',
                  )
                : text['hourglass_hint'] ?? '',
            key: const Key('use_item_effect'),
            style: const TextStyle(color: Color(0xFFF3E5C8)),
          ),
          actions: [
            TextButton(
              key: const Key('use_item_keep'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                (effect.givesManna ? text['keep'] : text['ok']) ?? '',
                style: const TextStyle(color: Color(0xFFF3E5C8)),
              ),
            ),
            if (effect.givesManna)
              TextButton(
                key: const Key('use_item_use'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  text['use'] ?? '',
                  style: const TextStyle(color: Color(0xFFD4802A)),
                ),
              ),
          ],
        ),
      );
      if (yes ?? false) use();
    } finally {
      _popupOpen = false;
    }
  }
}
