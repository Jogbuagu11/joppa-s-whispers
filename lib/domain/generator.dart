// Generator spawn logic — pure Dart, fully unit tested.
import 'dart:math';
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
