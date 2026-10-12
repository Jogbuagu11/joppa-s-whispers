// The board screen's part in the things of each day: daily tasks and the
// login calendar.
part of 'board_screen.dart';

/// The board screen's part in daily tasks: counting what the player does
/// and the button that shows today's.
mixin _BoardDaily on _BoardEvents {
  DailyTasksController? _daily;

  Map<String, String> _dailyText(BoardSession session) => {
    if (session.contentBundle.files['daily_tasks'] case {
      'text': final Map<String, dynamic> text,
    })
      for (final e in text.entries)
        if (e.value case final String words) e.key: words,
  };

  /// Starts daily tasks for [session], which must be the game in play.
  void _wireDaily(BoardSession session) {
    _daily?.dispose();
    final config = DailyTasksConfig.fromJson(
      session.contentBundle.files['daily_tasks'],
    );
    final unlock = session.levels.config.unlock('daily_tasks');
    if (config == null || unlock == null) return _daily = null;
    final daily = _daily = DailyTasksController(
      config: config,
      extras: session.extras,
      open: () =>
          session.tutorial.isOver &&
          !session.downgraded &&
          session.levels.level >= unlock.level,
      grant: (reward) => _giveReward(session, reward),
    );
    final onDelivered = session.orders.onDelivered;
    session.orders.onDelivered = (id) {
      onDelivered?.call(id);
      daily.orderDelivered(session.orders.talentsFor(id));
    };
    final onMerge = session.game.onMerge;
    session.game.onMerge = () {
      onMerge?.call();
      daily.merged();
    };
    final onSpent = session.manna.onSpent;
    session.manna.onSpent = (amount) {
      onSpent?.call(amount);
      daily.mannaSpent(amount);
    };
    daily.justPaid.addListener(() {
      if (!mounted || !identical(session, _session)) return;
      final text = _dailyText(session);
      const keys = {
        DailyPrize.task: 'toast_task',
        DailyPrize.chest: 'toast_chest',
        DailyPrize.weekly: 'toast_weekly',
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            key: const Key('daily_toast'),
            duration: const Duration(seconds: 3),
            backgroundColor: GamePalette.panel,
            content: Text(
              [
                for (final paid in daily.justPaid.value)
                  (text[keys[paid.prize]] ?? '').replaceAll(
                    '{reward}',
                    _rewardWords(session, paid.reward),
                  ),
              ].join('\n'),
              style: const TextStyle(color: GamePalette.talents),
            ),
          ),
        );
    });
  }

  String _rewardWords(BoardSession session, PassReward reward) =>
      goalRewardWords(reward, _boardText, (id) => _itemName(session, id));

  void _giveReward(BoardSession session, PassReward reward) {
    if (reward.manna > 0) session.manna.add(reward.manna);
    if (reward.talents > 0) session.orders.addTalents(reward.talents);
    if (reward.pearls > 0) session.purchases.earnPearls(reward.pearls);
    if (reward.items.isNotEmpty) session.grants.give(itemIds: reward.items);
  }

  /// Whether [feature] (of the things of each day) is open to this player.
  bool _dayFeatureOpen(BoardSession session, String feature) {
    final unlock = session.levels.config.unlock(feature);
    return unlock != null &&
        session.tutorial.isOver &&
        !session.downgraded &&
        session.levels.level >= unlock.level;
  }

  Map<String, String> _calendarText(BoardSession session) => {
    if (session.contentBundle.files['calendar'] case {
      'text': final Map<String, dynamic> text,
    })
      for (final e in text.entries)
        if (e.value case final String words) e.key: words,
  };

  /// The login calendar's round button (gold while today's gift waits).
  Widget? _calendarButton(BoardSession session) {
    final calendar = LoginCalendar.fromJson(
      session.contentBundle.files['calendar'],
    );
    if (calendar == null || !_dayFeatureOpen(session, 'login_calendar')) {
      return null;
    }
    CalendarState place() =>
        CalendarState.fromJson(session.extras.read(calendarRecord));
    return StripButton(
      buttonKey: const Key('calendar_button'),
      icon: Icons.calendar_month,
      tooltip: _calendarText(session)['button'] ?? '',
      lit: calendarCanTake(place(), DateTime.now()),
      onTap: () async {
        if (_busy || _syncing || _popupOpen || !mounted) return;
        _popupOpen = true;
        try {
          await showLoginCalendar(
            context,
            calendar: calendar,
            state: place,
            changes: session.extras,
            text: _calendarText(session),
            rewardWords: (reward) => _rewardWords(session, reward),
            take: () {
              final taken = calendarTake(calendar, place(), DateTime.now());
              if (taken == null || !identical(session, _session)) return false;
              // Recorded as taken before anything is handed over.
              session.extras.write(calendarRecord, taken.state.toJson());
              _giveReward(session, taken.day.reward);
              return true;
            },
          );
        } finally {
          _popupOpen = false;
        }
      },
    );
  }

  /// The round buttons of the things of each day.
  List<Widget> _dailyButtons(BoardSession session) => [
    ?_calendarButton(session),
    ?_dailyButton(session),
  ];

  /// The daily tasks' round button, once they are open to this player.
  Widget? _dailyButton(BoardSession session) {
    final daily = _daily;
    if (daily == null || !daily.open()) return null;
    return StripButton(
      buttonKey: const Key('daily_tasks_button'),
      icon: Icons.checklist,
      tooltip: _dailyText(session)['button'] ?? '',
      onTap: () async {
        if (_busy || _syncing || _popupOpen || !mounted) return;
        _popupOpen = true;
        try {
          await showDailyTasks(
            context,
            controller: daily,
            text: _dailyText(session),
            rewardWords: (reward) => _rewardWords(session, reward),
          );
        } finally {
          _popupOpen = false;
        }
      },
      lit: !daily.state.chest,
    );
  }
}
