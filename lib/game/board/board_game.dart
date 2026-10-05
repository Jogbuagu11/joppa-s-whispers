// The Flame game that runs the 7x9 merge board.
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/game/board/cell_component.dart';
import 'package:whispers_of_joppa/game/board/generator_component.dart';
import 'package:whispers_of_joppa/game/board/item_component.dart';

final _log = Logger('BoardGame');

/// A generator placement — which cell on the board it sits in.
typedef GeneratorPlacement = ({GeneratorModel gen, int col, int row});

/// The Flame game for the merge board.
class BoardGame extends FlameGame with DragCallbacks {
  static const int cols = BoardState.cols;
  static const int rows = BoardState.rows;

  final Map<String, ItemModel> itemCatalog;
  final Map<String, ChainTierData> chainData;
  final Map<String, List<GeneratorLevelData>> generatorLevels;
  final List<GeneratorPlacement> generatorPlacements;

  // Manna exposed to Flutter layer via ValueNotifier.
  final ValueNotifier<int> mannaNotifier;
  int _manna;

  // 2D array of cell visuals [col][row]
  late List<List<CellComponent>> _cells;

  // Item being dragged, and the cell it started from.
  ItemComponent? _dragging;
  CellComponent? _dragOriginCell;

  // Board data: item placed in each cell (null = empty).
  final List<List<ItemModel?>> _board = List.generate(
    cols,
    (_) => List.generate(rows, (_) => null),
  );

  // Items handed to placeItem before the board was built; placed in onLoad.
  final List<ItemModel> _pendingItems = [];
  bool _boardBuilt = false;

  // Set of (col, row) positions occupied by generators.
  final Set<(int, int)> _generatorCellSet = {};

  BoardGame({
    required this.itemCatalog,
    required this.chainData,
    required this.generatorLevels,
    required this.generatorPlacements,
    int initialManna = 10,
  }) : _manna = initialManna,
       mannaNotifier = ValueNotifier<int>(initialManna);

  @override
  Color backgroundColor() => const Color(0xFF1A1205);

  @override
  Future<void> onLoad() async {
    _buildCells();
    _buildGenerators();
    _boardBuilt = true;
    for (final item in _pendingItems) {
      placeItem(item);
    }
    _pendingItems.clear();
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

  void _buildGenerators() {
    final cellSize = _cellSize;
    final offsetX = (size.x - cols * cellSize) / 2;
    final offsetY = (size.y - rows * cellSize) / 2;

    for (final placement in generatorPlacements) {
      _generatorCellSet.add((placement.col, placement.row));
      final genComp = GeneratorComponent(
        generator: placement.gen,
        onTapped: _onGeneratorTapped,
        position: Vector2(
          offsetX + placement.col * cellSize,
          offsetY + placement.row * cellSize,
        ),
        cellSize: cellSize,
      );
      add(genComp);
    }
  }

  double get _cellSize {
    final maxW = size.x / cols;
    final maxH = size.y / rows;
    return (maxW < maxH ? maxW : maxH) - 2;
  }

  /// Called by BoardScreen to place an item in the first empty non-generator cell.
  void placeItem(ItemModel item) {
    if (!_boardBuilt) {
      _pendingItems.add(item);
      return;
    }
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (_board[c][r] == null && !_generatorCellSet.contains((c, r))) {
          _board[c][r] = item;
          _cells[c][r].setItem(item, this);
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

    final result = resolveGeneratorTap(
      gen: gen,
      manna: _manna,
      hasFreeCell: _hasSpaceForItem(),
      levels: generatorLevels[genId],
      chains: chainData,
    );
    final item = itemCatalog[result.itemId];
    if (!result.spawned || item == null) {
      _log.info(
        'Generator $genId did not spawn: ${result.refusal ?? 'item ${result.itemId} not in catalog'}',
      );
      return;
    }

    _manna = result.mannaAfter;
    mannaNotifier.value = _manna;
    placeItem(item);
    _log.fine('Generator $genId spawned ${item.itemId}, manna=$_manna');
  }

  bool _hasSpaceForItem() {
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (_board[c][r] == null && !_generatorCellSet.contains((c, r))) {
          return true;
        }
      }
    }
    return false;
  }

  // --- Drag handling ---

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
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

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _dragging?.position += event.localDelta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final dragging = _dragging;
    final origin = _dragOriginCell;
    if (dragging == null || origin == null) return;

    CellComponent? target;
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
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
      target.setItem(originItem, this);
    } else {
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
