import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';

SaveState _sample() => SaveState(
  items: const [
    SavedItem(itemId: 'bakery_01', col: 0, row: 0),
    SavedItem(itemId: 'fruit_02', col: 3, row: 4),
  ],
  generators: const [
    SavedGenerator(generatorId: 'gen_pantry', level: 2, col: 2, row: 8),
  ],
  manna: 42,
  mannaLastRegen: DateTime.utc(2040, 1, 1, 12, 30),
  talents: 120,
  blessings: 3,
  activeOrders: const ['ch1_o_004', 'ch1_o_002'],
  pendingOrders: const ['ch1_o_005'],
  lastOrderSkip: DateTime.utc(2040, 1, 1, 12),
);

SaveState _clean(SaveState s, {int maxManna = 100}) => sanitizeSave(
  s,
  itemIds: {'bakery_01', 'fruit_02'},
  generatorIds: {'gen_pantry'},
  orderIds: {'ch1_o_004', 'ch1_o_002', 'ch1_o_005'},
  cols: 7,
  rows: 9,
  maxManna: maxManna,
);

void main() {
  test('a save survives being written and read back exactly', () {
    final text = jsonEncode(_sample().toJson());
    final back = SaveState.fromJson(jsonDecode(text) as Map<String, dynamic>);
    expect(back.items.length, 2);
    expect(back.items[1].itemId, 'fruit_02');
    expect(back.items[1].col, 3);
    expect(back.items[1].row, 4);
    expect(back.generators.single.generatorId, 'gen_pantry');
    expect(back.generators.single.level, 2);
    expect(back.generators.single.col, 2);
    expect(back.generators.single.row, 8);
    expect(back.manna, 42);
    expect(back.mannaLastRegen, DateTime.utc(2040, 1, 1, 12, 30));
    expect(back.talents, 120);
    expect(back.blessings, 3);
    expect(back.activeOrders, ['ch1_o_004', 'ch1_o_002']);
    expect(back.pendingOrders, ['ch1_o_005']);
    expect(back.lastOrderSkip, DateTime.utc(2040, 1, 1, 12));
  });

  test('the save records its version', () {
    expect(_sample().toJson()['save_version'], currentSaveVersion);
  });

  test('a save with no skip time reads back as null', () {
    final json = _sample().toJson()..['last_order_skip'] = null;
    expect(SaveState.fromJson(json).lastOrderSkip, isNull);
  });

  group('migrateSave', () {
    test('keeps a current save as it is', () {
      final json = _sample().toJson();
      expect(migrateSave(json), json);
    });
    test('rejects a save with no version', () {
      final json = _sample().toJson()..remove('save_version');
      expect(() => migrateSave(json), throwsFormatException);
    });
    test('rejects a save from a newer app', () {
      final json = _sample().toJson()
        ..['save_version'] = currentSaveVersion + 1;
      expect(() => migrateSave(json), throwsFormatException);
    });
  });

  test('a save with a missing field is rejected, not crashed on', () {
    final json = _sample().toJson()..remove('manna');
    expect(() => SaveState.fromJson(json), throwsFormatException);
  });

  group('sanitizeSave', () {
    test('a good save is unchanged', () {
      final s = _clean(_sample());
      expect(s.items.length, 2);
      expect(s.generators.length, 1);
      expect(s.activeOrders, ['ch1_o_004', 'ch1_o_002']);
      expect(s.pendingOrders, ['ch1_o_005']);
      expect(s.manna, 42);
    });

    test('unknown items, generators and orders are dropped', () {
      final s = sanitizeSave(
        _sample(),
        itemIds: {'bakery_01'},
        generatorIds: {},
        orderIds: {'ch1_o_002'},
        cols: 7,
        rows: 9,
        maxManna: 100,
      );
      expect([for (final i in s.items) i.itemId], ['bakery_01']);
      expect(s.generators, isEmpty);
      expect(s.activeOrders, ['ch1_o_002']);
      expect(s.pendingOrders, isEmpty);
    });

    test('things off the board or sharing a cell are dropped', () {
      final base = _sample();
      final s = _clean(
        SaveState(
          items: const [
            SavedItem(itemId: 'bakery_01', col: 2, row: 8), // on the generator
            SavedItem(itemId: 'bakery_01', col: 7, row: 0), // off the board
            SavedItem(itemId: 'bakery_01', col: 1, row: 1),
            SavedItem(itemId: 'fruit_02', col: 1, row: 1), // same cell
          ],
          generators: base.generators,
          manna: base.manna,
          mannaLastRegen: base.mannaLastRegen,
          talents: base.talents,
          blessings: base.blessings,
          activeOrders: base.activeOrders,
          pendingOrders: base.pendingOrders,
          lastOrderSkip: base.lastOrderSkip,
        ),
      );
      expect(s.generators.length, 1);
      expect(s.items.length, 1);
      expect(s.items.single.col, 1);
      expect(s.items.single.itemId, 'bakery_01');
    });

    test('numbers are kept within sensible limits', () {
      final base = _sample();
      final s = _clean(
        SaveState(
          items: base.items,
          generators: base.generators,
          manna: 500,
          mannaLastRegen: base.mannaLastRegen,
          talents: -5,
          blessings: -1,
          activeOrders: const ['ch1_o_004', 'ch1_o_004'],
          pendingOrders: const ['ch1_o_004', 'ch1_o_005'],
          lastOrderSkip: null,
        ),
      );
      expect(s.manna, 100);
      expect(s.talents, 0);
      expect(s.blessings, 0);
      expect(s.activeOrders, ['ch1_o_004']);
      expect(s.pendingOrders, ['ch1_o_005']);
    });
  });
}
