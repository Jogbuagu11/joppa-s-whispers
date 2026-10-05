import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/board_grid.dart';
import 'package:whispers_of_joppa/domain/models.dart';

ItemModel _item(String id) =>
    ItemModel(itemId: id, chainId: 'bakery', tier: 1, name: '', asset: '');

/// A 3-column, 2-row grid: [col][row].
List<List<ItemModel?>> _grid() => [
  [_item('bakery_01'), _item('fruit_01')],
  [_item('bakery_01'), null],
  [_item('bakery_01'), _item('bakery_02')],
];

void main() {
  test('countItems counts each kind', () {
    expect(countItems(_grid()), {
      'bakery_01': 3,
      'fruit_01': 1,
      'bakery_02': 1,
    });
    expect(
      countItems([
        [null],
        [null],
      ]),
      isEmpty,
    );
  });

  group('cellsToRemove', () {
    test('picks exactly the number wanted, first cells first', () {
      expect(cellsToRemove(_grid(), {'bakery_01': 2}), [
        (col: 0, row: 0),
        (col: 1, row: 0),
      ]);
    });

    test('leaves the extras when the board has more than wanted', () {
      final cells = cellsToRemove(_grid(), {'bakery_01': 1});
      expect(cells, [(col: 0, row: 0)]);
    });

    test('handles two different items at once', () {
      expect(cellsToRemove(_grid(), {'bakery_02': 1, 'fruit_01': 1}), [
        (col: 0, row: 1),
        (col: 2, row: 1),
      ]);
    });

    test('returns null, removing nothing, when the board is short', () {
      expect(cellsToRemove(_grid(), {'bakery_01': 4}), isNull);
      expect(cellsToRemove(_grid(), {'fruit_01': 1, 'oil_01': 1}), isNull);
    });

    test('asking for nothing removes nothing', () {
      expect(cellsToRemove(_grid(), {}), isEmpty);
      expect(cellsToRemove(_grid(), {'bakery_01': 0}), isEmpty);
    });
  });
}
