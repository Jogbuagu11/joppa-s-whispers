// Shadow, Joy's cat (EXPANSION section 25): the player feeds him items
// from the board; each time he is full he brings a small gift, and after
// enough gifts he has a new look to wear. Pure Dart, fully unit tested.
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';

class PetLook {
  final String id;
  final String name;

  /// How many gifts Shadow must have brought before this look opens.
  final int gifts;

  /// The colour of his ribbon, as 0xAARRGGBB.
  final int color;

  const PetLook({
    required this.id,
    required this.name,
    required this.gifts,
    required this.color,
  });
}

/// content/pet.json. (Check it with petProblems first.)
class Pet {
  /// How much food fills him (an item feeds as much as its tier).
  final int feedGoal;

  /// What he brings, in turn, going round.
  final List<PassReward> gifts;
  final List<PetLook> looks;

  const Pet({required this.feedGoal, required this.gifts, required this.looks});

  /// Null if there is no pet (older content).
  static Pet? fromJson(Object? json) {
    if (json case {
      'feed_goal': final int feedGoal,
      'gifts': final List<dynamic> gifts,
      'looks': final List<dynamic> looks,
    } when feedGoal > 0 && gifts.isNotEmpty && looks.isNotEmpty) {
      return Pet(
        feedGoal: feedGoal,
        gifts: [for (final gift in gifts) PassReward.fromJson(gift)],
        looks: [
          for (final look in looks)
            if (look case {
              'id': final String id,
              'name': final String name,
              'gifts': final int gifts,
              'color': final String color,
            })
              PetLook(
                id: id,
                name: name,
                gifts: gifts,
                color: 0xFF000000 | (int.tryParse(color, radix: 16) ?? 0),
              ),
        ],
      );
    }
    return null;
  }
}

/// The player's Shadow, as kept in the save file.
class PetState {
  /// Food eaten towards the next gift.
  final int fed;

  /// Gifts brought so far.
  final int gifts;

  /// The look he wears ('' for the first).
  final String look;

  const PetState({this.fed = 0, this.gifts = 0, this.look = ''});

  factory PetState.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const PetState();
    int count(Object? value) => value is int && value > 0 ? value : 0;
    return PetState(
      fed: count(json['fed']),
      gifts: count(json['gifts']),
      look: switch (json['look']) {
        final String look => look,
        _ => '',
      },
    );
  }

  Map<String, dynamic> toJson() => {'fed': fed, 'gifts': gifts, 'look': look};
}

/// Whether [look] is open to a Shadow in [state].
bool petLookOpen(PetLook look, PetState state) => state.gifts >= look.gifts;

/// The look Shadow wears: the chosen one if it is open, else the first.
PetLook petLook(Pet pet, PetState state) => pet.looks.firstWhere(
  (look) => look.id == state.look && petLookOpen(look, state),
  orElse: () => pet.looks.first,
);

/// [state] with [look] put on; unchanged if it is not open yet.
PetState petWear(PetState state, PetLook look) => petLookOpen(look, state)
    ? PetState(fed: state.fed, gifts: state.gifts, look: look.id)
    : state;

/// Shadow after eating [food] (an item's tier): the gifts he brings (one
/// each time he is full) and the looks that open with them.
({PetState state, List<PassReward> gifts, List<PetLook> opened}) petAfterFeed(
  Pet pet,
  PetState state,
  int food,
) {
  if (food <= 0) return (state: state, gifts: const [], opened: const []);
  var fed = state.fed + food;
  var count = state.gifts;
  final gifts = <PassReward>[];
  while (fed >= pet.feedGoal) {
    fed -= pet.feedGoal;
    gifts.add(pet.gifts[count % pet.gifts.length]);
    count++;
  }
  final after = PetState(fed: fed, gifts: count, look: state.look);
  return (
    state: after,
    gifts: gifts,
    opened: [
      for (final look in pet.looks)
        if (!petLookOpen(look, state) && petLookOpen(look, after)) look,
    ],
  );
}

/// What on the board Shadow can be fed, lowest first, with how many of
/// each: anything that is not a thing to use (jars, hourglasses, tools)
/// and that [keep] does not hold back (rare finds, what an order wants).
Map<ItemModel, int> petFood(
  Map<String, int> onBoard,
  Map<String, ItemModel> catalog, {
  int most = 12,
  bool Function(ItemModel item)? keep,
}) {
  final items =
      [
        for (final id in onBoard.keys)
          if (catalog[id] case final ItemModel item
              when item.use == null &&
                  (onBoard[id] ?? 0) > 0 &&
                  !(keep?.call(item) ?? false))
            item,
      ]..sort(
        (a, b) => a.tier != b.tier
            ? a.tier.compareTo(b.tier)
            : a.itemId.compareTo(b.itemId),
      );
  return {
    // Safe: every item here came from the keys of onBoard.
    for (final item in items.take(most)) item: onBoard[item.itemId]!,
  };
}
