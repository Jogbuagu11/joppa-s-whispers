// The story card: the chapter being played, its next task, and the button
// that spends Blessings to do it. It shows the very thing the task will
// restore, and sits at the left of the swipeable row above the board.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/features/story/story_controller.dart';

const _cream = Color(0xFFF7ECD2);
const _shade = Color(0xD91C1408);

class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.controller,
    required this.onDo,
    this.picture,
  });

  final StoryController controller;

  /// Called when the player taps the button for the next task.
  final VoidCallback onDo;

  /// A picture of what the next task restores (or of the place), if the
  /// art is there.
  final String? picture;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final chapter = controller.chapter;
        if (chapter == null) return const SizedBox.shrink();
        final task = controller.next;
        final ready = controller.canDoNext;
        final total = chapter.tasks.length;
        final picture = this.picture;
        return Container(
          key: const Key('task_bar'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: GamePalette.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ready ? GamePalette.talents : GamePalette.panelEdge,
              width: ready ? 2.5 : 1.5,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (picture != null)
                Image.asset(
                  picture,
                  fit: BoxFit.cover,
                  // The card is small; never decode the full-size picture.
                  cacheWidth: 400,
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // A ribbon across the top: the chapter and how far along.
                  ColoredBox(
                    color: _shade,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_stories,
                            color: GamePalette.talents,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          // The chapter name may be cut short on a narrow
                          // phone; the count never is.
                          Expanded(
                            child: Text(
                              'Chapter ${chapter.number} · ${chapter.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _ribbonStyle,
                            ),
                          ),
                          Text(
                            ' ${controller.doneInChapter}/$total',
                            key: const Key('task_progress'),
                            style: _ribbonStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // How far through the chapter, as a thin gold line.
                  SizedBox(
                    height: 3,
                    child: Stack(
                      children: [
                        const ColoredBox(
                          color: Color(0xFF4A3716),
                          child: SizedBox.expand(),
                        ),
                        FractionallySizedBox(
                          widthFactor: total == 0
                              ? 0
                              : (controller.doneInChapter / total).clamp(0, 1),
                          child: const ColoredBox(
                            color: GamePalette.talents,
                            child: SizedBox.expand(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // The picture shows through here.
                  const Spacer(),
                  ColoredBox(
                    color: _shade,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            task?.title ?? 'Chapter complete',
                            key: const Key('task_title'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _cream,
                              fontSize: 12,
                              height: 1.15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (task != null) ...[
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 26,
                              child: FilledButton(
                                key: const Key('task_button'),
                                onPressed: ready ? onDo : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: GamePalette.talents,
                                  disabledBackgroundColor: const Color(
                                    0xFF4A3716,
                                  ),
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
                                      color: ready
                                          ? GamePalette.backgroundBottom
                                          : GamePalette.muted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

const _ribbonStyle = TextStyle(
  color: _cream,
  fontSize: 9.5,
  fontWeight: FontWeight.bold,
);
