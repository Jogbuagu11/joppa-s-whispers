import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/data/generator_type_validator.dart';
import 'package:whispers_of_joppa/domain/levels.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';

void main() {
  test('what an item does is read from content, and checked', () {
    expect(ItemUse.fromJson(null), isNull);
    expect(ItemUse.fromJson({'manna': 15})?.givesManna, isTrue);
    expect(ItemUse.fromJson({'skip_seconds': 900})?.skipsTime, isTrue);
    expect(ItemUse.fromJson({'skip_all': true})?.skipAll, isTrue);
    expect(ItemUse.fromJson(<String, dynamic>{}), isNull);
    List<String> check(Object? use) {
      final problems = <String>[];
      checkItemUse('Item', use, problems);
      return problems;
    }

    expect(check(null), isEmpty);
    expect(check({'manna': 5}), isEmpty);
    expect(check({'skip_all': true}), isEmpty);
    expect(check({'manna': 0}), isNotEmpty);
    expect(check({'manna': 5, 'skip_seconds': 60}), isNotEmpty);
    expect(check(<String, dynamic>{}), isNotEmpty);
    expect(check('lots'), isNotEmpty);
  });

  test('a level can give items and a temporary generator, each once', () {
    const config = LevelsConfig(
      xpPerTaskByChapter: {},
      xpPerTaskDefault: 10,
      steps: [
        LevelStep(level: 2, xp: 10, items: ['jar']),
        LevelStep(level: 3, xp: 20, items: ['glass'], generator: 'boat'),
      ],
    );
    final up = levelUpOwed(config, rewarded: 1, current: 3);
    expect(up?.items, ['jar', 'glass']);
    expect(up?.generators, ['boat']);
    expect(levelUpOwed(config, rewarded: 2, current: 3)?.items, ['glass']);
    final read = LevelsConfig.fromJson({
      'xp_per_task_by_chapter': <String, dynamic>{},
      'xp_per_task_default': 10,
      'levels': [
        {
          'level': 2,
          'xp': 10,
          'talents': 5,
          'items': ['jar'],
          'generator': 'boat',
        },
      ],
    });
    expect(read.steps.single.items, ['jar']);
    expect(read.steps.single.generator, 'boat');
  });

  test('waiting gifts are saved with the game; older saves have none', () {
    final save = SaveState(
      items: const [],
      generators: const [],
      manna: 1,
      mannaLastRegen: DateTime.utc(2026, 10, 10),
      talents: 0,
      blessings: 0,
      activeOrders: const [],
      pendingOrders: const [],
      completedOrders: const [],
      completedTasks: const [],
      tutorialStep: 0,
      lastOrderSkip: null,
      pendingGrants: const ['item:jar', 'gen:boat'],
    );
    final json = save.toJson();
    expect(SaveState.fromJson(json).pendingGrants, ['item:jar', 'gen:boat']);
    expect(
      SaveState.fromJson(json..remove('pending_grants')).pendingGrants,
      isEmpty,
    );
  });

  test('the board wording must be complete', () {
    expect(boardTextProblems(null), isNotEmpty);
    expect(
      boardTextProblems({for (final k in boardTextKeys) k: 'words'}),
      isEmpty,
    );
    expect(
      boardTextProblems({
        for (final k in boardTextKeys.skip(1)) k: 'words',
      }).single,
      contains(boardTextKeys.first),
    );
  });
}
