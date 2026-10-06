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
    expect(back.pearls, 75);
    expect(back.appliedTransactions, ['tx1']);
    expect(back.ownedProducts, ['starter_pack']);
    expect(back.activeOrders, ['ch1_o_004', 'ch1_o_002']);
    expect(back.pendingOrders, ['ch1_o_005']);
    expect(back.completedOrders, ['ch1_o_001']);
    expect(back.completedTasks, ['ch1_t_01']);
    expect(back.tutorialStep, 2);
    expect(back.tutorialFreeTapsUsed, 5);
    expect(back.endingsSeen, ['ch1']);
    expect(back.contentVersion, 3);
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
    test('a version 1 save gains an empty delivered list', () {
      final v1 = _sample().toJson()
        ..['save_version'] = 1
        ..remove('completed_orders')
        ..remove('completed_tasks')
        ..remove('tutorial_step')
        ..remove('pearls')
        ..remove('applied_transactions')
        ..remove('owned_products');
      final migrated = migrateSave(v1);
      expect(migrated['save_version'], currentSaveVersion);
      expect(migrated['completed_orders'], isEmpty);
      expect(SaveState.fromJson(v1).completedOrders, isEmpty);
      expect(SaveState.fromJson(v1).manna, 42);
    });
    test('a version 2 save gains empty task progress', () {
      final v2 = _sample().toJson()
        ..['save_version'] = 2
        ..remove('completed_tasks')
        ..remove('tutorial_step')
        ..remove('pearls')
        ..remove('applied_transactions')
        ..remove('owned_products');
      expect(migrateSave(v2)['save_version'], currentSaveVersion);
      expect(SaveState.fromJson(v2).completedTasks, isEmpty);
      expect(SaveState.fromJson(v2).completedOrders, ['ch1_o_001']);
    });
    test('a version 3 save counts the tutorial as finished', () {
      final v3 = _sample().toJson()
        ..['save_version'] = 3
        ..remove('tutorial_step')
        ..remove('pearls')
        ..remove('applied_transactions')
        ..remove('owned_products');
      expect(migrateSave(v3)['save_version'], currentSaveVersion);
      expect(SaveState.fromJson(v3).tutorialStep, tutorialFinished);
      expect(SaveState.fromJson(v3).completedTasks, ['ch1_t_01']);
    });
    test('a version 4 save gains an empty Pearl purse', () {
      final v4 = _sample().toJson()
        ..['save_version'] = 4
        ..remove('pearls')
        ..remove('applied_transactions')
        ..remove('owned_products');
      expect(migrateSave(v4)['save_version'], currentSaveVersion);
      final back = SaveState.fromJson(v4);
      expect(back.pearls, 0);
      expect(back.appliedTransactions, isEmpty);
      expect(back.ownedProducts, isEmpty);
      expect(back.talents, 120);
    });
    test('a version 5 save starts with no ads watched', () {
      final v5 = _sample().toJson()
        ..['save_version'] = 5
        ..remove('ad_day')
        ..remove('ad_manna_watched');
      expect(migrateSave(v5)['save_version'], currentSaveVersion);
      final back = SaveState.fromJson(v5);
      expect(back.adDay, '');
      expect(back.adMannaWatched, 0);
      expect(back.talents, 120);
    });
    test('the count of ads watched survives a save and load', () {
      final json = _sample().toJson()
        ..['ad_day'] = '2026-10-05'
        ..['ad_manna_watched'] = 3;
      final back = SaveState.fromJson(json);
      expect(back.adDay, '2026-10-05');
      expect(back.adMannaWatched, 3);
      expect(back.toJson()['ad_manna_watched'], 3);
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

  test('a current save missing its task progress is rejected', () {
    final json = _sample().toJson()..remove('completed_tasks');
    expect(() => SaveState.fromJson(json), throwsFormatException);
  });

  test('a version 4 save from before free-tap counting still loads', () {
    final json = _sample().toJson()
      ..remove('tutorial_free_taps_used')
      ..remove('endings_seen')
      ..remove('content_version');
    final back = SaveState.fromJson(json);
    expect(back.tutorialFreeTapsUsed, 0);
    expect(back.endingsSeen, isEmpty);
    expect(back.contentVersion, 0);
  });

  test('a wrongly typed order list is rejected, not crashed on later', () {
    final json = _sample().toJson()..['active_orders'] = [1, 2];
    expect(() => SaveState.fromJson(json), throwsFormatException);
  });
}
