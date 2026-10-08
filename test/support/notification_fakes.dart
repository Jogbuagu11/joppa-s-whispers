// In-memory stand-ins for the phone's notifications and the saved choices.
import 'dart:io';

import 'package:whispers_of_joppa/data/notification_prefs_repository.dart';
import 'package:whispers_of_joppa/domain/reminders.dart';
import 'package:whispers_of_joppa/services/notification_service.dart';

class FakeNotificationService implements NotificationService {
  /// What the phone answers when asked for permission.
  bool allow = true;
  bool granted = false;
  int prompts = 0;
  int cancels = 0;
  List<PlannedReminder> scheduled = [];
  bool? topicEvents;
  bool? topicChapters;
  String? token = 'token-1';

  @override
  Future<bool> requestPermission() async {
    prompts++;
    return granted = allow;
  }

  @override
  Future<bool> permissionGranted() async => granted;

  @override
  Future<void> scheduleReminders(
    List<PlannedReminder> reminders, {
    required String groupName,
    required String groupHint,
  }) async {
    // Like the real phone, this takes a moment.
    await Future<void>.delayed(Duration.zero);
    scheduled = reminders;
    this.groupName = groupName;
  }

  String? groupName;

  @override
  Future<void> cancelReminders() async {
    cancels++;
    scheduled = [];
  }

  @override
  Future<void> setTopics({required bool events, required bool chapters}) async {
    topicEvents = events;
    topicChapters = chapters;
  }

  @override
  Future<String?> pushToken() async => token;
}

class FakeDeviceTokenStore implements DeviceTokenStore {
  final List<(String, NotificationPrefs)> saved = [];
  bool fail = false;

  @override
  Future<void> save(String token, NotificationPrefs prefs) async {
    if (fail) throw Exception('offline');
    saved.add((token, prefs));
  }
}

/// A choices file in a fresh temporary folder.
NotificationPrefsRepository tempPrefsRepository() {
  final dir = Directory.systemTemp.createTempSync('joppa_notify');
  return NotificationPrefsRepository(directory: () async => dir);
}

const testNotificationContent = NotificationContent(
  askAfterTask: 't5',
  quietStartHour: 21,
  quietEndHour: 9,
  explainerTitle: 'A word',
  explainerBody: 'May we notify you?',
  explainerYes: 'Yes',
  explainerNo: 'No',
  mannaLowPercent: 20,
  mannaFullTitle: 'Manna full',
  mannaFullBody: 'Ready',
  comeBackAfterDays: 3,
  comeBackRepeatDays: 7,
  comeBackTitle: 'Come back',
  comeBackBody: 'A story waits',
  settingsText: {
    'title': 'Settings',
    'sound': 'Sound',
    'sound_hint': 'Chimes',
    'haptics': 'Vibration',
    'haptics_hint': 'A small tap',
    'tier_numbers': 'Numbers on items',
    'tier_numbers_hint': 'Each item shows its level',
    'reminders': 'Gentle reminders',
    'reminders_hint': 'Manna full',
    'events': 'Event news',
    'events_hint': 'Events',
    'chapters': 'New chapters',
    'chapters_hint': 'Chapters',
    'blocked': 'Turned off on this phone',
    'ad_privacy': 'Ad privacy choices',
    'page_support': 'Help & support',
    'page_privacy': 'Privacy Policy',
    'page_terms': 'Terms of Service',
  },
);
