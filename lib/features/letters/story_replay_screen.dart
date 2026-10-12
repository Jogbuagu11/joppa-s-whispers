// The story so far: every scene the player has seen, to play again.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_app_bar.dart';
import 'package:whispers_of_joppa/domain/replay.dart';

const _cream = Color(0xFFF3E6C8);
const _ink = Color(0xFF1A1205);
const _brown = Color(0xFF8A4B2A);

class StoryReplayScreen extends StatelessWidget {
  const StoryReplayScreen({
    super.key,
    required this.scenes,
    required this.title,
    required this.intro,
    required this.onPlay,
  });

  final List<ReplayScene> scenes;
  final String title;

  /// Shown above the list (and alone, when nothing has been seen yet).
  final String intro;

  /// Plays the scene with this id.
  final void Function(String sceneId) onPlay;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('story_replay_screen'),
    backgroundColor: _ink,
    appBar: gameAppBar(Text(title)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              intro,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _cream, fontSize: 14),
            ),
          ),
          for (final (i, scene) in scenes.indexed) ...[
            if (i == 0 || scenes[i - 1].chapter != scene.chapter)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  scene.chapter,
                  style: const TextStyle(
                    color: Color(0xFFD4802A),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: _cream,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  key: Key('replay_${scene.sceneId}'),
                  dense: true,
                  leading: const Icon(Icons.play_circle, color: _brown),
                  title: Text(
                    scene.title,
                    style: const TextStyle(color: _ink, fontSize: 15),
                  ),
                  onTap: () => onPlay(scene.sceneId),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
