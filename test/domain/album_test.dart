// The keepsake album: cards found with orders, and a prize for each
// finished set, once.
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/album.dart';

void main() {
  // Safe: the fixture has sets.
  final album = Album.fromJson({
    'order_percent': 25,
    'sets': [
      {
        'id': 'people',
        'name': 'People',
        'reward': {'pearls': 5},
        'cards': [
          {'id': 'a', 'name': 'A', 'note': 'a'},
          {'id': 'b', 'name': 'B', 'note': 'b'},
        ],
      },
      {
        'id': 'places',
        'name': 'Places',
        'reward': {'manna': 20},
        'cards': [
          {'id': 'c', 'name': 'C', 'note': 'c'},
        ],
      },
    ],
  })!;

  test('no album in older content', () {
    expect(Album.fromJson(null), isNull);
    expect(Album.fromJson({'order_percent': 5, 'sets': <Object>[]}), isNull);
  });

  test('only some orders bring a card', () {
    const state = AlbumState();
    expect(albumCardFor(album, state, chance: 25, pick: 1), isNull);
    expect(albumCardFor(album, state, chance: 99, pick: 1), isNull);
    expect(albumCardFor(album, state, chance: 24, pick: 1), isNotNull);
    expect(albumCardFor(album, state, chance: 0, pick: 1)?.id, 'a');
  });

  test('a missing card is favoured, so the album can be finished', () {
    const state = AlbumState(cards: {'a': 1, 'b': 2});
    // Two picks in three look only among the missing.
    expect(albumCardFor(album, state, chance: 0, pick: 1)?.id, 'c');
    expect(albumCardFor(album, state, chance: 0, pick: 2)?.id, 'c');
    // The third may be a spare.
    expect(albumCardFor(album, state, chance: 0, pick: 0)?.id, 'a');
    // With everything found, any card comes as a spare.
    const full = AlbumState(cards: {'a': 1, 'b': 1, 'c': 1});
    expect(albumCardFor(album, full, chance: 0, pick: 4)?.id, 'b');
  });

  test('a finished set pays once; spares are counted', () {
    final cards = album.cards;
    var result = albumAfterCard(album, const AlbumState(), cards[0]);
    expect(result.finished, isEmpty);
    result = albumAfterCard(album, result.state, cards[0]);
    expect(result.state.cards['a'], 2);
    expect(result.finished, isEmpty);
    result = albumAfterCard(album, result.state, cards[1]);
    expect([for (final s in result.finished) s.id], ['people']);
    expect(result.state.found(album.sets[0]), 2);
    result = albumAfterCard(album, result.state, cards[1]);
    expect(result.finished, isEmpty);
    result = albumAfterCard(album, result.state, cards[2]);
    expect([for (final s in result.finished) s.id], ['places']);
  });

  test('the saved album is read carefully', () {
    expect(AlbumState.fromJson('x').cards, isEmpty);
    final odd = AlbumState.fromJson(<String, dynamic>{
      'cards': {'a': 2, 'b': -1, 'c': 'x'},
      'paid': ['people', 4],
    });
    expect(odd.cards, {'a': 2});
    expect(odd.paid, {'people'});
    expect(AlbumState.fromJson(odd.toJson()).toJson(), odd.toJson());
  });
}
