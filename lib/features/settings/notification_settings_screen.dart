// The settings screen (sound, vibration, tier numbers and the notification
// switches), and the one-time in-game question that comes before the
// phone's own permission prompt.
import 'package:whispers_of_joppa/app/game_dialog.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_app_bar.dart';
import 'package:whispers_of_joppa/domain/reminders.dart';
import 'package:whispers_of_joppa/features/settings/comfort_controller.dart';
import 'package:whispers_of_joppa/features/settings/notifications_controller.dart';
import 'package:whispers_of_joppa/services/ad_service.dart';

const _gold = Color(0xFFD4802A);
const _ink = Color(0xFF1A1205);
const _cream = Color(0xFFF3E5C8);

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.controller,
    required this.content,
    this.comfort,
    this.ads,
    this.onOpenPage,
  });

  /// Opens one of the game's web pages (privacy, terms, support) by its
  /// name; null leaves those rows out.
  final void Function(String page)? onOpenPage;

  /// Ads. Where the player has ad privacy choices to change, a row for
  /// them is shown; null (or no such choices) leaves it out.
  final AdService? ads;

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
      appBar: gameAppBar(Text(text['title'] ?? '')),
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
                if (ads case final ads?)
                  _AdPrivacyRow(ads: ads, label: text['ad_privacy'] ?? ''),
                if (onOpenPage case final open?) ...[
                  const Divider(color: Color(0xFF3A2A0C)),
                  for (final page in const ['support', 'privacy', 'terms'])
                    ListTile(
                      key: Key('page_$page'),
                      onTap: () => open(page),
                      title: Text(
                        text['page_$page'] ?? '',
                        style: const TextStyle(color: _cream),
                      ),
                      trailing: const Icon(Icons.open_in_new, color: _gold),
                    ),
                ],
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
    builder: (context) => GameDialog(
      key: const Key('notification_explainer'),
      icon: Icons.notifications_active,
      title: Text(content.explainerTitle, style: const TextStyle(color: _gold)),
      content: Text(
        content.explainerBody,
        style: const TextStyle(color: Colors.white),
      ),
      actions: [
        TextButton(
          key: const Key('notification_explainer_no'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            content.explainerNo,
            style: const TextStyle(color: _cream),
          ),
        ),
        FilledButton(
          key: const Key('notification_explainer_yes'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(content.explainerYes),
        ),
      ],
    ),
  );
}

/// "Ad privacy choices": shown only to players who have such choices.
class _AdPrivacyRow extends StatefulWidget {
  const _AdPrivacyRow({required this.ads, required this.label});

  final AdService ads;
  final String label;

  @override
  State<_AdPrivacyRow> createState() => _AdPrivacyRowState();
}

class _AdPrivacyRowState extends State<_AdPrivacyRow> {
  // Asked once, not at every repaint.
  late final Future<bool> _required = widget.ads.privacyOptionsRequired();
  bool _open = false;

  Future<void> _show() async {
    if (_open) return;
    _open = true;
    try {
      await widget.ads.showPrivacyOptions();
    } finally {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _required,
    builder: (context, required) => required.data ?? false
        ? ListTile(
            key: const Key('ad_privacy'),
            onTap: _show,
            title: Text(widget.label, style: const TextStyle(color: _cream)),
            trailing: const Icon(Icons.chevron_right, color: _gold),
          )
        : const SizedBox.shrink(),
  );
}
