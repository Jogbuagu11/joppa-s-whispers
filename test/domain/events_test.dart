import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/events.dart';

import '../support/event_fixtures.dart';

void main() {
  final start = DateTime.utc(2026, 10, 1);
  final end = DateTime.utc(2026, 10, 22);
  EventModel event({String id = 'e', DateTime? endsAt}) => EventModel.fromJson(
    eventRow(id: id, startsAt: start, endsAt: endsAt ?? end),
  );

  test('an event row is read in full', () {
    final e = event();
    expect(e.id, 'e');
    expect(e.name, 'Joppa Boat Festival');
    expect((e.cols, e.rows), (5, 7));
    expect((e.generatorCol, e.generatorRow), (2, 6));
    expect(e.chain['id'], 'boat');
    expect([for (final m in e.milestones) m.points], [2, 5, 9]);
    expect(e.milestones.last.manna, 20);
    expect(e.milestones.last.talents, 100);
  });

  group('when an event is on', () {
    test('from its start up to, not including, its end', () {
      final e = event();
      expect(
        isEventLive(e, start.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(isEventLive(e, start), isTrue);
      expect(isEventLive(e, end.subtract(const Duration(seconds: 1))), isTrue);
      expect(isEventLive(e, end), isFalse);
    });

    test('the one ending soonest is shown; none when none is on', () {
      final long = event(id: 'long');
      final short = event(id: 'short', endsAt: DateTime.utc(2026, 10, 5));
      final now = DateTime.utc(2026, 10, 2);
      expect(currentEvent([long, short], now)?.id, 'short');
      expect(
        currentEvent([long, short], DateTime.utc(2026, 10, 6))?.id,
        'long',
      );
      expect(currentEvent([long, short], DateTime.utc(2026, 11, 1)), isNull);
      expect(currentEvent([], now), isNull);
    });

    test('time left counts down to zero and no further', () {
      final e = event();
      expect(
        eventTimeLeft(e, end.subtract(const Duration(hours: 3))),
        const Duration(hours: 3),
      );
      expect(eventTimeLeft(e, end.add(const Duration(days: 1))), Duration.zero);
    });

    test('time left is written briefly', () {
      expect(
        formatTimeLeft(const Duration(days: 2, hours: 5, minutes: 9)),
        '2d 5h',
      );
      expect(formatTimeLeft(const Duration(hours: 5, minutes: 12)), '5h 12m');
      expect(formatTimeLeft(const Duration(minutes: 12, seconds: 40)), '12m');
      expect(formatTimeLeft(Duration.zero), '0m');
    });
  });

  group('points and rewards', () {
    final steps = event().milestones;

    test('a merge is worth the tier it makes', () {
      expect(eventPointsForMerge(2), 2);
      expect(eventPointsForMerge(6), 6);
      expect(eventPointsForMerge(0), 0);
      expect(eventPointsForMerge(-3), 0);
    });

    test('steps are reached as points pass them', () {
      expect(milestonesReached(steps, 0), 0);
      expect(milestonesReached(steps, 2), 1);
      expect(milestonesReached(steps, 8), 2);
      expect(milestonesReached(steps, 500), 3);
    });

    test('each step is paid once, and several at once if jumped', () {
      expect(milestonesToPay(steps, 1, 0), isEmpty);
      expect([for (final m in milestonesToPay(steps, 6, 0)) m.points], [2, 5]);
      expect([for (final m in milestonesToPay(steps, 6, 1)) m.points], [5]);
      expect(milestonesToPay(steps, 6, 2), isEmpty);
      expect(milestonesToPay(steps, 99, 3), isEmpty);
      // A nonsense count never pays anything.
      expect(milestonesToPay(steps, 99, 7), isEmpty);
      expect(milestonesToPay(steps, 99, -1), isEmpty);
    });

    test('the next step, or none when the track is finished', () {
      expect(nextMilestone(steps, 0)?.points, 2);
      expect(nextMilestone(steps, 5)?.points, 9);
      expect(nextMilestone(steps, 9), isNull);
    });
  });

  test('progress survives being saved and read back', () {
    const progress = EventProgress(
      eventId: 'e',
      points: 7,
      paid: 2,
      items: [(itemId: 'boat_02', col: 1, row: 3)],
    );
    final back = EventProgress.fromJson(progress.toJson());
    expect(back.eventId, 'e');
    expect(back.points, 7);
    expect(back.paid, 2);
    expect(back.items.single, (itemId: 'boat_02', col: 1, row: 3));
  });
}
