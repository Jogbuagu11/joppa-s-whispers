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
import 'package:whispers_of_joppa/game/board/manna_controller.dart';

part 'board_game_drag.dart';

final _log = Logger('BoardGame');

/// A generator placement — which cell on the board it sits in.
typedef GeneratorPlacement = ({GeneratorModel gen, int col, int row});

/// An item that starts on the board, and the cell it starts in.
typedef ItemPlacement = ({ItemModel item, int col, int row});

/// The Flame game for the merge board.
class BoardGame extends FlameGame with DragCallbacks {
  static const int cols = BoardState.cols;
  static const int rows = BoardState.rows;

  final Map<String, ItemModel> itemCatalog;
  final Map<String, ChainTierData> chainData;
  final Map<String, List<GeneratorLevelData>> generatorLevels;
  final List<GeneratorPlacement> generatorPlacements;
  final List<ItemPlacement> startingItems;

  /// chain_id -> ARGB colour for placeholder tiles (from content).
  final Map<String, int> chainPlaceholderColors;

  /// Owns the Manna count and its regen; shared with the Manna bar.
  final MannaController manna;

  /// Called when a generator is tapped without enough Manna.
  final VoidCallback onOutOfManna;

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

  // Set of (col, row) positions occupied by generators.
  final Set<(int, int)> _generatorCellSet = {};

  BoardGame({
    required this.itemCatalog,
    required this.chainData,
    required this.generatorLevels,
    required this.generatorPlacements,
    required this.startingItems,
    required this.chainPlaceholderColors,
    required this.manna,
    required this.onOutOfManna,
  });

  @override
  Color backgroundColor() => const Color(0xFF1A1205);

  @override
  Future<void> onLoad() async {
    _buildCells();
    _buildGenerators();
    for (final start in startingItems) {
      final free =
          _board[start.col][start.row] == null &&
          !_generatorCellSet.contains((start.col, start.row));
      if (!free) {
        _log.warning('Starting cell ${start.col},${start.row} is taken');
        continue;
      }
      _board[start.col][start.row] = start.item;
      _cells[start.col][start.row].setItem(start.item, _colorFor(start.item));
    }
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

  // Grey is the fallback when a chain has no placeholder colour in content.
  Color _colorFor(ItemModel item) =>
      Color(chainPlaceholderColors[item.chainId] ?? 0xFF888888);

  double get _cellSize {
    final maxW = size.x / cols;
    final maxH = size.y / rows;
    return (maxW < maxH ? maxW : maxH) - 2;
  }

  /// Places an item in the first empty non-generator cell.
  void placeItem(ItemModel item) {
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (_board[c][r] == null && !_generatorCellSet.contains((c, r))) {
          _board[c][r] = item;
          _cells[c][r].setItem(item, _colorFor(item));
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
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (_board[c][r] == null && !_generatorCellSet.contains((c, r))) {
          return true;
        }
      }
    }
    return false;
  }

  // --- Drag handling (logic lives in board_game_drag.dart) ---

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _dragStart(event);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _dragUpdate(event);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _dragEnd(event);
  }
}
