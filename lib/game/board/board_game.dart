// The Flame game that runs the 7x9 merge board.
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/app/board_inventory.dart';
import 'package:whispers_of_joppa/domain/board_grid.dart';
import 'package:whispers_of_joppa/game/board/cell_component.dart';
import 'package:whispers_of_joppa/game/board/generator_component.dart';
import 'package:whispers_of_joppa/game/board/item_component.dart';
import 'package:whispers_of_joppa/game/board/manna_controller.dart';

part 'board_game_drag.dart';
part 'board_game_generators.dart';

final _log = Logger('BoardGame');

/// A generator placement — which cell on the board it sits in.
typedef GeneratorPlacement = ({GeneratorModel gen, int col, int row});

/// An item that starts on the board, and the cell it starts in.
typedef ItemPlacement = ({ItemModel item, int col, int row});

/// The Flame game for the merge board.
class BoardGame extends FlameGame with DragCallbacks implements BoardInventory {
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

  final ValueNotifier<int> _boardVersion = ValueNotifier<int>(0);

  @override
  Listenable get boardChanged => _boardVersion;

  /// Call after any change to which items are on the board. Listeners are
  /// told just afterwards, never in the middle of drawing the screen (the
  /// board is first filled while Flutter is still building it).
  void _boardTouched() => Future<void>.microtask(() => _boardVersion.value++);

  /// Every item on the board with its cell (written to the save file).
  List<SavedItem> snapshotItems() => [
    for (int c = 0; c < cols; c++)
      for (int r = 0; r < rows; r++)
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
      ),
  ];

  @override
  Map<String, int> itemCounts() => countItems(_board);

  @override
  bool removeItems(Map<String, int> counts) {
    // An item being dragged is put back first, so it cannot be delivered and
    // then dropped back onto the board.
    final dragging = _dragging;
    final origin = _dragOriginCell;
    if (dragging != null && origin != null) {
      _snapBack(dragging, origin, dragging.item);
    }
    final cells = cellsToRemove(_board, counts);
    if (cells == null) {
      _log.warning('Board does not hold $counts; nothing removed');
      return false;
    }
    for (final cell in cells) {
      _board[cell.col][cell.row] = null;
      _cells[cell.col][cell.row].clearItem();
    }
    _boardTouched();
    return true;
  }

  // item_id -> loaded picture, for items whose art file exists.
  final Map<String, ui.Image> _art = {};

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
      _cells[start.col][start.row].setItem(
        start.item,
        _colorFor(start.item),
        _art[start.item.itemId],
      );
    }
    _boardTouched();
  }

  /// Loads the picture for every item that names one. An item whose picture
  /// is missing or unreadable keeps its coloured placeholder. BoardScreen
  /// calls this before showing the board so the first frame already has art.
  Future<void> loadArt() async {
    images.prefix = '';
    await Future.wait([
      for (final item in itemCatalog.values)
        if (item.asset.isNotEmpty) _loadArtFor(item),
    ]);
  }

  Future<void> _loadArtFor(ItemModel item) async {
    try {
      _art[item.itemId] = await images.load(item.asset);
    } on Exception catch (e) {
      _log.warning('No art for ${item.itemId} at ${item.asset}: $e');
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
