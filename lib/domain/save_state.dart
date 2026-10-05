// What gets written to the save file — pure Dart, fully unit tested.

/// The save format this build writes. Raise it, and add a step to
/// [migrateSave], whenever the format changes. Never break an existing save.
const currentSaveVersion = 2;

/// An item and the cell it sits in.
class SavedItem {
  final String itemId;
  final int col;
  final int row;

  const SavedItem({required this.itemId, required this.col, required this.row});

  Map<String, dynamic> toJson() => {'item_id': itemId, 'col': col, 'row': row};

  factory SavedItem.fromJson(Map<String, dynamic> json) => SavedItem(
    itemId: json['item_id'] as String,
    col: json['col'] as int,
    row: json['row'] as int,
  );
}

/// A generator, its level and the cell it sits in.
class SavedGenerator {
  final String generatorId;
  final int level;
  final int col;
  final int row;

  const SavedGenerator({
    required this.generatorId,
    required this.level,
    required this.col,
    required this.row,
  });

  Map<String, dynamic> toJson() => {
    'generator_id': generatorId,
    'level': level,
    'col': col,
    'row': row,
  };

  factory SavedGenerator.fromJson(Map<String, dynamic> json) => SavedGenerator(
    generatorId: json['generator_id'] as String,
    level: json['level'] as int,
    col: json['col'] as int,
    row: json['row'] as int,
  );
}

/// Everything needed to put the player back exactly where they were.
class SaveState {
  final List<SavedItem> items;
  final List<SavedGenerator> generators;
  final int manna;
  final DateTime mannaLastRegen;
  final int talents;
  final int blessings;
  final List<String> activeOrders;
  final List<String> pendingOrders;

  /// Orders already delivered, so they are never handed out again.
  final List<String> completedOrders;
  final DateTime? lastOrderSkip;

  const SaveState({
    required this.items,
    required this.generators,
    required this.manna,
    required this.mannaLastRegen,
    required this.talents,
    required this.blessings,
    required this.activeOrders,
    required this.pendingOrders,
    required this.completedOrders,
    required this.lastOrderSkip,
  });

  Map<String, dynamic> toJson() => {
    'save_version': currentSaveVersion,
    'items': [for (final i in items) i.toJson()],
    'generators': [for (final g in generators) g.toJson()],
    'manna': manna,
    'manna_last_regen': mannaLastRegen.toUtc().toIso8601String(),
    'talents': talents,
    'blessings': blessings,
    'active_orders': activeOrders,
    'pending_orders': pendingOrders,
    'completed_orders': completedOrders,
    'last_order_skip': lastOrderSkip?.toUtc().toIso8601String(),
  };

  /// Reads a save of any known version. Throws [FormatException] if the data
  /// is not a save this build understands.
  factory SaveState.fromJson(Map<String, dynamic> raw) {
    final json = migrateSave(raw);
    try {
      final skip = json['last_order_skip'] as String?;
      return SaveState(
        items: [
          for (final i in json['items'] as List<dynamic>)
            SavedItem.fromJson(i as Map<String, dynamic>),
        ],
        generators: [
          for (final g in json['generators'] as List<dynamic>)
            SavedGenerator.fromJson(g as Map<String, dynamic>),
        ],
        manna: json['manna'] as int,
        mannaLastRegen: DateTime.parse(json['manna_last_regen'] as String),
        talents: json['talents'] as int,
        blessings: json['blessings'] as int,
        activeOrders: List<String>.from(json['active_orders'] as List<dynamic>),
        pendingOrders: List<String>.from(
          json['pending_orders'] as List<dynamic>,
        ),
        completedOrders: List<String>.from(
          json['completed_orders'] as List<dynamic>,
        ),
        lastOrderSkip: skip == null ? null : DateTime.parse(skip),
      );
    } on TypeError catch (e) {
      throw FormatException('Save file is missing or has a wrong field: $e');
    }
  }
}

/// Brings an older save up to [currentSaveVersion], one step at a time.
/// Throws [FormatException] for a save with no version or from a newer build.
Map<String, dynamic> migrateSave(Map<String, dynamic> raw) {
  final version = raw['save_version'];
  if (version is! int || version < 1) {
    throw const FormatException('Save file has no valid save_version');
  }
  if (version > currentSaveVersion) {
    throw FormatException(
      'Save file is version $version, newer than this app ($currentSaveVersion)',
    );
  }
  final json = Map<String, dynamic>.of(raw);
  if (json['save_version'] == 1) {
    // Version 2 remembers which orders were delivered. Version 1 did not
    // record that, so it starts as none.
    json['completed_orders'] = <String>[];
    json['save_version'] = 2;
  }
  // The next format change goes here, as another one-version step.
  return json;
}

/// Drops anything in [save] the current content no longer knows about, or
/// that sits off the board or on top of something else, so an old save can
/// never crash the game.
SaveState sanitizeSave(
  SaveState save, {
  required Set<String> itemIds,
  required Set<String> generatorIds,
  required Set<String> orderIds,
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
    manna: save.manna.clamp(0, maxManna),
    mannaLastRegen: save.mannaLastRegen,
    talents: save.talents < 0 ? 0 : save.talents,
    blessings: save.blessings < 0 ? 0 : save.blessings,
    activeOrders: active,
    pendingOrders: pending,
    completedOrders: completed,
    lastOrderSkip: save.lastOrderSkip,
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
