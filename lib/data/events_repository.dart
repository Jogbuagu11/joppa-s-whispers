// Where events come from: the server when it can be reached, otherwise
// the last list it gave, otherwise the app's own content/events.json. An
// event with any problem is left out; nothing here can stop the game.
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';
import 'package:whispers_of_joppa/data/event_validator.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/events.dart';

final _log = Logger('Events');

/// The server's list of events.
abstract class RemoteEvents {
  /// Every event the server has switched on, as raw rows. Throws if the
  /// server cannot be reached.
  Future<List<Object?>> fetch();
}

class EventsRepository {
  /// Reads content/events.json from inside the app.
  final Future<List<Object?>> Function() loadBundled;
  final RemoteEvents? remote;
  final Future<Directory> Function() _directory;

  EventsRepository({
    required this.loadBundled,
    this.remote,
    Future<Directory> Function()? directory,
  }) : _directory = directory ?? getApplicationDocumentsDirectory;

  Future<File> _cacheFile() async =>
      File('${(await _directory()).path}/events_cache.json');

  /// Every playable event known right now. Never throws.
  Future<List<EventModel>> load() async {
    final rows = await _fromServer() ?? await _fromCache() ?? await _bundled();
    return playableEvents(rows);
  }

  Future<List<Object?>?> _fromServer() async {
    final source = remote;
    if (source == null) return null;
    try {
      final rows = await source.fetch().timeout(const Duration(seconds: 10));
      try {
        await (await _cacheFile()).writeAsString(jsonEncode(rows), flush: true);
      } on Object catch (e) {
        _log.warning('Events could not be kept for offline use: $e');
      }
      return rows;
    } on Object catch (e) {
      _log.info('Events not fetched from the server: $e');
      return null;
    }
  }

  Future<List<Object?>?> _fromCache() async {
    try {
      final file = await _cacheFile();
      if (!file.existsSync()) return null;
      return jsonDecode(await file.readAsString()) as List<dynamic>;
    } on Object catch (e) {
      _log.warning('Saved events could not be read: $e');
      return null;
    }
  }

  Future<List<Object?>> _bundled() async {
    try {
      return await loadBundled();
    } on Object catch (e) {
      _log.warning('The app\'s own events could not be read: $e');
      return const [];
    }
  }
}

/// The events in [rows] that pass every check, each id once.
List<EventModel> playableEvents(List<Object?> rows) {
  final seen = <String>{};
  final events = <EventModel>[];
  for (final row in rows) {
    final problems = eventProblems(row);
    if (problems.isNotEmpty) {
      _log.warning('Event left out: ${problems.join('; ')}');
      continue;
    }
    try {
      final event = EventModel.fromJson(row as Map<String, dynamic>);
      // Proves the event's board can really be built, beyond the checks.
      ContentLoader.forEvent(
        chain: event.chain,
        generator: event.generator,
        economy: _trialEconomy,
      );
      if (seen.add(event.id)) events.add(event);
    } on Object catch (e) {
      _log.warning('Event left out, it could not be read: $e');
    }
  }
  return events;
}

// Only used to try building an event's board; its numbers do not matter.
const _trialEconomy = EconomyConfig(
  maxManna: 1,
  mannaRegenSeconds: 1,
  generatorTapCost: 1,
  orderTalentsPerTier: 1,
  orderSlots: 1,
  tutorialFreeTaps: 0,
  mannaRefillBasePearls: 1,
  basketSlotBasePearls: 1,
  orderSkipCooldownSeconds: 1,
  rewardedAdMannaBonus: 0,
  rewardedAdMannaDailyCap: 0,
  rewardedAdDoubleRewardDailyCap: 0,
);

/// A player's progress in each event, kept on the phone (one file an event,
/// so two events on at once never disturb each other).
class EventProgressRepository {
  final Future<Directory> Function() _directory;

  EventProgressRepository({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  // Event ids are checked to be plain lowercase words, safe in a file name.
  Future<File> _file(String eventId) async =>
      File('${(await _directory()).path}/event_progress_$eventId.json');

  /// Progress in [eventId]: what was saved, or a fresh start if nothing was
  /// (or it belongs to an earlier event, or cannot be read).
  Future<EventProgress> load(String eventId) async {
    try {
      final file = await _file(eventId);
      if (file.existsSync()) {
        final saved = EventProgress.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>,
        );
        if (saved.eventId == eventId) return saved;
      }
    } on Object catch (e) {
      _log.warning('Event progress could not be read: $e');
    }
    return EventProgress(eventId: eventId);
  }

  Future<void> save(EventProgress progress) async {
    try {
      final file = await _file(progress.eventId);
      await file.writeAsString(jsonEncode(progress.toJson()), flush: true);
    } on Object catch (e) {
      _log.warning('Event progress could not be saved: $e');
    }
  }
}
