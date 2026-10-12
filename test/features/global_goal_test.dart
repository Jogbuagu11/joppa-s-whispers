// The global feast goal: orders are sent to the server's total, and its
// milestones pay everyone who took part, once.
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/goal_event_validator.dart';
import 'package:whispers_of_joppa/domain/global_goal.dart';
import 'package:whispers_of_joppa/features/events/goal_events_controller.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

import '../support/goal_fixtures.dart';

class _Server implements GlobalGoalServer {
  int others = 0;
  int added = 0;
  bool down = false;
  @override
  bool signedIn = true;

  @override
  Future<int> total(String eventId) async {
    if (down) throw StateError('offline');
    return others + added;
  }

  @override
  Future<int> tell(String eventId, int mine) async {
    if (down) throw StateError('offline');
    // The whole count: telling it twice adds nothing.
    if (mine > added) added = mine;
    return others + added;
  }
}

Map<String, dynamic> _goal() => goalRow(
  id: 'feast',
  type: 'global',
  more: {
    'milestones': [
      {'points': 3, 'manna': 5},
      {'points': 100, 'talents': 40},
    ],
  },
);

void main() {
  late _Server server;
  late SaveExtras extras;
  late GoalEventsController goals;
  final paid = <int>[];

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    paid.clear();
    server = _Server();
    extras = SaveExtras();
    goals = GoalEventsController(
      events: playableGoalEvents([_goal()]),
      extras: extras,
      open: (_) => true,
      grant: (reward) => paid.add(reward.manna + reward.talents),
      server: server,
    );
  });
  tearDown(() => goals.dispose());

  test('a global goal is checked like any other', () {
    expect(goalEventProblems(_goal()), isEmpty);
  });

  test('orders are sent once; a milestone the total reaches is paid', () async {
    final event = goals.events.single;
    goals.merged();
    goals.mannaSpent(9);
    expect(goals.globalOf(event).mine, 0);
    goals.orderDelivered(40);
    await settle();
    expect(server.added, 1);
    goals.orderDelivered(40);
    goals.orderDelivered(40);
    await settle();
    await goals.syncGlobal();
    expect(server.added, 3);
    expect(goals.globalOf(event).sent, 3);
    expect(goals.progressOf(event).points, 3);
    expect(paid, [5]);
    // Others carry it to the next milestone.
    server.others = 200;
    await goals.syncGlobal();
    expect(paid, [5, 40]);
    await goals.syncGlobal();
    expect(paid, [5, 40]);
    expect(server.added, 3);
  });

  test('one who took no part is not paid; offline orders wait', () async {
    final event = goals.events.single;
    server.others = 500;
    await goals.syncGlobal();
    expect(goals.progressOf(event).points, 500);
    expect(paid, isEmpty);
    server.down = true;
    goals.orderDelivered(40);
    await settle();
    // The total last heard is enough: paid at once, sent when it can be.
    expect(paid, [5, 40]);
    expect(goals.globalOf(event).sent, 0);
    server.down = false;
    await goals.syncGlobal();
    expect(server.added, 1);
    expect(goals.globalOf(event).sent, 1);
  });

  test('a player not signed in adds nothing but shares the reward', () async {
    server
      ..signedIn = false
      ..others = 3;
    goals.orderDelivered(40);
    await settle();
    await goals.syncGlobal();
    expect(server.added, 0);
    expect(paid, [5]);
  });

  test('a goal that has ended is heard one last time, and paid', () async {
    var now = DateTime.now();
    final late = GoalEventsController(
      events: playableGoalEvents([_goal()]),
      extras: extras,
      open: (_) => true,
      grant: (reward) => paid.add(reward.manna + reward.talents),
      server: server,
      clock: () => now,
    );
    final event = late.events.single;
    late.orderDelivered(40);
    await settle();
    expect(paid, isEmpty);
    // The others finish it after this player's last visit; it ends.
    server.others = 500;
    now = now.add(const Duration(days: 30));
    await late.syncGlobal();
    expect(paid, [5, 40]);
    expect(late.globalOf(event).closed, isTrue);
    server.others = 900;
    await late.syncGlobal();
    expect(paid, [5, 40]);
    late.dispose();
  });

  test('what this phone knows of the total', () {
    const progress = GlobalProgress(mine: 450, sent: 100, total: 900);
    expect(progress.hasUnsent, isTrue);
    expect(progress.known, 1250);
    expect(const GlobalProgress(mine: 2, sent: 5).hasUnsent, isFalse);
    expect(
      GlobalProgress.fromJson(progress.toJson()).toJson(),
      progress.toJson(),
    );
  });
}
