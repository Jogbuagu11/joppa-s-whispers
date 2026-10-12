// The daily login calendar (EXPANSION section 25): 28 days, a reward and a
// short verse for each, one a day by the player's own calendar. A missed
// day loses nothing: the next visit takes the next square. After the 28th
// it begins again. Pure Dart, fully unit tested.
import 'package:whispers_of_joppa/domain/daily_tasks.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';

class CalendarDay {
  final PassReward reward;
  final String verse;

  /// Where the verse is from ("Proverbs 15:1 (KJV)").
  final String ref;

  const CalendarDay({
    required this.reward,
    required this.verse,
    required this.ref,
  });
}

/// content/calendar.json. (Check it with calendarProblems first.)
class LoginCalendar {
  final List<CalendarDay> days;

  const LoginCalendar(this.days);

  /// Null if there is no calendar (older content).
  static LoginCalendar? fromJson(Object? json) {
    if (json case {'days': final List<dynamic> days} when days.isNotEmpty) {
      return LoginCalendar([
        for (final day in days)
          CalendarDay(
            reward: PassReward.fromJson(day),
            verse: switch (day) {
              {'verse': final String verse} => verse,
              _ => '',
            },
            ref: switch (day) {
              {'ref': final String ref} => ref,
              _ => '',
            },
          ),
      ]);
    }
    return null;
  }
}

/// A player's place in the calendar, as kept in the save file.
class CalendarState {
  /// How many squares have been taken this time round.
  final int taken;

  /// The day (see dayNumber) the last square was taken; 0 for never.
  final int lastDay;

  const CalendarState({this.taken = 0, this.lastDay = 0});

  factory CalendarState.fromJson(Object? json) {
    int count(String key) =>
        switch (json is Map<String, dynamic> ? json[key] : null) {
          final int n when n > 0 => n,
          _ => 0,
        };
    return CalendarState(taken: count('taken'), lastDay: count('last_day'));
  }

  Map<String, dynamic> toJson() => {'taken': taken, 'last_day': lastDay};
}

/// Whether today's square is still to be taken. (A clock put back gives
/// nothing: only a day after the last one counts.)
bool calendarCanTake(CalendarState state, DateTime now) =>
    dayNumber(now) > state.lastDay;

/// The square that is today's: the next to take, or (once today's is
/// taken) the one just taken. Counted from 0.
int calendarToday(LoginCalendar calendar, CalendarState state, DateTime now) {
  final length = calendar.days.length;
  if (calendarCanTake(state, now)) return state.taken % length;
  return (state.taken - 1).clamp(0, length - 1);
}

/// Takes today's square: the state after, and its reward. Null if today's
/// has been taken already.
({CalendarState state, CalendarDay day})? calendarTake(
  LoginCalendar calendar,
  CalendarState state,
  DateTime now,
) {
  if (!calendarCanTake(state, now)) return null;
  final length = calendar.days.length;
  // A full calendar begins again.
  final taken = state.taken >= length ? 0 : state.taken;
  return (
    state: CalendarState(taken: taken + 1, lastDay: dayNumber(now)),
    day: calendar.days[taken],
  );
}
