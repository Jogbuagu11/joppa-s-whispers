// What a new chapter brings onto the board. Pure Dart, fully unit tested.
import 'package:whispers_of_joppa/domain/models.dart';

/// The generators the player should have by [chapter] but does not have yet
/// ([have] = ids already on the board).
List<StartingGenerator> generatorsOwed(
  List<StartingGenerator> all,
  Set<String> have,
  int chapter,
) => [
  for (final g in all)
    if (g.chapter <= chapter && !have.contains(g.generatorId)) g,
];

/// Where a new generator goes: its home cell if nothing is there, otherwise
/// the free cell nearest to home. Null when the board has no free cell (the
/// generator then waits until one opens up).
({int col, int row})? cellForNewGenerator({
  required int homeCol,
  required int homeRow,
  required Set<(int, int)> taken,
  required int cols,
  required int rows,
}) {
  ({int col, int row})? best;
  var bestDistance = 1 << 30;
  for (int c = 0; c < cols; c++) {
    for (int r = 0; r < rows; r++) {
      if (taken.contains((c, r))) continue;
      final distance = (c - homeCol).abs() + (r - homeRow).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = (col: c, row: r);
      }
    }
  }
  return best;
}

/// The level a newly arrived generator starts at: the lowest level among the
/// generators the player already has (1 if there are none), so it is never
/// behind them.
int lowestLevel(List<int> levels) {
  var lowest = 0;
  for (final level in levels) {
    if (lowest == 0 || level < lowest) lowest = level;
  }
  return lowest < 1 ? 1 : lowest;
}
