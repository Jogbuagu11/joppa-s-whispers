// The story card: the chapter being played, its next task, and the button
// that spends Blessings to do it. It sits at the left end of the swipeable
// row above the board.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/features/story/story_controller.dart';

const _cream = Color(0xFFF3E6C8);

class StoryCard extends StatelessWidget {
  const StoryCard({super.key, required this.controller, required this.onDo});

  final StoryController controller;

  /// Called when the player taps the button for the next task.
  final VoidCallback onDo;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final chapter = controller.chapter;
        if (chapter == null) return const SizedBox.shrink();
        final task = controller.next;
        final ready = controller.canDoNext;
        return Container(
          key: const Key('task_bar'),
          padding: const EdgeInsets.fromLTRB(7, 6, 7, 5),
          decoration: BoxDecoration(
            color: GamePalette.panel.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ready ? GamePalette.gold : GamePalette.panelEdge,
              width: ready ? 2.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_stories,
                    color: GamePalette.level,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  // The chapter name may be cut short on a narrow phone;
                  // the count never is.
                  Expanded(
                    child: Text(
                      'Chapter ${chapter.number} · ${chapter.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _smallStyle,
                    ),
                  ),
                  Text(
                    ' ${controller.doneInChapter}/${chapter.tasks.length}',
                    key: const Key('task_progress'),
                    style: _smallStyle,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    task?.title ?? 'Chapter complete',
                    key: const Key('task_title'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _cream,
                      fontSize: 13,
                      height: 1.15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (task != null)
                SizedBox(
                  height: 26,
                  child: FilledButton(
                    key: const Key('task_button'),
                    onPressed: ready ? onDo : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: GamePalette.gold,
                      disabledBackgroundColor: const Color(0xFF3A2A10),
                      padding: EdgeInsets.zero,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${task.costBlessings} ✦  Go',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: ready ? Colors.black : GamePalette.muted,
                        ),
                      ),
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

const _smallStyle = TextStyle(color: GamePalette.muted, fontSize: 9.5);
