// The splitting knife and the Golden Thread on the board (EXPANSION 20.3).
part of 'board_game.dart';

extension BoardTools on BoardGame {
  /// Uses the tool in ([fromCol], [fromRow]) on the item in ([toCol],
  /// [toRow]). The tool is used up: a knife leaves two items of the tier
  /// below (one in each cell), a wildcard raises the item one tier. Returns
  /// false, changing nothing, if the tool does nothing there.
  bool useToolOn(int fromCol, int fromRow, int toCol, int toRow) {
    bool onBoard(int c, int r) =>
        c >= 0 && c < gridCols && r >= 0 && r < gridRows;
    if (!onBoard(fromCol, fromRow) || !onBoard(toCol, toRow)) return false;
    if (fromCol == toCol && fromRow == toRow) return false;
    final tool = _board[fromCol][fromRow];
    final target = _board[toCol][toRow];
    if (tool == null || target == null) return false;
    final result = resolveTool(tool, target, chainData);
    final becomes = itemCatalog[result?.targetBecomes];
    if (result == null || becomes == null) return false;
    final left = itemCatalog[result.toolCellBecomes];
    _put(toCol, toRow, becomes);
    _put(fromCol, fromRow, left);
    _log.fine('${tool.itemId} on ${target.itemId} -> ${becomes.itemId}');
    // A wildcard is a merge in all but name: it sounds and counts as one.
    if (tool.use?.wild ?? false) onMerged?.call(becomes);
    _boardTouched();
    return true;
  }

  void _put(int col, int row, ItemModel? item) {
    _board[col][row] = item;
    if (item == null) {
      _cells[col][row].clearItem();
    } else {
      _cells[col][row].setItem(item, _colorFor(item), _art[item.itemId]);
    }
  }

  /// A tool let go over another item: if it does something there it is
  /// used. Returns whether it was.
  bool _dropTool(ItemComponent dragging, CellComponent origin) {
    if (!(dragging.item.use?.isTool ?? false)) return false;
    for (int c = 0; c < gridCols; c++) {
      for (int r = 0; r < gridRows; r++) {
        final cell = _cells[c][r];
        if (cell == origin || _generatorCellSet.contains((c, r))) continue;
        if (!cell.containsPoint(dragging.center)) continue;
        if (!useToolOn(origin.col, origin.row, c, r)) return false;
        dragging.removeFromParent();
        _dragging = null;
        _dragOriginCell = null;
        return true;
      }
    }
    return false;
  }
}
