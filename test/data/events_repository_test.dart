import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/data/event_validator.dart';
import 'package:whispers_of_joppa/data/events_repository.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/events.dart';

import '../support/event_fixtures.dart';

class _Remote implements RemoteEvents {
  List<Object?> rows = [];
  bool offline = false;
  int calls = 0;

  @override
  Future<List<Object?>> fetch() async {
    calls++;
    if (offline) throw Exception('offline');
    return rows;
  }
}

Map<String, dynamic> _config(Map<String, dynamic> row) =>
    row['config'] as Map<String, dynamic>;

void main() {
  group('eventProblems', () {
    test('a complete event has none, and its board can be built', () {
      final row = eventRow();
      expect(eventProblems(row), isEmpty);
      final event = EventModel.fromJson(row);
      final loader = ContentLoader.forEvent(
        chain: event.chain,
        generator: event.generator,
        economy: const EconomyConfig(
          maxManna: 100,
          mannaRegenSeconds: 120,
          generatorTapCost: 1,
          orderTalentsPerTier: 5,
          orderSlots: 3,
          tutorialFreeTaps: 12,
          mannaRefillBasePearls: 10,
          basketSlotBasePearls: 10,
          orderSkipCooldownSeconds: 1800,
          rewardedAdMannaBonus: 20,
          rewardedAdMannaDailyCap: 5,
          rewardedAdDoubleRewardDailyCap: 3,
        ),
      );
      expect(loader.items, hasLength(6));
      expect(loader.generators['gen_boatyard']?.energyCost, 1);
      expect(loader.chains['boat']?.maxTier, 6);
    });

    test('junk is refused, not crashed on', () {
      expect(eventProblems(null), isNotEmpty);
      expect(eventProblems('event'), isNotEmpty);
      expect(eventProblems(<String, dynamic>{}), isNotEmpty);
      expect(eventProblems({'id': 'x', 'name': 'X', 'config': 7}), isNotEmpty);
    });

    test('dates must be dates, in order', () {
      final row = eventRow()..['ends_at'] = 'soon';
      expect(eventProblems(row).single, contains('must be dates'));
      final backwards = eventRow(
        startsAt: DateTime.utc(2026, 10, 9),
        endsAt: DateTime.utc(2026, 10, 1),
      );
      expect(eventProblems(backwards).single, contains('end after it starts'));
    });

    test('the board must be a sensible size', () {
      final row = eventRow();
      _config(row)['board'] = {'cols': 12, 'rows': 7};
      expect(eventProblems(row), contains(contains('board must be')));
    });

    test('the generator must be on the board and make the event chain', () {
      final off = eventRow();
      (_config(off)['generator'] as Map<String, dynamic>)['col'] = 5;
      expect(eventProblems(off).single, contains('sit on the event board'));
      final wrong = eventRow();
      (_config(wrong)['generator'] as Map<String, dynamic>)['chain_id'] =
          'bakery';
      expect(eventProblems(wrong).single, contains('make the event chain'));
    });

    test('generator odds must be for real tiers and add up to 1', () {
      final row = eventRow();
      (_config(row)['generator'] as Map<String, dynamic>)['levels'] = [
        {
          'level': 1,
          'odds': {'1': 0.5, '9': 0.5},
        },
      ];
      expect(eventProblems(row).single, contains('bad odds'));
      final short = eventRow();
      (_config(short)['generator'] as Map<String, dynamic>)['levels'] = [
        {
          'level': 1,
          'odds': {'1': 0.4},
        },
      ];
      expect(eventProblems(short).single, contains('add up to 1'));
    });

    test('chain tiers must run 1, 2, 3 with different items', () {
      final row = eventRow();
      final tiers =
          (_config(row)['chain'] as Map<String, dynamic>)['tiers']
              as List<dynamic>;
      (tiers[1] as Map<String, dynamic>)['item_id'] = 'boat_01';
      expect(eventProblems(row).single, contains('tier 2'));
    });

    test(
      'numbers written with a decimal point are refused, not crashed on',
      () {
        final tier = eventRow();
        final tiers =
            (_config(tier)['chain'] as Map<String, dynamic>)['tiers']
                as List<dynamic>;
        (tiers[1] as Map<String, dynamic>)['tier'] = 2.0;
        expect(eventProblems(tier), isNotEmpty);
        final level = eventRow();
        ((_config(level)['generator'] as Map<String, dynamic>)['levels']
            as List<dynamic>)[0] = {
          'level': 1.0,
          'odds': {'1': 1.0},
        };
        expect(eventProblems(level), isNotEmpty);
        expect(playableEvents([tier, level]), isEmpty);
      },
    );

    test('a colour or picture of the wrong kind is refused', () {
      final colour = eventRow();
      (_config(colour)['chain'] as Map<String, dynamic>)['placeholder_color'] =
          123;
      expect(eventProblems(colour).single, contains('placeholder_color'));
      final art = eventRow();
      final tiers =
          (_config(art)['chain'] as Map<String, dynamic>)['tiers']
              as List<dynamic>;
      (tiers[0] as Map<String, dynamic>)['asset'] = '../secret.png';
      expect(eventProblems(art).single, contains('tier 1'));
      (tiers[0] as Map<String, dynamic>)['asset'] =
          'assets/items/item_boat_01.jpg';
      expect(eventProblems(art), isEmpty);
    });

    test('sizes are capped', () {
      final long = eventRow();
      (_config(long)['generator'] as Map<String, dynamic>)['name'] = 'x' * 41;
      expect(eventProblems(long), isNotEmpty);
      final many = eventRow();
      _config(many)['milestones'] = [
        for (var i = 1; i <= 41; i++) {'points': i, 'manna': 1},
      ];
      expect(eventProblems(many).single, contains('at most 40'));
    });

    test('milestones must rise and give something sensible', () {
      final flat = eventRow();
      _config(flat)['milestones'] = [
        {'points': 5, 'manna': 10},
        {'points': 5, 'manna': 10},
      ];
      expect(eventProblems(flat).single, contains('keep rising'));
      final empty = eventRow();
      _config(empty)['milestones'] = [
        {'points': 5},
      ];
      expect(eventProblems(empty).single, contains('gives nothing'));
      final huge = eventRow();
      _config(huge)['milestones'] = [
        {'points': 5, 'manna': 100000},
      ];
      expect(eventProblems(huge).single, contains('too much'));
      final none = eventRow();
      _config(none)['milestones'] = <Object>[];
      expect(eventProblems(none).single, contains('at least one milestone'));
    });
  });

  group('EventsRepository', () {
    late Directory dir;
    late _Remote remote;

    EventsRepository make({List<Object?> bundled = const []}) =>
        EventsRepository(
          loadBundled: () async => bundled,
          remote: remote,
          directory: () async => dir,
        );

    setUp(() {
      dir = Directory.systemTemp.createTempSync('joppa_events');
      remote = _Remote();
    });

    test('events come from the server', () async {
      remote.rows = [eventRow(id: 'a'), eventRow(id: 'b')];
      final events = await make().load();
      expect([for (final e in events) e.id], ['a', 'b']);
    });

    test('a broken event is left out; the good ones still show', () async {
      final broken = eventRow(id: 'bad')..remove('config');
      remote.rows = [
        broken,
        eventRow(id: 'good'),
        'junk',
        eventRow(id: 'good'),
      ];
      final events = await make().load();
      expect([for (final e in events) e.id], ['good']);
    });

    test('offline, the last list from the server is used', () async {
      remote.rows = [eventRow(id: 'a')];
      await make().load();
      remote.offline = true;
      final events = await make(bundled: [eventRow(id: 'own')]).load();
      expect([for (final e in events) e.id], ['a']);
    });

    test('never fetched: the app\'s own events are used', () async {
      remote.offline = true;
      final events = await make(bundled: [eventRow(id: 'own')]).load();
      expect([for (final e in events) e.id], ['own']);
    });

    test('the server switching every event off is respected', () async {
      remote.rows = [eventRow(id: 'a')];
      await make().load();
      remote.rows = [];
      expect(await make(bundled: [eventRow(id: 'own')]).load(), isEmpty);
    });

    test('an unreadable own file means no events, not a crash', () async {
      remote.offline = true;
      final repository = EventsRepository(
        loadBundled: () async => throw const FormatException('bad'),
        remote: remote,
        directory: () async => dir,
      );
      expect(await repository.load(), isEmpty);
    });

    test(
      'the app\'s real events file is readable and every event in it is valid',
      () {
        final rows =
            jsonDecode(File('content/events.json').readAsStringSync())
                as List<dynamic>;
        expect(playableEvents(rows), hasLength(rows.length));
      },
    );
  });

  group('EventProgressRepository', () {
    test('progress is kept per event', () async {
      final dir = Directory.systemTemp.createTempSync('joppa_progress');
      final repository = EventProgressRepository(directory: () async => dir);
      expect((await repository.load('a')).points, 0);
      await repository.save(
        const EventProgress(eventId: 'a', points: 4, paid: 1),
      );
      expect((await repository.load('a')).points, 4);
      // A different event starts fresh, and does not disturb the first.
      expect((await repository.load('b')).points, 0);
      await repository.save(const EventProgress(eventId: 'b', points: 9));
      expect((await repository.load('a')).points, 4);
      expect((await repository.load('b')).points, 9);
      // A damaged file starts fresh too.
      File('${dir.path}/event_progress_a.json').writeAsStringSync('{not json');
      expect((await repository.load('a')).points, 0);
    });
  });
}
