// Loads content/*.json and builds runtime lookup tables.
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/reminders.dart';
import 'package:whispers_of_joppa/domain/generator.dart';
import 'package:whispers_of_joppa/domain/letters.dart';
import 'package:whispers_of_joppa/domain/locations.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/orders.dart';
import 'package:whispers_of_joppa/domain/progression.dart';
import 'package:whispers_of_joppa/domain/purchases.dart';
import 'package:whispers_of_joppa/domain/scenes.dart';
import 'package:whispers_of_joppa/domain/tutorial.dart';

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

  /// Every order in content, in the order players meet them.
  final List<OrderModel> orders = [];

  /// The first-session tutorial hints, in order.
  final List<TutorialStep> tutorial = [];

  /// chapter_id -> the message shown when that chapter is finished.
  final Map<String, ChapterEnding> endings = {};

  /// product_id -> what the product gives.
  final Map<String, ProductModel> products = {};

  /// Esther's letters, in content order.
  final List<LetterModel> letters = [];

  /// location_id -> location
  final Map<String, LocationModel> locations = {};

  /// Every chapter in content, in story order.
  final List<ChapterModel> chapters = [];

  /// scene_id -> scene
  final Map<String, SceneModel> scenes = {};

  /// character_id -> display name
  final Map<String, String> characterNames = {};

  /// Notification wording and timing; null only in tests that leave it out.
  NotificationContent? notifications;

  late EconomyConfig economy;
  late StartingBoard startingBoard;

  /// The version of the content that was loaded.
  int contentVersion = 0;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// A loader holding only one event's chain and generator (in the same
  /// form as content/chains.json and content/generators.json entries).
  static ContentLoader forEvent({
    required Map<String, dynamic> chain,
    required Map<String, dynamic> generator,
    required EconomyConfig economy,
  }) => ContentLoader()
    ..economy = economy
    .._parseChains([chain])
    .._parseGenerators([generator]);

  /// Reads the content that ships in the app and builds the lookup tables.
  Future<void> load() async => loadFromBundle(await loadBundledContent());

  /// Builds the lookup tables from a content bundle (the app's own, or one
  /// downloaded from the server and already checked).
  void loadFromBundle(ContentBundle bundle) {
    final files = bundle.files;
    try {
      loadFromJson(
        chainsJson: files['chains'],
        generatorsJson: files['generators'],
        economyJson: files['economy'],
        startingBoardJson: files['starting_board'],
        ordersJson: files['orders'],
        charactersJson: files['characters'],
        scenesJson: files['scenes'],
        chaptersJson: files['chapters'],
        locationsJson: files['locations'],
        tutorialJson: files['tutorial'],
        endingsJson: files['endings'],
        lettersJson: files['letters'],
        productsJson: files['products'],
        notificationsJson: files['notifications'],
      );
      contentVersion = bundle.version;
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
    required Object? ordersJson,
    required Object? charactersJson,
    required Object? scenesJson,
    required Object? chaptersJson,
    required Object? locationsJson,
    required Object? tutorialJson,
    required Object? endingsJson,
    required Object? lettersJson,
    required Object? productsJson,
    Object? notificationsJson,
  }) {
    notifications = notificationsJson == null
        ? null
        : NotificationContent.fromJson(
            notificationsJson as Map<String, dynamic>,
          );
    economy = EconomyConfig.fromJson(economyJson as Map<String, dynamic>);
    _parseChains(chainsJson as List<dynamic>);
    _parseGenerators(generatorsJson as List<dynamic>);
    startingBoard = StartingBoard.fromJson(
      startingBoardJson as Map<String, dynamic>,
    );
    for (final o in ordersJson as List<dynamic>) {
      orders.add(OrderModel.fromJson(o as Map<String, dynamic>));
    }
    for (final c in charactersJson as List<dynamic>) {
      final character = c as Map<String, dynamic>;
      characterNames[character['id'] as String] = character['name'] as String;
    }
    for (final s in scenesJson as List<dynamic>) {
      final scene = SceneModel.fromJson(s as Map<String, dynamic>);
      scenes[scene.id] = scene;
    }
    for (final c in chaptersJson as List<dynamic>) {
      chapters.add(ChapterModel.fromJson(c as Map<String, dynamic>));
    }
    chapters.sort((a, b) => a.number.compareTo(b.number));
    for (final l in locationsJson as List<dynamic>) {
      final location = LocationModel.fromJson(l as Map<String, dynamic>);
      locations[location.id] = location;
    }
    for (final t in tutorialJson as List<dynamic>) {
      tutorial.add(TutorialStep.fromJson(t as Map<String, dynamic>));
    }
    for (final e in endingsJson as List<dynamic>) {
      final ending = ChapterEnding.fromJson(e as Map<String, dynamic>);
      endings[ending.chapterId] = ending;
    }
    for (final l in lettersJson as List<dynamic>) {
      letters.add(LetterModel.fromJson(l as Map<String, dynamic>));
    }
    for (final p in productsJson as List<dynamic>) {
      final product = ProductModel.fromJson(p as Map<String, dynamic>);
      products[product.id] = product;
    }
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
}

/// Turns "#RRGGBB" into an opaque ARGB int, or null if it is not that shape.
int? parseHexColor(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return 0xFF000000 | int.parse(hex.substring(1), radix: 16);
}

/// Reads the content that ships inside the app (content/*.json).
Future<ContentBundle> loadBundledContent() async {
  Future<Object?> read(String name) async =>
      jsonDecode(await rootBundle.loadString('content/$name.json'));
  final manifest = await read('version') as Map<String, dynamic>;
  return ContentBundle(
    version: manifest['version'] as int,
    format: manifest['format'] as int,
    files: {for (final name in contentFileNames) name: await read(name)},
  );
}

/// Reads the app's own events (content/events.json): the fallback when the
/// server's list has never been fetched.
Future<List<Object?>> loadBundledEvents() async =>
    jsonDecode(await rootBundle.loadString('content/events.json'))
        as List<dynamic>;
