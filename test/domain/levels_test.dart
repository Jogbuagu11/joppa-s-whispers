import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/level_validator.dart';
import 'package:whispers_of_joppa/domain/levels.dart';
import 'package:whispers_of_joppa/domain/progression.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';

const _config = LevelsConfig(
  xpPerTaskByChapter: {1: 10, 2: 20},
  xpPerTaskDefault: 5,
  steps: [
    LevelStep(level: 2, xp: 10, talents: 20),
    LevelStep(level: 3, xp: 30, talents: 30),
    LevelStep(level: 4, xp: 60, talents: 40),
  ],
  unlocks: [
    FeatureUnlock(level: 3, feature: 'wheel', name: 'Wheel', available: true),
    FeatureUnlock(level: 4, feature: 'races', name: 'Races'),
  ],
);

ChapterModel _chapter(int number, List<String> taskIds) => ChapterModel(
  id: 'ch$number',
  number: number,
  title: 'Chapter $number',
  locationId: 'place',
  tasks: [
    for (final id in taskIds)
      TaskModel(id: id, beat: 1, title: id, costBlessings: 1),
  ],
);

Map<String, dynamic> _real() =>
    jsonDecode(File('content/levels.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('everyone starts at level 1, and levels follow XP', () {
    expect(_config.levelAt(0), 1);
    expect(_config.levelAt(9), 1);
    expect(_config.levelAt(10), 2);
    expect(_config.levelAt(59), 3);
    expect(_config.levelAt(60), 4);
    expect(_config.levelAt(9999), 4);
    expect(_config.maxLevel, 4);
  });

  test('progress is measured within the present level', () {
    expect(_config.progress(0), (into: 0, needed: 10));
    expect(_config.progress(15), (into: 5, needed: 20));
    expect(_config.progress(59), (into: 29, needed: 30));
    // The highest level has nothing left to fill.
    expect(_config.progress(60), (into: 0, needed: 0));
  });

  test('XP is the sum of each finished task, by its chapter', () {
    final chapters = [
      _chapter(1, ['a', 'b']),
      _chapter(2, ['c']),
      _chapter(9, ['z']),
    ];
    expect(xpEarned(_config, chapters, {}), 0);
    expect(xpEarned(_config, chapters, {'a'}), 10);
    expect(xpEarned(_config, chapters, {'a', 'b', 'c'}), 40);
    // A chapter with no XP set uses the usual amount.
    expect(xpEarned(_config, chapters, {'z'}), 5);
    // A task id no chapter has earns nothing.
    expect(xpEarned(_config, chapters, {'gone'}), 0);
  });

  test('a level gained is paid once, with what opened on the way', () {
    expect(levelUpOwed(_config, rewarded: 2, current: 2), isNull);
    expect(levelUpOwed(_config, rewarded: 3, current: 2), isNull);
    final one = levelUpOwed(_config, rewarded: 1, current: 2);
    expect(one?.talents, 20);
    expect(one?.unlocked, isEmpty);
    // Several levels at once: every reward, none missed.
    final many = levelUpOwed(_config, rewarded: 1, current: 4);
    expect(many?.from, 1);
    expect(many?.to, 4);
    expect(many?.talents, 90);
    // Only features that exist in the game are announced.
    expect(
      [for (final u in many?.unlocked ?? <FeatureUnlock>[]) u.feature],
      ['wheel'],
    );
  });

  test('features open at their level; unlisted features are always open', () {
    expect(_config.isUnlocked('wheel', 2), isFalse);
    expect(_config.isUnlocked('wheel', 3), isTrue);
    expect(_config.isUnlocked('races', 3), isFalse);
    expect(_config.isUnlocked('something_else', 1), isTrue);
  });

  test('content from before levels keeps everyone at level 1', () {
    expect(noLevels.levelAt(5000), 1);
    expect(noLevels.progress(5000), (into: 0, needed: 0));
    expect(levelUpOwed(noLevels, rewarded: 1, current: 1), isNull);
  });

  test('the real levels file: 60 levels, level 10 inside Chapter 1, and the '
      'last task of Season 1 reaches level 60', () {
    final config = LevelsConfig.fromJson(_real());
    final chapters = [
      for (final c
          in jsonDecode(File('content/chapters.json').readAsStringSync())
              as List<dynamic>)
        ChapterModel.fromJson(c as Map<String, dynamic>),
    ];
    expect(config.maxLevel, 60);
    final all = [for (final c in chapters) ...c.tasks.map((t) => t.id)];
    expect(config.levelAt(xpEarned(config, chapters, all.toSet())), 60);
    // One task short is not yet the top.
    expect(
      config.levelAt(
        xpEarned(config, chapters, all.take(all.length - 1).toSet()),
      ),
      lessThan(60),
    );
    final firstChapter = chapters.first.tasks.map((t) => t.id).toSet();
    expect(
      config.levelAt(xpEarned(config, chapters, firstChapter)),
      greaterThanOrEqualTo(10),
    );
    // The unlock schedule from the expansion document.
    expect(config.isUnlocked('blessing_wheel', 4), isFalse);
    expect(config.isUnlocked('blessing_wheel', 5), isTrue);
    expect(config.isUnlocked('boost_4x', 39), isFalse);
    expect(config.isUnlocked('boost_4x', 40), isTrue);
  });

  group('checking the levels file', () {
    List<String> check(Map<String, dynamic> json) {
      final problems = <String>[];
      checkLevels(json, chapterNumbers: {1, 2, 3, 4, 5, 6}, problems: problems);
      return problems;
    }

    test('the real file has no problems', () {
      expect(check(_real()), isEmpty);
    });

    test('a skipped level, XP that does not rise, and a bad unlock are '
        'all reported', () {
      final json = _real();
      final levels = json['levels'] as List<dynamic>;
      (levels[3] as Map<String, dynamic>)['xp'] = 1;
      levels.removeAt(10);
      (json['unlocks'] as List<dynamic>).add({
        'level': 99,
        'feature': 'too_far',
        'name': 'Too far',
      });
      (json['text'] as Map<String, dynamic>).remove('title');
      (json['xp_per_task_by_chapter'] as Map<String, dynamic>)['9'] = 10;
      final problems = check(json).join('\n');
      expect(problems, contains('must need more XP'));
      expect(problems, contains('expected level 12 next'));
      expect(problems, contains('"too_far" needs a level'));
      expect(problems, contains('text "title"'));
      expect(problems, contains('chapter "9"'));
    });

    test('a file with the wrong shape is reported, not a crash', () {
      expect(check({'levels': 'none'}), isNotEmpty);
    });
  });

  test('a game saved before levels opens with nothing owed', () {
    final old = <String, dynamic>{
      'save_version': 6,
      'items': <dynamic>[],
      'generators': <dynamic>[],
      'manna': 5,
      'manna_last_regen': '2026-10-05T12:00:00Z',
      'talents': 1,
      'blessings': 2,
      'pearls': 0,
      'applied_transactions': <dynamic>[],
      'owned_products': <dynamic>[],
      'active_orders': <dynamic>[],
      'pending_orders': <dynamic>[],
      'completed_orders': <dynamic>[],
      'completed_tasks': ['ch1_t_01'],
      'tutorial_step': 0,
      'last_order_skip': null,
      'ad_day': '',
      'ad_manna_watched': 0,
    };
    final save = SaveState.fromJson(old);
    expect(save.levelRewarded, 0);
    // And the level last rewarded survives being saved and read back.
    final again = SaveState.fromJson({...save.toJson(), 'level_rewarded': 7});
    expect(SaveState.fromJson(again.toJson()).levelRewarded, 7);
  });
}
