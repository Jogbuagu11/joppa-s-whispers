// Checks content/*.json for mistakes before the game uses it.
// Pure Dart (no Flutter imports) so tool/validate_content.dart can run it.
import 'package:whispers_of_joppa/data/level_validator.dart';
import 'package:whispers_of_joppa/data/notification_validator.dart';
import 'package:whispers_of_joppa/data/chapter_validator.dart';
import 'package:whispers_of_joppa/data/order_validator.dart';
import 'package:whispers_of_joppa/data/scene_validator.dart';
import 'package:whispers_of_joppa/data/starting_board_validator.dart';
import 'package:whispers_of_joppa/data/tutorial_validator.dart';

final _idPattern = RegExp(r'^[a-z][a-z0-9_]*$');
final _itemAssetPattern = RegExp(
  r'^assets/items/item_[a-z]+_\d{2}\.(png|jpg)$',
);
final _colorPattern = RegExp(r'^#[0-9a-fA-F]{6}$');

/// Economy values the game divides by, so they can never be 0.
const _mustBePositive = {'max_manna', 'manna_regen_seconds', 'order_slots'};

/// Every key the game reads from content/economy.json.
const requiredEconomyKeys = [
  'max_manna',
  'manna_regen_seconds',
  'generator_tap_cost',
  'order_talents_per_tier',
  'order_slots',
  'tutorial_free_taps',
  'manna_refill_base_pearls',
  'basket_slot_base_pearls',
  'order_skip_cooldown_seconds',
  'rewarded_ad_manna_bonus',
  'rewarded_ad_manna_daily_cap',
  'rewarded_ad_double_reward_daily_cap',
];

/// Returns a list of plain-English problems. An empty list means the content
/// is valid.
List<String> validateContent({
  required Object? chainsJson,
  required Object? generatorsJson,
  required Object? economyJson,
  required Object? startingBoardJson,
  required Object? ordersJson,
  required Object? charactersJson,
  required Object? scenesJson,
  required Object? chaptersJson,
  required Object? locationsJson,
  required Object? lettersJson,
  required Object? tutorialJson,
  required Object? endingsJson,
  required Object? productsJson,
  Object? notificationsJson,
  Object? levelsJson,
}) {
  final problems = <String>[];
  try {
    if (startingBoardJson is! Map<String, dynamic>) {
      throw TypeError();
    }
    final chains = (chainsJson as List<dynamic>).cast<Map<String, dynamic>>();
    final generators = (generatorsJson as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final maxTierByChain = _checkChains(chains, problems);
    final generatorIds = _checkGenerators(generators, maxTierByChain, problems);
    for (final chain in chains) {
      final genId = chain['generator_id'];
      if (!generatorIds.contains(genId)) {
        problems.add('Chain ${chain['id']}: unknown generator "$genId"');
      }
    }
    _checkEconomy(economyJson as Map<String, dynamic>, problems);
    final characters = (charactersJson as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final scenes = (scenesJson as List<dynamic>).cast<Map<String, dynamic>>();
    checkOrdersAndCharacters(
      orders: (ordersJson as List<dynamic>).cast<Map<String, dynamic>>(),
      characters: characters,
      chains: chains,
      economy: economyJson,
      problems: problems,
    );
    checkScenes(scenes: scenes, characters: characters, problems: problems);
    final chapters = (chaptersJson as List<dynamic>)
        .cast<Map<String, dynamic>>();
    checkChapters(
      chapters: chapters,
      locations: (locationsJson as List<dynamic>).cast<Map<String, dynamic>>(),
      letters: (lettersJson as List<dynamic>).cast<Map<String, dynamic>>(),
      sceneIds: {for (final s in scenes) s['id'] as String},
      chainIds: {for (final c in chains) c['id'] as String},
      orders: ordersJson.cast<Map<String, dynamic>>(),
      problems: problems,
    );
    checkProducts(
      (productsJson as List<dynamic>).cast<Map<String, dynamic>>(),
      problems,
    );
    checkTutorialAndEndings(
      tutorial: (tutorialJson as List<dynamic>).cast<Map<String, dynamic>>(),
      endings: (endingsJson as List<dynamic>).cast<Map<String, dynamic>>(),
      characterIds: {for (final c in characters) c['id'] as String},
      orderIds: {
        for (final o in ordersJson) (o as Map<String, dynamic>)['id'] as String,
      },
      taskIds: {
        for (final c in chapters)
          for (final t in c['tasks'] as List<dynamic>)
            (t as Map<String, dynamic>)['id'] as String,
      },
      chapterIds: {for (final c in chapters) c['id'] as String},
      problems: problems,
    );
    if (notificationsJson != null) {
      checkNotifications(
        notificationsJson as Map<String, dynamic>,
        taskIds: {
          for (final c in chapters)
            for (final t in c['tasks'] as List<dynamic>)
              (t as Map<String, dynamic>)['id'] as String,
        },
        problems: problems,
      );
    }
    if (levelsJson != null) {
      checkLevels(
        levelsJson as Map<String, dynamic>,
        chapterNumbers: {for (final c in chapters) c['number'] as int},
        problems: problems,
      );
    }
    final opening = startingBoardJson['opening_scene'];
    if (opening != null && !scenes.any((s) => s['id'] == opening)) {
      problems.add('Starting board: unknown opening scene "$opening"');
    }
    checkStartingBoard(
      startingBoardJson,
      generatorIds: generatorIds,
      generatorUnlockChapters: {
        for (final g in generators)
          if (g['unlock_chapter'] case final int chapter)
            g['id'] as String: chapter,
      },
      itemIds: {
        for (final chain in chains)
          for (final t in chain['tiers'] as List<dynamic>)
            (t as Map<String, dynamic>)['item_id'] as String,
      },
      economy: economyJson,
      problems: problems,
    );
  } on TypeError catch (e) {
    problems.add(
      'Content has the wrong shape: a field is missing or is the wrong kind '
      'of value (details: $e)',
    );
  }
  return problems;
}

void _checkId(String kind, Object? id, Set<String> seen, List<String> out) {
  if (id is! String || !_idPattern.hasMatch(id)) {
    out.add('$kind id "$id" must be lowercase snake_case');
  } else if (!seen.add(id)) {
    out.add('$kind id "$id" is used more than once');
  }
}

/// Returns chain_id -> highest tier.
Map<String, int> _checkChains(
  List<Map<String, dynamic>> chains,
  List<String> problems,
) {
  final chainIds = <String>{};
  final itemIds = <String>{};
  final maxTier = <String, int>{};
  for (final chain in chains) {
    final id = chain['id'];
    _checkId('Chain', id, chainIds, problems);
    final color = chain['placeholder_color'];
    if (color is! String || !_colorPattern.hasMatch(color)) {
      problems.add('Chain $id: placeholder_color must look like #RRGGBB');
    }
    final tiers = (chain['tiers'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (tiers.isEmpty) problems.add('Chain $id: has no tiers');
    for (var i = 0; i < tiers.length; i++) {
      final tier = tiers[i];
      _checkId('Item', tier['item_id'], itemIds, problems);
      if (tier['tier'] != i + 1) {
        problems.add('Chain $id: tiers must count 1, 2, 3… in order');
      }
      final name = tier['name'];
      if (name is! String || name.trim().isEmpty) {
        problems.add('Chain $id tier ${i + 1}: missing name');
      }
      final asset = tier['asset'];
      if (asset != null &&
          (asset is! String || !_itemAssetPattern.hasMatch(asset))) {
        problems.add(
          'Chain $id tier ${i + 1}: asset must be assets/items/item_…_NN.png or .jpg',
        );
      }
      final sell = tier['sell'];
      if (sell is! int || sell < 0) {
        problems.add('Chain $id tier ${i + 1}: sell must be a whole number');
      }
    }
    if (id is String) maxTier[id] = tiers.length;
  }
  return maxTier;
}

/// Returns the set of generator ids.
Set<String> _checkGenerators(
  List<Map<String, dynamic>> generators,
  Map<String, int> maxTierByChain,
  List<String> problems,
) {
  final ids = <String>{};
  for (final gen in generators) {
    final id = gen['id'];
    _checkId('Generator', id, ids, problems);
    final chainMax = maxTierByChain[gen['chain_id']];
    if (chainMax == null) {
      problems.add('Generator $id: unknown chain "${gen['chain_id']}"');
    }
    final name = gen['name'];
    if (name is! String || name.trim().isEmpty) {
      problems.add('Generator $id: missing name');
    }
    final cost = gen['energy_cost'];
    if (cost != null && (cost is! int || cost < 0)) {
      problems.add('Generator $id: energy_cost must be 0 or more');
    }
    final levels = (gen['levels'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (levels.isEmpty) problems.add('Generator $id: has no levels');
    for (var i = 0; i < levels.length; i++) {
      final level = levels[i];
      if (level['level'] != i + 1) {
        problems.add('Generator $id: levels must count 1, 2, 3… in order');
      }
      final odds = level['odds'] as Map<String, dynamic>;
      var sum = 0.0;
      for (final entry in odds.entries) {
        final tier = int.tryParse(entry.key);
        if (tier == null || tier < 1 || (chainMax != null && tier > chainMax)) {
          problems.add(
            'Generator $id level ${i + 1}: tier "${entry.key}" is not in its chain',
          );
        }
        sum += (entry.value as num).toDouble();
      }
      if ((sum - 1.0).abs() > 1e-9) {
        problems.add(
          'Generator $id level ${i + 1}: odds add up to $sum, not 1.0',
        );
      }
    }
  }
  return ids;
}

void _checkEconomy(Map<String, dynamic> economy, List<String> problems) {
  for (final key in requiredEconomyKeys) {
    if (!economy.containsKey(key)) problems.add('Economy $key is missing');
  }
  for (final entry in economy.entries) {
    final value = entry.value;
    if (value is! int || value < 0) {
      problems.add('Economy ${entry.key}: must be a whole number, 0 or more');
    } else if (value == 0 && _mustBePositive.contains(entry.key)) {
      problems.add('Economy ${entry.key}: must be at least 1');
    }
  }
}
