// Remembers, on this phone, the player's notification choices.
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whispers_of_joppa/domain/reminders.dart';

final _log = Logger('NotificationPrefs');

class NotificationPrefsRepository {
  final Future<Directory> Function() _directory;

  NotificationPrefsRepository({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  Future<File> _file() async =>
      File('${(await _directory()).path}/notifications.json');

  /// The saved choices, or "never asked" if there are none or they cannot
  /// be read.
  Future<NotificationPrefs> load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return const NotificationPrefs();
      return NotificationPrefs.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } on Object catch (e) {
      _log.warning('Notification choices could not be read: $e');
      return const NotificationPrefs();
    }
  }

  Future<void> save(NotificationPrefs prefs) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(prefs.toJson()), flush: true);
    } on Object catch (e) {
      _log.warning('Notification choices could not be saved: $e');
    }
  }
}
