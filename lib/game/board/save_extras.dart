// Small records that later features keep in the save file, by name: each
// feature (the Blessing Wheel, Jars of Clay…) reads and writes its own.
import 'package:flutter/foundation.dart';

class SaveExtras extends ChangeNotifier {
  final Map<String, dynamic> _records;

  SaveExtras([Map<String, dynamic> saved = const {}])
    : _records = Map<String, dynamic>.of(saved);

  /// Everything, as it is written to the save file.
  Map<String, dynamic> get all => Map<String, dynamic>.unmodifiable(_records);

  /// The record called [name], or null if there is none (or it is not a
  /// record).
  Map<String, dynamic>? read(String name) => switch (_records[name]) {
    final Map<String, dynamic> record => record,
    _ => null,
  };

  /// Replaces the record called [name]; the game is then saved.
  void write(String name, Map<String, dynamic> record) {
    _records[name] = record;
    notifyListeners();
  }
}
