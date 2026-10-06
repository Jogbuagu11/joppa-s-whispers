// Keeps a signed-in player's game in step with their cloud save.
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/data/cloud_save_store.dart';
import 'package:whispers_of_joppa/data/sync_base_repository.dart';
import 'package:whispers_of_joppa/domain/cloud_sync.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/services/auth_service.dart';

final _log = Logger('CloudSync');

/// What a sync did.
enum SyncResult { signedOut, upToDate, uploaded, downloaded, keptLocal, failed }

/// The outcome of [CloudSync.sync]. [cloudSave] is set when the phone's game
/// must be replaced by the cloud's ([SyncResult.downloaded]).
class SyncOutcome {
  final SyncResult result;
  final SaveState? cloudSave;

  const SyncOutcome(this.result, [this.cloudSave]);
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

  /// Compares [local] with the cloud and uploads, downloads or asks.
  Future<SyncOutcome> sync(
    SaveState local, {
    required ChooseSave choose,
  }) async {
    final user = auth.user.value;
    if (user == null) return const SyncOutcome(SyncResult.signedOut);
    try {
      final cloud = await store.fetch(user.id);
      final base = await bases.load(user.id);
      final fingerprint = saveFingerprint(local);
      final action = decideSync(
        hasCloud: cloud != null,
        localFresh: isFreshGame(local),
        hasBase: base != null,
        localChanged: base != null && base.localFingerprint != fingerprint,
        cloudChanged:
            base != null &&
            cloud != null &&
            !cloud.updatedAt.isAtSameMomentAs(base.cloudUpdatedAt),
      );
      _log.info('Sync decision: $action');

      if (cloud == null || action == SyncAction.upload) {
        return _upload(user.id, local, SyncResult.uploaded);
      }
      switch (action) {
        case SyncAction.nothing:
          return const SyncOutcome(SyncResult.upToDate);
        case SyncAction.download:
          return _adopt(user.id, cloud);
        case SyncAction.ask:
          final keepCloud = await choose(
            local: local,
            cloud: cloud.state,
            cloudIsFurtherOn: cloudIsFurtherOn(local, cloud.state),
          );
          if (keepCloud == null) return const SyncOutcome(SyncResult.keptLocal);
          return keepCloud
              ? _adopt(user.id, cloud)
              : _upload(user.id, local, SyncResult.keptLocal);
        case SyncAction.upload:
          return _upload(user.id, local, SyncResult.uploaded);
      }
    } on Exception catch (e, stack) {
      _log.warning('Cloud sync failed', e, stack);
      return const SyncOutcome(SyncResult.failed);
    }
  }

  /// Sends [local] to the cloud without comparing first. Used after ordinary
  /// local saves once the phone and cloud are known to be in step.
  Future<bool> push(SaveState local) async {
    final user = auth.user.value;
    if (user == null) return false;
    try {
      await _upload(user.id, local, SyncResult.uploaded);
      return true;
    } on Exception catch (e) {
      _log.warning('Cloud upload failed: $e');
      return false;
    }
  }

  Future<SyncOutcome> _upload(
    String userId,
    SaveState local,
    SyncResult result,
  ) async {
    final updatedAt = await store.upload(userId, local);
    await bases.save(
      SyncBase(
        userId: userId,
        cloudUpdatedAt: updatedAt,
        localFingerprint: saveFingerprint(local),
      ),
    );
    return SyncOutcome(result);
  }

  Future<SyncOutcome> _adopt(String userId, CloudSave cloud) async {
    await bases.save(
      SyncBase(
        userId: userId,
        cloudUpdatedAt: cloud.updatedAt,
        localFingerprint: saveFingerprint(cloud.state),
      ),
    );
    return SyncOutcome(SyncResult.downloaded, cloud.state);
  }
}
