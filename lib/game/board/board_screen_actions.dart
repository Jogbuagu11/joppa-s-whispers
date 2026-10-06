// What the board screen does: loading the game, story tasks, and the screens
// opened from the board (location, letters, account). The layout itself is in
// board_screen.dart.
part of 'board_screen.dart';

mixin _BoardScreenActions on State<BoardScreen> {
  BoardSession? _session;
  bool _popupOpen = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    // Saves any unsaved change, then stops the timers.
    _session?.dispose();
    super.dispose();
  }

  Future<void> _showOutOfManna() async {
    final manna = _session?.manna;
    if (manna == null || _popupOpen || !mounted) return;
    _popupOpen = true;
    await showOutOfMannaPopup(context, manna);
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
    } finally {
      _busy = false;
    }
  }

  /// Shows the closing message of a finished chapter, once.
  Future<void> _showPendingEnding() async {
    final session = _session;
    final ending = session?.pendingEnding;
    if (session == null || ending == null || !mounted) return;
    session.markEndingSeen(ending.chapterId);
    await showChapterEnding(context, ending);
  }

  /// The location button: shows the current chapter's location.
  Future<void> _openLocation() async {
    if (_busy) return;
    _busy = true;
    try {
      await _showLocation(_session?.story.chapter?.locationId);
    } finally {
      _busy = false;
    }
  }

  /// The account button: sign in, sync, sign out, delete account.
  Future<void> _openAccount() async {
    final cloud = widget.cloud;
    if (cloud == null || _busy || !mounted) return;
    _busy = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AccountScreen(auth: cloud.auth, syncNow: _syncWithAccount),
        ),
      );
      if (!cloud.signedIn) cloud.reset();
    } finally {
      _busy = false;
    }
  }

  /// Compares this phone's game with the account's. If the account's game
  /// wins, it replaces this one and the board reloads. Returns a short line
  /// saying what happened.
  Future<String> _syncWithAccount() async {
    final cloud = widget.cloud;
    final session = _session;
    if (cloud == null || session == null || !mounted) return '';
    final result = await cloud.syncNow(context, session.snapshot());
    final adopt = result.adopt;
    if (adopt != null && mounted) await _replaceGame(session, adopt);
    return result.message;
  }

  /// Swaps the running game for [save] (a game brought from the account).
  Future<void> _replaceGame(BoardSession old, SaveState save) async {
    setState(() => _session = null);
    // Stop the old session saving over the new game, then write the new one.
    old.saver.onSaved = null;
    await old.discard();
    await (widget.saveRepository ?? SaveRepository()).save(save);
    if (mounted) await _init(resuming: true);
  }

  /// The letters button: opens the keepsake book.
  Future<void> _openLetters() async {
    final session = _session;
    if (session == null || _busy || !mounted) return;
    _busy = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LettersScreen(
            letters: session.letters,
            foundLetterIds: session.story.foundLetterIds,
          ),
        ),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _showLocation(String? locationId, {String? justRestored}) async {
    final session = _session;
    final location = session?.locations[locationId];
    if (session == null || location == null) {
      _log.warning('No location to show for "$locationId"');
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocationScreen(
          location: location,
          restoredAreaIds: session.story.restoredAreaIds,
          availableAssets: session.assetPaths,
          justRestoredAreaId: justRestored,
        ),
      ),
    );
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
      );
      if (!mounted) {
        await session.dispose();
        return;
      }
      session.saver.onSaved = (state) => widget.cloud?.afterLocalSave(state);
      setState(() => _session = session);
      if (resuming) return;
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
      // A signed-in player's game is checked against their account.
      if (widget.cloud?.signedIn ?? false) await _syncWithAccount();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }
}
