import 'package:flutter_test/flutter_test.dart';

import 'validator_fixture.dart';

void main() {
  group('orders', () {
    Map<String, dynamic> order(Map<String, Object?> c) => firstOf(c, 'orders');

    test('wrong talents are reported with the right amount', () {
      final c = validContent();
      (order(c)['rewards'] as Map<String, dynamic>)['talents'] = 40;
      expect(checkContent(c).single, contains('talents should be 400'));
    });

    test('unknown character and unknown item are reported', () {
      final c = validContent();
      order(c)['character_id'] = 'nobody';
      (order(c)['items'] as List<dynamic>).add({
        'item_id': 'bakery_99',
        'count': 1,
      });
      final problems = checkContent(c);
      expect(problems, contains(contains('unknown character "nobody"')));
      expect(problems, contains(contains('unknown item "bakery_99"')));
    });

    test('text that is too long, bad kind and bad blessings are reported', () {
      final c = validContent();
      order(c)['text'] = 'x' * 141;
      order(c)['kind'] = 'other';
      (order(c)['rewards'] as Map<String, dynamic>)['blessings'] = 4;
      final problems = checkContent(c);
      expect(problems, contains(contains('over 140 characters')));
      expect(problems, contains(contains('kind must be')));
      expect(problems, contains(contains('blessings must be')));
    });

    test('an item from a chain not yet unlocked is reported', () {
      final c = validContent();
      firstOf(c, 'chains')['unlock_chapter'] = 2;
      expect(checkContent(c).single, contains('not unlocked until chapter 2'));
    });

    test(
      'duplicate order ids, zero counts and too many items are reported',
      () {
        final c = validContent();
        final orders = c['orders'] as List<dynamic>;
        orders.add(Map<String, dynamic>.of(order(c)));
        (order(c)['items'] as List<dynamic>).first['count'] = 0;
        final problems = checkContent(c);
        expect(problems, contains(contains('used more than once')));
        expect(problems, contains(contains('must be 1 or more')));
      },
    );

    test('an item listed twice and more than 3 items are reported', () {
      final c = validContent();
      final items = order(c)['items'] as List<dynamic>;
      for (var i = 0; i < 3; i++) {
        items.add({'item_id': 'bakery_02', 'count': 1});
      }
      final problems = checkContent(c);
      expect(problems, contains(contains('is listed twice')));
      expect(problems, contains(contains('1 to 3 different items')));
    });

    test('duplicate or nameless characters are reported', () {
      final c = validContent();
      (c['characters'] as List<dynamic>).add({'id': 'silas', 'name': ' '});
      final problems = checkContent(c);
      expect(problems, contains(contains('Character id "silas" is used more')));
      expect(problems, contains(contains('missing name')));
    });
  });

  test('a scene_id that is not text is reported', () {
    final c = validContent();
    firstOf(c, 'orders')['scene_id'] = 5;
    expect(checkContent(c).single, contains('scene_id must be text'));
  });

  test('an unknown opening scene is reported', () {
    final c = validContent();
    (c['board'] as Map<String, dynamic>)['opening_scene'] = 'ch9_s_99';
    expect(checkContent(c).single, contains('unknown opening scene'));
    (c['board'] as Map<String, dynamic>)['opening_scene'] = 'ch1_s_01';
    expect(checkContent(c), isEmpty);
  });

  test('a starting board that is not an object is reported', () {
    final c = validContent()..['board'] = <dynamic>[];
    expect(checkContent(c).single, contains('wrong shape'));
  });
}
