// The dialogue screen: a background, the speaker's portrait, and a speech
// bubble. Tap anywhere to move to the next line.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/domain/scenes.dart';

const _gold = Color(0xFFD4802A);
const _cream = Color(0xFFF3E6C8);
const _ink = Color(0xFF2A1F08);

class SceneScreen extends StatefulWidget {
  const SceneScreen({
    super.key,
    required this.scene,
    required this.characterNames,
    required this.availableAssets,
  });

  final SceneModel scene;

  /// character_id -> display name.
  final Map<String, String> characterNames;

  /// Every bundled asset path, used to pick a portrait that exists.
  final Set<String> availableAssets;

  @override
  State<SceneScreen> createState() => _SceneScreenState();
}

class _SceneScreenState extends State<SceneScreen> {
  late ScenePosition _position = ScenePosition(widget.scene);

  bool _closing = false;

  /// Leaves the scene once only, however many taps arrive in the same moment.
  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  void _advance() {
    final next = _position.next();
    if (next == null) {
      _close();
    } else {
      setState(() => _position = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final line = _position.line;
    final speaker = line?.speaker ?? '';
    final portrait = line == null
        ? null
        : portraitAssetFor(speaker, line.expression, widget.availableAssets);
    final background = backgroundAssetFor(
      widget.scene.background,
      widget.availableAssets,
    );

    return Scaffold(
      key: const Key('scene_screen'),
      backgroundColor: _ink,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advance,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Location art when it exists; a warm dusk wash until then.
            if (background != null)
              Image.asset(background, fit: BoxFit.cover)
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF3B2A4A), Color(0xFF8A4B2A), _ink],
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton(
                      key: const Key('scene_skip'),
                      onPressed: _close,
                      child: const Text(
                        'Skip',
                        style: TextStyle(color: _cream),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: portrait == null
                            ? const SizedBox.shrink(key: ValueKey('none'))
                            : _Portrait(
                                key: ValueKey(portrait),
                                asset: portrait,
                              ),
                      ),
                    ),
                  ),
                  _SpeechBubble(
                    name: widget.characterNames[speaker] ?? speaker,
                    text: line?.text ?? '',
                    isLast: _position.isLastLine,
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

class _Portrait extends StatelessWidget {
  const _Portrait({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _gold, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          asset,
          key: const Key('scene_portrait'),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    required this.name,
    required this.text,
    required this.isLast,
  });

  final String name;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      constraints: const BoxConstraints(minHeight: 130),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            key: const Key('scene_speaker'),
            style: const TextStyle(
              color: Color(0xFF8A4B2A),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            key: const Key('scene_text'),
            style: const TextStyle(color: _ink, fontSize: 17, height: 1.3),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              isLast ? 'Tap to finish' : 'Tap to continue',
              style: const TextStyle(color: Color(0xFF8A7A5A), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
