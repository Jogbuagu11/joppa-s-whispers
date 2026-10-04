// The Flame game that runs the 7x9 merge board.
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/game/board/cell_component.dart';
import 'package:whispers_of_joppa/game/board/item_component.dart';

final _log = Logger('BoardGame');

/// The Flame game for the merge board.
class BoardGame extends FlameGame with DragCallbacks {
  static const int cols = BoardState.cols;
  static const int rows = BoardState.rows;

  final Map<String, ItemModel> itemCatalog;
  final Map<String, ChainTierData> chainData;

  // 2D array of cell visuals [col][row]
  late List<List<CellComponent>> _cells;

  // Item being dragged, and the cell it started from.
  ItemComponent? _dragging;
  CellComponent? _dragOriginCell;

  // Board data: item placed in each cell (null = empty).
  final List<List<ItemModel?>> _board = List.generate(
    cols, (_) => List.generate(rows, (_) => null),
  );

  BoardGame({required this.itemCatalog, required this.chainData});

  @override
  Color backgroundColor() => const Color(0xFF1A1205);

  @override
  Future<void> onLoad() async {
    _buildCells();
  }

  void _buildCells() {
    final cellSize = _cellSize;
    final offsetX = (size.x - cols * cellSize) / 2;
    final offsetY = (size.y - rows * cellSize) / 2;

    _cells = List.generate(cols, (c) {
      return List.generate(rows, (r) {
        final cell = CellComponent(
          col: c,
          row: r,
          cellSize: cellSize,
          position: Vector2(offsetX + c * cellSize, offsetY + r * cellSize),
        );
        add(cell);
        return cell;
      });
    });
  }

  double get _cellSize {
    final maxW = size.x / cols;
    final maxH = size.y / rows;
    return (maxW < maxH ? maxW : maxH) - 2;
  }

  /// Called by BoardScreen to place an item in the first empty cell.
  void placeItem(ItemModel item) {
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (_board[c][r] == null) {
          _board[c][r] = item;
          _cells[c][r].setItem(item, this);
          return;
        }
      }
    }
    _log.warning('No empty cell to place item ${item.itemId}');
  }

  // --- Drag handling ---

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    // Find item under the touch point.
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        final cell = _cells[c][r];
        if (_board[c][r] != null && cell.containsPoint(event.canvasPosition)) {
          _dragOriginCell = cell;
          _dragging = cell.liftItem();
          if (_dragging != null) {
            add(_dragging!);
            _dragging!.position = event.canvasPosition - Vector2(_cellSize / 2, _cellSize / 2);
          }
          return;
        }
      }
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (_dragging != null) {
      _dragging!.position += event.localDelta;
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final dragging = _dragging;
    if (dragging == null) return;

    // Find the target cell under the drag end point.
    CellComponent? target;
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (_cells[c][r].containsPoint(dragging.center)) {
          target = _cells[c][r];
          break;
        }
      }
      if (target != null) break;
    }

    final origin = _dragOriginCell!;
    final originItem = dragging.item;

    if (target == null || target == origin) {
      // No valid target — snap back.
      _snapBack(dragging, origin, originItem);
      return;
    }

    final targetItem = _board[target.col][target.row];

    if (targetItem == null) {
      // Move to empty cell.
      _board[origin.col][origin.row] = null;
      _board[target.col][target.row] = originItem;
      dragging.removeFromParent();
      target.setItem(originItem, this);
    } else {
      // Try to merge.
      final result = canMerge(originItem, targetItem, chainData);
      if (result == MergeResult.success) {
        final mergedId = mergedItemId(originItem, chainData);
        final merged = itemCatalog[mergedId];
        if (merged != null) {
          _board[origin.col][origin.row] = null;
          _board[target.col][target.row] = merged;
          dragging.removeFromParent();
          target.setItem(merged, this);
          _log.fine('Merged ${originItem.itemId} -> ${merged.itemId}');
        } else {
          _snapBack(dragging, origin, originItem);
        }
      } else {
        // Invalid drop — snap back.
        _snapBack(dragging, origin, originItem);
      }
    }

    _dragging = null;
    _dragOriginCell = null;
  }

  void _snapBack(ItemComponent dragging, CellComponent origin, ItemModel item) {
    dragging.removeFromParent();
    origin.setItem(item, this);
    _board[origin.col][origin.row] = item;
    _dragging = null;
    _dragOriginCell = null;
  }
}
