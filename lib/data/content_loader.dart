// Loads content/*.json and builds runtime lookup tables.
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/economy.dart';

final _log = Logger('ContentLoader');

class ContentLoader {
  /// All chains indexed by chain_id.
  final Map<String, List<Map<String, dynamic>>> _rawChains = {};

  /// item_id -> ItemModel
  final Map<String, ItemModel> items = {};

  /// chain_id -> ChainTierData
  final Map<String, ChainTierData> chains = {};

  /// generator_id -> GeneratorLevelData list
  final Map<String, List<GeneratorLevelData>> generatorLevels = {};

  /// generator_id -> GeneratorModel (default level 1)
  final Map<String, GeneratorModel> generators = {};

  late EconomyConfig economy;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      await _loadChains();
      await _loadGenerators();
      await _loadEconomy();
      _loaded = true;
      _log.info(
        'Content loaded: ${items.length} items, ${generators.length} generators',
      );
    } catch (e, stack) {
      _log.severe('Failed to load content', e, stack);
      rethrow;
    }
  }

  Future<void> _loadChains() async {
    final json = await _loadJson('content/chains.json');
    final list = json as List<dynamic>;
    for (final chainJson in list) {
      final chain = chainJson as Map<String, dynamic>;
      final chainId = chain['id'] as String;
      final tiersJson = chain['tiers'] as List<dynamic>;

      final itemTiers = <String, int>{};
      final tierToItemId = <String, String>{};
      int maxTier = 0;

      for (final tierJson in tiersJson) {
        final t = tierJson as Map<String, dynamic>;
        final itemId = t['item_id'] as String;
        final tier = t['tier'] as int;
        final name = t['name'] as String;
        final asset = t['asset'] as String? ?? '';
        items[itemId] = ItemModel(
          itemId: itemId,
          chainId: chainId,
          tier: tier,
          name: name,
          asset: asset,
        );
        itemTiers[itemId] = tier;
        tierToItemId['${chainId}_$tier'] = itemId;
        if (tier > maxTier) maxTier = tier;
      }

      chains[chainId] = ChainTierData(
        chainId: chainId,
        maxTier: maxTier,
        itemTiers: itemTiers,
        tierToItemId: tierToItemId,
      );
      _rawChains[chainId] = tiersJson.cast<Map<String, dynamic>>();
    }
  }

  Future<void> _loadGenerators() async {
    final json = await _loadJson('content/generators.json');
    final list = json as List<dynamic>;
    for (final genJson in list) {
      final gen = genJson as Map<String, dynamic>;
      final genId = gen['id'] as String;
      final levelsJson = gen['levels'] as List<dynamic>;
      final levels = levelsJson.map((l) {
        final lm = l as Map<String, dynamic>;
        final oddsJson = lm['odds'] as Map<String, dynamic>;
        return GeneratorLevelData(
          level: lm['level'] as int,
          odds: oddsJson.map((k, v) => MapEntry(k, (v as num).toDouble())),
        );
      }).toList();
      generatorLevels[genId] = levels;
      generators[genId] = GeneratorModel(
        generatorId: genId,
        chainId: gen['chain_id'] as String,
        level: 1,
        energyCost: gen['energy_cost'] as int,
        name: gen['name'] as String,
      );
    }
  }

  Future<void> _loadEconomy() async {
    final json = await _loadJson('content/economy.json');
    economy = EconomyConfig.fromJson(json as Map<String, dynamic>);
  }

  Future<dynamic> _loadJson(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return jsonDecode(raw);
  }
}
