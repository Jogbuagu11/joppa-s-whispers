import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/game/board/session_content.dart';

import '../support/content_fixtures.dart';
import '../support/fakes.dart';

const _v2 = ContentBundle(version: 2, format: 1, files: {});

void main() {
  test('a new game is stamped with the running content version', () {
    final r = contentVersionFor(null, _v2);
    expect(r.contentVersion, 2);
    expect(r.downgraded, isFalse);
  });

  test(
    'a game from the same or older content moves up to the running version',
    () {
      expect(
        contentVersionFor(testSave(contentVersion: 2), _v2).contentVersion,
        2,
      );
      final older = contentVersionFor(testSave(contentVersion: 1), _v2);
      expect(older.contentVersion, 2);
      expect(older.downgraded, isFalse);
    },
  );

  test('a game from newer content is flagged and keeps its higher version', () {
    final r = contentVersionFor(testSave(contentVersion: 5), _v2);
    expect(r.downgraded, isTrue);
    expect(r.contentVersion, 5);
  });

  group('with the real content', () {
    final loader = ContentLoader()..loadFromBundle(realContent());
    final chapterOne = loader.chapters.first;
    final firstOf = {
      for (final c in loader.chapters)
        c.number: loader.orders.firstWhere((o) => o.chapter == c.number).id,
    };

    test('a new player may be shown Chapter 1 orders only', () {
      final open = ordersOpenAt(loader, const []);
      expect(open(firstOf[1] ?? ''), isTrue);
      expect(open(firstOf[2] ?? ''), isFalse);
    });

    test('one task short of finishing Chapter 1 is still Chapter 1', () {
      final almost = [for (final t in chapterOne.tasks.skip(1)) t.id];
      expect(ordersOpenAt(loader, almost)(firstOf[2] ?? ''), isFalse);
    });

    test('finishing Chapter 1 opens Chapter 2\'s orders', () {
      final done = [for (final t in chapterOne.tasks) t.id];
      final open = ordersOpenAt(loader, done);
      expect(open(firstOf[2] ?? ''), isTrue);
      expect(open(firstOf[1] ?? ''), isTrue);
    });

    test(
      'a saved game keeps what content knows and loses what it does not',
      () {
        final repaired = repairedSave(
          testSave(
            tasks: [chapterOne.tasks.first.id, 'no_such_task'],
            orders: [firstOf[1] ?? '', 'no_such_order'],
            talents: 40,
          ),
          loader,
        );
        expect(repaired.completedTasks, [chapterOne.tasks.first.id]);
        expect(repaired.completedOrders, [firstOf[1]]);
        expect(repaired.talents, 40);
      },
    );

    test('what later features keep in the save comes through a repair', () {
      final saved = SaveState.fromJson({
        ...testSave(tasks: const [], orders: const [], talents: 0).toJson(),
        'extras': {
          'wheel': {'free': 1},
        },
      });
      expect(repairedSave(saved, loader).extras, {
        'wheel': {'free': 1},
      });
    });
  });
}
