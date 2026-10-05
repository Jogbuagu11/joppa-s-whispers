// Loads content/*.json and builds runtime lookup tables.
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';

final _log = Logger('ContentLoader');

class ContentLoader {
  /// item_id -> ItemModel
  final Map<String, ItemModel> items = {};

  /// chain_id -> ChainTierData
  final Map<String, ChainTierData> chains = {};

  /// chain_id -> ARGB colour used for placeholder tiles until real art exists.
  final Map<String, int> chainPlaceholderColors = {};

  /// generator_id -> GeneratorLevelData list
  final Map<String, List<GeneratorLevelData>> generatorLevels = {};

  /// generator_id -> GeneratorModel (default level 1)
  final Map<String, GeneratorModel> generators = {};

  late EconomyConfig economy;
  late StartingBoard startingBoard;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Reads the bundled content files and builds the lookup tables.
  Future<void> load() async {
    try {
      loadFromJson(
        chainsJson: await _loadJson('content/chains.json'),
        generatorsJson: await _loadJson('content/generators.json'),
        economyJson: await _loadJson('content/economy.json'),
        startingBoardJson: await _loadJson('content/starting_board.json'),
      );
    } catch (e, stack) {
      _log.severe('Failed to load content', e, stack);
      rethrow;
    }
  }

  /// Builds the lookup tables from already-decoded JSON. Used by [load] and
  /// directly by unit tests, which read the files from disk.
  void loadFromJson({
    required Object? chainsJson,
    required Object? generatorsJson,
    required Object? economyJson,
    required Object? startingBoardJson,
  }) {
    economy = EconomyConfig.fromJson(economyJson as Map<String, dynamic>);
    _parseChains(chainsJson as List<dynamic>);
    _parseGenerators(generatorsJson as List<dynamic>);
    startingBoard = StartingBoard.fromJson(
      startingBoardJson as Map<String, dynamic>,
    );
    _loaded = true;
    _log.info(
      'Content loaded: ${items.length} items, ${generators.length} generators',
    );
  }

  void _parseChains(List<dynamic> list) {
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
        items[itemId] = ItemModel(
          itemId: itemId,
          chainId: chainId,
          tier: tier,
          name: t['name'] as String,
          asset: t['asset'] as String? ?? '',
          sell: t['sell'] as int,
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

      final color = parseHexColor(chain['placeholder_color'] as String?);
      if (color != null) chainPlaceholderColors[chainId] = color;
    }
  }

  void _parseGenerators(List<dynamic> list) {
    for (final genJson in list) {
      final gen = genJson as Map<String, dynamic>;
      final genId = gen['id'] as String;
      final levelsJson = gen['levels'] as List<dynamic>;
      generatorLevels[genId] = levelsJson.map((l) {
        final lm = l as Map<String, dynamic>;
        final oddsJson = lm['odds'] as Map<String, dynamic>;
        return GeneratorLevelData(
          level: lm['level'] as int,
          odds: oddsJson.map((k, v) => MapEntry(k, (v as num).toDouble())),
        );
      }).toList();
      generators[genId] = GeneratorModel(
        generatorId: genId,
        chainId: gen['chain_id'] as String,
        level: 1,
        // Tap cost comes from economy.json unless this generator overrides it.
        energyCost: gen['energy_cost'] as int? ?? economy.generatorTapCost,
        name: gen['name'] as String,
      );
    }
  }

  Future<dynamic> _loadJson(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return jsonDecode(raw);
  }
}

/// Turns "#RRGGBB" into an opaque ARGB int, or null if it is not that shape.
int? parseHexColor(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return 0xFF000000 | int.parse(hex.substring(1), radix: 16);
}
