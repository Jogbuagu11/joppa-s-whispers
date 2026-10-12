import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/album_validator.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/domain/album.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/features/events/album_drop.dart';
import 'package:whispers_of_joppa/features/events/album_screen.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

class _Fixed implements Random {
  _Fixed(this.values);
  final List<int> values;
  int _at = 0;
  @override
  int nextInt(int max) => values[_at++ % values.length];
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0;
}

Map<String, dynamic> _file() =>
    jsonDecode(File('content/album.json').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _items() =>
    itemIdsOf(jsonDecode(File('content/chains.json').readAsStringSync()));

// Safe: the map is a whole album.
final _album = Album.fromJson({
  'order_percent': 50,
  'sets': [
    {
      'id': 's',
      'name': 'Set',
      'reward': {'talents': 9},
      'cards': [
        {'id': 'a', 'name': 'A', 'note': 'a'},
        {'id': 'b', 'name': 'B', 'note': 'b'},
      ],
    },
  ],
})!;

const _text = {
  'found': 'New {name}',
  'spare': 'Spare {name}',
  'finished': '{name} done {reward}',
};

void main() {
  String? draw(SaveExtras extras, List<int> luck, List<PassReward> paid) =>
      albumCardOnOrder(
        album: _album,
        extras: extras,
        random: _Fixed(luck),
        grant: paid.add,
        text: _text,
        rewardWords: (r) => '${r.talents}T',
      );

  test('the game\'s own album is sound', () {
    expect(albumProblems(_file(), itemIds: _items()), isEmpty);
  });

  test('album problems are named', () {
    final bad = _file();
    final sets = (bad['sets'] as List<dynamic>).cast<Map<String, dynamic>>();
    final cards = sets[0]['cards'] as List<dynamic>;
    cards.add(cards.first);
    sets[1]['reward'] = <String, dynamic>{};
    (bad['text'] as Map<String, dynamic>)['found'] = 'New card';
    expect(albumProblems(bad, itemIds: _items()), hasLength(3));
  });

  test('an unlucky order brings nothing and saves nothing', () {
    final extras = SaveExtras();
    final paid = <PassReward>[];
    expect(draw(extras, [50, 0], paid), isNull);
    expect(extras.read(albumRecord), isNull);
  });

  test('a card is kept; a second of it is a spare; a set pays once', () {
    final extras = SaveExtras();
    final paid = <PassReward>[];
    // pick 0: any card, the first.
    expect(draw(extras, [0, 0], paid), 'New A');
    expect(draw(extras, [0, 0], paid), 'Spare A');
    expect(paid, isEmpty);
    // pick 1: a missing card, the first of them.
    expect(draw(extras, [0, 1], paid), 'New B\nSet done 9T');
    expect(paid.single.talents, 9);
    expect(draw(extras, [0, 3], paid), 'Spare B');
    expect(paid, hasLength(1));
    final state = AlbumState.fromJson(extras.read(albumRecord));
    expect(state.cards, {'a': 2, 'b': 2});
    expect(state.paid, {'s'});
  });
}
