import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/bubbles.dart';
import 'package:whispers_of_joppa/domain/lucky.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/features/bubbles/bubble_controller.dart';

const _b2 = ItemModel(
  itemId: 'b2',
  chainId: 'bakery',
  tier: 2,
  name: 'B',
  asset: '',
);
const _b3 = ItemModel(
  itemId: 'b3',
  chainId: 'bakery',
  tier: 3,
  name: 'C',
  asset: '',
);
const _rules = BubbleRules(
  chance: 1,
  higherChance: 0,
  seconds: 60,
  pearlsPerTier: 2,
  adMaxTier: 2,
  talentsPerTier: 3,
  maxAtOnce: 2,
);

void main() {
  late DateTime now;
  late int talents;
  late List<String> given;

  setUp(() {
    now = DateTime(2026, 10, 10, 12);
    talents = 0;
    given = [];
  });

  group('mystery bubbles', () {
    BubbleController withMystery(double share, int lift) => BubbleController(
      rules: _rules,
      items: const {'b2': _b2, 'b3': _b3},
      chains: const {
        'bakery': ChainTierData(
          chainId: 'bakery',
          maxTier: 3,
          itemTiers: {'b2': 2, 'b3': 3},
          tierToItemId: {'bakery_2': 'b2', 'bakery_3': 'b3'},
        ),
      },
      mystery: MysteryBubble.fromJson({
        'share': share,
        'lifts': [
          {'tiers': lift, 'weight': 1},
        ],
      }),
      allowed: () => true,
      addTalents: (n) => talents += n,
      spendPearls: (n) => true,
      giveItem: given.add,
      random: Random(1),
      clock: () => now,
    );

    test('every bubble is one when the share is all, none when it is '
        'nothing', () {
      final all = withMystery(1, 0)..afterMerge(_b2, col: 0, row: 0);
      expect(all.bubbles.single.mystery, isTrue);
      all.dispose();
      final none = withMystery(0, 0)..afterMerge(_b2, col: 0, row: 0);
      expect(none.bubbles.single.mystery, isFalse);
      none.dispose();
    });

    test('its item is drawn when it is kept, priced by the item merged', () {
      final bubbles = withMystery(1, 1)..afterMerge(_b2, col: 0, row: 0);
      final bubble = bubbles.bubbles.single;
      // It starts from the plain item: the price is that of tier 2.
      expect(bubble.item.itemId, 'b2');
      expect(bubbles.pearlsFor(bubble), 4);
      expect(bubbles.keepWithPearls(bubble.id), isTrue);
      expect(given, ['b3']);
      expect(bubbles.lastKept?.itemId, 'b3');
      bubbles.dispose();
    });

    test('an item without room above it for every lift shown never gets a '
        'mystery bubble', () {
      // b3 is the top of its chain: "1 bigger" could not come true.
      final top = withMystery(1, 1)..afterMerge(_b3, col: 0, row: 0);
      expect(top.bubbles.single.mystery, isFalse);
      top.dispose();
      // b2 has room for a lift of 1, not of 2.
      final short = withMystery(1, 2)..afterMerge(_b2, col: 0, row: 0);
      expect(short.bubbles.single.mystery, isFalse);
      short.dispose();
    });

    test('left alone it pays the Talents of the item merged, like any '
        'bubble', () {
      final bubbles = withMystery(1, 1)..afterMerge(_b2, col: 0, row: 0);
      now = now.add(const Duration(minutes: 2));
      bubbles.tick();
      expect(talents, 6);
      expect(given, isEmpty);
      bubbles.dispose();
    });
  });
}
