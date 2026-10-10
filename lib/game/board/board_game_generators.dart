// Generator taps and placing spawned items.
part of 'board_game.dart';

extension BoardGenerators on BoardGame {
  /// Places an item in the first empty non-generator cell.
  void placeItem(ItemModel item) {
    for (int c = 0; c < gridCols; c++) {
      for (int r = 0; r < gridRows; r++) {
        if (_board[c][r] == null && !_generatorCellSet.contains((c, r))) {
          _board[c][r] = item;
          _cells[c][r].setItem(item, _colorFor(item), _art[item.itemId]);
          _boardTouched();
          return;
        }
      }
    }
    _log.warning('No empty cell to place item ${item.itemId}');
  }

  /// Gives the player a new generator (a new chapter's), at [homeCol],
  /// [homeRow] or the nearest free cell. Returns false, changing nothing, if
  /// the board has no free cell; it can be tried again later.
  bool addGenerator(GeneratorModel gen, int homeCol, int homeRow) {
    if (generatorPlacements.any((p) => p.gen.generatorId == gen.generatorId)) {
      return true;
    }
    final cell = cellForNewGenerator(
      homeCol: homeCol,
      homeRow: homeRow,
      taken: {
        for (final p in generatorPlacements) (p.col, p.row),
        // Before the board is drawn the items are still the starting list.
        if (_built)
          for (final i in snapshotItems()) (i.col, i.row)
        else
          for (final i in startingItems) (i.col, i.row),
      },
      cols: gridCols,
      rows: gridRows,
    );
    if (cell == null) return false;
    final placement = (gen: gen, col: cell.col, row: cell.row);
    generatorPlacements.add(placement);
    if (_built) {
      _showGenerator(placement);
      _boardTouched();
    }
    return true;
  }

  void _onGeneratorTapped(String genId) {
    final placement = generatorPlacements
        .where((p) => p.gen.generatorId == genId)
        .firstOrNull;
    if (placement == null) return;

    final gen = placement.gen;
    final rules = gen.rules;
    // A free generator makes its items by itself; a charged one that is
    // resting, or a temporary one with nothing left, gives nothing.
    if (!canGive(rules, _timerFor(gen), now())) {
      _log.fine('Generator $genId has nothing to give right now');
      return;
    }

    // Collect any Manna that is already due before deciding.
    manna.tick();
    final free = freeGeneratorTaps?.call() ?? false;
    final result = resolveGeneratorTap(
      gen: gen,
      manna: manna.manna,
      hasFreeCell: _hasSpaceForItem(),
      levels: generatorLevels[genId],
      chains: chainData,
      costOverride: free || !rules.costsManna ? 0 : null,
    );
    final item = itemCatalog[result.itemId];
    if (result.refusal == GeneratorTapRefusal.notEnoughManna) onOutOfManna();
    if (!result.spawned || item == null) {
      _log.info(
        'Generator $genId did not spawn: ${result.refusal ?? 'item ${result.itemId} not in catalog'}',
      );
      return;
    }

    if (rules.costsManna) manna.setAfterSpend(result.mannaAfter);
    placeItem(item);
    _afterGave(placement);
    onGeneratorSpawn?.call(wasFree: free || !rules.costsManna);
    _log.fine('Generator $genId spawned ${item.itemId}, manna=${manna.manna}');
  }

  bool _hasSpaceForItem() {
    for (int c = 0; c < gridCols; c++) {
      for (int r = 0; r < gridRows; r++) {
        if (_board[c][r] == null && !_generatorCellSet.contains((c, r))) {
          return true;
        }
      }
    }
    return false;
  }

  /// Raises every generator on the board to at least [level] (a purchase
  /// reward). Generators already at or above it are left alone.
  void raiseGeneratorsTo(int level) {
    final levels = raisedGeneratorLevels([
      for (final p in generatorPlacements) p.gen.level,
    ], level);
    for (int i = 0; i < generatorPlacements.length; i++) {
      final p = generatorPlacements[i];
      generatorPlacements[i] = (
        gen: p.gen.atLevel(levels[i]),
        col: p.col,
        row: p.row,
      );
    }
    _boardTouched();
  }
}
