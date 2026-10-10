// The board screen's part in bubbles (EXPANSION 20.1): making them after
// merges, drawing them over the board, and asking what to do with one.
part of 'board_screen.dart';

mixin _BoardBubbles on _BoardWheel {
  /// Starts bubbles for [session] (and ends those of the game before it).
  void _wireBubbles(BoardSession session) {
    _bubbles?.dispose();
    final unlock = session.levels.config.bubbles;
    final bubbles = BubbleController(
      rules: unlock?.bubble,
      items: session.game.itemCatalog,
      chains: session.game.chainData,
      sideChains: session.game.sideChains,
      mystery: _mysteryBubble,
      // Not for a new player, nor for a game played from memory only
      // (older content): what it gave could not be kept.
      allowed: () =>
          session.tutorial.isOver &&
          !session.downgraded &&
          session.levels.level >= (unlock?.level ?? 0),
      addTalents: session.orders.addTalents,
      spendPearls: session.purchases.spendPearls,
      giveItem: (id) => session.grants.give(itemIds: [id]),
      random: widget.luck,
    );
    _bubbles = bubbles;
    final onMerged = session.game.onMerged;
    session.game.onMerged = (item) {
      onMerged?.call(item);
      final (col, row) = session.game.lastMergeCell ?? (0, 0);
      bubbles.afterMerge(item, col: col, row: row);
    };
  }

  /// The bubbles, drawn over the board.
  Widget _bubbleLayer(BoardSession session) {
    final bubbles = _bubbles;
    if (bubbles == null) return const SizedBox.shrink();
    return BubbleLayer(
      controller: bubbles,
      cellRect: session.game.cellRect,
      placeholderColors: session.game.chainPlaceholderColors,
      onTap: _askAboutBubble,
      label: _boardText['bubble_label'] ?? '',
      mysteryName: _chanceText['mystery_name'] ?? '',
    );
  }

  /// A bubble was tapped: keep what is in it (for Pearls, or an ad if it is
  /// small enough), or leave it to pop.
  Future<void> _askAboutBubble(Bubble tapped) async {
    final session = _session;
    final bubbles = _bubbles;
    if (session == null || bubbles == null) return;
    if (_busy || _syncing || _popupOpen || !mounted) return;
    final text = _boardText;
    final pearls = bubbles.pearlsFor(tapped);
    // It does not pop while the player is reading.
    bubbles.hold(tapped.id);
    _popupOpen = true;
    try {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('bubble_dialog'),
          backgroundColor: const Color(0xFF2A1F08),
          title: Text(
            tapped.mystery
                ? _chanceText['mystery_name'] ?? ''
                : tapped.item.name,
            style: const TextStyle(color: Color(0xFFD4802A)),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  (text['bubble_body'] ?? '').replaceAll(
                    '{talents}',
                    '${bubbles.talentsFor(tapped)}',
                  ),
                  style: const TextStyle(color: Color(0xFFF3E5C8)),
                ),
                // What a mystery bubble may hold is shown before it is
                // paid for.
                if (bubbles.mystery case final mystery? when tapped.mystery)
                  OddsList(
                    key: const Key('mystery_odds'),
                    title: tapped.item.name,
                    odds: mystery.odds(_mysteryStep),
                  ),
              ],
            ),
          ),
          actionsOverflowAlignment: OverflowBarAlignment.end,
          actions: [
            TextButton(
              key: const Key('bubble_leave'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                text['bubble_leave'] ?? '',
                style: const TextStyle(color: Color(0xFFF3E5C8)),
              ),
            ),
            if (bubbles.adAllowedFor(tapped) && session.ads.rewardAdReady)
              TextButton(
                key: const Key('bubble_ad'),
                onPressed: () => Navigator.of(context).pop('ad'),
                child: Text(
                  text['bubble_ad'] ?? '',
                  style: const TextStyle(color: Color(0xFFE9B44C)),
                ),
              ),
            TextButton(
              key: const Key('bubble_pearls'),
              // Greyed out without the Pearls for it.
              onPressed: session.purchases.pearls >= pearls
                  ? () => Navigator.of(context).pop('pearls')
                  : null,
              child: Text(
                (text['bubble_pearls'] ?? '').replaceAll('{pearls}', '$pearls'),
                style: TextStyle(
                  color: session.purchases.pearls >= pearls
                      ? const Color(0xFFD4802A)
                      : const Color(0xFF7A6A4A),
                ),
              ),
            ),
          ],
        ),
      );
      // The game may have been swapped for the cloud's meanwhile.
      if (!identical(session, _session) || !identical(bubbles, _bubbles)) {
        return;
      }
      var kept = choice == 'pearls' && bubbles.keepWithPearls(tapped.id);
      if (choice == 'ad') {
        final watched = await session.ads.watchForReward();
        kept =
            watched &&
            identical(bubbles, _bubbles) &&
            bubbles.keepAfterAd(tapped.id);
      }
      // A mystery bubble's item is named once it is the player's.
      final held = bubbles.lastKept;
      if (kept && tapped.mystery && held != null && mounted) {
        await showPrize(
          context,
          text: _chanceText,
          prize: Prize(id: held.itemId, name: held.name, weight: 1),
        );
      }
    } finally {
      bubbles.release(tapped.id);
      _popupOpen = false;
    }
  }
}
