// The Flame game that runs the 7x9 merge board.
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/generator_types.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/domain/tools.dart';
import 'package:whispers_of_joppa/domain/unlocks.dart';
import 'package:whispers_of_joppa/app/board_inventory.dart';
import 'package:whispers_of_joppa/data/asset_names.dart';
import 'package:whispers_of_joppa/domain/board_grid.dart';
import 'package:whispers_of_joppa/game/board/cell_component.dart';
import 'package:whispers_of_joppa/game/board/generator_component.dart';
import 'package:whispers_of_joppa/game/board/item_component.dart';
import 'package:whispers_of_joppa/game/board/manna_controller.dart';

part 'board_game_art.dart';
part 'board_game_drag.dart';
part 'board_game_generator_types.dart';
part 'board_game_layout.dart';
part 'board_game_generators.dart';
part 'board_game_tools.dart';

final _log = Logger('BoardGame');

/// A generator placement — which cell on the board it sits in.
typedef GeneratorPlacement = ({GeneratorModel gen, int col, int row});

/// An item that starts on the board, and the cell it starts in.
typedef ItemPlacement = ({ItemModel item, int col, int row});

/// The Flame game for the merge board.
class BoardGame extends FlameGame with DragCallbacks implements BoardInventory {
  static const int cols = BoardState.cols;
  static const int rows = BoardState.rows;

  /// This board's own size (an event board is smaller than the main one).
  final int gridCols;
  final int gridRows;

  /// Called with the new item after two items merge.
  void Function(ItemModel merged)? onMerged;

  /// The cell of the latest merge (set just before [onMerged] is called).
  (int, int)? lastMergeCell;

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

  /// Called after two items merge, and after a generator spawns an item.
  VoidCallback? onMerge;

  /// Called after a generator spawns an item; [wasFree] is true when the tap
  /// cost nothing.
  void Function({required bool wasFree})? onGeneratorSpawn;

  /// Whether every item shows its tier number (the player's choice).
  bool showTierNumbers = false;

  /// generator id -> its charges or countdown (charged, free and temporary
  /// generators only).
  final Map<String, GeneratorTimer> generatorTimers;

  /// The time (tests pass their own).
  final DateTime Function() now;

  /// Called when an item that can be used or sold is tapped. [use] and
  /// [sell] do it (null if that is not possible for this item) and return
  /// false if the item was no longer there. The screen asks first.
  void Function(ItemModel item, {bool Function()? use, bool Function()? sell})?
  onItemAsked;

  /// Called with an item just sold, to pay for it.
  void Function(ItemModel item)? onSold;

  /// Chains no generator makes (rare finds, gifts): always sellable.
  Set<String> sideChains = const {};

  /// Whether an order on show asks for this item (so it is not for sale).
  bool Function(String itemId)? wantedByOrder;

  /// False while rare drops are held back (the tutorial).
  bool Function()? rareDrops;

  /// The generator boosts there are (weakest first), which of them the
  /// player has unlocked, and the one switched on (0 = none, 1 = the first…).
  List<GeneratorBoost> boosts = const [];
  bool Function(int index)? boostUnlocked;
  final ValueNotifier<int> boost = ValueNotifier<int>(0);

  /// When this returns true, generator taps cost nothing (tutorial).
  bool Function()? freeGeneratorTaps;

  // 2D array of cell visuals [col][row]
  late List<List<CellComponent>> _cells;

  // Item being dragged, and the cell it started from.
  ItemComponent? _dragging;
  CellComponent? _dragOriginCell;

  // Board data: item placed in each cell (null = empty).
  late final List<List<ItemModel?>> _board = List.generate(
    gridCols,
    (_) => List.generate(gridRows, (_) => null),
  );

  final ValueNotifier<int> _boardVersion = ValueNotifier<int>(0);

  @override
  Listenable get boardChanged => _boardVersion;

  /// Call after any change to which items are on the board. Listeners are
  /// told just afterwards, never in the middle of drawing the screen (the
  /// board is first filled while Flutter is still building it).
  void _boardTouched() => Future<void>.microtask(() => _boardVersion.value++);

  @override
  Map<String, int> itemCounts() => countItems(_board);

  @override
  bool removeItems(Map<String, int> counts) {
    // An item being dragged is put back first, so it cannot be delivered and
    // then dropped back onto the board.
    _putBackDragged();
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

  // "<generator id>_l<level>" -> loaded picture, where one exists.
  final Map<String, ui.Image> _generatorArt = {};

  // item_id -> loaded picture, for items whose art file exists.
  final Map<String, ui.Image> _art = {};

  // Seconds since free generators were last looked at.
  double _sinceGeneratorTick = 0;

  // True once the cells, generators and starting items are in place.
  bool _built = false;

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
    this.gridCols = cols,
    this.gridRows = rows,
    Map<String, GeneratorTimer>? generatorTimers,
    DateTime Function()? clock,
  }) : generatorTimers = generatorTimers ?? {},
       now = clock ?? DateTime.now;

  @override
  // See-through: the screen behind the board shows between the tiles.
  Color backgroundColor() => const Color(0x00000000);

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
    _built = true;
    _boardTouched();
  }

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

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _relayout();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _tickGenerators(dt);
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
