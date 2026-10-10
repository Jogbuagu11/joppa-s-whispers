// Charged, free and temporary generators on the board: their clocks, the
// items a free one makes by itself, and removing one that is used up.
part of 'board_game.dart';

extension BoardGeneratorTypes on BoardGame {
  /// The level a newly arrived generator starts at: the lowest among the
  /// generators that stay (a purchase may have raised them all). A gifted
  /// temporary generator does not count, or it would hold later arrivals
  /// back at its own level.
  int get lowestLastingLevel => lowestLevel([
    for (final p in generatorPlacements)
      if (p.gen.rules.kind != GeneratorKind.temporary) p.gen.level,
  ]);

  /// The boost that applies to a tap right now: the one switched on, if it
  /// is (still) unlocked.
  GeneratorBoost get activeBoost {
    final index = boost.value - 1;
    if (index < 0 || index >= boosts.length) return GeneratorBoost.none;
    return (boostUnlocked?.call(index) ?? false)
        ? boosts[index]
        : GeneratorBoost.none;
  }

  /// Whether the player has any boost to switch on.
  bool get hasBoost => boosts.isNotEmpty && (boostUnlocked?.call(0) ?? false);

  /// Steps to the next boost the player has unlocked, then back to none.
  void cycleBoost() {
    var next = boost.value + 1;
    if (next > boosts.length || !(boostUnlocked?.call(next - 1) ?? false)) {
      next = 0;
    }
    boost.value = next;
    _boardTouched();
  }

  /// This generator's clock, started fresh the first time it is asked for.
  GeneratorTimer _timerFor(GeneratorModel gen) {
    final rules = gen.rules;
    final saved = generatorTimers[gen.generatorId];
    final timer = settled(rules, saved ?? freshTimer(rules, now()), now());
    if (rules.kind != GeneratorKind.standard) {
      generatorTimers[gen.generatorId] = timer;
    }
    return timer;
  }

  /// The small words on a generator tile: its Manna cost, charges left,
  /// time to wait, or taps left.
  String generatorLabel(GeneratorModel gen) {
    final rules = gen.rules;
    if (rules.kind == GeneratorKind.standard) {
      return '${gen.energyCost * boostFor(gen).mannaTimes}M';
    }
    final timer = _timerFor(gen);
    final wait = secondsToWait(rules, timer, now());
    if (wait != null) return formatWait(wait);
    return '×${timer.left}';
  }

  /// After a tap gave an item: one charge or tap fewer; a temporary
  /// generator that has given its last leaves the board.
  void _afterGave(GeneratorPlacement placement) {
    final gen = placement.gen;
    final rules = gen.rules;
    if (rules.kind == GeneratorKind.standard) return;
    final timer = afterGiving(rules, _timerFor(gen), now());
    generatorTimers[gen.generatorId] = timer;
    if (isUsedUp(rules, timer)) removeGenerator(gen.generatorId);
    _boardTouched();
  }

  /// Takes a generator off the board, leaving its cell free.
  void removeGenerator(String generatorId) {
    final index = generatorPlacements.indexWhere(
      (p) => p.gen.generatorId == generatorId,
    );
    if (index < 0) return;
    final placement = generatorPlacements.removeAt(index);
    generatorTimers.remove(generatorId);
    _generatorCellSet.remove((placement.col, placement.row));
    children
        .whereType<GeneratorComponent>()
        .where((c) => c.generator.generatorId == generatorId)
        .toList()
        .forEach(remove);
    _boardTouched();
  }

  /// Uses a time-skip on a generator. Returns false, changing nothing, if
  /// it has no wait to shorten ([seconds] null ends the wait).
  bool skipGeneratorWait(String generatorId, {int? seconds}) {
    final placement = generatorPlacements
        .where((p) => p.gen.generatorId == generatorId)
        .firstOrNull;
    if (placement == null) return false;
    final gen = placement.gen;
    final sooner = skipped(gen.rules, _timerFor(gen), now(), seconds: seconds);
    if (sooner == null) return false;
    generatorTimers[generatorId] = sooner;
    _boardTouched();
    return true;
  }

  /// Once a second: free generators make any item that is due, into a free
  /// cell next to them.
  void _tickGenerators(double dt) {
    if (!_built) return;
    _sinceGeneratorTick += dt;
    if (_sinceGeneratorTick < 1) return;
    _sinceGeneratorTick = 0;
    for (final placement in generatorPlacements.toList()) {
      final gen = placement.gen;
      if (gen.rules.kind != GeneratorKind.free) continue;
      final cells = _freeCellsBeside(placement.col, placement.row);
      final due = freeItemsDue(
        gen.rules,
        _timerFor(gen),
        now(),
        room: cells.length,
      );
      if (due.items == 0) continue;
      final levels = generatorLevels[gen.generatorId];
      if (levels == null || levels.isEmpty) continue;
      final levelData = levels.firstWhere(
        (l) => l.level == gen.level,
        orElse: () => levels.first,
      );
      for (var i = 0; i < due.items; i++) {
        final itemId = resolveSpawnedItemId(
          gen.chainId,
          spawnTier(levelData),
          chainData,
        );
        final item = itemCatalog[itemId];
        if (item == null) continue;
        final (col, row) = cells[i];
        _board[col][row] = item;
        _cells[col][row].setItem(item, _colorFor(item), _art[item.itemId]);
      }
      generatorTimers[gen.generatorId] = due.timer;
      _boardTouched();
    }
  }

  /// The empty cells touching ([col], [row]), corners included.
  List<(int, int)> _freeCellsBeside(int col, int row) => [
    for (int c = col - 1; c <= col + 1; c++)
      for (int r = row - 1; r <= row + 1; r++)
        if (c >= 0 &&
            c < gridCols &&
            r >= 0 &&
            r < gridRows &&
            _board[c][r] == null &&
            !_generatorCellSet.contains((c, r)) &&
            _dragOriginCell != _cells[c][r])
          (c, r),
  ];

  void _onItemTapped(int col, int row) {
    final item = _board[col][row];
    if (item == null) return;
    final jar = item.use?.jar != null;
    final usable = jar || (item.use?.givesManna ?? false);
    final sellable = canSell(item);
    if (item.use == null && !sellable) return;
    onItemAsked?.call(
      item,
      // A Jar of Clay only leaves the board here: the screen draws what
      // was in it.
      use: !usable
          ? null
          : jar
          ? () => _takeItemAt(col, row, item)
          : () => useItemAt(col, row, only: item),
      sell: sellable ? () => sellItemAt(col, row, only: item) : null,
    );
  }

  /// Whether [item] can be sold from the board: anything from a side chain
  /// (rare finds, gifts) and anything that cannot be merged any further, so
  /// nothing can ever be stuck on the board for good. Never something an
  /// order on show is asking for, and never with nobody to pay for it.
  bool canSell(ItemModel item) {
    if (item.sell <= 0 || onSold == null) return false;
    if (wantedByOrder?.call(item.itemId) ?? false) return false;
    final top = chainData[item.chainId]?.maxTier;
    return sideChains.contains(item.chainId) ||
        (top != null && item.tier >= top);
  }

  /// Sells the item in ([col], [row]): it leaves the board and is paid for.
  /// Returns false, changing nothing, if it is no longer there to sell (or
  /// the cell now holds something other than [only]).
  bool sellItemAt(int col, int row, {ItemModel? only}) {
    final item = _itemToTake(col, row, only);
    if (item == null || !canSell(item)) return false;
    _board[col][row] = null;
    _cells[col][row].clearItem();
    onSold?.call(item);
    _boardTouched();
    return true;
  }

  /// Uses the Manna item in ([col], [row]): it leaves the board and its
  /// Manna is added (over the bar if need be). Returns false, changing
  /// nothing, if that cell no longer holds such an item (or holds something
  /// other than [only]).
  bool useItemAt(int col, int row, {ItemModel? only}) {
    final use = _itemToTake(col, row, only)?.use;
    if (use == null || !use.givesManna) return false;
    _board[col][row] = null;
    _cells[col][row].clearItem();
    manna.add(use.manna);
    _boardTouched();
    return true;
  }

  /// Takes exactly [only] off the board from ([col], [row]). Returns false,
  /// changing nothing, if it is no longer there.
  bool _takeItemAt(int col, int row, ItemModel only) {
    if (_itemToTake(col, row, only) == null) return false;
    _board[col][row] = null;
    _cells[col][row].clearItem();
    _boardTouched();
    return true;
  }

  /// The item in ([col], [row]) if it may be taken off the board: any drag
  /// is ended first (a lifted item goes back to its cell), and if [only] is
  /// given the cell must still hold exactly that item.
  ItemModel? _itemToTake(int col, int row, ItemModel? only) {
    if (col < 0 || col >= gridCols || row < 0 || row >= gridRows) return null;
    _putBackDragged();
    final item = _board[col][row];
    return only == null || identical(item, only) ? item : null;
  }

  /// An hourglass let go over a generator: if that generator is waiting,
  /// the wait is shortened and the hourglass is used up. Returns whether
  /// it was.
  bool _dropOnGenerator(ItemComponent dragging, CellComponent origin) {
    final use = dragging.item.use;
    if (use == null || !use.skipsTime) return false;
    for (final placement in generatorPlacements) {
      final cell = _cells[placement.col][placement.row];
      if (!cell.containsPoint(dragging.center)) continue;
      final used = skipGeneratorWait(
        placement.gen.generatorId,
        seconds: use.skipAll ? null : use.skipSeconds,
      );
      if (!used) return false;
      _board[origin.col][origin.row] = null;
      dragging.removeFromParent();
      _dragging = null;
      _dragOriginCell = null;
      _boardTouched();
      return true;
    }
    return false;
  }
}
