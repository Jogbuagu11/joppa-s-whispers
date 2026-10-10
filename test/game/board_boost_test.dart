import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/generator_component.dart';
import 'package:whispers_of_joppa/game/board/manna_bar.dart';
import 'package:whispers_of_joppa/game/board/manna_controller.dart';

const _economy = EconomyConfig(
  maxManna: 100,
  mannaRegenSeconds: 120,
  generatorTapCost: 1,
  orderTalentsPerTier: 5,
  orderSlots: 3,
  tutorialFreeTaps: 12,
  mannaRefillBasePearls: 10,
  basketSlotBasePearls: 10,
  orderSkipCooldownSeconds: 1800,
  rewardedAdMannaBonus: 20,
  rewardedAdMannaDailyCap: 5,
  rewardedAdDoubleRewardDailyCap: 3,
);
const _items = {
  'g1': ItemModel(
    itemId: 'g1',
    chainId: 'grain',
    tier: 1,
    name: 'A',
    asset: '',
  ),
  'g2': ItemModel(
    itemId: 'g2',
    chainId: 'grain',
    tier: 2,
    name: 'B',
    asset: '',
  ),
  'g3': ItemModel(
    itemId: 'g3',
    chainId: 'grain',
    tier: 3,
    name: 'C',
    asset: '',
  ),
};
const _pantry = GeneratorModel(
  generatorId: 'pantry',
  chainId: 'grain',
  level: 1,
  energyCost: 1,
  name: 'Pantry',
);

void main() {
  late MannaController manna;
  late int level;

  Future<BoardGame> board() async {
    manna = MannaController(config: _economy, startingManna: 10);
    final game =
        BoardGame(
            itemCatalog: _items,
            chainData: const {
              'grain': ChainTierData(
                chainId: 'grain',
                maxTier: 3,
                itemTiers: {'g1': 1, 'g2': 2, 'g3': 3},
                tierToItemId: {
                  'grain_1': 'g1',
                  'grain_2': 'g2',
                  'grain_3': 'g3',
                },
              ),
            },
            generatorLevels: const {
              'pantry': [
                GeneratorLevelData(level: 1, odds: {'1': 1.0}),
              ],
            },
            generatorPlacements: [(gen: _pantry, col: 1, row: 1)],
            startingItems: const [],
            chainPlaceholderColors: const {},
            manna: manna,
            onOutOfManna: () {},
            gridCols: 3,
            gridRows: 3,
          )
          ..boosts = const [
            GeneratorBoost(mannaTimes: 2, tierBonus: 1),
            GeneratorBoost(mannaTimes: 4, tierBonus: 2),
          ]
          // 2x opens at level 15, 4x at level 40.
          ..boostUnlocked = (i) => level >= const [15, 40][i];
    game.onGameResize(Vector2(300, 300));
    await game.onLoad();
    game.update(0);
    return game;
  }

  void tap(BoardGame game) =>
      game.children.whereType<GeneratorComponent>().single.onTapped('pantry');

  List<String> made(BoardGame game) => [
    for (final i in game.snapshotItems()) i.itemId,
  ];

  setUp(() => level = 1);

  test('before its level there is no boost to switch on', () async {
    final game = await board();
    expect(game.hasBoost, isFalse);
    game.cycleBoost();
    expect(game.boost.value, 0);
    tap(game);
    expect(made(game), ['g1']);
    expect(manna.manna, 9);
  });

  test('at level 15 the boost steps none, 2x, none; taps follow it', () async {
    level = 15;
    final game = await board();
    expect(game.hasBoost, isTrue);
    expect(game.generatorLabel(_pantry), '1M');
    game.cycleBoost();
    expect(game.boost.value, 1);
    expect(game.generatorLabel(_pantry), '2M');
    tap(game);
    expect(made(game), ['g2']);
    expect(manna.manna, 8);
    // 4x is not open yet: the next step is back to none.
    game.cycleBoost();
    expect(game.boost.value, 0);
    tap(game);
    expect(manna.manna, 7);
  });

  test('at level 40 it steps on to 4x', () async {
    level = 40;
    final game = await board();
    game
      ..cycleBoost()
      ..cycleBoost();
    expect(game.boost.value, 2);
    expect(game.generatorLabel(_pantry), '4M');
    tap(game);
    expect(made(game), ['g3']);
    expect(manna.manna, 6);
    game.cycleBoost();
    expect(game.boost.value, 0);
  });

  test(
    'a saved boost the player no longer has is simply not applied',
    () async {
      final game = await board();
      game.boost.value = 2;
      expect(game.activeBoost.mannaTimes, 1);
      tap(game);
      expect(made(game), ['g1']);
      expect(manna.manna, 9);
    },
  );

  testWidgets('the Manna pill shows the boost chip only when there is one, '
      'and tapping it asks for the next', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final manna = MannaController(config: _economy, startingManna: 100);
    var asked = 0;
    Future<void> show(String? label) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 150,
              child: MannaBar(
                controller: manna,
                boostLabel: label,
                onBoost: () => asked++,
              ),
            ),
          ),
        ),
      ),
    );
    await show(null);
    expect(find.byKey(const Key('boost_chip')), findsNothing);
    await show('×2');
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Text>(find.byKey(const Key('boost_label'))).data,
      '×2',
    );
    await tester.tap(find.byKey(const Key('boost_chip')));
    expect(asked, 1);
  });
}
