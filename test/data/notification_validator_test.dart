import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/data/notification_validator.dart';
import 'package:whispers_of_joppa/domain/reminders.dart';

Map<String, dynamic> _real() =>
    jsonDecode(File('content/notifications.json').readAsStringSync())
        as Map<String, dynamic>;

List<String> _check(Map<String, dynamic> json) {
  final problems = <String>[];
  checkNotifications(json, taskIds: {'ch1_t_05'}, problems: problems);
  return problems;
}

void main() {
  test('the real file is valid and loads', () {
    expect(_check(_real()), isEmpty);
    final content = NotificationContent.fromJson(_real());
    expect(content.askAfterTask, 'ch1_t_05');
    expect(content.quietStartHour, 21);
    expect(content.quietEndHour, 9);
    expect(content.settingsText['blocked'], isNotEmpty);
  });

  test('an unknown task is reported', () {
    final json = _real()..['ask_after_task'] = 'nope';
    expect(_check(json).single, contains('not a story task'));
  });

  test('a bad hour is reported', () {
    final json = _real()..['quiet_start_hour'] = 24;
    expect(_check(json).single, contains('quiet_start_hour'));
  });

  test('missing and over-long text is reported', () {
    final json = _real();
    (json['explainer'] as Map<String, dynamic>)['title'] = 'x' * 41;
    (json['settings'] as Map<String, dynamic>).remove('blocked');
    final problems = _check(json);
    expect(problems, hasLength(2));
    expect(problems.first, contains('41 characters'));
    expect(problems.last, contains('settings.blocked is missing'));
  });

  test('a missing section and bad numbers are reported', () {
    final json = _real()..remove('come_back');
    (json['manna_full'] as Map<String, dynamic>)['low_percent'] = 0;
    final problems = _check(json);
    expect(problems.any((p) => p.contains('"come_back" is missing')), isTrue);
    expect(problems.any((p) => p.contains('low_percent')), isTrue);
  });
}
