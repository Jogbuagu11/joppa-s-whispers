// Plays every chapter in content from start to finish using the real rules,
// to prove the chapter can be completed: every order can be made and
// delivered, and the Blessings earned always cover the next task.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/orders.dart';
import 'package:whispers_of_joppa/domain/progression.dart';

Object? _read(String name) =>
    jsonDecode(File('content/$name.json').readAsStringSync());

void main() {
  final loader = ContentLoader()
    ..loadFromJson(
      chainsJson: _read('chains'),
      generatorsJson: _read('generators'),
      economyJson: _read('economy'),
      startingBoardJson: _read('starting_board'),
      ordersJson: _read('orders'),
      charactersJson: _read('characters'),
      scenesJson: _read('scenes'),
      chaptersJson: _read('chapters'),
      locationsJson: _read('locations'),
      tutorialJson: _read('tutorial'),
      endingsJson: _read('endings'),
      lettersJson: _read('letters'),
    );

  for (final chapter in loader.chapters) {
    test('${chapter.id} can be played from first order to last task', () {
      final orders = {
        for (final o in loader.orders.where((o) => o.chapter == chapter.number))
          o.id: o,
      };
      // Chains with a generator on the board at the start of the game.
      final spawnable = {
        for (final g in loader.startingBoard.generators)
          loader.generators[g.generatorId]?.chainId,
      };
      final freeCells =
          BoardState.cols * BoardState.rows -
          loader.startingBoard.generators.length;

      var book = startOrders(orders.keys.toList(), loader.economy.orderSlots);
      var blessings = 0;
      var taps = 0;
      final done = <String>{};
      var guard = 0;

      while (book.active.isNotEmpty) {
        expect(guard++, lessThan(500), reason: 'playthrough did not finish');
        // Always work on the first card.
        final order = orders[book.active.first];
        expect(order, isNotNull);
        if (order == null) break;

        // Every item must come from a generator the player has, and making
        // the whole order must fit on the board (worst case: one cell per
        // tier while merging up, per item).
        var cellsNeeded = 0;
        for (final wanted in order.items) {
          final item = loader.items[wanted.itemId];
          expect(item, isNotNull, reason: '${order.id}: ${wanted.itemId}');
          if (item == null) continue;
          expect(
            spawnable.contains(item.chainId),
            isTrue,
            reason: '${order.id} needs ${item.chainId}, which has no generator',
          );
          // A tier-n item is made from 2^(n-1) tier-1 spawns.
          taps += wanted.count * (1 << (item.tier - 1));
          cellsNeeded += wanted.count * item.tier;
        }
        expect(cellsNeeded, lessThanOrEqualTo(freeCells), reason: order.id);

        blessings += order.blessings;
        book = completeOrder(book, order.id);

        // Spend on every task that can now be afforded, in order.
        var task = nextTask(chapter, done);
        while (task != null && canAffordTask(task, blessings)) {
          blessings -= task.costBlessings;
          done.add(task.id);
          task = nextTask(chapter, done);
        }
      }

      expect(
        isChapterComplete(chapter, done),
        isTrue,
        reason:
            'all orders delivered but ${chapter.tasks.length - done.length} '
            'task(s) left with $blessings Blessings',
      );
      expect(blessings, greaterThanOrEqualTo(0));
      expect(taps, greaterThan(0));
      // Every scene the chapter's tasks play exists.
      for (final t in chapter.tasks) {
        expect(loader.scenes.containsKey(t.sceneId), isTrue, reason: t.id);
      }
      // And the chapter has a closing message.
      expect(loader.endings.containsKey(chapter.id), isTrue);
    });
  }
}
