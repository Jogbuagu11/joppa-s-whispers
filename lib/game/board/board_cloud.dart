// The board screen's link to the player's account: syncing on sign-in, at
// launch and on return to the app, and sending new saves to the cloud while
// they play.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/cloud_sync.dart';
import 'package:whispers_of_joppa/data/cloud_save_store.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';
import 'package:whispers_of_joppa/features/settings/save_choice_dialog.dart';
import 'package:whispers_of_joppa/services/auth_service.dart';

class BoardCloud {
  final AuthService auth;
  final CloudSync sync;

  /// The least time between automatic uploads while playing.
  final Duration uploadEvery;

  final DateTime Function() _now;

  // True once this phone and the cloud are known to hold the same game, so
  // ordinary saves may be sent on. Every send is still conditional: the cloud
  // refuses it if another phone has saved in the meantime.
  bool _inStep = false;
  DateTime? _lastUpload;
  String? _userId;

  BoardCloud({
    required this.auth,
    required this.sync,
    this.uploadEvery = const Duration(seconds: 20),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now {
    _userId = auth.user.value?.id;
    // A different (or no) account means nothing is known to be in step.
    auth.user.addListener(() {
      final id = auth.user.value?.id;
      if (id != _userId) {
        _userId = id;
        reset();
      }
    });
  }

  bool get signedIn => auth.user.value != null;

  /// True when automatic uploads are running.
  bool get inStep => _inStep;

  /// Compares [local] with the cloud. Returns what happened in words, and the
  /// cloud save if this phone's game must be replaced by it (write it to the
  /// phone, then call [confirmAdopted]).
  Future<({String message, CloudSave? adopt})> syncNow(
    BuildContext context,
    SaveState local,
  ) async {
    final outcome = await sync.sync(
      local,
      choose:
          ({
            required SaveState local,
            required SaveState cloud,
            required bool cloudIsFurtherOn,
          }) => context.mounted
          ? showSaveChoice(
              context,
              localTasks: local.completedTasks.length,
              localOrders: local.completedOrders.length,
              cloudTasks: cloud.completedTasks.length,
              cloudOrders: cloud.completedOrders.length,
              cloudIsFurtherOn: cloudIsFurtherOn,
            )
          : Future<bool?>.value(),
    );
    _inStep = switch (outcome.result) {
      SyncResult.upToDate ||
      SyncResult.uploaded ||
      SyncResult.keptLocalUploaded => true,
      // A download is in step only once the phone has really taken the game.
      SyncResult.downloaded ||
      SyncResult.undecided ||
      SyncResult.needsNewerApp ||
      SyncResult.failed ||
      SyncResult.signedOut => false,
    };
    if (_inStep) _lastUpload = _now();
    final message = switch (outcome.result) {
      SyncResult.signedOut => 'Sign in to save your game to your account.',
      SyncResult.upToDate => 'Your game is saved to your account.',
      SyncResult.uploaded => 'Your game has been saved to your account.',
      SyncResult.downloaded =>
        'Your saved game has been brought to this phone.',
      SyncResult.keptLocalUploaded =>
        'Kept the game on this phone and saved it to your account.',
      SyncResult.undecided =>
        'Nothing was changed. Your account still holds a different game.',
      SyncResult.needsNewerApp =>
        'Your account has a game from a newer version. Please update the app.',
      SyncResult.failed =>
        'Could not reach your account. Check your connection and try again.',
    };
    return (message: message, adopt: outcome.cloud);
  }

  /// Call once a downloaded game has been written to this phone.
  Future<void> confirmAdopted(CloudSave cloud) async {
    await sync.confirmAdopted(cloud);
    _inStep = true;
    _lastUpload = _now();
  }

  /// Called after each local save: sends it on if the player is signed in,
  /// the phone and cloud are in step, and enough time has passed (or [force]
  /// is set, as when the app is being put away).
  Future<void> afterLocalSave(SaveState state, {bool force = false}) async {
    if (!signedIn || !_inStep) return;
    final last = _lastUpload;
    if (!force && last != null && _now().difference(last) < uploadEvery) return;
    _lastUpload = _now();
    // A refused or failed send means the two may have drifted: stop sending
    // until a full sync has compared them again.
    if (!await sync.push(state)) _inStep = false;
  }

  /// Forgets the sync record on this phone (after the account is deleted).
  Future<void> forgetAccount() async {
    reset();
    await sync.forget();
  }

  /// The next sync must compare the two games again before anything is sent.
  void reset() {
    _inStep = false;
    _lastUpload = null;
  }
}
