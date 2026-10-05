// Counting and removing items on the board grid — pure Dart, unit tested.
import 'package:whispers_of_joppa/domain/models.dart';

/// item_id -> how many are in [grid] ([col][row], null = empty cell).
Map<String, int> countItems(List<List<ItemModel?>> grid) {
  final counts = <String, int>{};
  for (final column in grid) {
    for (final item in column) {
      if (item != null) counts[item.itemId] = (counts[item.itemId] ?? 0) + 1;
    }
  }
  return counts;
}

/// The cells to empty so that [wanted] (item_id -> count) leaves the board,
/// scanning column by column. Returns null, removing nothing, if the board
/// does not hold everything wanted.
List<({int col, int row})>? cellsToRemove(
  List<List<ItemModel?>> grid,
  Map<String, int> wanted,
) {
  final left = Map<String, int>.of(wanted)..removeWhere((_, n) => n <= 0);
  final cells = <({int col, int row})>[];
  for (int c = 0; c < grid.length; c++) {
    for (int r = 0; r < grid[c].length; r++) {
      final id = grid[c][r]?.itemId;
      final want = left[id] ?? 0;
      if (id == null || want <= 0) continue;
      cells.add((col: c, row: r));
      if (want == 1) {
        left.remove(id);
      } else {
        left[id] = want - 1;
      }
    }
  }
  return left.isEmpty ? cells : null;
}
