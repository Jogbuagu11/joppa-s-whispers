// Notification rules: what to remind the player about and when. Pure Dart,
// fully unit tested.
import 'package:whispers_of_joppa/domain/economy.dart';

/// Wording and timing from content/notifications.json.
class NotificationContent {
  /// The story task after which the player is first asked about notifications.
  final String askAfterTask;

  /// No notification is shown from [quietStartHour] until [quietEndHour]
  /// (the phone's own time).
  final int quietStartHour;
  final int quietEndHour;
  final String explainerTitle;
  final String explainerBody;
  final String explainerYes;
  final String explainerNo;

  /// "Manna full" is only sent if Manna was at or below this share of the
  /// bar when the player left.
  final int mannaLowPercent;
  final String mannaFullTitle;
  final String mannaFullBody;
  final int comeBackAfterDays;

  /// The come-back reminder is never shown again sooner than this.
  final int comeBackRepeatDays;
  final String comeBackTitle;
  final String comeBackBody;

  /// Labels for the settings screen, by key.
  final Map<String, String> settingsText;

  const NotificationContent({
    required this.askAfterTask,
    required this.quietStartHour,
    required this.quietEndHour,
    required this.explainerTitle,
    required this.explainerBody,
    required this.explainerYes,
    required this.explainerNo,
    required this.mannaLowPercent,
    required this.mannaFullTitle,
    required this.mannaFullBody,
    required this.comeBackAfterDays,
    required this.comeBackRepeatDays,
    required this.comeBackTitle,
    required this.comeBackBody,
    required this.settingsText,
  });

  factory NotificationContent.fromJson(Map<String, dynamic> json) {
    final explainer = json['explainer'] as Map<String, dynamic>;
    final manna = json['manna_full'] as Map<String, dynamic>;
    final back = json['come_back'] as Map<String, dynamic>;
    return NotificationContent(
      askAfterTask: json['ask_after_task'] as String,
      quietStartHour: json['quiet_start_hour'] as int,
      quietEndHour: json['quiet_end_hour'] as int,
      explainerTitle: explainer['title'] as String,
      explainerBody: explainer['body'] as String,
      explainerYes: explainer['yes'] as String,
      explainerNo: explainer['no'] as String,
      mannaLowPercent: manna['low_percent'] as int,
      mannaFullTitle: manna['title'] as String,
      mannaFullBody: manna['body'] as String,
      comeBackAfterDays: back['after_days'] as int,
      comeBackRepeatDays: back['repeat_days'] as int,
      comeBackTitle: back['title'] as String,
      comeBackBody: back['body'] as String,
      settingsText: (json['settings'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      ),
    );
  }
}

/// The player's notification choices, kept on the phone.
class NotificationPrefs {
  /// True once the in-game question has been answered (it is asked once).
  final bool asked;
  final bool reminders;
  final bool events;
  final bool chapters;

  /// When the latest come-back reminder was set to show, or null.
  final DateTime? comeBackAt;

  const NotificationPrefs({
    this.asked = false,
    this.reminders = false,
    this.events = false,
    this.chapters = false,
    this.comeBackAt,
  });

  /// Everything on: what saying yes to the in-game question gives.
  const NotificationPrefs.allOn()
    : asked = true,
      reminders = true,
      events = true,
      chapters = true,
      comeBackAt = null;

  /// Asked and declined.
  const NotificationPrefs.declined()
    : asked = true,
      reminders = false,
      events = false,
      chapters = false,
      comeBackAt = null;

  bool get anyOn => reminders || events || chapters;

  /// These choices with some switches changed. Using a switch counts as
  /// having been asked.
  NotificationPrefs copyWith({bool? reminders, bool? events, bool? chapters}) =>
      NotificationPrefs(
        asked: true,
        reminders: reminders ?? this.reminders,
        events: events ?? this.events,
        chapters: chapters ?? this.chapters,
        comeBackAt: comeBackAt,
      );

  NotificationPrefs withComeBackAt(DateTime? when) => NotificationPrefs(
    asked: asked,
    reminders: reminders,
    events: events,
    chapters: chapters,
    comeBackAt: when,
  );

  Map<String, dynamic> toJson() => {
    'asked': asked,
    'reminders': reminders,
    'events': events,
    'chapters': chapters,
    'come_back_at': comeBackAt?.toUtc().toIso8601String(),
  };

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) =>
      NotificationPrefs(
        asked: json['asked'] == true,
        reminders: json['reminders'] == true,
        events: json['events'] == true,
        chapters: json['chapters'] == true,
        comeBackAt: DateTime.tryParse('${json['come_back_at']}')?.toLocal(),
      );
}

/// Whether to show the in-game question now: once only, and not before the
/// chosen task is done.
bool shouldAskAboutNotifications(
  NotificationPrefs prefs,
  NotificationContent content,
  Iterable<String> completedTasks,
) => !prefs.asked && completedTasks.contains(content.askAfterTask);

/// Whether [hour] (0-23) falls in the quiet hours.
bool isQuietHour(int hour, int quietStart, int quietEnd) {
  if (quietStart == quietEnd) return false;
  return quietStart > quietEnd
      // Overnight, for example 21 to 9.
      ? hour >= quietStart || hour < quietEnd
      : hour >= quietStart && hour < quietEnd;
}

/// [moment] as the phone's own time, moved, if it falls in the quiet hours,
/// to the moment they end.
DateTime afterQuietHours(DateTime moment, int quietStart, int quietEnd) {
  // Quiet hours are by the phone's clock, whatever form the time came in.
  final when = moment.toLocal();
  if (!isQuietHour(when.hour, quietStart, quietEnd)) return when;
  final sameDay = DateTime(when.year, when.month, when.day, quietEnd);
  return sameDay.isAfter(when)
      ? sameDay
      : DateTime(when.year, when.month, when.day + 1, quietEnd);
}

/// When Manna will be full, or null if no reminder is due: the bar is
/// already full, or the player was not low when they left.
DateTime? mannaFullAt(
  EconomyConfig config,
  MannaState state,
  DateTime now, {
  required int lowPercent,
}) {
  final max = config.maxManna;
  if (max <= 0 || state.manna >= max) return null;
  if (state.manna * 100 > max * lowPercent) return null;
  final missing = max - state.manna;
  final full = state.lastRegen.add(
    Duration(seconds: missing * config.mannaRegenSeconds),
  );
  // A moment too close to now cannot be scheduled reliably.
  return full.isAfter(now.add(const Duration(minutes: 1))) ? full : null;
}

/// A reminder to put on the phone's schedule.
class PlannedReminder {
  /// Fixed per kind, so scheduling again replaces the old one.
  final int id;
  final String title;
  final String body;

  /// The phone's own time.
  final DateTime when;

  const PlannedReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
  });
}

const mannaFullReminderId = 1;
const comeBackReminderId = 2;

/// The reminders to schedule as the player leaves the game at [now]. Empty
/// if reminders are off. Each is moved out of the quiet hours.
List<PlannedReminder> planReminders({
  required NotificationPrefs prefs,
  required NotificationContent content,
  required EconomyConfig config,
  required MannaState manna,
  required DateTime now,
}) {
  if (!prefs.reminders) return const [];
  DateTime polite(DateTime when) =>
      afterQuietHours(when, content.quietStartHour, content.quietEndHour);
  final full = mannaFullAt(
    config,
    manna,
    now,
    lowPercent: content.mannaLowPercent,
  );
  return [
    if (full != null)
      PlannedReminder(
        id: mannaFullReminderId,
        title: content.mannaFullTitle,
        body: content.mannaFullBody,
        when: polite(full),
      ),
    if (content.comeBackAfterDays > 0)
      PlannedReminder(
        id: comeBackReminderId,
        title: content.comeBackTitle,
        body: content.comeBackBody,
        when: polite(
          comeBackTime(
            now,
            afterDays: content.comeBackAfterDays,
            repeatDays: content.comeBackRepeatDays,
            lastShown: prefs.comeBackAt,
          ),
        ),
      ),
  ];
}

/// When the come-back reminder should show for a player leaving at [now]:
/// [afterDays] from now, but never within [repeatDays] of one already shown.
/// [lastShown] still in the future was never shown (the player came back
/// first), so it does not count.
DateTime comeBackTime(
  DateTime now, {
  required int afterDays,
  required int repeatDays,
  DateTime? lastShown,
}) {
  final usual = now.add(Duration(days: afterDays));
  if (lastShown == null || lastShown.isAfter(now)) return usual;
  final earliest = lastShown.add(Duration(days: repeatDays));
  return earliest.isAfter(usual) ? earliest : usual;
}
