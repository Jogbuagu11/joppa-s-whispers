import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/orders.dart';
import 'package:whispers_of_joppa/domain/progression.dart';
import 'package:whispers_of_joppa/domain/unlocks.dart';

const _board = [
  StartingGenerator(generatorId: 'pantry', col: 2, row: 8),
  StartingGenerator(generatorId: 'tree', col: 4, row: 8),
  StartingGenerator(generatorId: 'chest', col: 3, row: 8, chapter: 2),
  StartingGenerator(generatorId: 'armor', col: 1, row: 8, chapter: 3),
];

ChapterModel _chapter(int number, List<String> taskIds) => ChapterModel(
  id: 'ch$number',
  number: number,
  title: 'Chapter $number',
  locationId: 'loc',
  tasks: [
    for (final id in taskIds)
      TaskModel(id: id, beat: 1, title: id, costBlessings: 1),
  ],
);

void main() {
  group('chapterReached', () {
    final chapters = [
      _chapter(1, ['a', 'b']),
      _chapter(2, ['c']),
    ];

    test('the first chapter with a task still to do', () {
      expect(chapterReached(chapters, {}), 1);
      expect(chapterReached(chapters, {'a'}), 1);
      expect(chapterReached(chapters, {'a', 'b'}), 2);
    });

    test('the last chapter once everything is done; 1 with no chapters', () {
      expect(chapterReached(chapters, {'a', 'b', 'c'}), 2);
      expect(chapterReached([], {}), 1);
    });
  });

  group('generatorsOwed', () {
    test('a generator that names a player level waits for it too', () {
      const board = [
        StartingGenerator(generatorId: 'fig', col: 6, row: 7, level: 4),
        StartingGenerator(
          generatorId: 'olive',
          col: 0,
          row: 7,
          chapter: 2,
          level: 3,
        ),
      ];
      List<String> owed(int chapter, int level) => [
        for (final g in generatorsOwed(board, {}, chapter, level: level))
          g.generatorId,
      ];
      expect(owed(1, 3), isEmpty);
      expect(owed(1, 4), ['fig']);
      // Both the chapter and the level must be reached.
      expect(owed(2, 2), isEmpty);
      expect(owed(2, 3), ['olive']);
      expect(owed(2, 9), ['fig', 'olive']);
      expect(generatorsOwed(board, {'fig'}, 1, level: 9), isEmpty);
    });

    test('chapter 1 owes nothing beyond the starting generators', () {
      expect(generatorsOwed(_board, {'pantry', 'tree'}, 1), isEmpty);
    });

    test('reaching a chapter brings its generator, once', () {
      final owed = generatorsOwed(_board, {'pantry', 'tree'}, 2);
      expect([for (final g in owed) g.generatorId], ['chest']);
      expect(generatorsOwed(_board, {'pantry', 'tree', 'chest'}, 2), isEmpty);
    });

    test('a player who jumped ahead gets every generator they are owed', () {
      final owed = generatorsOwed(_board, {'pantry', 'tree'}, 3);
      expect([for (final g in owed) g.generatorId], ['chest', 'armor']);
    });

    test('a starting generator that went missing is owed again', () {
      final owed = generatorsOwed(_board, {'pantry'}, 1);
      expect([for (final g in owed) g.generatorId], ['tree']);
    });
  });

  group('cellForNewGenerator', () {
    ({int col, int row})? cell(Set<(int, int)> taken) => cellForNewGenerator(
      homeCol: 3,
      homeRow: 8,
      taken: taken,
      cols: 7,
      rows: 9,
    );

    test('its home cell when that is free', () {
      expect(cell({(2, 8), (4, 8)}), (col: 3, row: 8));
    });

    test('the nearest free cell when an item sits on its home', () {
      expect(cell({(2, 8), (3, 8), (4, 8)}), (col: 3, row: 7));
    });

    test('nowhere when the board is full', () {
      final full = {
        for (int c = 0; c < 7; c++)
          for (int r = 0; r < 9; r++) (c, r),
      };
      expect(cell(full), isNull);
      // One free cell anywhere is enough.
      expect(cell(full.difference({(0, 0)})), (col: 0, row: 0));
    });
  });

  group('orders wait for their chapter', () {
    // a, b belong to chapter 1; x, y to chapter 2.
    const ids = ['a', 'b', 'x', 'y'];
    bool chapterOne(String id) => id == 'a' || id == 'b';

    test('a new game shows only the reached chapter\'s orders', () {
      final book = startOrders(ids, 3, available: chapterOne);
      expect(book.active, ['a', 'b']);
      expect(book.pending, ['x', 'y']);
    });

    test('delivering does not pull a later chapter\'s order forward', () {
      final start = startOrders(ids, 3, available: chapterOne);
      final book = completeOrder(start, 'a', available: chapterOne);
      expect(book.active, ['b']);
      expect(book.pending, ['x', 'y']);
    });

    test('reaching the chapter fills the empty cards', () {
      final start = startOrders(ids, 3, available: chapterOne);
      final book = fillOrderCards(
        completeOrder(start, 'a', available: chapterOne),
        3,
      );
      expect(book.active, ['b', 'x', 'y']);
      expect(book.pending, isEmpty);
    });

    test('an earlier chapter\'s leftovers are dealt before the new ones', () {
      const book = OrderBook(active: ['x'], pending: ['y', 'b']);
      expect(fillOrderCards(book, 3).active, ['x', 'y', 'b']);
      expect(completeOrder(book, 'x', available: chapterOne).active, ['b']);
    });

    test('a saved game does not get a later chapter\'s orders early', () {
      final book = reconcileOrderBook(
        saved: const OrderBook(active: ['b'], pending: []),
        completed: {'a'},
        allOrderIds: ids,
        slots: 3,
        available: chapterOne,
      );
      expect(book.active, ['b']);
      expect(book.pending, ['x', 'y']);
    });
  });

  group('skipping while later chapters wait', () {
    const config = EconomyConfig(
      maxManna: 100,
      mannaRegenSeconds: 120,
      generatorTapCost: 1,
      orderTalentsPerTier: 5,
      orderSlots: 2,
      tutorialFreeTaps: 12,
      mannaRefillBasePearls: 10,
      basketSlotBasePearls: 10,
      orderSkipCooldownSeconds: 1800,
      rewardedAdMannaBonus: 20,
      rewardedAdMannaDailyCap: 5,
      rewardedAdDoubleRewardDailyCap: 3,
    );
    final t0 = DateTime(2040, 1, 1, 12);
    // a, b, c belong to chapter 1; x, y to chapter 2.
    bool chapterOne(String id) => const {'a', 'b', 'c'}.contains(id);

    test(
      'a skip takes the next order of the reached chapter, not a later one',
      () {
        const book = OrderBook(active: ['a', 'b'], pending: ['x', 'y', 'c']);
        final skipped = skipOrder(config, book, 'a', t0, available: chapterOne);
        expect(skipped.active, ['c', 'b']);
        expect(skipped.pending, ['x', 'y', 'a']);
      },
    );

    test('nothing can be skipped when only later chapters wait', () {
      const book = OrderBook(active: ['a', 'b'], pending: ['x', 'y']);
      expect(canSkipOrder(config, book, t0, available: chapterOne), isFalse);
      expect(skipOrder(config, book, 'a', t0, available: chapterOne).active, [
        'a',
        'b',
      ]);
      // With the chapter reached, it can.
      expect(canSkipOrder(config, book, t0), isTrue);
    });

    test('a skipped order behind later-chapter orders is still dealt next', () {
      const book = OrderBook(active: ['b'], pending: ['x', 'y', 'a']);
      final after = completeOrder(book, 'b', available: chapterOne);
      expect(after.active, ['a']);
      expect(after.pending, ['x', 'y']);
    });
  });

  test('a new generator arrives at the level the others have all reached', () {
    expect(lowestLevel([]), 1);
    expect(lowestLevel([1, 1]), 1);
    expect(lowestLevel([2, 3]), 2);
    expect(lowestLevel([0]), 1);
  });
}
