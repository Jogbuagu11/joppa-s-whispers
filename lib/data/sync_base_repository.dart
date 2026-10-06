// Remembers, on this phone, the last time it synced with an account.
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whispers_of_joppa/domain/cloud_sync.dart';

final _log = Logger('SyncBase');

class SyncBaseRepository {
  final Future<Directory> Function() _directory;

  SyncBaseRepository({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  Future<File> _file() async =>
      File('${(await _directory()).path}/cloud_sync.json');

  /// The last sync with [userId], or null if this phone has never synced with
  /// that account (or the record cannot be read).
  Future<SyncBase?> load(String userId) async {
    final file = await _file();
    if (!file.existsSync()) return null;
    try {
      final base = SyncBase.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
      return base.userId == userId ? base : null;
    } on Object catch (e) {
      // An unreadable record only means the next sync is treated as a first
      // sync, which asks the player rather than guessing.
      _log.warning('Sync record could not be read: $e');
      return null;
    }
  }

  Future<void> save(SyncBase base) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(base.toJson()), flush: true);
  }

  Future<void> clear() async {
    final file = await _file();
    if (file.existsSync()) await file.delete();
  }
}
