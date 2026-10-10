// Core game models — pure Dart, no Flutter or Flame imports.

import 'package:whispers_of_joppa/domain/generator_types.dart';

/// A single item on the board or in the basket.
class ItemModel {
  final String itemId; // e.g. "bakery_03"
  final String chainId; // e.g. "bakery"
  final int tier;
  final String name;
  final String asset; // asset path, may be empty (uses placeholder)
  final int sell; // Talents earned when sold

  /// What using this item does, for the few items that can be used (Manna
  /// jars, hourglasses); null for everything else.
  final ItemUse? use;

  const ItemModel({
    required this.itemId,
    required this.chainId,
    required this.tier,
    required this.name,
    required this.asset,
    this.sell = 0,
    this.use,
  });
}

/// The effect of using an item.
class ItemUse {
  /// Manna given when it is used (it may take Manna over the bar).
  final int manna;

  /// Seconds taken off a generator's wait when it is dropped on one.
  final int skipSeconds;

  /// True if it ends a generator's wait outright.
  final bool skipAll;

  const ItemUse({this.manna = 0, this.skipSeconds = 0, this.skipAll = false});

  /// Null if [json] describes no effect.
  static ItemUse? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final use = ItemUse(
      manna: json['manna'] as int? ?? 0,
      skipSeconds: json['skip_seconds'] as int? ?? 0,
      skipAll: json['skip_all'] as bool? ?? false,
    );
    return use.givesManna || use.skipsTime ? use : null;
  }

  bool get givesManna => manna > 0;
  bool get skipsTime => skipAll || skipSeconds > 0;
}

/// One cell on the 7×9 board.
class BoardCell {
  final int col; // 0–6
  final int row; // 0–8
  ItemModel? item;
  bool locked; // locked = rubble not yet cleared

  BoardCell({
    required this.col,
    required this.row,
    this.item,
    this.locked = false,
  });

  bool get isEmpty => item == null && !locked;
}

/// One generator on the board.
class GeneratorModel {
  final String generatorId;
  final String chainId;
  final int level; // 1–5
  final int energyCost;
  final String name;

  /// Standard, charged, free or temporary, with its numbers.
  final GeneratorRules rules;

  const GeneratorModel({
    required this.generatorId,
    required this.chainId,
    required this.level,
    required this.energyCost,
    required this.name,
    this.rules = GeneratorRules.standard,
  });

  /// The same generator at another level.
  GeneratorModel atLevel(int newLevel) => GeneratorModel(
    generatorId: generatorId,
    chainId: chainId,
    level: newLevel,
    energyCost: energyCost,
    name: name,
    rules: rules,
  );
}

/// The full board state (7 cols × 9 rows = 63 cells).
class BoardState {
  static const int cols = 7;
  static const int rows = 9;

  final List<List<BoardCell>> cells; // [col][row]
  final List<GeneratorModel> generators;
  final int manna;
  final int maxManna;
  final int talents;
  final int pearls;
  final int blessings;

  const BoardState({
    required this.cells,
    required this.generators,
    required this.manna,
    required this.maxManna,
    required this.talents,
    required this.pearls,
    required this.blessings,
  });

  /// Returns the cell at (col, row), or null if out of bounds.
  BoardCell? cellAt(int col, int row) {
    if (col < 0 || col >= cols || row < 0 || row >= rows) return null;
    return cells[col][row];
  }

  /// Returns the first empty cell, or null if the board is full.
  BoardCell? firstEmpty() {
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (cells[c][r].isEmpty) return cells[c][r];
      }
    }
    return null;
  }
}

/// Where a generator sits when a new game begins.
class StartingGenerator {
  final String generatorId;
  final int col;
  final int row;

  /// The chapter in which the player receives this generator (1 = from the
  /// start of the game).
  final int chapter;

  /// The player level at which this generator arrives (1 = no wait).
  final int level;

  const StartingGenerator({
    required this.generatorId,
    required this.col,
    required this.row,
    this.chapter = 1,
    this.level = 1,
  });
}

/// An item already on the board when a new game begins.
class StartingItem {
  final String itemId;
  final int col;
  final int row;

  const StartingItem({
    required this.itemId,
    required this.col,
    required this.row,
  });
}

/// The board a brand-new player sees, from content/starting_board.json.
class StartingBoard {
  final int manna;

  /// The scene a brand-new player sees before the board, if any.
  final String? openingScene;
  final List<StartingGenerator> generators;
  final List<StartingItem> items;

  const StartingBoard({
    required this.manna,
    this.openingScene,
    required this.generators,
    required this.items,
  });

  factory StartingBoard.fromJson(Map<String, dynamic> json) => StartingBoard(
    manna: json['manna'] as int,
    openingScene: json['opening_scene'] as String?,
    generators: [
      for (final g in json['generators'] as List<dynamic>)
        StartingGenerator(
          generatorId: (g as Map<String, dynamic>)['generator_id'] as String,
          col: g['col'] as int,
          row: g['row'] as int,
          chapter: g['chapter'] as int? ?? 1,
          level: g['level'] as int? ?? 1,
        ),
    ],
    items: [
      for (final i in json['items'] as List<dynamic>)
        StartingItem(
          itemId: (i as Map<String, dynamic>)['item_id'] as String,
          col: i['col'] as int,
          row: i['row'] as int,
        ),
    ],
  );
}
