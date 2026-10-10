// Remembers, on this phone, that the first-launch welcome (Terms and
// Privacy Policy) has been agreed to.
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

final _log = Logger('WelcomeStore');

/// Remembers, on this phone, that the welcome has been agreed to.
class WelcomeStore {
  final Future<Directory> Function() _directory;

  WelcomeStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  Future<File> _file() async =>
      File('${(await _directory()).path}/welcome.json');

  Future<bool> agreed() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return false;
      // A tiny file, read in one go.
      final json = jsonDecode(file.readAsStringSync());
      return json is Map<String, dynamic> && json['agreed'] == true;
    } on Object catch (e) {
      _log.warning('The welcome record could not be read: $e');
      return false;
    }
  }

  Future<void> agree(DateTime when) async {
    try {
      final file = await _file();
      file.writeAsStringSync(
        jsonEncode({'agreed': true, 'at': when.toUtc().toIso8601String()}),
        flush: true,
      );
    } on Object catch (e) {
      // It is simply asked again next time.
      _log.warning('The welcome record could not be saved: $e');
    }
  }
}
