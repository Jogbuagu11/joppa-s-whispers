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

  /// Where cell ([col], [row]) is drawn, inside the board widget.
  Rect cellRect(int col, int row) {
    final cellSize = _cellSize;
    final at = _cellPosition(col, row, cellSize);
    return Rect.fromLTWH(at.x, at.y, cellSize, cellSize);
  }

  /// Two cells holding the same item that can be merged, or null if the
  /// board has no such pair.
  ((int, int), (int, int))? mergeablePair() {
    final seen = <String, (int, int)>{};
    for (int c = 0; c < gridCols; c++) {
      for (int r = 0; r < gridRows; r++) {
        final item = _board[c][r];
        if (item == null) continue;
        final other = seen[item.itemId];
        if (other == null) {
          seen[item.itemId] = (c, r);
        } else if (canMerge(item, item, chainData) == MergeResult.success) {
          return (other, (c, r));
        }
      }
    }
    return null;
  }

  /// Every item on the board with its cell (written to the save file).
  List<SavedItem> snapshotItems() => [
    for (int c = 0; c < gridCols; c++)
      for (int r = 0; r < gridRows; r++)
        if (_board[c][r] case final item?)
          SavedItem(itemId: item.itemId, col: c, row: r),
  ];

  /// Every generator with its level and cell (written to the save file).
  List<SavedGenerator> snapshotGenerators() => [
    for (final p in generatorPlacements)
      SavedGenerator(
        generatorId: p.gen.generatorId,
        level: p.gen.level,
        col: p.col,
        row: p.row,
        timer: generatorTimers[p.gen.generatorId],
      ),
  ];

  void _buildCells() {
    final cellSize = _cellSize;

    _cells = List.generate(gridCols, (c) {
      return List.generate(gridRows, (r) {
        final cell = CellComponent(
          col: c,
          row: r,
          cellSize: cellSize,
          position: _cellPosition(c, r, cellSize),
          onItemTapped: _onItemTapped,
        );
        add(cell);
        return cell;
      });
    });
  }

  void _buildGenerators() => generatorPlacements.forEach(_showGenerator);

  void _showGenerator(GeneratorPlacement placement) {
    final cellSize = _cellSize;
    _generatorCellSet.add((placement.col, placement.row));
    add(
      GeneratorComponent(
        generator: placement.gen,
        onTapped: _onGeneratorTapped,
        label: () => generatorLabel(placement.gen),
        art: () => _generatorArtFor(placement.gen.generatorId),
        position: _cellPosition(placement.col, placement.row, cellSize),
        cellSize: cellSize,
      ),
    );
  }

  // Grey is the fallback when a chain has no placeholder colour in content.
  Color _colorFor(ItemModel item) =>
      Color(chainPlaceholderColors[item.chainId] ?? 0xFF888888);

  double get _cellSize {
    final maxW = size.x / gridCols;
    final maxH = size.y / gridRows;
    return (maxW < maxH ? maxW : maxH) - 2;
  }
}
