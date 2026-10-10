// Fitting the board to the space it is given, again whenever that space
// changes (a hint or a banner above it comes or goes).
part of 'board_game.dart';

extension BoardLayout on BoardGame {
  /// Where cell ([col], [row]) sits, for cells of [cellSize].
  Vector2 _cellPosition(int col, int row, double cellSize) => Vector2(
    (size.x - gridCols * cellSize) / 2 + col * cellSize,
    (size.y - gridRows * cellSize) / 2 + row * cellSize,
  );

  /// Moves and resizes every cell, item and generator to fit the board's
  /// present size. Nothing about what is on the board changes.
  void _relayout() {
    if (!_built) return;
    // A dragged item goes home first: its position was for the old size.
    final dragging = _dragging;
    final origin = _dragOriginCell;
    if (dragging != null && origin != null) {
      _snapBack(dragging, origin, dragging.item);
    }
    final cellSize = _cellSize;
    for (int c = 0; c < gridCols; c++) {
      for (int r = 0; r < gridRows; r++) {
        _cells[c][r].fit(cellSize, _cellPosition(c, r, cellSize));
      }
    }
    for (final tile in children.whereType<GeneratorComponent>()) {
      final placement = generatorPlacements
          .where((p) => p.gen.generatorId == tile.generator.generatorId)
          .firstOrNull;
      if (placement == null) continue;
      tile.fit(cellSize, _cellPosition(placement.col, placement.row, cellSize));
    }
  }
}
