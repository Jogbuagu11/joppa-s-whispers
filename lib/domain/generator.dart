// Generator spawn logic — pure Dart, fully unit tested.
import 'dart:math';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';

/// Generator level data loaded from content/generators.json.
class GeneratorLevelData {
  final int level;
  // Maps tier number (as string) -> spawn probability
  final Map<String, double> odds;

  const GeneratorLevelData({required this.level, required this.odds});
}

/// Returns the tier that a generator spawns based on its odds table.
/// [random] is injectable for deterministic unit testing.
int spawnTier(GeneratorLevelData levelData, {Random? random}) {
  final rng = random ?? Random();
  final roll = rng.nextDouble();
  double cumulative = 0.0;
  // Sort by tier ascending so lower tiers are checked first.
  final sorted = levelData.odds.entries.toList()
    ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
  for (final entry in sorted) {
    cumulative += entry.value;
    if (roll < cumulative) return int.parse(entry.key);
  }
  // Fallback: return tier 1.
  return 1;
}

/// Whether the board has space for a new item.
bool boardHasSpace(BoardState state) => state.firstEmpty() != null;

/// Whether the player has enough manna to tap a generator.
bool canAffordGenerator(BoardState state, GeneratorModel gen) =>
    state.manna >= gen.energyCost;

/// Returns the item_id that should be spawned for the given chain and tier.
/// Returns null if the chain or tier is not found in the catalog.
String? resolveSpawnedItemId(
  String chainId,
  int tier,
  Map<String, ChainTierData> chains,
) => chains[chainId]?.tierToItemId['${chainId}_$tier'];

/// Why a generator tap produced nothing.
enum GeneratorTapRefusal { notEnoughManna, boardFull, noLevelData, noItem }

/// Outcome of tapping a generator: either an item to spawn or a refusal.
class GeneratorTapResult {
  final String? itemId;
  final int? tier;
  final int mannaAfter;
  final GeneratorTapRefusal? refusal;

  const GeneratorTapResult.spawn({
    required String this.itemId,
    required int this.tier,
    required this.mannaAfter,
  }) : refusal = null;

  const GeneratorTapResult.refused(
    GeneratorTapRefusal this.refusal, {
    required this.mannaAfter,
  }) : itemId = null,
       tier = null;

  bool get spawned => refusal == null;
}

/// Decides what happens when a generator is tapped. Manna is only spent
/// when an item is actually spawned.
GeneratorTapResult resolveGeneratorTap({
  required GeneratorModel gen,
  required int manna,
  required bool hasFreeCell,
  required List<GeneratorLevelData>? levels,
  required Map<String, ChainTierData> chains,
  Random? random,
}) {
  GeneratorTapResult refuse(GeneratorTapRefusal why) =>
      GeneratorTapResult.refused(why, mannaAfter: manna);

  if (manna < gen.energyCost) return refuse(GeneratorTapRefusal.notEnoughManna);
  if (!hasFreeCell) return refuse(GeneratorTapRefusal.boardFull);
  if (levels == null || levels.isEmpty) {
    return refuse(GeneratorTapRefusal.noLevelData);
  }
  // Use the generator's current level; fall back to the first level listed.
  final levelData = levels.firstWhere(
    (l) => l.level == gen.level,
    orElse: () => levels.first,
  );
  final tier = spawnTier(levelData, random: random);
  final itemId = resolveSpawnedItemId(gen.chainId, tier, chains);
  if (itemId == null) return refuse(GeneratorTapRefusal.noItem);
  return GeneratorTapResult.spawn(
    itemId: itemId,
    tier: tier,
    mannaAfter: manna - gen.energyCost,
  );
}
