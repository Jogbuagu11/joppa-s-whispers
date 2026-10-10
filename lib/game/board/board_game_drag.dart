// Drag, drop and merge handling for the board.
part of 'board_game.dart';

extension _BoardDrag on BoardGame {
  void _dragStart(DragStartEvent event) {
    for (int c = 0; c < gridCols; c++) {
      for (int r = 0; r < gridRows; r++) {
        final cell = _cells[c][r];
        final hasItem = _board[c][r] != null;
        final isGenCell = _generatorCellSet.contains((c, r));
        if (hasItem && !isGenCell && cell.containsPoint(event.canvasPosition)) {
          final lifted = cell.liftItem();
          if (lifted == null) return;
          _dragOriginCell = cell;
          _dragging = lifted;
          add(lifted);
          lifted.position =
              event.canvasPosition - Vector2(_cellSize / 2, _cellSize / 2);
          return;
        }
      }
    }
  }

  void _dragUpdate(DragUpdateEvent event) {
    _dragging?.position += event.localDelta;
  }

  void _dragEnd(DragEndEvent event) {
    final dragging = _dragging;
    final origin = _dragOriginCell;
    if (dragging == null || origin == null) return;
    if (_dropOnGenerator(dragging, origin)) return;

    CellComponent? target;
    for (int c = 0; c < gridCols; c++) {
      for (int r = 0; r < gridRows; r++) {
        if (!_generatorCellSet.contains((c, r)) &&
            _cells[c][r].containsPoint(dragging.center)) {
          target = _cells[c][r];
          break;
        }
      }
      if (target != null) break;
    }

    final originItem = dragging.item;

    if (target == null || target == origin) {
      _snapBack(dragging, origin, originItem);
      return;
    }

    final targetItem = _board[target.col][target.row];

    if (targetItem == null) {
      _board[origin.col][origin.row] = null;
      _board[target.col][target.row] = originItem;
      dragging.removeFromParent();
      target.setItem(
        originItem,
        _colorFor(originItem),
        _art[originItem.itemId],
      );
      _boardTouched();
    } else {
      final result = canMerge(originItem, targetItem, chainData);
      if (result == MergeResult.success) {
        final mergedId = mergedItemId(originItem, chainData);
        final merged = itemCatalog[mergedId];
        if (merged != null) {
          _board[origin.col][origin.row] = null;
          _board[target.col][target.row] = merged;
          dragging.removeFromParent();
          target.setItem(merged, _colorFor(merged), _art[merged.itemId]);
          _log.fine('Merged ${originItem.itemId} -> ${merged.itemId}');
          _boardTouched();
          onMerge?.call();
          onMerged?.call(merged);
        } else {
          _snapBack(dragging, origin, originItem);
        }
      } else {
        _snapBack(dragging, origin, originItem);
      }
    }

    _dragging = null;
    _dragOriginCell = null;
  }

  void _snapBack(ItemComponent dragging, CellComponent origin, ItemModel item) {
    dragging.removeFromParent();
    origin.setItem(item, _colorFor(item), _art[item.itemId]);
    _board[origin.col][origin.row] = item;
    _dragging = null;
    _dragOriginCell = null;
  }
}
