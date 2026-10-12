// The keepsake album (EXPANSION section 25): cards in sets, found now and
// then with a delivered order; a finished set pays a prize, once. Pure
// Dart, fully unit tested.
import 'package:whispers_of_joppa/domain/season_pass.dart';

class AlbumCard {
  final String id;
  final String name;

  /// A line about it, shown once the card is found.
  final String note;

  const AlbumCard({required this.id, required this.name, required this.note});
}

class AlbumSet {
  final String id;
  final String name;
  final List<AlbumCard> cards;

  /// The prize for finding every card of the set.
  final PassReward reward;

  const AlbumSet({
    required this.id,
    required this.name,
    required this.cards,
    required this.reward,
  });
}

/// content/album.json. (Check it with albumProblems first.)
class Album {
  final List<AlbumSet> sets;

  /// Out of a hundred delivered orders, how many bring a card.
  final int orderPercent;

  const Album({required this.sets, required this.orderPercent});

  /// Null if there is no album (older content).
  static Album? fromJson(Object? json) {
    if (json case {
      'order_percent': final int percent,
      'sets': final List<dynamic> sets,
    } when sets.isNotEmpty) {
      return Album(
        orderPercent: percent,
        sets: [
          for (final set in sets)
            if (set case {
              'id': final String id,
              'name': final String name,
              'cards': final List<dynamic> cards,
            })
              AlbumSet(
                id: id,
                name: name,
                reward: PassReward.fromJson(set['reward']),
                cards: [
                  for (final card in cards)
                    if (card case {
                      'id': final String id,
                      'name': final String name,
                      'note': final String note,
                    })
                      AlbumCard(id: id, name: name, note: note),
                ],
              ),
        ],
      );
    }
    return null;
  }

  List<AlbumCard> get cards => [for (final set in sets) ...set.cards];
}

/// A player's album, as kept in the save file.
class AlbumState {
  /// Card id -> how many have been found (spares are kept for trading).
  final Map<String, int> cards;

  /// The sets whose prize has been paid.
  final Set<String> paid;

  const AlbumState({this.cards = const {}, this.paid = const {}});

  factory AlbumState.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const AlbumState();
    return AlbumState(
      cards: {
        if (json['cards'] case final Map<String, dynamic> cards)
          for (final e in cards.entries)
            if (e.value case final int n when n > 0) e.key: n,
      },
      paid: {
        if (json['paid'] case final List<dynamic> ids)
          for (final id in ids)
            if (id is String) id,
      },
    );
  }

  Map<String, dynamic> toJson() => {'cards': cards, 'paid': paid.toList()};

  bool has(String cardId) => (cards[cardId] ?? 0) > 0;

  /// How many of [set]'s cards have been found.
  int found(AlbumSet set) => set.cards.where((c) => has(c.id)).length;
}

/// The card an order brings, or null if it brings none. [chance] is a
/// number from 0 up to (not including) 100 and [pick] any number 0 or
/// more, both drawn by chance. A card not yet found comes before a spare
/// two times in three, so an album can be finished.
AlbumCard? albumCardFor(
  Album album,
  AlbumState state, {
  required int chance,
  required int pick,
}) {
  if (chance >= album.orderPercent) return null;
  final all = album.cards;
  if (all.isEmpty) return null;
  final missing = [
    for (final card in all)
      if (!state.has(card.id)) card,
  ];
  final from = missing.isNotEmpty && pick % 3 != 0 ? missing : all;
  return from[(pick ~/ 3) % from.length];
}

/// The album after [card] is found, and the sets it finishes (each paid
/// once).
({AlbumState state, List<AlbumSet> finished}) albumAfterCard(
  Album album,
  AlbumState state,
  AlbumCard card,
) {
  final cards = {...state.cards, card.id: (state.cards[card.id] ?? 0) + 1};
  final paid = {...state.paid};
  final after = AlbumState(cards: cards, paid: paid);
  final finished = [
    for (final set in album.sets)
      if (after.found(set) == set.cards.length && paid.add(set.id)) set,
  ];
  return (state: AlbumState(cards: cards, paid: paid), finished: finished);
}
