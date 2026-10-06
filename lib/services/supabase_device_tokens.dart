// Keeps a signed-in player's push address and notification choices on the
// server (table device_tokens), so pushes respect them.
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whispers_of_joppa/domain/reminders.dart';
import 'package:whispers_of_joppa/services/notification_service.dart';

class SupabaseDeviceTokens implements DeviceTokenStore {
  final SupabaseClient _client;

  SupabaseDeviceTokens(this._client);

  @override
  Future<void> save(String token, NotificationPrefs prefs) async {
    final userId = _client.auth.currentUser?.id;
    // Signed out: topics still work, there is just no per-player record.
    if (userId == null) return;
    await _client.from('device_tokens').upsert({
      'user_id': userId,
      'fcm_token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'notify_reminders': prefs.reminders,
      'notify_events': prefs.events,
      'notify_chapters': prefs.chapters,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,fcm_token');
  }
}
