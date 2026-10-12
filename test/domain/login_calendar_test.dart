// The daily login calendar: one square a day, nothing lost for a missed
// day, and round again after the last.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/calendar_validator.dart';
import 'package:whispers_of_joppa/data/content_bundle.dart';
import 'package:whispers_of_joppa/domain/login_calendar.dart';

void main() {
  // Safe: the list is not empty.
  final calendar = LoginCalendar.fromJson({
    'days': [
      {'talents': 10, 'verse': 'A', 'ref': 'a'},
      {'manna': 5, 'verse': 'B', 'ref': 'b'},
      {'pearls': 2, 'verse': 'C', 'ref': 'c'},
    ],
  })!;
  final start = DateTime(2026, 10, 12, 8);

  test('no calendar in older content', () {
    expect(LoginCalendar.fromJson(null), isNull);
    expect(LoginCalendar.fromJson({'days': <Object>[]}), isNull);
  });

  test('one square a day, in order; a missed day loses nothing', () {
    var state = const CalendarState();
    expect(calendarToday(calendar, state, start), 0);
    final first = calendarTake(calendar, state, start);
    expect(first?.day.reward.talents, 10);
    state = first?.state ?? state;
    // The same day again: nothing, and today is still the first square.
    final later = start.add(const Duration(hours: 10));
    expect(calendarTake(calendar, state, later), isNull);
    expect(calendarCanTake(state, later), isFalse);
    expect(calendarToday(calendar, state, later), 0);
    // Three days on: the second square, not the fourth.
    final back = start.add(const Duration(days: 3));
    expect(calendarToday(calendar, state, back), 1);
    final second = calendarTake(calendar, state, back);
    expect(second?.day.reward.manna, 5);
    expect(second?.state.taken, 2);
  });

  test('after the last square it begins again', () {
    var state = const CalendarState();
    final got = <String>[];
    for (int i = 0; i < 5; i++) {
      final now = start.add(Duration(days: i));
      got.add(calendar.days[calendarToday(calendar, state, now)].verse);
      final taken = calendarTake(calendar, state, now);
      state = taken?.state ?? state;
    }
    expect(got, ['A', 'B', 'C', 'A', 'B']);
    expect(state.taken, 2);
  });

  test('a clock put back gives nothing', () {
    final state = calendarTake(calendar, const CalendarState(), start)?.state;
    expect(state, isNotNull);
    final before = start.subtract(const Duration(days: 2));
    expect(
      calendarTake(calendar, state ?? const CalendarState(), before),
      isNull,
    );
  });

  test('the game\'s own calendar is sound, and mistakes are named', () {
    Object? read(String name) =>
        jsonDecode(File('content/$name.json').readAsStringSync());
    final ids = itemIdsOf(read('chains'));
    final real = read('calendar') as Map<String, dynamic>;
    expect(calendarProblems(real, itemIds: ids), isEmpty);
    expect(LoginCalendar.fromJson(real)?.days.length, 28);
    final days = [...real['days'] as List<dynamic>];
    days[0] = {'verse': 'A word', 'ref': 'Somewhere 1:1 (NIV)'};
    final problems = calendarProblems({
      'days': days,
      'text': {'day': 'Day'},
    }, itemIds: ids).join('\n');
    expect(problems, contains('day 1: it gives nothing'));
    expect(problems, contains('(KJV) or (WEB)'));
    expect(problems, contains('text "day" must contain'));
    expect(calendarProblems({'days': <Object>[]}, itemIds: ids), isNotEmpty);
  });

  test('the saved place is read carefully', () {
    expect(CalendarState.fromJson('x').taken, 0);
    expect(CalendarState.fromJson({'taken': -2, 'last_day': 'x'}).lastDay, 0);
    const state = CalendarState(taken: 4, lastDay: 20000);
    expect(CalendarState.fromJson(state.toJson()).toJson(), state.toJson());
  });
}
