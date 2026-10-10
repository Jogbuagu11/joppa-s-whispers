// Making a loaded save safe to play with today's content. Pure Dart.
import 'package:whispers_of_joppa/domain/save_state.dart';

/// Drops anything in [save] the current content no longer knows about, or
/// that sits off the board or on top of something else, so an old save can
/// never crash the game.
SaveState sanitizeSave(
  SaveState save, {
  required Set<String> itemIds,
  required Set<String> generatorIds,
  required Set<String> orderIds,
  required Set<String> taskIds,
  required int cols,
  required int rows,
  required int maxManna,
}) {
  final taken = <(int, int)>{};
  bool free(int col, int row) =>
      col >= 0 && col < cols && row >= 0 && row < rows && taken.add((col, row));

  final generators = [
    for (final g in save.generators)
      if (generatorIds.contains(g.generatorId) && free(g.col, g.row)) g,
  ];
  final items = [
    for (final i in save.items)
      if (itemIds.contains(i.itemId) && free(i.col, i.row)) i,
  ];
  final seenOrders = <String>{};
  List<String> known(List<String> ids) => [
    for (final id in ids)
      if (orderIds.contains(id) && seenOrders.add(id)) id,
  ];
  // Delivered first, so a delivered order can never also be showing or waiting.
  final completed = known(save.completedOrders);
  final active = known(save.activeOrders);
  final pending = known(save.pendingOrders);

  return SaveState(
    items: items,
    generators: generators,
    // Bought Manna may sit above the bar; only nonsense values are cut.
    manna: save.manna.clamp(0, maxManna + maxBonusManna),
    mannaLastRegen: save.mannaLastRegen,
    talents: save.talents < 0 ? 0 : save.talents,
    blessings: save.blessings < 0 ? 0 : save.blessings,
    pearls: save.pearls < 0 ? 0 : save.pearls,
    appliedTransactions: save.appliedTransactions.toSet().toList(),
    ownedProducts: save.ownedProducts.toSet().toList(),
    activeOrders: active,
    pendingOrders: pending,
    completedOrders: completed,
    completedTasks: [
      for (final id in save.completedTasks.toSet())
        if (taskIds.contains(id)) id,
    ],
    tutorialStep: save.tutorialStep < 0 ? 0 : save.tutorialStep,
    tutorialFreeTapsUsed: save.tutorialFreeTapsUsed < 0
        ? 0
        : save.tutorialFreeTapsUsed,
    endingsSeen: save.endingsSeen.toSet().toList(),
    contentVersion: save.contentVersion,
    lastOrderSkip: save.lastOrderSkip,
    adDay: save.adDay,
    adMannaWatched: save.adMannaWatched < 0 ? 0 : save.adMannaWatched,
    levelRewarded: save.levelRewarded < 0 ? 0 : save.levelRewarded,
    pendingGrants: save.pendingGrants,
    boost: save.boost < 0 ? 0 : save.boost,
    extras: save.extras,
  );
}

/// Puts back any generator from the starting board that [save] has lost (for
/// example after its id changed in content), so the player can always spawn
/// items. A missing generator goes to its starting cell, or is left out if an
/// item now sits there.
List<SavedGenerator> withMissingGenerators(
  SaveState save,
  List<SavedGenerator> startingGenerators,
) {
  final have = {for (final g in save.generators) g.generatorId};
  final taken = {
    for (final g in save.generators) (g.col, g.row),
    for (final i in save.items) (i.col, i.row),
  };
  return [
    ...save.generators,
    for (final g in startingGenerators)
      if (!have.contains(g.generatorId) && taken.add((g.col, g.row))) g,
  ];
}
