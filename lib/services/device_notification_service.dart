// Notifications through the phone: scheduled reminders with
// flutter_local_notifications, push topics with Firebase Messaging.
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:whispers_of_joppa/domain/reminders.dart';
import 'package:whispers_of_joppa/services/notification_service.dart';

final _log = Logger('Notifications');

const _topicEvents = 'events';
const _topicChapters = 'chapters';
const _pushWait = Duration(seconds: 10);

class DeviceNotificationService implements NotificationService {
  /// False when Firebase could not start: push is then skipped entirely.
  final bool pushAvailable;
  final _local = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  DeviceNotificationService({required this.pushAvailable});

  Future<void> _init() => _ready ??= () async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Never ask for permission here: the game asks at its own moment.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }();

  AndroidFlutterLocalNotificationsPlugin? get _android => _local
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _local
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    try {
      await _init();
      if (Platform.isIOS) {
        return await _ios?.requestPermissions(alert: true, sound: true) ??
            false;
      }
      return await _android?.requestNotificationsPermission() ?? false;
    } on Object catch (e) {
      _log.warning('Could not ask for notification permission: $e');
      return false;
    }
  }

  @override
  Future<bool> permissionGranted() async {
    try {
      await _init();
      if (Platform.isIOS) {
        return (await _ios?.checkPermissions())?.isEnabled ?? false;
      }
      return await _android?.areNotificationsEnabled() ?? false;
    } on Object catch (e) {
      _log.warning('Could not read notification permission: $e');
      return false;
    }
  }

  @override
  Future<void> scheduleReminders(
    List<PlannedReminder> reminders, {
    required String groupName,
    required String groupHint,
  }) async {
    try {
      await _init();
      await _local.cancelAllPendingNotifications();
    } on Object catch (e) {
      _log.warning('Could not clear old reminders: $e');
      return;
    }
    for (final reminder in reminders) {
      // Each by itself: one that cannot be scheduled must not stop the rest.
      try {
        await _local.zonedSchedule(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          // An exact moment in time, so the phone's time zone name is not
          // needed.
          scheduledDate: tz.TZDateTime.from(reminder.when.toUtc(), tz.UTC),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'reminders',
              groupName,
              channelDescription: groupHint,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          // Roughly on time is fine, and needs no special permission.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } on Object catch (e) {
        _log.warning('Could not schedule reminder ${reminder.id}: $e');
      }
    }
  }

  @override
  Future<void> cancelReminders() async {
    try {
      await _init();
      await _local.cancelAll();
    } on Object catch (e) {
      _log.warning('Could not cancel reminders: $e');
    }
  }

  @override
  Future<void> setTopics({required bool events, required bool chapters}) async {
    if (!pushAvailable) return;
    try {
      final push = FirebaseMessaging.instance;
      await Future.wait([
        events
            ? push.subscribeToTopic(_topicEvents)
            : push.unsubscribeFromTopic(_topicEvents),
        chapters
            ? push.subscribeToTopic(_topicChapters)
            : push.unsubscribeFromTopic(_topicChapters),
      ]).timeout(_pushWait);
    } on Object catch (e) {
      // Push needs Apple's push key and a real phone; without them the
      // reminders above still work.
      _log.info('Push topics not set: $e');
    }
  }

  @override
  Future<String?> pushToken() async {
    if (!pushAvailable) return null;
    try {
      return await FirebaseMessaging.instance.getToken().timeout(_pushWait);
    } on Object catch (e) {
      _log.info('No push token: $e');
      return null;
    }
  }
}
