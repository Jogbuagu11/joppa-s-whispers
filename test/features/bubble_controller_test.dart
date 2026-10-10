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
  late int pearls;
  late List<String> given;
  late bool allowed;

  BubbleController controller({BubbleRules? rules = _rules}) =>
      BubbleController(
        rules: rules,
        items: const {'b2': _b2, 'b3': _b3},
        chains: const {
          'bakery': ChainTierData(
            chainId: 'bakery',
            maxTier: 3,
            itemTiers: {'b2': 2, 'b3': 3},
            tierToItemId: {'bakery_2': 'b2', 'bakery_3': 'b3'},
          ),
        },
        allowed: () => allowed,
        addTalents: (n) => talents += n,
        spendPearls: (n) {
          if (n > pearls) return false;
          pearls -= n;
          return true;
        },
        giveItem: given.add,
        random: Random(1),
        clock: () => now,
      );

  setUp(() {
    now = DateTime(2026, 10, 10, 12);
    talents = 0;
    pearls = 10;
    given = [];
    allowed = true;
  });

  test('a merge leaves a bubble holding a copy, over the cell it was made '
      'in', () {
    final bubbles = controller()..afterMerge(_b2, col: 3, row: 4);
    final bubble = bubbles.bubbles.single;
    expect(bubble.item.itemId, 'b2');
    expect((bubble.col, bubble.row), (3, 4));
    expect(bubbles.secondsLeft(bubble.id), 60);
    expect(bubbles.shareLeft(bubble.id), 1);
    bubbles.dispose();
  });

  test('no bubbles when the game has none, before they are allowed, or '
      'past the most at once', () {
    final none = controller(rules: null)..afterMerge(_b2, col: 0, row: 0);
    expect(none.bubbles, isEmpty);
    none.dispose();
    allowed = false;
    final early = controller()..afterMerge(_b2, col: 0, row: 0);
    expect(early.bubbles, isEmpty);
    early.dispose();
    allowed = true;
    final full = controller();
    for (var i = 0; i < 5; i++) {
      full.afterMerge(_b2, col: i, row: 0);
    }
    expect(full.bubbles, hasLength(2));
    full.dispose();
  });

  testWidgets('left alone, it pops after its time and pays a few Talents, '
      'once', (tester) async {
    final bubbles = controller()..afterMerge(_b2, col: 0, row: 0);
    now = now.add(const Duration(seconds: 59));
    await tester.pump(const Duration(seconds: 59));
    expect(bubbles.bubbles, hasLength(1));
    expect(talents, 0);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(bubbles.bubbles, isEmpty);
    expect(talents, 6);
    expect(given, isEmpty);
    // Nothing more happens; and no timer is left running (the test would
    // fail at its end if one were).
    now = now.add(const Duration(minutes: 5));
    await tester.pump(const Duration(minutes: 5));
    expect(talents, 6);
  });

  test('kept for Pearls: the price is taken once and the item handed over', () {
    final bubbles = controller()..afterMerge(_b2, col: 0, row: 0);
    final id = bubbles.bubbles.single.id;
    expect(bubbles.pearlsFor(bubbles.bubbles.single), 4);
    expect(bubbles.keepWithPearls(id), isTrue);
    expect(pearls, 6);
    expect(given, ['b2']);
    expect(bubbles.bubbles, isEmpty);
    // It is gone: it cannot be kept twice, and pops for nothing later.
    expect(bubbles.keepWithPearls(id), isFalse);
    expect(bubbles.keepAfterAd(id), isFalse);
    expect(pearls, 6);
    expect(given, hasLength(1));
    bubbles.tick();
    expect(talents, 0);
    bubbles.dispose();
  });

  test('with too few Pearls nothing is taken and the bubble stays', () {
    pearls = 3;
    final bubbles = controller()..afterMerge(_b2, col: 0, row: 0);
    expect(bubbles.keepWithPearls(bubbles.bubbles.single.id), isFalse);
    expect(pearls, 3);
    expect(given, isEmpty);
    expect(bubbles.bubbles, hasLength(1));
    bubbles.dispose();
  });

  test('an ad keeps a small item, never a big one', () {
    final bubbles = controller()
      ..afterMerge(_b2, col: 0, row: 0)
      ..afterMerge(_b3, col: 1, row: 0);
    final small = bubbles.bubbles.first;
    final big = bubbles.bubbles.last;
    expect(bubbles.adAllowedFor(small), isTrue);
    expect(bubbles.adAllowedFor(big), isFalse);
    expect(bubbles.keepAfterAd(big.id), isFalse);
    expect(bubbles.keepAfterAd(small.id), isTrue);
    expect(given, ['b2']);
    expect(pearls, 10);
    expect(bubbles.bubbles.single.id, big.id);
    bubbles.dispose();
  });

  test('a bubble being decided on does not pop until it is let go', () {
    final bubbles = controller()..afterMerge(_b2, col: 0, row: 0);
    final id = bubbles.bubbles.single.id;
    bubbles.hold(id);
    now = now.add(const Duration(minutes: 5));
    bubbles.tick();
    expect(bubbles.bubbles, hasLength(1));
    expect(talents, 0);
    // It can still be kept.
    expect(bubbles.keepWithPearls(id), isTrue);
    expect(given, ['b2']);
    bubbles.dispose();
  });

  test('let go after its time ran out, it pops at once and pays', () {
    final bubbles = controller()..afterMerge(_b2, col: 0, row: 0);
    final id = bubbles.bubbles.single.id;
    bubbles.hold(id);
    now = now.add(const Duration(minutes: 5));
    bubbles
      ..release(id)
      ..tick();
    expect(bubbles.bubbles, isEmpty);
    expect(talents, 6);
    bubbles.dispose();
  });

  test('no bubble copies a usable item, and a rare find is never kept for '
      'an ad', () {
    const jar = ItemModel(
      itemId: 'jar',
      chainId: 'jar',
      tier: 1,
      name: 'Jar',
      asset: '',
      use: ItemUse(manna: 5),
    );
    const honey = ItemModel(
      itemId: 'h1',
      chainId: 'honey',
      tier: 1,
      name: 'Honey',
      asset: '',
    );
    final bubbles = BubbleController(
      rules: _rules,
      items: const {'jar': jar, 'h1': honey},
      chains: const {},
      sideChains: const {'honey', 'jar'},
      allowed: () => true,
      addTalents: (_) {},
      spendPearls: (_) => true,
      giveItem: given.add,
      clock: () => now,
    )..afterMerge(jar, col: 0, row: 0);
    expect(bubbles.bubbles, isEmpty);
    bubbles.afterMerge(honey, col: 0, row: 0);
    final rare = bubbles.bubbles.single;
    expect(bubbles.adAllowedFor(rare), isFalse);
    expect(bubbles.keepAfterAd(rare.id), isFalse);
    expect(bubbles.keepWithPearls(rare.id), isTrue);
    bubbles.dispose();
  });

  test('after the game is closed nothing more is paid or given', () {
    final bubbles = controller()..afterMerge(_b2, col: 0, row: 0);
    final id = bubbles.bubbles.single.id;
    bubbles.dispose();
    now = now.add(const Duration(minutes: 2));
    bubbles.tick();
    expect(bubbles.keepWithPearls(id), isFalse);
    expect(talents, 0);
    expect(pearls, 10);
    expect(given, isEmpty);
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
