import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/events_repository.dart';
import 'package:whispers_of_joppa/domain/events.dart';
import 'package:whispers_of_joppa/features/events/event_controller.dart';

import '../support/event_fixtures.dart';

void main() {
  late EventProgressRepository repository;
  late int manna;
  late int talents;
  late List<String> writes;
  late DateTime now;
  final start = DateTime.utc(2026, 10, 1);
  final end = DateTime.utc(2026, 10, 22);
  final event = EventModel.fromJson(eventRow(startsAt: start, endsAt: end));

  EventController make([EventProgress? progress]) => EventController(
    event: event,
    progress: progress ?? EventProgress(eventId: event.id),
    repository: repository,
    addManna: (n) => manna += n,
    addTalents: (n) => talents += n,
    saveGame: () async => writes.add('game'),
    clock: () => now,
  );

  setUp(() {
    final dir = Directory.systemTemp.createTempSync('joppa_event_ctl');
    repository = EventProgressRepository(directory: () async => dir);
    manna = 0;
    talents = 0;
    writes = [];
    now = DateTime.utc(2026, 10, 5);
  });

  test('merging earns points; reaching a step pays its reward once', () async {
    final c = make();
    c.onMerged(2);
    expect(c.points, 2);
    expect(manna, 10);
    expect(c.paid, 1);
    c.onMerged(2);
    expect(c.points, 4);
    expect(manna, 10);
    expect(talents, 0);
    expect(c.next?.points, 5);
    await c.save();
    expect((await repository.load(event.id)).points, 4);
  });

  test('one big merge can pay several steps', () {
    final c = make();
    c.onMerged(6);
    expect(c.paid, 2);
    expect(manna, 10);
    expect(talents, 50);
    expect([for (final m in c.justPaid.value) m.points], [2, 5]);
  });

  test('the main game is written before progress records a reward', () async {
    final c = make();
    c.onMerged(2);
    await c.save();
    expect(writes, ['game']);
    // A merge that pays nothing does not write the main game.
    c.onMerged(2);
    await c.save();
    expect(writes, ['game']);
  });

  test(
    'a reward is never recorded as paid before the game is written',
    () async {
      final order = <String>[];
      late EventController c;
      c = EventController(
        event: event,
        progress: EventProgress(eventId: event.id),
        repository: repository,
        addManna: (n) => manna += n,
        addTalents: (n) => talents += n,
        saveGame: () async {
          final onDisk = await repository.load(event.id);
          order.add('game written with ${onDisk.paid} recorded as paid');
        },
        clock: () => now,
      );
      // Two plain board saves are queued, then a merge pays a step.
      c.save();
      c.save();
      c.onMerged(2);
      await c.save();
      expect(order, ['game written with 0 recorded as paid']);
      expect((await repository.load(event.id)).paid, 1);
    },
  );

  test('rewards already paid are not paid again after reopening', () async {
    final first = make();
    first.onMerged(6);
    await first.save();
    final again = make(await repository.load(event.id));
    expect(again.points, 6);
    expect(again.paid, 2);
    again.onMerged(2);
    expect(manna, 10);
    expect(talents, 50);
    again.onMerged(2);
    expect(again.trackFinished, isTrue);
    expect(manna, 30);
    expect(talents, 150);
  });

  test('points stop counting once the event has ended', () {
    final c = make();
    now = end;
    expect(c.isLive, isFalse);
    c.onMerged(6);
    expect(c.points, 0);
    expect(manna, 0);
  });

  test('nonsense saved progress cannot pay or skip rewards wrongly', () {
    final c = make(EventProgress(eventId: event.id, points: -5, paid: 99));
    expect(c.points, 0);
    expect(c.paid, 3);
    c.onMerged(6);
    expect(manna, 0);
    expect(talents, 0);
  });

  test('the board\'s items are written with the progress', () async {
    final c = make()
      ..boardItems = (() => [(itemId: 'boat_01', col: 0, row: 0)]);
    await c.save();
    expect((await repository.load(event.id)).items.single, (
      itemId: 'boat_01',
      col: 0,
      row: 0,
    ));
  });
}
