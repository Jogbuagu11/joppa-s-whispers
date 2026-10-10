// The tutorial hint shown above the board.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/features/story/face_portrait.dart';
import 'package:whispers_of_joppa/domain/scenes.dart';
import 'package:whispers_of_joppa/domain/tutorial.dart';
import 'package:whispers_of_joppa/features/story/tutorial_controller.dart';

const _gold = Color(0xFFD4802A);
const _cream = Color(0xFFF3E6C8);
const _ink = Color(0xFF2A1F08);

class TutorialBanner extends StatelessWidget {
  const TutorialBanner({
    super.key,
    required this.controller,
    required this.characterNames,
    required this.availableAssets,
    this.looks = const {},
  });

  /// character_id -> their portrait framing, from content.
  final Map<String, CharacterLook> looks;

  final TutorialController controller;
  final Map<String, String> characterNames;
  final Set<String> availableAssets;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final step = controller.current;
        if (step == null) return const SizedBox.shrink();
        final portrait = portraitAssetFor(
          step.speaker,
          'neutral',
          availableAssets,
        );
        return Container(
          key: const Key('tutorial_banner'),
          margin: const EdgeInsets.fromLTRB(9, 6, 9, 2),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold, width: 2),
          ),
          child: Row(
            children: [
              if (portrait != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FacePortrait(
                    asset: portrait,
                    size: 54,
                    name: controller.current?.speaker ?? '',
                    ring: _gold,
                    zoom:
                        looks[controller.current?.speaker]?.zoom ??
                        defaultFaceZoom,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      characterNames[step.speaker] ?? step.speaker,
                      style: const TextStyle(
                        color: Color(0xFF8A4B2A),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      step.text,
                      key: const Key('tutorial_text'),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              // A step that waits for nothing but a tap gets a button.
              if (step.trigger == TutorialTrigger.tap)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: FilledButton(
                    key: const Key('tutorial_ok'),
                    onPressed: () => controller.handle(
                      const TutorialEvent(TutorialTrigger.tap),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 34),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(color: Colors.black, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
