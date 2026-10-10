// Player levels: XP comes from story tasks, and each level reached gives a
// Manna refill, a small reward, and sometimes unlocks a feature. Pure Dart.
import 'package:whispers_of_joppa/domain/bubbles.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/progression.dart';

/// One level above the first: the total XP it takes to reach it, and what
/// reaching it gives.
class LevelStep {
  final int level;
  final int xp;
  final int talents;

  /// Item ids given on reaching it (an hourglass, a Manna jar).
  final List<String> items;

  /// A temporary generator given on reaching it, if any.
  final String? generator;

  const LevelStep({
    required this.level,
    required this.xp,
    this.talents = 0,
    this.items = const [],
    this.generator,
  });
}

/// A feature that opens at a level.
class FeatureUnlock {
  final int level;
  final String feature;
  final String name;

  /// False until the feature exists in the game; such unlocks are not
  /// announced to the player.
  final bool available;

  /// For a generator-boost unlock: what the boost does.
  final GeneratorBoost? boost;

  /// For the bubbles unlock: the numbers bubbles go by.
  final BubbleRules? bubble;

  const FeatureUnlock({
    required this.level,
    required this.feature,
    required this.name,
    this.available = false,
    this.boost,
    this.bubble,
  });
}

class LevelsConfig {
  /// chapter number -> XP for each task in it.
  final Map<int, int> xpPerTaskByChapter;

  /// XP for a task in a chapter not listed above.
  final int xpPerTaskDefault;

  /// Levels 2 and up, lowest first.
  final List<LevelStep> steps;
  final List<FeatureUnlock> unlocks;

  /// Wording for the level badge and the level-up message.
  final Map<String, String> text;

  const LevelsConfig({
    required this.xpPerTaskByChapter,
    required this.xpPerTaskDefault,
    required this.steps,
    this.unlocks = const [],
    this.text = const {},
  });

  factory LevelsConfig.fromJson(Map<String, dynamic> json) => LevelsConfig(
    xpPerTaskByChapter: {
      for (final e
          in (json['xp_per_task_by_chapter'] as Map<String, dynamic>).entries)
        int.parse(e.key): e.value as int,
    },
    xpPerTaskDefault: json['xp_per_task_default'] as int,
    steps: [
      for (final l in json['levels'] as List<dynamic>)
        LevelStep(
          level: (l as Map<String, dynamic>)['level'] as int,
          xp: l['xp'] as int,
          talents: l['talents'] as int? ?? 0,
          items: List<String>.from(l['items'] as List<dynamic>? ?? const []),
          generator: l['generator'] as String?,
        ),
    ],
    unlocks: [
      for (final u in json['unlocks'] as List<dynamic>? ?? const [])
        FeatureUnlock(
          level: (u as Map<String, dynamic>)['level'] as int,
          feature: u['feature'] as String,
          name: u['name'] as String,
          available: u['available'] as bool? ?? false,
          boost: switch (u['boost']) {
            {'manna_times': final int times, 'tier_bonus': final int bonus} =>
              GeneratorBoost(mannaTimes: times, tierBonus: bonus),
            _ => null,
          },
          bubble: BubbleRules.fromJson(u['bubble']),
        ),
    ],
    text: {
      for (final e
          in (json['text'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: e.value as String,
    },
  );

  int get maxLevel => steps.isEmpty ? 1 : steps.last.level;

  /// The unlock of [feature], or null if the game has none (or it is held
  /// back).
  FeatureUnlock? unlock(String feature) =>
      unlocks.where((u) => u.feature == feature && u.available).firstOrNull;

  /// The level bubbles begin at and their numbers, or null if the game has
  /// none (or they are held back).
  FeatureUnlock? get bubbles =>
      unlocks.where((u) => u.bubble != null && u.available).firstOrNull;

  /// The generator boosts in the game, weakest first (one marked not yet
  /// available is left out, like any other feature held back).
  List<FeatureUnlock> get boosts => [
    for (final u in unlocks)
      if (u.boost != null && u.available) u,
  ]..sort((a, b) => a.level.compareTo(b.level));

  /// The level a player with [xp] has reached. Everyone starts at level 1.
  int levelAt(int xp) {
    var level = 1;
    for (final step in steps) {
      if (xp < step.xp) break;
      level = step.level;
    }
    return level;
  }

  /// How far [xp] is into the current level: XP gained since reaching it,
  /// and the XP the whole level takes. At the highest level both are 0.
  ({int into, int needed}) progress(int xp) {
    var floor = 0;
    for (final step in steps) {
      if (xp < step.xp) return (into: xp - floor, needed: step.xp - floor);
      floor = step.xp;
    }
    return (into: 0, needed: 0);
  }

  /// Whether [feature] is open at [level]. A feature with no level set is
  /// always open.
  bool isUnlocked(String feature, int level) {
    for (final unlock in unlocks) {
      if (unlock.feature == feature) return level >= unlock.level;
    }
    return true;
  }
}

/// For content from before levels existed: everyone stays at level 1.
const noLevels = LevelsConfig(
  xpPerTaskByChapter: {},
  xpPerTaskDefault: 0,
  steps: [],
);

/// All the XP earned from the tasks in [done].
int xpEarned(
  LevelsConfig config,
  List<ChapterModel> chapters,
  Set<String> done,
) {
  var xp = 0;
  for (final chapter in chapters) {
    final each =
        config.xpPerTaskByChapter[chapter.number] ?? config.xpPerTaskDefault;
    for (final task in chapter.tasks) {
      if (done.contains(task.id)) xp += each;
    }
  }
  return xp;
}

/// What a player is owed for the levels gained since they were last
/// rewarded.
class LevelUp {
  final int from;
  final int to;
  final int talents;

  /// Features that opened on the way and exist in the game.
  final List<FeatureUnlock> unlocked;

  /// Gift items and temporary generators, by id.
  final List<String> items;
  final List<String> generators;

  const LevelUp({
    required this.from,
    required this.to,
    required this.talents,
    required this.unlocked,
    this.items = const [],
    this.generators = const [],
  });
}

/// The rewards for every level after [rewarded] up to [current], or null if
/// none is owed. Each level is paid exactly once, however many are gained
/// at a time.
LevelUp? levelUpOwed(
  LevelsConfig config, {
  required int rewarded,
  required int current,
}) {
  if (current <= rewarded) return null;
  var talents = 0;
  final items = <String>[];
  final generators = <String>[];
  for (final step in config.steps) {
    if (step.level <= rewarded || step.level > current) continue;
    talents += step.talents;
    items.addAll(step.items);
    if (step.generator case final generator?) generators.add(generator);
  }
  return LevelUp(
    from: rewarded,
    to: current,
    talents: talents,
    items: items,
    generators: generators,
    unlocked: [
      for (final unlock in config.unlocks)
        if (unlock.available &&
            unlock.level > rewarded &&
            unlock.level <= current)
          unlock,
    ],
  );
}
