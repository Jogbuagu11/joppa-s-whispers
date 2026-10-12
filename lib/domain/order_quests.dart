// Order quests (EXPANSION section 24): long goals that need a set of fine
// items, given one at a time from the board; each pays once when
// everything has been given. Pure Dart, fully unit tested.
import 'package:whispers_of_joppa/domain/season_pass.dart';

class OrderQuest {
  final String id;

  /// The chapter it belongs to: it opens when the chapter before is done.
  final String chapter;
  final String name;

  /// Who is asking, and why.
  final String text;

  /// The thanks when it is finished.
  final String done;

  /// Item id -> how many are needed.
  final Map<String, int> needs;
  final PassReward reward;

  const OrderQuest({
    required this.id,
    required this.chapter,
    required this.name,
    required this.text,
    required this.done,
    required this.needs,
    required this.reward,
  });
}

/// The quests of content/quests.json, in order. (Check the file with
/// questsProblems first.) Empty if there are none (older content).
List<OrderQuest> orderQuestsFrom(Object? json) => [
  if (json case {'quests': final List<dynamic> quests})
    for (final quest in quests)
      if (quest case {
        'id': final String id,
        'chapter': final String chapter,
        'name': final String name,
        'text': final String text,
        'done': final String done,
        'needs': final Map<String, dynamic> needs,
      })
        OrderQuest(
          id: id,
          chapter: chapter,
          name: name,
          text: text,
          done: done,
          reward: PassReward.fromJson(quest['reward']),
          needs: {
            for (final e in needs.entries)
              if (e.value case final int n when n > 0) e.key: n,
          },
        ),
];

/// What the player has given, as kept in the save file.
class QuestsState {
  /// Quest id -> item id -> how many have been given.
  final Map<String, Map<String, int>> given;

  /// The quests whose reward has been paid.
  final Set<String> paid;

  const QuestsState({this.given = const {}, this.paid = const {}});

  factory QuestsState.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const QuestsState();
    return QuestsState(
      given: {
        if (json['given'] case final Map<String, dynamic> given)
          for (final quest in given.entries)
            if (quest.value case final Map<String, dynamic> items)
              quest.key: {
                for (final e in items.entries)
                  if (e.value case final int n when n > 0) e.key: n,
              },
      },
      paid: {
        if (json['paid'] case final List<dynamic> ids)
          for (final id in ids)
            if (id is String) id,
      },
    );
  }

  Map<String, dynamic> toJson() => {'given': given, 'paid': paid.toList()};
}

/// Whether [quest] is open: every chapter before its own (in
/// [chapterOrder]) is one of [finished]. A quest of no known chapter is
/// never open.
bool questOpen(
  OrderQuest quest,
  List<String> chapterOrder,
  Set<String> finished,
) {
  final at = chapterOrder.indexOf(quest.chapter);
  return at >= 0 && chapterOrder.take(at).every(finished.contains);
}

/// What [quest] still needs: item id -> how many (nothing left out).
Map<String, int> questLeft(OrderQuest quest, QuestsState state) {
  final given = state.given[quest.id] ?? const <String, int>{};
  return {
    for (final e in quest.needs.entries)
      e.key: (e.value - (given[e.key] ?? 0)).clamp(0, e.value),
  };
}

bool questDone(OrderQuest quest, QuestsState state) =>
    state.paid.contains(quest.id);

/// [state] after one [itemId] is given to [quest], and whether that
/// finishes it (its reward is then due, once). Null, with nothing to
/// change, if the quest is finished or does not need the item.
({QuestsState state, bool finished})? questGive(
  OrderQuest quest,
  QuestsState state,
  String itemId,
) {
  if (questDone(quest, state)) return null;
  if ((questLeft(quest, state)[itemId] ?? 0) <= 0) return null;
  final mine = {...?state.given[quest.id]};
  mine[itemId] = (mine[itemId] ?? 0) + 1;
  final given = {...state.given, quest.id: mine};
  final after = QuestsState(given: given, paid: state.paid);
  final finished = questLeft(quest, after).values.every((n) => n == 0);
  return (
    state: finished
        ? QuestsState(given: given, paid: {...state.paid, quest.id})
        : after,
    finished: finished,
  );
}
