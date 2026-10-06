// The player's notification choices, and what follows from them: the
// one-time question, the scheduled reminders and the push topics.
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/data/notification_prefs_repository.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/domain/reminders.dart';
import 'package:whispers_of_joppa/services/notification_service.dart';

final _log = Logger('NotificationsController');

class NotificationsController extends ChangeNotifier {
  final NotificationService service;
  final NotificationPrefsRepository repository;

  /// Null where a signed-in record is not kept (tests).
  final DeviceTokenStore? tokens;
  final DateTime Function() _now;

  NotificationPrefs _prefs = const NotificationPrefs();
  bool _loaded = false;
  bool _allowedByPhone = true;

  // Work on the phone's schedule runs one piece at a time, so a quick
  // leave-and-return cannot leave a reminder behind.
  Future<void>? _queue;

  Future<void> _inOrder(Future<void> Function() work) {
    final before = _queue;
    return _queue = () async {
      if (before != null) await before;
      await work();
    }();
  }

  NotificationsController({
    required this.service,
    required this.repository,
    this.tokens,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  NotificationPrefs get prefs => _prefs;

  /// False when the phone itself has notifications turned off for the game
  /// although the player has some turned on here.
  bool get blockedByPhone => _prefs.anyOn && !_allowedByPhone;

  /// Reads the saved choices. Safe to call more than once.
  Future<void> load() async {
    if (_loaded) return;
    _prefs = await repository.load();
    _loaded = true;
    if (_prefs.anyOn) {
      _allowedByPhone = await service.permissionGranted();
      // The player may have signed in since choosing: record it for them.
      await _recordOnServer();
    }
    notifyListeners();
  }

  /// Whether to show the in-game question now.
  bool shouldAsk(
    NotificationContent content,
    Iterable<String> completedTasks,
  ) => _loaded && shouldAskAboutNotifications(_prefs, content, completedTasks);

  /// The player's answer to the in-game question. Only a yes brings up the
  /// phone's own prompt.
  Future<void> answer({required bool yes}) async {
    if (!yes) {
      await _set(const NotificationPrefs.declined());
      return;
    }
    _allowedByPhone = await service.requestPermission();
    await _set(const NotificationPrefs.allOn());
  }

  Future<void> setReminders(bool on) => _toggle(_prefs.copyWith(reminders: on));
  Future<void> setEvents(bool on) => _toggle(_prefs.copyWith(events: on));
  Future<void> setChapters(bool on) => _toggle(_prefs.copyWith(chapters: on));

  Future<void> _toggle(NotificationPrefs next) async {
    // Turning something on needs the phone's permission too.
    if (next.anyOn && !_prefs.anyOn) {
      _allowedByPhone = await service.requestPermission();
    }
    await _set(next);
  }

  Future<void> _set(NotificationPrefs next) async {
    final wasOn = _prefs.anyOn;
    _prefs = next;
    notifyListeners();
    await repository.save(next);
    if (!next.reminders) await _inOrder(service.cancelReminders);
    await service.setTopics(events: next.events, chapters: next.chapters);
    // A player who has never turned anything on has nothing to record.
    if (next.anyOn || wasOn) await _recordOnServer();
  }

  Future<void> _recordOnServer() async {
    final store = tokens;
    if (store == null) return;
    try {
      final token = await service.pushToken();
      if (token != null) await store.save(token, _prefs);
    } on Exception catch (e) {
      _log.warning('Notification choices not recorded on the server: $e');
    }
  }

  /// The player is leaving the game: schedule what they chose to hear about.
  Future<void> onLeaving({
    required NotificationContent content,
    required EconomyConfig config,
    required MannaState manna,
  }) async {
    if (!_loaded) return;
    final planned = planReminders(
      prefs: _prefs,
      content: content,
      config: config,
      manna: manna,
      now: _now(),
    );
    // Remember when the come-back reminder is due, so it is not repeated
    // too soon.
    for (final reminder in planned) {
      if (reminder.id == comeBackReminderId) {
        _prefs = _prefs.withComeBackAt(reminder.when);
        await repository.save(_prefs);
      }
    }
    await _inOrder(
      () => service.scheduleReminders(
        planned,
        groupName: content.settingsText['reminders'] ?? '',
        groupHint: content.settingsText['reminders_hint'] ?? '',
      ),
    );
  }

  /// The player is back: nothing needs reminding.
  Future<void> onReturning() async {
    if (!_loaded) return;
    await _inOrder(service.cancelReminders);
    if (_prefs.anyOn) {
      final allowed = await service.permissionGranted();
      if (allowed != _allowedByPhone) {
        _allowedByPhone = allowed;
        notifyListeners();
      }
    }
  }
}
