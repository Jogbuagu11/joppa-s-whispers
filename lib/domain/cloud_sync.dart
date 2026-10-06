// Deciding what to do with a cloud save — pure Dart, fully unit tested.
import 'dart:convert';

import 'package:whispers_of_joppa/domain/save_state.dart';

/// How far a save has got: story tasks count most, then orders delivered.
int saveProgressScore(SaveState save) =>
    save.completedTasks.length * 1000 + save.completedOrders.length;

/// Whether [save] is a game nobody has played yet, so replacing it loses
/// nothing.
bool isFreshGame(SaveState save) =>
    save.completedTasks.isEmpty &&
    save.completedOrders.isEmpty &&
    save.talents == 0 &&
    save.blessings == 0;

/// A short text that changes whenever the player's progress changes. Manna
/// and its clock are left out: they tick by themselves and are not progress.
String saveFingerprint(SaveState save) {
  final json = save.toJson()
    ..remove('manna')
    ..remove('manna_last_regen');
  return jsonEncode(json);
}

/// What to do when a signed-in player's phone and the cloud are compared.
enum SyncAction {
  /// Both are the same; do nothing.
  nothing,

  /// Send this phone's game to the cloud.
  upload,

  /// Replace this phone's game with the cloud's.
  download,

  /// Both have moved on separately; the player must choose.
  ask,
}

/// The rule from TECH_SPEC section 4: keep whichever side has changed, and
/// ask the player only when both have.
///
/// - [hasCloud]: a cloud save exists for this account.
/// - [localFresh]: this phone's game has not been played ([isFreshGame]).
/// - [hasBase]: this phone has synced with this account before.
/// - [localChanged] / [cloudChanged]: that side changed since the last sync
///   (only meaningful when [hasBase] is true).
/// - [cloudFresh]: the cloud save is itself an unplayed game.
SyncAction decideSync({
  required bool hasCloud,
  required bool localFresh,
  required bool hasBase,
  required bool localChanged,
  required bool cloudChanged,
  bool cloudFresh = false,
}) {
  if (!hasCloud) return SyncAction.upload;
  // An unplayed game on this phone (a new phone, or a lost or reset save)
  // must never replace real progress in the cloud: the cloud rescues it.
  if (localFresh && !cloudFresh) return SyncAction.download;
  if (!hasBase) {
    // First time this phone meets this account.
    return localFresh ? SyncAction.download : SyncAction.ask;
  }
  if (localChanged && cloudChanged) return SyncAction.ask;
  if (cloudChanged) return SyncAction.download;
  if (localChanged) return SyncAction.upload;
  return SyncAction.nothing;
}

/// When the player has to choose, which side to suggest: the cloud only if
/// it is strictly further on.
bool cloudIsFurtherOn(SaveState local, SaveState cloud) =>
    saveProgressScore(cloud) > saveProgressScore(local);

/// What this phone remembers about its last sync with an account.
class SyncBase {
  final String userId;

  /// The cloud save's timestamp at the last sync.
  final DateTime cloudUpdatedAt;

  /// [saveFingerprint] of the local save at the last sync.
  final String localFingerprint;

  const SyncBase({
    required this.userId,
    required this.cloudUpdatedAt,
    required this.localFingerprint,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'cloud_updated_at': cloudUpdatedAt.toUtc().toIso8601String(),
    'local_fingerprint': localFingerprint,
  };

  /// Throws [FormatException] if the stored data is not a sync record.
  factory SyncBase.fromJson(Map<String, dynamic> json) {
    try {
      return SyncBase(
        userId: json['user_id'] as String,
        cloudUpdatedAt: DateTime.parse(json['cloud_updated_at'] as String),
        localFingerprint: json['local_fingerprint'] as String,
      );
    } on TypeError catch (e) {
      throw FormatException('Sync record is missing a field: $e');
    }
  }
}
