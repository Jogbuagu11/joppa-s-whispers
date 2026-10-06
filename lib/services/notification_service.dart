// Notifications, as the game sees them. The real one is in
// device_notification_service.dart; tests use a stand-in.
import 'package:whispers_of_joppa/domain/reminders.dart';

abstract class NotificationService {
  /// Shows the phone's own permission prompt (it can only be shown once on
  /// an iPhone). Returns whether notifications are allowed.
  Future<bool> requestPermission();

  /// Whether the phone currently allows this app to notify.
  Future<bool> permissionGranted();

  /// Replaces every scheduled reminder with [reminders]. [groupName] and
  /// [groupHint] are what the phone's own Settings call these.
  Future<void> scheduleReminders(
    List<PlannedReminder> reminders, {
    required String groupName,
    required String groupHint,
  });

  /// Removes every reminder, scheduled or already showing.
  Future<void> cancelReminders();

  /// Joins or leaves the push topics for event and new-chapter news.
  Future<void> setTopics({required bool events, required bool chapters});

  /// This phone's push address, or null if push is not available.
  Future<String?> pushToken();
}

/// Where a signed-in player's push address and choices are kept, so the
/// server can respect them.
abstract class DeviceTokenStore {
  Future<void> save(String token, NotificationPrefs prefs);
}
