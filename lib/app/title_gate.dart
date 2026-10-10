// What a player sees before the game: the title screen while things load,
// and, the first time only, a welcome that points to the Terms and the
// Privacy Policy. The game itself is built only once both are past.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';

final _log = Logger('TitleGate');

const _cream = Color(0xFFF7ECD2);
const _titlePicture = 'assets/ui/title.jpg';

/// Remembers, on this phone, that the welcome has been agreed to.
class WelcomeStore {
  final Future<Directory> Function() _directory;

  WelcomeStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  Future<File> _file() async =>
      File('${(await _directory()).path}/welcome.json');

  Future<bool> agreed() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return false;
      // A tiny file, read in one go.
      final json = jsonDecode(file.readAsStringSync());
      return json is Map<String, dynamic> && json['agreed'] == true;
    } on Object catch (e) {
      _log.warning('The welcome record could not be read: $e');
      return false;
    }
  }

  Future<void> agree(DateTime when) async {
    try {
      final file = await _file();
      file.writeAsStringSync(
        jsonEncode({'agreed': true, 'at': when.toUtc().toIso8601String()}),
        flush: true,
      );
    } on Object catch (e) {
      // It is simply asked again next time.
      _log.warning('The welcome record could not be saved: $e');
    }
  }
}

class TitleGate extends StatefulWidget {
  const TitleGate({
    super.key,
    required this.child,
    required this.store,
    required this.onOpenPage,
    this.hold = const Duration(milliseconds: 1800),
    this.loadText,
  });

  /// The game, built once the gate is passed.
  final Widget child;
  final WelcomeStore store;

  /// Opens one of the game's web pages ("privacy", "terms").
  final void Function(String page) onOpenPage;

  /// How long the title is shown at the least.
  final Duration hold;

  /// Reads the wording (content/board_text.json); tests pass their own.
  final Future<Map<String, String>> Function()? loadText;

  @override
  State<TitleGate> createState() => _TitleGateState();
}

enum _Stage { title, welcome, game }

class _TitleGateState extends State<TitleGate> {
  _Stage _stage = _Stage.title;
  Map<String, String> _text = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<Map<String, String>> _bundledText() async {
    final json = jsonDecode(
      await rootBundle.loadString('content/board_text.json'),
    );
    return {
      if (json is Map<String, dynamic>)
        for (final e in json.entries)
          if (e.value case final String words) e.key: words,
    };
  }

  Future<void> _open() async {
    var agreed = false;
    try {
      final results = await Future.wait<Object>([
        (widget.loadText ?? _bundledText)(),
        widget.store.agreed(),
        Future<Object>.delayed(widget.hold, () => true),
      ]);
      _text = results[0] as Map<String, String>;
      agreed = results[1] as bool;
    } on Object catch (e) {
      _log.warning('The title screen could not get ready: $e');
    }
    if (!mounted) return;
    setState(() => _stage = agreed ? _Stage.game : _Stage.welcome);
  }

  Future<void> _agree() async {
    await widget.store.agree(DateTime.now());
    if (mounted) setState(() => _stage = _Stage.game);
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == _Stage.game) return widget.child;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: const Key('title_screen'),
        backgroundColor: GamePalette.backgroundBottom,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _titlePicture,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const _Title(),
                  const Spacer(flex: 9),
                  if (_stage == _Stage.title)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 36),
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          color: GamePalette.talents,
                          strokeWidth: 3,
                        ),
                      ),
                    )
                  else
                    _Welcome(
                      text: _text,
                      onOpenPage: widget.onOpenPage,
                      onAgree: _agree,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The game's name, in its own lettering.
class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) => const FittedBox(
    fit: BoxFit.scaleDown,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            'Whispers',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: _cream,
              fontSize: 58,
              height: 1,
              fontFamily: 'Georgia',
              fontFamilyFallback: ['serif'],
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              shadows: [Shadow(blurRadius: 14, color: Color(0xCC000000))],
            ),
          ),
          Text(
            'of Joppa',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: GamePalette.talents,
              fontSize: 34,
              height: 1.25,
              fontFamily: 'Georgia',
              fontFamilyFallback: ['serif'],
              fontStyle: FontStyle.italic,
              shadows: [Shadow(blurRadius: 12, color: Color(0xCC000000))],
            ),
          ),
        ],
      ),
    ),
  );
}

/// The first-launch welcome: the Terms and Privacy Policy, and Play.
class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.text,
    required this.onOpenPage,
    required this.onAgree,
  });

  final Map<String, String> text;
  final void Function(String page) onOpenPage;
  final VoidCallback onAgree;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('welcome'),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    decoration: BoxDecoration(
      color: const Color(0xF22A1F0C),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: GamePalette.panelEdge),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text['welcome_title'] ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: GamePalette.talents,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text['welcome_body'] ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _cream, fontSize: 13, height: 1.3),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (final page in const ['terms', 'privacy'])
              TextButton(
                key: Key('welcome_$page'),
                onPressed: () => onOpenPage(page),
                child: Text(
                  text['welcome_$page'] ?? '',
                  style: const TextStyle(
                    color: GamePalette.talents,
                    decoration: TextDecoration.underline,
                    decorationColor: GamePalette.talents,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton(
            key: const Key('welcome_play'),
            onPressed: onAgree,
            style: FilledButton.styleFrom(backgroundColor: GamePalette.talents),
            child: Text(
              text['welcome_play'] ?? '',
              style: const TextStyle(
                color: GamePalette.backgroundBottom,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
