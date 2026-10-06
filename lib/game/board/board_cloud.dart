// The board screen's link to the player's account: syncing on sign-in and at
// launch, and sending new saves to the cloud while they play.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/cloud_sync.dart';
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
  // ordinary saves may be uploaded without comparing first.
  bool _inStep = false;
  DateTime? _lastUpload;

  BoardCloud({
    required this.auth,
    required this.sync,
    this.uploadEvery = const Duration(seconds: 20),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  bool get signedIn => auth.user.value != null;

  /// Compares [local] with the cloud. Returns what happened in words, and the
  /// cloud save if this phone's game must be replaced by it.
  Future<({String message, SaveState? adopt})> syncNow(
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
      SyncResult.downloaded => true,
      // Kept this phone's game: in step only if it was uploaded, which the
      // next sync will show. Stay cautious until then.
      SyncResult.keptLocal ||
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
      SyncResult.keptLocal => 'Kept the game on this phone.',
      SyncResult.failed =>
        'Could not reach your account. Check your connection and try again.',
    };
    return (message: message, adopt: outcome.cloudSave);
  }

  /// Called after each local save: uploads it if the player is signed in, the
  /// phone and cloud are in step, and enough time has passed.
  Future<void> afterLocalSave(SaveState state) async {
    if (!signedIn || !_inStep) return;
    final last = _lastUpload;
    if (last != null && _now().difference(last) < uploadEvery) return;
    _lastUpload = _now();
    if (!await sync.push(state)) _inStep = false;
  }

  /// Signing out or switching account means the next sync must compare again.
  void reset() {
    _inStep = false;
    _lastUpload = null;
  }
}
