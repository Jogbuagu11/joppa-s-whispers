// Generator taps and placing spawned items.
part of 'board_game.dart';

extension _BoardGenerators on BoardGame {
  /// Places an item in the first empty non-generator cell.
  void placeItem(ItemModel item) {
    for (int c = 0; c < BoardGame.cols; c++) {
      for (int r = 0; r < BoardGame.rows; r++) {
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

  void _onGeneratorTapped(String genId) {
    final placement = generatorPlacements
        .where((p) => p.gen.generatorId == genId)
        .firstOrNull;
    if (placement == null) return;

    final gen = placement.gen;

    // Collect any Manna that is already due before deciding.
    manna.tick();
    final result = resolveGeneratorTap(
      gen: gen,
      manna: manna.manna,
      hasFreeCell: _hasSpaceForItem(),
      levels: generatorLevels[genId],
      chains: chainData,
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
    _log.fine('Generator $genId spawned ${item.itemId}, manna=${manna.manna}');
  }

  bool _hasSpaceForItem() {
    for (int c = 0; c < BoardGame.cols; c++) {
      for (int r = 0; r < BoardGame.rows; r++) {
        if (_board[c][r] == null && !_generatorCellSet.contains((c, r))) {
          return true;
        }
      }
    }
    return false;
  }
}
