// The settings screen (sound, vibration, tier numbers and the notification
// switches), and the one-time in-game question that comes before the
// phone's own permission prompt.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/domain/reminders.dart';
import 'package:whispers_of_joppa/features/settings/comfort_controller.dart';
import 'package:whispers_of_joppa/features/settings/notifications_controller.dart';

const _gold = Color(0xFFD4802A);
const _ink = Color(0xFF1A1205);
const _cream = Color(0xFFF3E5C8);

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.controller,
    required this.content,
    this.comfort,
  });

  /// Sound, vibration and tier numbers. Null leaves those switches out.
  final ComfortController? comfort;

  final NotificationsController controller;
  final NotificationContent content;

  @override
  Widget build(BuildContext context) {
    final text = content.settingsText;
    return Scaffold(
      key: const Key('notification_settings_screen'),
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: _gold,
        title: Text(text['title'] ?? ''),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([controller, comfort]),
          builder: (context, _) {
            final prefs = controller.prefs;
            final comfort = this.comfort;
            return ListView(
              children: [
                if (comfort != null) ...[
                  _switch(
                    'sound',
                    text,
                    comfort.prefs.sound,
                    comfort.setSound,
                    prefix: 'comfort',
                  ),
                  _switch(
                    'haptics',
                    text,
                    comfort.prefs.haptics,
                    comfort.setHaptics,
                    prefix: 'comfort',
                  ),
                  _switch(
                    'tier_numbers',
                    text,
                    comfort.prefs.tierNumbers,
                    comfort.setTierNumbers,
                    prefix: 'comfort',
                  ),
                  const Divider(color: Color(0xFF3A2A0C)),
                ],
                if (controller.blockedByPhone)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      text['blocked'] ?? '',
                      key: const Key('notifications_blocked'),
                      style: const TextStyle(color: _gold),
                    ),
                  ),
                _switch(
                  'reminders',
                  text,
                  prefs.reminders,
                  controller.setReminders,
                ),
                _switch('events', text, prefs.events, controller.setEvents),
                _switch(
                  'chapters',
                  text,
                  prefs.chapters,
                  controller.setChapters,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _switch(
    String key,
    Map<String, String> text,
    bool value,
    Future<void> Function(bool) onChanged, {
    String prefix = 'notify',
  }) => SwitchListTile(
    key: Key('${prefix}_$key'),
    value: value,
    onChanged: onChanged,
    activeThumbColor: _gold,
    title: Text(text[key] ?? '', style: const TextStyle(color: _cream)),
    subtitle: Text(
      text['${key}_hint'] ?? '',
      style: const TextStyle(color: Color(0xFFBFA77A), fontSize: 12),
    ),
  );
}

/// Asks, in the game's own words, whether the player would like
/// notifications. Returns true for yes, false for no, and null if it was
/// closed without an answer (it is then asked again another time).
Future<bool?> showNotificationExplainer(
  BuildContext context,
  NotificationContent content,
) {
  return showDialog<bool>(
    context: context,
    // A stray tap outside must not count as an answer.
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      key: const Key('notification_explainer'),
      backgroundColor: const Color(0xFF2A1F08),
      title: Text(content.explainerTitle, style: const TextStyle(color: _gold)),
      content: Text(
        content.explainerBody,
        style: const TextStyle(color: Colors.white),
      ),
      actionsOverflowAlignment: OverflowBarAlignment.end,
      actions: [
        TextButton(
          key: const Key('notification_explainer_no'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            content.explainerNo,
            style: const TextStyle(color: _cream),
          ),
        ),
        TextButton(
          key: const Key('notification_explainer_yes'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            content.explainerYes,
            style: const TextStyle(color: _gold),
          ),
        ),
      ],
    ),
  );
}
