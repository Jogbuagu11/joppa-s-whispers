import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/data/pet_validator.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/pet.dart';

Map<String, dynamic> _file() =>
    jsonDecode(File('content/pet.json').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _items() =>
    itemIdsOf(jsonDecode(File('content/chains.json').readAsStringSync()));

final _pet = Pet.fromJson({
  'feed_goal': 10,
  'gifts': [
    {'talents': 5},
    {'manna': 2},
  ],
  'looks': [
    {'id': 'plain', 'name': 'Plain', 'gifts': 0, 'color': '000000'},
    {'id': 'ribbon', 'name': 'Ribbon', 'gifts': 2, 'color': '3F6FA8'},
  ],
})!; // Safe: the map above is a whole pet.

void main() {
  test('the game\'s own pet is sound, and no gift is worth its food', () {
    expect(petProblems(_file(), itemIds: _items()), isEmpty);
    final pet = Pet.fromJson(_file());
    expect(pet, isNotNull);
    // Food costs Manna to make: a gift must never give back more Manna
    // than the food took, or feeding would be a Manna machine.
    for (final gift in pet!.gifts) {
      expect(gift.manna, lessThan(pet.feedGoal));
      expect(gift.pearls, 0);
    }
  });

  test('food adds up; a full cat brings the next gift in turn', () {
    var fed = petAfterFeed(_pet, const PetState(), 4);
    expect(fed.state.fed, 4);
    expect(fed.gifts, isEmpty);
    fed = petAfterFeed(_pet, fed.state, 7);
    expect(fed.state.fed, 1);
    expect(fed.state.gifts, 1);
    expect(fed.gifts.single.talents, 5);
    expect(fed.opened, isEmpty);
    fed = petAfterFeed(_pet, fed.state, 9);
    expect(fed.gifts.single.manna, 2);
    expect(fed.opened.single.id, 'ribbon');
    // Round again to the first gift.
    fed = petAfterFeed(_pet, fed.state, 10);
    expect(fed.gifts.single.talents, 5);
    expect(fed.opened, isEmpty);
  });

  test('a big meal can bring more than one gift; none feeds nothing', () {
    final fed = petAfterFeed(_pet, const PetState(), 25);
    expect(fed.gifts, hasLength(2));
    expect(fed.state.fed, 5);
    expect(petAfterFeed(_pet, const PetState(fed: 3), 0).state.fed, 3);
    expect(petAfterFeed(_pet, const PetState(fed: 3), -4).gifts, isEmpty);
  });

  test('a look is worn only once it is open', () {
    final ribbon = _pet.looks[1];
    expect(petWear(const PetState(), ribbon).look, '');
    final worn = petWear(const PetState(gifts: 2), ribbon);
    expect(worn.look, 'ribbon');
    expect(petLook(_pet, worn).id, 'ribbon');
    // A save that names a look not open yet shows the first.
    expect(petLook(_pet, const PetState(look: 'ribbon')).id, 'plain');
    expect(petLook(_pet, const PetState(look: 'gone', gifts: 9)).id, 'plain');
  });

  test('the save record goes there and back; damage means a new cat', () {
    const state = PetState(fed: 3, gifts: 4, look: 'ribbon');
    final back = PetState.fromJson(state.toJson());
    expect((back.fed, back.gifts, back.look), (3, 4, 'ribbon'));
    final odd = PetState.fromJson({'fed': -2, 'gifts': 'x', 'look': 7});
    expect((odd.fed, odd.gifts, odd.look), (0, 0, ''));
    expect(PetState.fromJson(null).gifts, 0);
  });

  test('food is what lies on the board, lowest first, never a tool', () {
    ItemModel item(String id, int tier, {ItemUse? use}) => ItemModel(
      itemId: id,
      chainId: 'c',
      tier: tier,
      name: id,
      asset: '',
      use: use,
    );
    final catalog = {
      'a2': item('a2', 2),
      'a1': item('a1', 1),
      'jar': item('jar', 1, use: const ItemUse(manna: 5)),
    };
    final food = petFood({'a2': 1, 'a1': 3, 'jar': 1, 'gone': 2}, catalog);
    expect(food.keys.map((i) => i.itemId), ['a1', 'a2']);
    expect(food.values, [3, 1]);
    expect(petFood({'a1': 1, 'a2': 1}, catalog, most: 1), hasLength(1));
    expect(
      petFood(
        {'a1': 1, 'a2': 1},
        catalog,
        keep: (i) => i.itemId == 'a1',
      ).keys.single.itemId,
      'a2',
    );
  });

  test('problems are named', () {
    final bad = _file();
    bad['feed_goal'] = 1;
    (bad['gifts'] as List<dynamic>)[0] = {'pearls': 5};
    ((bad['looks'] as List<dynamic>)[0] as Map<String, dynamic>)['gifts'] = 2;
    (bad['text'] as Map<String, dynamic>)['meter'] = 'Fed';
    final problems = petProblems(bad, itemIds: _items());
    expect(problems, hasLength(7));
    expect(Pet.fromJson(null), isNull);
    // A gift item that gives as much Manna as the food costs is refused.
    expect(
      petProblems(
        _file(),
        itemIds: _items(),
        itemManna: const {'manna_jar_01': 20},
      ),
      hasLength(1),
    );
  });
}
