// Bringing older save files up to date. Pure Dart.
import 'package:whispers_of_joppa/domain/save_state.dart';

/// Brings an older save up to [currentSaveVersion], one step at a time.
/// Throws [FormatException] for a save with no version or from a newer build.
Map<String, dynamic> migrateSave(Map<String, dynamic> raw) {
  final version = raw['save_version'];
  if (version is! int || version < 1) {
    throw const FormatException('Save file has no valid save_version');
  }
  if (version > currentSaveVersion) {
    throw FormatException(
      'Save file is version $version, newer than this app ($currentSaveVersion)',
    );
  }
  final json = Map<String, dynamic>.of(raw);
  if (json['save_version'] == 1) {
    // Version 2 remembers which orders were delivered. Version 1 did not
    // record that, so it starts as none.
    json['completed_orders'] = <String>[];
    json['save_version'] = 2;
  }
  if (json['save_version'] == 2) {
    // Version 3 adds story-task progress, which starts empty.
    json['completed_tasks'] = <String>[];
    json['save_version'] = 3;
  }
  if (json['save_version'] == 3) {
    // Version 4 adds the tutorial. Anyone with an older save has already been
    // playing, so the tutorial counts as finished for them.
    json['tutorial_step'] = tutorialFinished;
    json['save_version'] = 4;
  }
  if (json['save_version'] == 4) {
    // Version 5 adds Pearls and the record of applied purchases.
    json['pearls'] = 0;
    json['applied_transactions'] = <String>[];
    json['owned_products'] = <String>[];
    json['save_version'] = 5;
  }
  if (json['save_version'] == 5) {
    // Version 6 adds the count of rewarded ads watched today.
    json['ad_day'] = '';
    json['ad_manna_watched'] = 0;
    json['save_version'] = 6;
  }
  if (json['save_version'] == 6) {
    // Player levels arrived: a game from before them starts at its present
    // level, with nothing owed for the levels already passed.
    json['level_rewarded'] = 0;
    json['save_version'] = 7;
  }
  // The next format change goes here, as another one-version step.
  return json;
}
