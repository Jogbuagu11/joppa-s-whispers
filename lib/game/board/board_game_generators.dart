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

  /// Loads the picture for every level of every generator that has one
  /// among [have] (the pictures in the app). A generator without art keeps
  /// its plain tile.
  Future<void> _loadGeneratorArt(Set<String> have) => Future.wait([
    for (final entry in generatorLevels.entries)
      for (final level in entry.value)
        if (have.contains(generatorArtPath(entry.key, level.level)))
          () async {
            final key = '${entry.key}_l${level.level}';
            try {
              _generatorArt[key] = await images.load(
                generatorArtPath(entry.key, level.level),
              );
            } on Object catch (e) {
              _log.warning('Generator picture $key could not be read: $e');
            }
          }(),
  ]);

  /// The picture for a generator at the level it has now. If that level has
  /// no picture, the nearest lower level's is used.
  ui.Image? _generatorArtFor(String generatorId) {
    final level = generatorPlacements
        .where((p) => p.gen.generatorId == generatorId)
        .firstOrNull
        ?.gen
        .level;
    for (int l = level ?? 1; l >= 1; l--) {
      final picture = _generatorArt['${generatorId}_l$l'];
      if (picture != null) return picture;
    }
    return null;
  }

  void _onGeneratorTapped(String genId) {
    final placement = generatorPlacements
        .where((p) => p.gen.generatorId == genId)
        .firstOrNull;
    if (placement == null) return;

    final gen = placement.gen;

    // Collect any Manna that is already due before deciding.
    manna.tick();
    final free = freeGeneratorTaps?.call() ?? false;
    final result = resolveGeneratorTap(
      gen: gen,
      manna: manna.manna,
      hasFreeCell: _hasSpaceForItem(),
      levels: generatorLevels[genId],
      chains: chainData,
      costOverride: free ? 0 : null,
    );
    final item = itemCatalog[result.itemId];
    if (result.refusal == GeneratorTapRefusal.notEnoughManna) onOutOfManna();
    if (!result.spawned || item == null) {
      _log.info(
        'Generator $genId did not spawn: ${result.refusal ?? 'item ${result.itemId} not in catalog'}',
      );
      return;
    }

    manna.setAfterSpend(result.mannaAfter);
    placeItem(item);
    onGeneratorSpawn?.call(wasFree: free);
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
}
