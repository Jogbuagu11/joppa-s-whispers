// Remembers, on this phone, the player's sound, vibration and tier-number
// choices.
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whispers_of_joppa/domain/comfort.dart';

final _log = Logger('ComfortPrefs');

class ComfortPrefsRepository {
  final Future<Directory> Function() _directory;

  ComfortPrefsRepository({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  Future<File> _file() async =>
      File('${(await _directory()).path}/comfort.json');

  /// The saved choices, or the usual ones if there are none or they cannot
  /// be read.
  Future<ComfortPrefs> load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return const ComfortPrefs();
      return ComfortPrefs.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } on Object catch (e) {
      _log.warning('Comfort choices could not be read: $e');
      return const ComfortPrefs();
    }
  }

  Future<void> save(ComfortPrefs prefs) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(prefs.toJson()), flush: true);
    } on Object catch (e) {
      _log.warning('Comfort choices could not be saved: $e');
    }
  }
}
