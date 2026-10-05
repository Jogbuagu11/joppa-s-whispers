// Reads and writes the local save file (save.json in the app documents folder).
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';

final _log = Logger('SaveRepository');

class SaveRepository {
  /// Where the save lives. Tests pass a temporary folder.
  final Future<Directory> Function() _directory;

  SaveRepository({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  Future<File> _file(String name) async =>
      File('${(await _directory()).path}/$name');

  /// Returns the saved game, or null if there is none or it cannot be read.
  /// An unreadable save is kept aside as save.corrupt.json, never deleted.
  Future<SaveState?> load() async {
    final file = await _file('save.json');
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(await file.readAsString());
      return SaveState.fromJson(json as Map<String, dynamic>);
    } on Object catch (e, stack) {
      _log.severe('Save file could not be read; starting fresh', e, stack);
      try {
        await file.copy((await _file('save.corrupt.json')).path);
      } on FileSystemException catch (copyError) {
        _log.warning('Could not keep a copy of the bad save: $copyError');
      }
      return null;
    }
  }

  /// Writes the save. It is written to a temporary file first and then
  /// swapped in, so a crash mid-write cannot damage the existing save.
  Future<void> save(SaveState state) async {
    final file = await _file('save.json');
    final temp = await _file('save.json.tmp');
    await temp.writeAsString(jsonEncode(state.toJson()), flush: true);
    await temp.rename(file.path);
  }

  /// Removes the save (used by tests and by "start over").
  Future<void> clear() async {
    final file = await _file('save.json');
    if (file.existsSync()) await file.delete();
  }
}
