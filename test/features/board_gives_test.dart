import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/app/board_inventory.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/order_quests.dart';
import 'package:whispers_of_joppa/domain/pet.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/features/events/board_gives.dart';
import 'package:whispers_of_joppa/features/events/pet_screen.dart';
import 'package:whispers_of_joppa/features/orders/order_quests_screen.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

class _Board implements BoardInventory {
  _Board(this.items);
  final Map<String, int> items;
  @override
  Map<String, int> itemCounts() => items;
  @override
  bool removeItems(Map<String, int> counts) {
    if (counts.entries.any((e) => (items[e.key] ?? 0) < e.value)) return false;
    for (final e in counts.entries) {
      items[e.key] = (items[e.key] ?? 0) - e.value;
    }
    return true;
  }

  @override
  Listenable get boardChanged => ChangeNotifier();
}

// Safe: the map is a whole pet.
final _pet = Pet.fromJson({
  'feed_goal': 5,
  'gifts': [
    {'talents': 7},
  ],
  'looks': [
    {'id': 'plain', 'name': 'Plain', 'gifts': 0, 'color': '000000'},
    {'id': 'bow', 'name': 'Bow', 'gifts': 1, 'color': 'FFFFFF'},
  ],
})!;

final _quest = orderQuestsFrom({
  'quests': [
    {
      'id': 'q',
      'chapter': 'ch1',
      'name': 'Q',
      'text': 't',
      'done': 'd',
      'needs': {'a': 2},
      'reward': {'talents': 40},
    },
  ],
}).single;

const _loaf = ItemModel(
  itemId: 'a',
  chainId: 'c',
  tier: 3,
  name: 'Loaf',
  asset: '',
);

void main() {
  String words(PassReward r) => '${r.talents}T';

  group('feeding Shadow', () {
    String feed(_Board board, SaveExtras extras, List<PassReward> paid) =>
        petFeedItem(
          pet: _pet,
          item: _loaf,
          board: board,
          extras: extras,
          grant: paid.add,
          text: const {'gift': 'Gift {reward}', 'new_look': 'Look {name}'},
          rewardWords: words,
        );

    test('an item not on the board feeds nothing', () {
      final extras = SaveExtras();
      final paid = <PassReward>[];
      expect(feed(_Board({}), extras, paid), '');
      expect(extras.read(petRecord), isNull);
      expect(paid, isEmpty);
    });

    test('the item leaves the board; a full cat pays one gift', () {
      final board = _Board({'a': 2});
      final extras = SaveExtras();
      final paid = <PassReward>[];
      expect(feed(board, extras, paid), '');
      expect(board.items['a'], 1);
      expect(PetState.fromJson(extras.read(petRecord)).fed, 3);
      expect(feed(board, extras, paid), 'Gift 7T\nLook Bow');
      expect(board.items['a'], 0);
      expect(paid.single.talents, 7);
      final state = PetState.fromJson(extras.read(petRecord));
      expect((state.fed, state.gifts), (1, 1));
      // Nothing left to feed: nothing more is paid.
      expect(feed(board, extras, paid), '');
      expect(paid, hasLength(1));
    });
  });

  group('giving to a quest', () {
    String give(
      _Board board,
      SaveExtras extras,
      List<PassReward> paid, [
      String item = 'a',
    ]) => questGiveItem(
      quest: _quest,
      itemId: item,
      board: board,
      extras: extras,
      grant: paid.add,
      text: const {'finished': 'Done {reward}'},
      rewardWords: words,
    );

    test('an item not on the board gives nothing', () {
      final extras = SaveExtras();
      final paid = <PassReward>[];
      expect(give(_Board({}), extras, paid), '');
      expect(extras.read(questsRecord), isNull);
      expect(paid, isEmpty);
    });

    test('an item the quest does not need stays on the board', () {
      final board = _Board({'z': 1});
      expect(give(board, SaveExtras(), [], 'z'), '');
      expect(board.items['z'], 1);
    });

    test('the last item pays the reward, exactly once', () {
      final board = _Board({'a': 5});
      final extras = SaveExtras();
      final paid = <PassReward>[];
      expect(give(board, extras, paid), '');
      expect(paid, isEmpty);
      expect(give(board, extras, paid), 'Done 40T');
      expect(paid.single.talents, 40);
      expect(board.items['a'], 3);
      // A finished quest takes nothing more.
      expect(give(board, extras, paid), '');
      expect(board.items['a'], 3);
      expect(paid, hasLength(1));
    });

    test('a quest whose needs shrank below what was given is settled', () {
      final extras = SaveExtras()
        ..write(questsRecord, {
          'given': {
            'q': {'a': 2},
          },
        });
      final paid = <PassReward>[];
      List<OrderQuest> settle() =>
          questsSettle(quests: [_quest], extras: extras, grant: paid.add);
      expect(settle().single.id, 'q');
      expect(settle(), isEmpty);
      expect(paid.single.talents, 40);
      // A quest never begun is not paid.
      final fresh = SaveExtras();
      expect(
        questsSettle(quests: [_quest], extras: fresh, grant: paid.add),
        isEmpty,
      );
    });
  });
}
