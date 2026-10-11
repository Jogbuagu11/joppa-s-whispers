// The Treasure Jar's settings are checked before the game uses them.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/treasure_jar_validator.dart';

void main() {
  final offers =
      jsonDecode(File('content/offers.json').readAsStringSync())
          as Map<String, dynamic>;
  Map<String, dynamic> jar() =>
      jsonDecode(jsonEncode(offers['treasure_jar'])) as Map<String, dynamic>;

  test("the game's own Treasure Jar is sound; no jar at all is allowed", () {
    expect(treasureJarProblems(jar(), offers), isEmpty);
    expect(treasureJarProblems(null, offers), isEmpty);
    expect(treasureJarProblems('x', offers), hasLength(1));
  });

  test('sizes must be whole, different and growing', () {
    final none = jar()..['sizes'] = <dynamic>[];
    expect(treasureJarProblems(none, offers).single, contains('one size'));
    final sizes = (jar()['sizes'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final shrinking = jar()..['sizes'] = [sizes[1], sizes[0]];
    expect(
      treasureJarProblems(shrinking, offers).single,
      contains('must hold more'),
    );
    final twice = jar()
      ..['sizes'] = [
        sizes[0],
        {...sizes[0], 'pearls': 999},
      ];
    expect(treasureJarProblems(twice, offers).single, contains('twice'));
    final broken = jar()
      ..['sizes'] = [
        {'id': 'small'},
      ];
    expect(treasureJarProblems(broken, offers).single, contains('needs an id'));
    final offer = jar()
      ..['sizes'] = [
        {...sizes[0], 'product_id': 'offer_099'},
      ];
    expect(
      treasureJarProblems(offer, offers).single,
      contains('offer product'),
    );
  });

  test('something must fill it, and its words must be there', () {
    final idle = jar()..['earn'] = {'order': 0};
    expect(treasureJarProblems(idle, offers).single, contains('nothing fills'));
    final odd = jar()..['earn'] = {'order': -1, 'task': 3};
    expect(treasureJarProblems(odd, offers).single, contains('"order"'));
    final mute = jar()..['text'] = {'title': 'Treasure Jar'};
    expect(
      treasureJarProblems(mute, offers),
      hasLength(treasureJarTextKeys.length - 1),
    );
  });
}
