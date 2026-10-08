// The board screen's part in notifications: the one-time question, the
// settings screen, and scheduling reminders as the player leaves.
part of 'board_screen.dart';

mixin _BoardNotifications on _BoardRoutes {
  /// Notification wording and timing from the content being played, or null
  /// if that content has none.
  NotificationContent? get _notificationContent {
    final json = _session?.contentBundle.files['notifications'];
    try {
      return json is Map<String, dynamic>
          ? NotificationContent.fromJson(json)
          : null;
    } on TypeError catch (e) {
      _log.warning('Notification content could not be read: $e');
      return null;
    }
  }

  /// After a story task: asks, once, whether the player wants notifications.
  /// The phone's own prompt only follows a yes.
  Future<void> _maybeAskAboutNotifications() async {
    final notifications = widget.notifications;
    final session = _session;
    final content = _notificationContent;
    if (notifications == null || session == null || content == null) return;
    if (!mounted ||
        !notifications.shouldAsk(content, session.story.completedTasks)) {
      return;
    }
    final yes = await showNotificationExplainer(context, content);
    // Closed without answering (the back button): ask again another time.
    if (yes != null) await notifications.answer(yes: yes);
  }

  /// The settings button: sound, vibration and notification switches.
  Future<void> _openNotificationSettings() async {
    final notifications = widget.notifications;
    final content = _notificationContent;
    if (notifications == null || content == null || _busy || !mounted) return;
    _busy = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationSettingsScreen(
            controller: notifications,
            content: content,
            comfort: widget.comfort,
            ads: widget.ads,
            onOpenPage: widget.onOpenPage,
          ),
        ),
      );
    } finally {
      _busy = false;
    }
  }

  /// Leaving the app schedules the reminders; coming back clears them.
  void _notificationsOnLifecycle(AppLifecycleState state) {
    final notifications = widget.notifications;
    final session = _session;
    if (notifications == null || session == null) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(notifications.onReturning());
    } else if (state == AppLifecycleState.paused) {
      final content = _notificationContent;
      if (content == null) return;
      unawaited(
        notifications.onLeaving(
          content: content,
          config: session.manna.config,
          manna: MannaState(
            manna: session.manna.manna,
            lastRegen: session.manna.lastRegen,
          ),
        ),
      );
    }
  }
}
