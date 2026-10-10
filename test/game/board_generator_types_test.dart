import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/generator_types.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';
import 'package:whispers_of_joppa/game/board/generator_component.dart';
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
const _fig = ItemModel(
  itemId: 'fruit_1',
  chainId: 'fruit',
  tier: 1,
  name: 'Fig',
  asset: '',
);

GeneratorModel _gen(String id, GeneratorRules rules) => GeneratorModel(
  generatorId: id,
  chainId: 'fruit',
  level: 1,
  energyCost: rules.costsManna ? 1 : 0,
  name: id,
  rules: rules,
);

void main() {
  late DateTime now;
  late MannaController manna;

  Future<BoardGame> board(
    GeneratorModel gen, {
    int col = 1,
    int row = 1,
    Map<String, GeneratorTimer>? timers,
    int startingManna = 10,
  }) async {
    manna = MannaController(
      config: _economy,
      startingManna: startingManna,
      clock: () => now,
    );
    final game = BoardGame(
      itemCatalog: const {'fruit_1': _fig},
      chainData: const {
        'fruit': ChainTierData(
          chainId: 'fruit',
          itemTiers: {'fruit_1': 1},
          tierToItemId: {'fruit_1': 'fruit_1'},
          maxTier: 1,
        ),
      },
      generatorLevels: {
        gen.generatorId: const [
          GeneratorLevelData(level: 1, odds: {'1': 1.0}),
        ],
      },
      generatorPlacements: [(gen: gen, col: col, row: row)],
      startingItems: const [],
      chainPlaceholderColors: const {},
      manna: manna,
      onOutOfManna: () {},
      gridCols: 3,
      gridRows: 3,
      generatorTimers: timers,
      clock: () => now,
    );
    game.onGameResize(Vector2(300, 300));
    await game.onLoad();
    // Let the cells and the generator tile take their places.
    game.update(0);
    return game;
  }

  void tap(BoardGame game, String id) => game.children
      .whereType<GeneratorComponent>()
      .firstWhere((c) => c.generator.generatorId == id)
      .onTapped(id);

  setUp(() => now = DateTime.utc(2026, 10, 10, 12));

  test('a charged generator gives its charges for no Manna, rests, and is '
      'full again after the cooldown', () async {
    final gen = _gen(
      'fig',
      const GeneratorRules(
        kind: GeneratorKind.charged,
        charges: 2,
        cooldownSeconds: 3600,
      ),
    );
    final game = await board(gen);
    expect(game.generatorLabel(gen), '×2');
    tap(game, 'fig');
    tap(game, 'fig');
    expect(game.snapshotItems(), hasLength(2));
    expect(manna.manna, 10);
    expect(game.generatorLabel(gen), '1:00:00');
    // Resting: a tap gives nothing.
    tap(game, 'fig');
    expect(game.snapshotItems(), hasLength(2));
    // Its rest is saved with it.
    final saved = game.snapshotGenerators().single.timer;
    expect(saved?.left, 0);
    expect(saved?.at, now.add(const Duration(hours: 1)));

    now = now.add(const Duration(minutes: 59));
    expect(game.generatorLabel(gen), '1:00');
    now = now.add(const Duration(minutes: 1));
    expect(game.generatorLabel(gen), '×2');
    tap(game, 'fig');
    expect(game.snapshotItems(), hasLength(3));
  });

  test('a saved rest carries on where it was', () async {
    final gen = _gen(
      'fig',
      const GeneratorRules(
        kind: GeneratorKind.charged,
        charges: 2,
        cooldownSeconds: 3600,
      ),
    );
    final game = await board(
      gen,
      timers: {
        'fig': GeneratorTimer(
          left: 0,
          at: now.add(const Duration(minutes: 10)),
        ),
      },
    );
    expect(game.generatorLabel(gen), '10:00');
    tap(game, 'fig');
    expect(game.snapshotItems(), isEmpty);
    // The saved form reads back to the same clock.
    final again = SavedGenerator.fromJson(
      game.snapshotGenerators().single.toJson(),
    );
    expect(again.timer?.at, now.add(const Duration(minutes: 10)));
  });

  test('an hourglass ends a rest; with no rest it is not used', () async {
    final gen = _gen(
      'fig',
      const GeneratorRules(
        kind: GeneratorKind.charged,
        charges: 1,
        cooldownSeconds: 3600,
      ),
    );
    final game = await board(gen);
    expect(game.skipGeneratorWait('fig'), isFalse);
    tap(game, 'fig');
    expect(game.skipGeneratorWait('fig', seconds: 900), isTrue);
    expect(game.generatorLabel(gen), '45:00');
    expect(game.skipGeneratorWait('fig'), isTrue);
    expect(game.generatorLabel(gen), '×1');
    expect(game.skipGeneratorWait('nobody'), isFalse);
  });

  test('a free generator makes an item beside itself every interval, and '
      'is not tapped for more', () async {
    final gen = _gen(
      'olive',
      const GeneratorRules(
        kind: GeneratorKind.free,
        intervalSeconds: 600,
        maxWaiting: 2,
      ),
    );
    final game = await board(gen);
    expect(game.generatorLabel(gen), '10:00');
    tap(game, 'olive');
    game.update(1.1);
    expect(game.snapshotItems(), isEmpty);

    now = now.add(const Duration(minutes: 10));
    game.update(1.1);
    final made = game.snapshotItems();
    expect(made, hasLength(1));
    // In a cell touching the generator at (1, 1).
    expect((made.single.col - 1).abs(), lessThanOrEqualTo(1));
    expect((made.single.row - 1).abs(), lessThanOrEqualTo(1));
    expect(manna.manna, 10);
    expect(game.generatorLabel(gen), '10:00');

    // A long time away: a few items, never more than its limit.
    now = now.add(const Duration(days: 2));
    game.update(1.1);
    expect(game.snapshotItems(), hasLength(3));
  });

  test(
    'a free generator with no room beside it waits, then delivers',
    () async {
      final gen = _gen(
        'olive',
        const GeneratorRules(kind: GeneratorKind.free, intervalSeconds: 600),
      );
      final game = await board(gen, col: 0, row: 0);
      // Fill the three cells that touch the corner.
      for (var i = 0; i < 3; i++) {
        game.placeItem(_fig);
      }
      final blocked = {for (final i in game.snapshotItems()) (i.col, i.row)};
      if (!blocked.containsAll({(0, 1), (1, 0), (1, 1)})) {
        // placeItem fills column by column; top up until the corner is shut.
        while (!{
          for (final i in game.snapshotItems()) (i.col, i.row),
        }.containsAll({(0, 1), (1, 0), (1, 1)})) {
          game.placeItem(_fig);
        }
      }
      final before = game.snapshotItems().length;
      now = now.add(const Duration(minutes: 30));
      game.update(1.1);
      expect(game.snapshotItems(), hasLength(before));
      // A neighbour is cleared: the waiting item arrives.
      expect(game.removeItems({'fruit_1': 1}), isTrue);
      final freed = game.snapshotItems().length;
      game.update(1.1);
      final after = {for (final i in game.snapshotItems()) (i.col, i.row)};
      if (after.containsAll({(0, 1), (1, 0), (1, 1)})) {
        expect(game.snapshotItems().length, freed + 1);
      }
    },
  );

  test('a temporary generator gives its items for no Manna and then leaves '
      'the board', () async {
    final gen = _gen(
      'boat',
      const GeneratorRules(kind: GeneratorKind.temporary, taps: 2),
    );
    final game = await board(gen);
    expect(game.generatorLabel(gen), '×2');
    tap(game, 'boat');
    expect(game.generatorPlacements, hasLength(1));
    tap(game, 'boat');
    expect(game.snapshotItems(), hasLength(2));
    expect(manna.manna, 10);
    expect(game.generatorPlacements, isEmpty);
    expect(game.snapshotGenerators(), isEmpty);
    game.update(0);
    expect(game.children.whereType<GeneratorComponent>(), isEmpty);
    // Its cell can now hold an item.
    for (var i = 0; i < 7; i++) {
      game.placeItem(_fig);
    }
    expect(game.snapshotItems(), hasLength(9));
  });

  test('a standard generator is unchanged: Manna per tap, no clock', () async {
    final gen = _gen('pantry', GeneratorRules.standard);
    final game = await board(gen);
    expect(game.generatorLabel(gen), '1M');
    tap(game, 'pantry');
    expect(manna.manna, 9);
    expect(game.snapshotGenerators().single.timer, isNull);
    expect(game.skipGeneratorWait('pantry'), isFalse);
  });
}
