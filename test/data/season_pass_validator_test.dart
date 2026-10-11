// The season pass's settings are checked before the game uses them.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/event_validator.dart';
import 'package:whispers_of_joppa/data/season_pass_validator.dart';

import '../support/event_fixtures.dart';

void main() {
  Map<String, dynamic> pass() =>
      jsonDecode(jsonEncode(testPass)) as Map<String, dynamic>;
  List<String> check(Object? p) => eventPassProblems(p, 3, 'Event');

  test('a sound pass has no problems; an event may have none', () {
    expect(check(pass()), isEmpty);
    expect(check(null), isEmpty);
    expect(check('x').single, contains('settings'));
    expect(eventProblems(eventRow(pass: testPass)), isEmpty);
    // The game's own events and their passes.
    final events =
        jsonDecode(File('content/events.json').readAsStringSync())
            as List<dynamic>;
    for (final event in events) {
      expect(eventProblems(event), isEmpty);
    }
  });

  test('every milestone needs a Premium reward, none empty or huge', () {
    final short = pass()..['premium'] = [(pass()['premium'] as List).first];
    expect(check(short).single, contains('one Premium reward for each'));
    final none = pass()..['premium'] = <dynamic>[];
    expect(check(none).single, contains('needs a Premium reward'));
    final rewards = pass()['premium'] as List<dynamic>;
    final empty = pass()
      ..['premium'] = [<String, dynamic>{}, rewards[1], rewards[2]];
    expect(check(empty).single, contains('reward 1'));
    final huge = pass()
      ..['premium'] = [
        rewards[0],
        {'pearls': 5000},
        rewards[2],
      ];
    expect(check(huge).single, contains('reward 2'));
    // A bad pass keeps the whole event from being shown.
    expect(eventProblems(eventRow(pass: huge)), isNotEmpty);
  });

  test('Premium Plus: a sane bonus, and an endless track that is not too '
      'quick and never pays Pearls', () {
    final bonus = pass()..['plus'] = {'bonus_percent': 500};
    expect(check(bonus).single, contains('bonus_percent'));
    final quick = pass()
      ..['plus'] = {
        'endless': {'every': 5, 'talents': 7},
      };
    expect(check(quick).single, contains('50 or more'));
    final pearls = pass()
      ..['plus'] = {
        'endless': {'every': 100, 'pearls': 1},
      };
    expect(check(pearls).single, contains('cannot give Pearls'));
    final nothing = pass()
      ..['plus'] = {
        'endless': {'every': 100},
      };
    expect(check(nothing).single, contains('empty'));
    expect(check(pass()..['plus'] = 3).single, contains('"plus"'));
  });

  test('the pass\'s products and words in the offers file', () {
    final offers =
        jsonDecode(File('content/offers.json').readAsStringSync())
            as Map<String, dynamic>;
    Map<String, dynamic> copy() =>
        jsonDecode(jsonEncode(offers)) as Map<String, dynamic>;
    expect(seasonPassProblems(offers), isEmpty);
    expect(seasonPassProblems({}), isEmpty);
    expect(seasonPassProblems({'season_pass': 1}), hasLength(1));
    final same = copy();
    (same['season_pass'] as Map<String, dynamic>)['plus_product'] =
        'pass_premium';
    expect(seasonPassProblems(same).single, contains('two different'));
    final taken = copy();
    (taken['season_pass'] as Map<String, dynamic>)['premium_product'] =
        'offer_499';
    expect(seasonPassProblems(taken).single, contains('something else'));
    final blank = copy();
    ((blank['season_pass'] as Map<String, dynamic>)['text']
            as Map<String, dynamic>)['buy_plus'] =
        'Premium Plus';
    expect(seasonPassProblems(blank).single, contains('{price}'));
    final mute = copy();
    (mute['season_pass'] as Map<String, dynamic>)['text'] = {'title': 'Pass'};
    expect(seasonPassProblems(mute), hasLength(seasonPassTextKeys.length - 1));
  });
}
