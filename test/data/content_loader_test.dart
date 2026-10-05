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
      );
  });

  test('loads every chain, item and generator from content', () {
    final chains = _read('chains')! as List<dynamic>;
    final itemCount = chains.fold<int>(
      0,
      (n, c) => n + ((c as Map<String, dynamic>)['tiers'] as List).length,
    );
    expect(loader.isLoaded, isTrue);
    expect(loader.chains.length, chains.length);
    expect(loader.items.length, itemCount);
    expect(
      loader.generators.length,
      (_read('generators')! as List<dynamic>).length,
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
}
