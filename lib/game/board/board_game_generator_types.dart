// Charged, free and temporary generators on the board: their clocks, the
// items a free one makes by itself, and removing one that is used up.
part of 'board_game.dart';

extension BoardGeneratorTypes on BoardGame {
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
    if (rules.kind == GeneratorKind.standard) return '${gen.energyCost}M';
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
}
