import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/data/quests_validator.dart';
import 'package:whispers_of_joppa/data/study_guides_validator.dart';
import 'package:whispers_of_joppa/domain/order_quests.dart';

final _quests = orderQuestsFrom({
  'quests': [
    {
      'id': 'q1',
      'chapter': 'ch1',
      'name': 'One',
      'text': 't',
      'done': 'd',
      'needs': {'a': 2, 'b': 1},
      'reward': {'talents': 50},
    },
    {
      'id': 'q2',
      'chapter': 'ch2',
      'name': 'Two',
      'text': 't',
      'done': 'd',
      'needs': {'c': 1},
      'reward': {'manna': 5},
    },
  ],
});

Object? _read(String name) =>
    jsonDecode(File('content/$name.json').readAsStringSync());

void main() {
  test('the game\'s own quests are sound; problems are named', () {
    final items = itemIdsOf(_read('chains'));
    final chapters = chapterIdsOf(_read('chapters'));
    final file = _read('quests') as Map<String, dynamic>;
    expect(questsProblems(file, itemIds: items, chapterIds: chapters), isEmpty);
    final quests = (file['quests'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    quests[0]['chapter'] = 'ch99';
    (quests[1]['needs'] as Map<String, dynamic>)['no_such'] = 1;
    quests[2]['reward'] = <String, dynamic>{};
    (file['text'] as Map<String, dynamic>)['need'] = 'x';
    expect(
      questsProblems(file, itemIds: items, chapterIds: chapters),
      hasLength(4),
    );
  });

  const order = ['ch1', 'ch2', 'ch3'];

  test('quests are read; no file means none', () {
    expect(_quests, hasLength(2));
    expect(_quests.first.needs, {'a': 2, 'b': 1});
    expect(_quests.first.reward.talents, 50);
    expect(orderQuestsFrom(null), isEmpty);
  });

  test('a quest opens when the chapters before its own are finished', () {
    expect(questOpen(_quests[0], order, const {}), isTrue);
    expect(questOpen(_quests[1], order, const {}), isFalse);
    expect(questOpen(_quests[1], order, const {'ch1'}), isTrue);
    expect(questOpen(_quests[1], const ['ch1'], const {'ch1'}), isFalse);
  });

  test('giving counts down; the last thing finishes it, once', () {
    final q = _quests[0];
    var state = const QuestsState();
    expect(questLeft(q, state), {'a': 2, 'b': 1});
    var gave = questGive(q, state, 'a');
    expect(gave!.finished, isFalse); // Safe: 'a' is needed.
    state = gave.state;
    expect(questLeft(q, state), {'a': 1, 'b': 1});
    state = questGive(q, state, 'b')!.state; // Safe: 'b' is needed.
    // No more of b is wanted.
    expect(questGive(q, state, 'b'), isNull);
    gave = questGive(q, state, 'a');
    expect(gave!.finished, isTrue); // Safe: one 'a' is still needed.
    state = gave.state;
    expect(questDone(q, state), isTrue);
    expect(questGive(q, state, 'a'), isNull);
    expect(questDone(_quests[1], state), isFalse);
  });

  test('a thing the quest does not need is not taken', () {
    expect(questGive(_quests[0], const QuestsState(), 'zzz'), isNull);
  });

  test('the save record goes there and back; damage means nothing given', () {
    final state = questGive(_quests[1], const QuestsState(), 'c')!.state;
    final back = QuestsState.fromJson(state.toJson());
    expect(back.given, {
      'q2': {'c': 1},
    });
    expect(back.paid, {'q2'});
    final odd = QuestsState.fromJson({
      'given': {
        'q1': {'a': -3, 'b': 'x'},
        'q9': 4,
      },
      'paid': [1, 'q1'],
    });
    expect(odd.given, {'q1': <String, int>{}});
    expect(odd.paid, {'q1'});
    // More given than needed (older content) leaves nothing below zero.
    final over = QuestsState.fromJson({
      'given': {
        'q1': {'a': 9},
      },
    });
    expect(questLeft(_quests[0], over), {'a': 0, 'b': 1});
  });
}
