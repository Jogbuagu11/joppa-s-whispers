// What the board screen does: loading the game, story tasks, and the
// player's account. The screens opened from the board are in
// board_screen_routes.dart; the layout is in board_screen.dart.
part of 'board_screen.dart';

mixin _BoardScreenActions
    on _BoardRoutes, _BoardNotifications, _BoardEvents, _BoardItems {
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    _init();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _quiet?.call();
    _events?.detach();
    widget.shop?.detach();
    // Saves any unsaved change, then stops the timers.
    _session?.dispose();
    super.dispose();
  }

  Future<void> _showOutOfManna() async {
    final manna = _session?.manna;
    if (manna == null || _popupOpen || !mounted) return;
    _popupOpen = true;
    widget.comfort?.cue(GameCue.empty);
    _events?.outOfEnergy();
    await showOutOfMannaPopup(context, manna, ads: _session?.ads);
    _popupOpen = false;
  }

  /// Pays for the next story task, then plays its scene. While this (or any
  /// other screen opened from the task bar) is running, [_busy] is set and
  /// further taps are ignored, so one tap can never pay for two tasks or
  /// stack two screens.
  Future<void> _doNextTask() async {
    final session = _session;
    if (session == null || _busy) return;
    _busy = true;
    try {
      // The task's own chapter, read before doing it: finishing a chapter's
      // last task moves the story on to the next chapter.
      final chapter = session.story.chapter;
      final locationId = chapter?.locationId;
      final task = session.story.doNext();
      if (task == null) return;
      final scene = session.scenes[task.sceneId];
      if (scene == null || scene.lines.isEmpty) {
        _log.warning('Task ${task.id} has no scene to play (${task.sceneId})');
      } else if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SceneScreen(
              scene: scene,
              characterNames: session.characterNames,
              availableAssets: session.assetPaths,
            ),
          ),
        );
      }
      // A task that restores part of the location shows the change.
      final area = task.restoresArea;
      if (area != null) await _showLocation(locationId, justRestored: area);
      // The chapter's last task ends with its closing message.
      await _showPendingEnding();
      await _showLevelUp();
      await _maybeAskAboutNotifications();
    } finally {
      _busy = false;
    }
    _startAdsWhenQuiet();
  }

  /// Lets ads begin loading (which may first show a consent message), but
  /// only at a quiet moment: the tutorial over and nothing open over the
  /// board. Called when the game opens, when the player returns, and after
  /// each story task.
  void _startAdsWhenQuiet() {
    if (!mounted || _busy || _popupOpen || _eventOpen) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _session?.ads.startWhenAllowed();
  }

  /// Shows the closing message of a finished chapter, once.
  Future<void> _showPendingEnding() async {
    final session = _session;
    final ending = session?.pendingEnding;
    if (session == null || ending == null || !mounted) return;
    session.endings.markSeen(ending.chapterId);
    await showChapterEnding(context, ending);
  }

  /// The account button: sign in, sync, sign out, delete account.
  Future<void> _openAccount() async {
    final cloud = widget.cloud;
    if (cloud == null || _busy || !mounted) return;
    _busy = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AccountScreen(
            auth: cloud.auth,
            syncNow: _syncWithAccount,
            onDeleted: cloud.forgetAccount,
            onTestCrash: widget.analytics?.testCrash,
          ),
        ),
      );
    } finally {
      _busy = false;
    }
    // The player may have just signed in (perhaps on a new phone): bring
    // over anything their account has bought.
    unawaited(widget.shop?.resume());
  }

  /// Compares this phone's game with the account's. If the account's game
  /// wins, it replaces this one and the board reloads. Returns a short line
  /// saying what happened. Only one comparison runs at a time.
  Future<String> _syncWithAccount() async {
    final cloud = widget.cloud;
    final session = _session;
    if (cloud == null || session == null || _syncing || !mounted) return '';
    _syncing = true;
    try {
      final before = saveFingerprint(session.snapshot());
      final result = await cloud.syncNow(
        context,
        session.snapshot(),
        contentVersion: session.contentBundle.version,
      );
      final adopt = result.adopt;
      if (adopt == null || !mounted) return result.message;
      // Never swap the game out from under an open event board.
      if (_eventOpen) return result.message;
      // If the player kept playing while the account was being checked, do
      // not throw those moves away: compare again next time instead.
      if (saveFingerprint(session.snapshot()) != before) {
        return 'Your game changed while checking. Tap Sync now to try again.';
      }
      final replaced = await _replaceGame(session, adopt);
      return replaced
          ? result.message
          : 'Your saved game could not be brought to this phone. '
                'Nothing was changed.';
    } finally {
      _syncing = false;
    }
  }

  /// Swaps the running game for [cloud] (a game brought from the account).
  /// Returns false, leaving the old game on the phone, if it cannot be
  /// written.
  Future<bool> _replaceGame(BoardSession old, CloudSave cloud) async {
    final repository = widget.saveRepository ?? SaveRepository();
    setState(() => _session = null);
    // Stop the old session saving over the new game, then write the new one.
    old.saver.onSaved = null;
    _quiet?.call();
    _events?.detach();
    widget.shop?.detach();
    await old.discard();
    var replaced = true;
    try {
      await repository.save(cloud.state);
      // Only now does this phone really hold the account's game.
      await widget.cloud?.confirmAdopted(cloud);
    } on Exception catch (e, stack) {
      _log.severe('Could not write the game from the account', e, stack);
      replaced = false;
    }
    // Reload from the phone: the new game, or the old one if writing failed.
    if (mounted) await _init(resuming: true);
    return replaced;
  }

  /// Leaving the app sends the latest save on at once; coming back checks the
  /// account again, in case the game moved on from another phone meanwhile.
  void _onLifecycle(AppLifecycleState state) {
    _notificationsOnLifecycle(state);
    final cloud = widget.cloud;
    final session = _session;
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadEvent());
      _events?.sessionStarted();
      unawaited(widget.shop?.resume());
      _startAdsWhenQuiet();
    } else if (state == AppLifecycleState.paused) {
      _events?.sessionEnded();
    }
    if (cloud == null || session == null || !cloud.signedIn) return;
    if (state == AppLifecycleState.paused) {
      unawaited(cloud.afterLocalSave(session.snapshot(), force: true));
    } else if (state == AppLifecycleState.resumed &&
        !_busy &&
        !_popupOpen &&
        // Nothing (a scene, a popup, the ending) is open over the board.
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      cloud.reset();
      unawaited(_syncWithAccount());
    }
  }

  /// Loads the game. [resuming] is true when reloading after a cloud save
  /// replaced the game: no opening scene and no second account check.
  Future<void> _init({bool resuming = false}) async {
    try {
      final session = await BoardSession.create(
        saveRepository: widget.saveRepository ?? SaveRepository(),
        onOutOfManna: _showOutOfManna,
        startingMannaOverride: widget.startingMannaOverride,
        playTutorial: widget.playTutorial,
        content: widget.content,
      );
      if (!mounted) {
        await session.dispose();
        return;
      }
      final analytics = widget.analytics;
      if (analytics != null) {
        (_events ??= GameAnalytics(analytics)).attach(session);
      }
      _attachShop(session);
      _attachComfort(session);
      session.game.onUsableItemTapped = _askToUse;
      session.ads.service = widget.ads;
      widget.cloud?.blockUploads = session.downgraded;
      session.saver.onSaved = (state) => widget.cloud?.afterLocalSave(state);
      unawaited(_loadEvent());
      // Look for newer content in the background; it is used from next launch.
      unawaited(widget.content?.checkForUpdate(session.contentBundle));
      setState(() => _session = session);
      // Back in the game: saved choices are read, old reminders cleared.
      unawaited(
        widget.notifications?.load().then(
          (_) => widget.notifications?.onReturning(),
        ),
      );
      if (resuming) {
        // The account's game may arrive with a level reached but unpaid.
        await _showLevelUp();
        return;
      }
      final opening = session.openingScene;
      if (opening != null &&
          opening.lines.isNotEmpty &&
          widget.playOpeningScene) {
        await Navigator.of(context).push(
          // No slide-in: the story is the first thing a new player sees, not
          // a glimpse of the board followed by the story.
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => SceneScreen(
              scene: opening,
              characterNames: session.characterNames,
              availableAssets: session.assetPaths,
            ),
          ),
        );
      }
      // A chapter finished earlier whose closing message was never seen.
      await _showPendingEnding();
      // A level reached just before the game was closed.
      await _showLevelUp();
      // A signed-in player's game is checked against their account.
      if (widget.cloud?.signedIn ?? false) await _syncWithAccount();
      _startAdsWhenQuiet();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }
}
