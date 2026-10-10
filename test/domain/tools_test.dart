import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/generator_type_validator.dart';
import 'package:whispers_of_joppa/domain/merge.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/tools.dart';

ItemModel _item(String id, String chain, int tier, {ItemUse? use}) => ItemModel(
  itemId: id,
  chainId: chain,
  tier: tier,
  name: id,
  asset: '',
  use: use,
);

final _knife = _item('knife', 'knife', 1, use: const ItemUse(split: true));
final _thread = _item('thread', 'thread', 1, use: const ItemUse(wild: true));
final _jar = _item('jar', 'jar', 1, use: const ItemUse(manna: 5));
final _b1 = _item('b1', 'bakery', 1);
final _b2 = _item('b2', 'bakery', 2);
final _b3 = _item('b3', 'bakery', 3);
const _chains = {
  'bakery': ChainTierData(
    chainId: 'bakery',
    maxTier: 3,
    itemTiers: {'b1': 1, 'b2': 2, 'b3': 3},
    tierToItemId: {'bakery_1': 'b1', 'bakery_2': 'b2', 'bakery_3': 'b3'},
  ),
  'knife': ChainTierData(
    chainId: 'knife',
    maxTier: 1,
    itemTiers: {'knife': 1},
    tierToItemId: {'knife_1': 'knife'},
  ),
  'thread': ChainTierData(
    chainId: 'thread',
    maxTier: 1,
    itemTiers: {'thread': 1},
    tierToItemId: {'thread_1': 'thread'},
  ),
};

void main() {
  test('a knife makes two of the tier below: one where the item was, one '
      'where the knife was', () {
    final r = resolveTool(_knife, _b3, _chains);
    expect(r?.targetBecomes, 'b2');
    expect(r?.toolCellBecomes, 'b2');
  });

  test('a knife does nothing to a first-tier item', () {
    expect(resolveTool(_knife, _b1, _chains), isNull);
  });

  test('a Golden Thread raises any item one tier and leaves nothing '
      'behind', () {
    final r = resolveTool(_thread, _b1, _chains);
    expect(r?.targetBecomes, 'b2');
    expect(r?.toolCellBecomes, isNull);
  });

  test('a Golden Thread does nothing to an item at the top of its chain', () {
    expect(resolveTool(_thread, _b3, _chains), isNull);
  });

  test('tools do nothing to each other, and only tools are tools', () {
    expect(resolveTool(_thread, _knife, _chains), isNull);
    expect(resolveTool(_knife, _thread, _chains), isNull);
    expect(resolveTool(_thread, _thread, _chains), isNull);
    expect(resolveTool(_b1, _b2, _chains), isNull);
    expect(resolveTool(_jar, _b2, _chains), isNull);
  });

  test('an item of a chain the game does not know is left alone', () {
    final stray = _item('x2', 'stray', 2);
    expect(resolveTool(_knife, stray, _chains), isNull);
    expect(resolveTool(_thread, stray, _chains), isNull);
  });

  test('a use is read from content, and must do exactly one thing', () {
    expect(ItemUse.fromJson({'split': true})?.split, isTrue);
    expect(ItemUse.fromJson({'wild': true})?.wild, isTrue);
    expect(ItemUse.fromJson({'split': false}), isNull);
    expect(ItemUse.fromJson({'wild': true})?.isTool, isTrue);
    expect(ItemUse.fromJson({'manna': 5})?.isTool, isFalse);
    List<String> check(Object? use) {
      final problems = <String>[];
      checkItemUse('Item', use, problems);
      return problems;
    }

    expect(check({'split': true}), isEmpty);
    expect(check({'wild': true}), isEmpty);
    expect(check({'split': true, 'wild': true}), isNotEmpty);
    expect(check({'split': true, 'manna': 5}), isNotEmpty);
    expect(check({'split': 'yes'}), isNotEmpty);
    expect(check({'split': false}), isNotEmpty);
  });

  test('the real game has one knife and one Golden Thread, both for sale, '
      'and levels that give them', () {
    final chains =
        (jsonDecode(File('content/chains.json').readAsStringSync())
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
    Map<String, dynamic> only(String id) =>
        ((chains.firstWhere((c) => c['id'] == id)['tiers'] as List<dynamic>)
                .single
            as Map<String, dynamic>);
    expect(ItemUse.fromJson(only('knife')['use'])?.split, isTrue);
    expect(ItemUse.fromJson(only('thread')['use'])?.wild, isTrue);
    expect(only('knife')['sell'], greaterThan(0));
    expect(only('thread')['sell'], greaterThan(0));
    final levels =
        ((jsonDecode(File('content/levels.json').readAsStringSync())
                    as Map<String, dynamic>)['levels']
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
    final gifts = [
      for (final l in levels) ...(l['items'] as List<dynamic>? ?? const []),
    ];
    expect(gifts, contains('knife_01'));
    expect(gifts, contains('thread_01'));
  });
}
