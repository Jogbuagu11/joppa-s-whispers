import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/save_repair.dart';
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
  pearls: 75,
  appliedTransactions: const ['tx1'],
  ownedProducts: const ['starter_pack'],
  activeOrders: const ['ch1_o_004', 'ch1_o_002'],
  pendingOrders: const ['ch1_o_005'],
  completedOrders: const ['ch1_o_001'],
  completedTasks: const ['ch1_t_01'],
  tutorialStep: 2,
  tutorialFreeTapsUsed: 5,
  endingsSeen: const ['ch1'],
  contentVersion: 3,
  lastOrderSkip: DateTime.utc(2040, 1, 1, 12),
);

SaveState _clean(SaveState s, {int maxManna = 100}) => sanitizeSave(
  s,
  itemIds: {'bakery_01', 'fruit_02'},
  generatorIds: {'gen_pantry'},
  orderIds: {'ch1_o_001', 'ch1_o_004', 'ch1_o_002', 'ch1_o_005'},
  taskIds: {'ch1_t_01'},
  cols: 7,
  rows: 9,
  maxManna: maxManna,
);

void main() {
  group('withMissingGenerators', () {
    const tree = SavedGenerator(
      generatorId: 'gen_tree',
      level: 1,
      col: 4,
      row: 8,
    );
    test('a lost generator is put back in its starting cell', () {
      final all = withMissingGenerators(_sample(), [tree]);
      expect([for (final g in all) g.generatorId], ['gen_pantry', 'gen_tree']);
    });
    test('a generator the save already has is not added twice', () {
      final all = withMissingGenerators(_sample(), _sample().generators);
      expect(all.length, 1);
    });
    test('it is left out if something now sits in its cell', () {
      const blocked = SavedGenerator(
        generatorId: 'gen_tree',
        level: 1,
        col: 3,
        row: 4,
      );
      expect(withMissingGenerators(_sample(), [blocked]).length, 1);
    });
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

    test('the level last rewarded is kept; a damaged one means none', () {
      SaveState withLevel(int level) =>
          SaveState.fromJson({..._sample().toJson(), 'level_rewarded': level});
      expect(_clean(withLevel(12)).levelRewarded, 12);
      expect(_clean(withLevel(-4)).levelRewarded, 0);
    });

    test('unknown items, generators and orders are dropped', () {
      final s = sanitizeSave(
        _sample(),
        itemIds: {'bakery_01'},
        generatorIds: {},
        orderIds: {'ch1_o_002'},
        taskIds: {'ch1_t_01'},
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
          completedOrders: const [],
          completedTasks: const [],
          tutorialStep: 2,
          lastOrderSkip: base.lastOrderSkip,
        ),
      );
      expect(s.generators.length, 1);
      expect(s.items.length, 1);
      expect(s.items.single.col, 1);
      expect(s.items.single.itemId, 'bakery_01');
    });

    test('unknown and repeated task ids are dropped', () {
      final base = _sample();
      final s = _clean(
        SaveState(
          items: base.items,
          generators: base.generators,
          manna: base.manna,
          mannaLastRegen: base.mannaLastRegen,
          talents: base.talents,
          blessings: base.blessings,
          activeOrders: base.activeOrders,
          pendingOrders: base.pendingOrders,
          completedOrders: base.completedOrders,
          completedTasks: const ['ch1_t_01', 'ch1_t_01', 'gone'],
          tutorialStep: 2,
          lastOrderSkip: null,
        ),
      );
      expect(s.completedTasks, ['ch1_t_01']);
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
          completedOrders: const [],
          completedTasks: const [],
          tutorialStep: 2,
          lastOrderSkip: null,
        ),
      );
      // 500 is allowed: bought Manna may sit above the bar.
      expect(s.manna, 500);
      expect(s.talents, 0);
      expect(s.blessings, 0);
      expect(s.activeOrders, ['ch1_o_004']);
      expect(s.pendingOrders, ['ch1_o_005']);
      expect(s.completedOrders, isEmpty);
    });
  });
}
