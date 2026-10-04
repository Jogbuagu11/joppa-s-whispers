// Core game models — pure Dart, no Flutter or Flame imports.

/// A single item on the board or in the basket.
class ItemModel {
  final String itemId;  // e.g. "bakery_03"
  final String chainId; // e.g. "bakery"
  final int tier;
  final String name;
  final String asset;   // asset path, may be empty (uses placeholder)

  const ItemModel({
    required this.itemId,
    required this.chainId,
    required this.tier,
    required this.name,
    required this.asset,
  });
}

/// One cell on the 7×9 board.
class BoardCell {
  final int col; // 0–6
  final int row; // 0–8
  ItemModel? item;
  bool locked; // locked = rubble not yet cleared

  BoardCell({required this.col, required this.row, this.item, this.locked = false});

  bool get isEmpty => item == null && !locked;
}

/// One generator on the board.
class GeneratorModel {
  final String generatorId;
  final String chainId;
  final int level; // 1–5
  final int energyCost;
  final String name;

  const GeneratorModel({
    required this.generatorId,
    required this.chainId,
    required this.level,
    required this.energyCost,
    required this.name,
  });
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
