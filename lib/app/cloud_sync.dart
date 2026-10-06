// Keeps a signed-in player's game in step with their cloud save.
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/data/cloud_save_store.dart';
import 'package:whispers_of_joppa/data/sync_base_repository.dart';
import 'package:whispers_of_joppa/domain/cloud_sync.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/services/auth_service.dart';

final _log = Logger('CloudSync');

/// What a sync did.
enum SyncResult {
  signedOut,
  upToDate,
  uploaded,

  /// The cloud game should replace this phone's: see [SyncOutcome.cloud].
  downloaded,

  /// The player was asked and chose this phone's game, which was uploaded.
  keptLocalUploaded,

  /// The player was asked and backed out; nothing changed.
  undecided,

  /// The account's save was made by a newer version of the app.
  needsNewerApp,

  /// One of the two games was played with newer game content than this phone
  /// is running. Restarting the app picks the newer content up.
  needsNewerContent,

  /// Another phone saved to the account while this one was deciding.
  changedMeanwhile,
  failed,
}

/// The outcome of [CloudSync.sync]. [cloud] is set for
/// [SyncResult.downloaded]: write it to the phone, then call
/// [CloudSync.confirmAdopted].
class SyncOutcome {
  final SyncResult result;
  final CloudSave? cloud;

  const SyncOutcome(this.result, [this.cloud]);
}

/// Asks the player which game to keep when both have moved on. Returns true
/// to keep the cloud game, false to keep this phone's, null if they backed
/// out (nothing is changed).
typedef ChooseSave =
    Future<bool?> Function({
      required SaveState local,
      required SaveState cloud,
      required bool cloudIsFurtherOn,
    });

class CloudSync {
  final AuthService auth;
  final CloudSaveStore store;
  final SyncBaseRepository bases;

  CloudSync({required this.auth, required this.store, required this.bases});

  /// Compares [local] with the cloud and uploads, hands back the cloud game
  /// to adopt, or asks the player.
  ///
  /// [contentVersion] is the game content this phone is running. A game made
  /// with newer content is never taken over or sent from here, because this
  /// phone would have to throw away the parts it does not know.
  Future<SyncOutcome> sync(
    SaveState local, {
    required ChooseSave choose,
    int contentVersion = 1 << 30,
  }) async {
    final user = auth.user.value;
    if (user == null) return const SyncOutcome(SyncResult.signedOut);
    try {
      final CloudSave? cloud;
      try {
        cloud = await store.fetch(user.id);
      } on FormatException catch (e) {
        // The save exists but this build cannot read it.
        _log.warning('Cloud save cannot be read by this version: $e');
        return const SyncOutcome(SyncResult.needsNewerApp);
      }
      if (local.contentVersion > contentVersion ||
          (cloud != null && cloud.state.contentVersion > contentVersion)) {
        return const SyncOutcome(SyncResult.needsNewerContent);
      }
      final base = await bases.load(user.id);
      final action = decideSync(
        hasCloud: cloud != null,
        localFresh: isFreshGame(local),
        cloudFresh: cloud != null && isFreshGame(cloud.state),
        hasBase: base != null,
        localChanged:
            base != null && base.localFingerprint != saveFingerprint(local),
        cloudChanged:
            base != null &&
            cloud != null &&
            !cloud.updatedAt.isAtSameMomentAs(base.cloudUpdatedAt),
      );
      _log.info('Sync decision: $action');

      if (cloud == null) return _upload(user.id, local, SyncResult.uploaded);
      switch (action) {
        case SyncAction.nothing:
          return const SyncOutcome(SyncResult.upToDate);
        case SyncAction.download:
          return SyncOutcome(SyncResult.downloaded, cloud);
        case SyncAction.upload:
          return _replaceCloud(user.id, local, cloud, SyncResult.uploaded);
        case SyncAction.ask:
          final keepCloud = await choose(
            local: local,
            cloud: cloud.state,
            cloudIsFurtherOn: cloudIsFurtherOn(local, cloud.state),
          );
          if (keepCloud == null) return const SyncOutcome(SyncResult.undecided);
          return keepCloud
              ? SyncOutcome(SyncResult.downloaded, cloud)
              : _replaceCloud(
                  user.id,
                  local,
                  cloud,
                  SyncResult.keptLocalUploaded,
                );
      }
    } on Exception catch (e, stack) {
      _log.warning('Cloud sync failed', e, stack);
      return const SyncOutcome(SyncResult.failed);
    }
  }

  /// Records that [cloud] is now the game on this phone. Call only after it
  /// has been written to the phone, so a failed write cannot leave the phone
  /// claiming to hold a game it does not.
  Future<void> confirmAdopted(CloudSave cloud) async {
    final user = auth.user.value;
    if (user == null) return;
    await bases.save(
      SyncBase(
        userId: user.id,
        cloudUpdatedAt: cloud.updatedAt,
        localFingerprint: saveFingerprint(cloud.state),
      ),
    );
  }

  /// Sends [local] to the cloud, but only if the cloud save is still the one
  /// this phone last synced with. Returns false, changing nothing, if another
  /// phone has saved since (a full [sync] is then needed), if this phone has
  /// never synced, or if the cloud cannot be reached.
  Future<bool> push(SaveState local) async {
    final user = auth.user.value;
    if (user == null) return false;
    try {
      final base = await bases.load(user.id);
      if (base == null) return false;
      final updatedAt = await store.uploadIfUnchanged(
        user.id,
        local,
        base.cloudUpdatedAt,
      );
      if (updatedAt == null) {
        _log.info('Cloud changed elsewhere; not uploading over it');
        return false;
      }
      await _remember(user.id, updatedAt, local);
      return true;
    } on Exception catch (e) {
      _log.warning('Cloud upload failed: $e');
      return false;
    }
  }

  /// Replaces the cloud game [seen] with [local], unless another phone has
  /// saved since [seen] was fetched (the player may have taken minutes to
  /// choose). In that case nothing is changed.
  Future<SyncOutcome> _replaceCloud(
    String userId,
    SaveState local,
    CloudSave seen,
    SyncResult result,
  ) async {
    final updatedAt = await store.uploadIfUnchanged(
      userId,
      local,
      seen.updatedAt,
    );
    if (updatedAt == null) {
      return const SyncOutcome(SyncResult.changedMeanwhile);
    }
    await _remember(userId, updatedAt, local);
    return SyncOutcome(result);
  }

  /// Forgets what this phone knows about its last sync (after an account is
  /// deleted).
  Future<void> forget() => bases.clear();

  Future<SyncOutcome> _upload(
    String userId,
    SaveState local,
    SyncResult result,
  ) async {
    await _remember(userId, await store.upload(userId, local), local);
    return SyncOutcome(result);
  }

  Future<void> _remember(String userId, DateTime updatedAt, SaveState local) =>
      bases.save(
        SyncBase(
          userId: userId,
          cloudUpdatedAt: updatedAt,
          localFingerprint: saveFingerprint(local),
        ),
      );
}
