import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';

Object? _read(String name) =>
    jsonDecode(File('content/$name.json').readAsStringSync());

void main() {
  late ContentLoader loader;

  setUp(() {
    loader = ContentLoader()
      ..loadFromJson(
        chainsJson: _read('chains'),
        generatorsJson: _read('generators'),
        economyJson: _read('economy'),
        startingBoardJson: _read('starting_board'),
        ordersJson: _read('orders'),
        charactersJson: _read('characters'),
        scenesJson: _read('scenes'),
        chaptersJson: _read('chapters'),
        locationsJson: _read('locations'),
        tutorialJson: _read('tutorial'),
        endingsJson: _read('endings'),
      );
  });

  test('loads every chain, item and generator from content', () {
    final chains = _read('chains') as List<dynamic>;
    final itemCount = chains.fold<int>(
      0,
      (n, c) => n + ((c as Map<String, dynamic>)['tiers'] as List).length,
    );
    expect(loader.isLoaded, isTrue);
    expect(loader.chains.length, chains.length);
    expect(loader.items.length, itemCount);
    expect(
      loader.generators.length,
      (_read('generators') as List<dynamic>).length,
    );
  });

  test('items know their chain and tier', () {
    final item = loader.items['bakery_02'];
    expect(item?.chainId, 'bakery');
    expect(item?.tier, 2);
    expect(loader.chains['bakery']?.tierToItemId['bakery_2'], 'bakery_02');
  });

  test('every chain has a placeholder colour', () {
    expect(loader.chainPlaceholderColors.keys, loader.chains.keys);
  });

  test('every generator has level data and a known chain', () {
    for (final gen in loader.generators.values) {
      expect(loader.generatorLevels[gen.generatorId], isNotEmpty);
      expect(loader.chains.containsKey(gen.chainId), isTrue);
    }
  });

  test('starting board refers only to loaded content', () {
    final start = loader.startingBoard;
    expect(start.generators, isNotEmpty);
    for (final g in start.generators) {
      expect(loader.generators.containsKey(g.generatorId), isTrue);
    }
    for (final i in start.items) {
      expect(loader.items.containsKey(i.itemId), isTrue);
    }
    expect(start.manna, lessThanOrEqualTo(loader.economy.maxManna));
  });

  test('parseHexColor', () {
    expect(parseHexColor('#D4802A'), 0xFFD4802A);
    expect(parseHexColor('D4802A'), isNull);
    expect(parseHexColor('#12'), isNull);
    expect(parseHexColor(null), isNull);
  });

  test('starting board values are parsed from content', () {
    final raw = _read('starting_board') as Map<String, dynamic>;
    final rawGen =
        (raw['generators'] as List<dynamic>).first as Map<String, dynamic>;
    final rawItem =
        (raw['items'] as List<dynamic>).first as Map<String, dynamic>;
    final start = loader.startingBoard;
    expect(start.manna, raw['manna']);
    expect(start.generators.length, (raw['generators'] as List).length);
    expect(start.generators.first.generatorId, rawGen['generator_id']);
    expect(start.generators.first.col, rawGen['col']);
    expect(start.generators.first.row, rawGen['row']);
    expect(start.items.length, (raw['items'] as List).length);
    expect(start.items.first.itemId, rawItem['item_id']);
    expect(start.items.first.col, rawItem['col']);
    expect(start.items.first.row, rawItem['row']);
  });

  test('items carry the sell value from content', () {
    final chains = _read('chains') as List<dynamic>;
    final firstTier =
        ((chains.first as Map<String, dynamic>)['tiers'] as List<dynamic>).first
            as Map<String, dynamic>;
    expect(loader.items[firstTier['item_id']]?.sell, firstTier['sell']);
  });

  test('generator tap cost comes from economy.json', () {
    for (final gen in loader.generators.values) {
      expect(gen.energyCost, loader.economy.generatorTapCost);
    }
  });

  test('a generator can override the tap cost', () {
    final generators = _read('generators') as List<dynamic>;
    final first = Map<String, dynamic>.of(
      generators.first as Map<String, dynamic>,
    )..['energy_cost'] = 0;
    final custom = ContentLoader()
      ..loadFromJson(
        chainsJson: _read('chains'),
        generatorsJson: [first, ...generators.skip(1)],
        economyJson: _read('economy'),
        startingBoardJson: _read('starting_board'),
        ordersJson: _read('orders'),
        charactersJson: _read('characters'),
        scenesJson: _read('scenes'),
        chaptersJson: _read('chapters'),
        locationsJson: _read('locations'),
        tutorialJson: _read('tutorial'),
        endingsJson: _read('endings'),
      );
    expect(custom.generators[first['id']]?.energyCost, 0);
  });

  test('every art file named in content exists', () {
    for (final item in loader.items.values) {
      if (item.asset.isEmpty) continue;
      expect(File(item.asset).existsSync(), isTrue, reason: item.asset);
    }
  });

  test('scenes and the opening scene are loaded from content', () {
    final raw = _read('scenes') as List<dynamic>;
    expect(loader.scenes.length, raw.length);
    final first = raw.first as Map<String, dynamic>;
    final scene = loader.scenes[first['id']];
    expect(scene?.background, first['background']);
    expect(scene?.lines.length, (first['lines'] as List).length);
    final opening = loader.startingBoard.openingScene;
    expect(opening, (_read('starting_board') as Map)['opening_scene']);
    expect(loader.scenes.containsKey(opening), isTrue);
  });

  test('chapters and their tasks are loaded in story order', () {
    final raw =
        (_read('chapters') as List<dynamic>).first as Map<String, dynamic>;
    final chapter = loader.chapters.first;
    expect(chapter.id, raw['id']);
    expect(chapter.title, raw['title']);
    final rawTasks = raw['tasks'] as List<dynamic>;
    expect(chapter.tasks.length, rawTasks.length);
    expect(chapter.tasks.first.id, (rawTasks.first as Map)['id']);
    for (final task in chapter.tasks) {
      expect(loader.scenes.containsKey(task.sceneId), isTrue, reason: task.id);
    }
  });

  test('locations are loaded and every chapter and task points at them', () {
    for (final chapter in loader.chapters) {
      final location = loader.locations[chapter.locationId];
      expect(location, isNotNull, reason: chapter.id);
      final areaIds = {for (final a in location?.areas ?? []) a.id};
      for (final task in chapter.tasks) {
        if (task.restoresArea case final area?) {
          expect(areaIds.contains(area), isTrue, reason: task.id);
        }
      }
    }
  });

  test('tutorial steps and chapter endings are loaded', () {
    final raw = _read('tutorial') as List<dynamic>;
    expect(loader.tutorial.length, raw.length);
    expect(loader.tutorial.first.id, (raw.first as Map)['id']);
    expect(loader.tutorial.first.text, (raw.first as Map)['text']);
    for (final chapter in loader.chapters) {
      expect(loader.endings[chapter.id]?.title, isNotEmpty, reason: chapter.id);
    }
  });
}
