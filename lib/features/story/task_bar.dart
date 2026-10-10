// The strip above the orders that shows the next story task and its cost.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/features/story/story_controller.dart';

const _cream = Color(0xFFF3E6C8);

class TaskBar extends StatelessWidget {
  const TaskBar({
    super.key,
    required this.controller,
    required this.onDo,
    required this.onOpenLocation,
    required this.onOpenLetters,
  });

  /// Called when the player taps the button that opens Esther's letters.
  final VoidCallback onOpenLetters;

  /// Called when the player taps the button that shows the location.
  final VoidCallback onOpenLocation;

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
        return Container(
          key: const Key('task_bar'),
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          padding: const EdgeInsets.fromLTRB(4, 3, 6, 3),
          decoration: BoxDecoration(
            color: GamePalette.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: controller.canDoNext
                  ? GamePalette.gold
                  : GamePalette.panelEdge,
              width: controller.canDoNext ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              _BarIcon(
                buttonKey: const Key('location_button'),
                icon: Icons.home_work,
                color: GamePalette.level,
                tooltip: 'See what you have restored',
                onTap: onOpenLocation,
              ),
              _BarIcon(
                buttonKey: const Key('letters_button'),
                icon: Icons.mail,
                color: GamePalette.level,
                tooltip: "Esther's letters",
                onTap: onOpenLetters,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // The chapter name may be cut short on a narrow
                        // phone; the count never is.
                        Flexible(
                          child: Text(
                            'Chapter ${chapter.number} · ${chapter.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _smallStyle,
                          ),
                        ),
                        Text(
                          '  ${controller.doneInChapter}/${chapter.tasks.length}',
                          key: const Key('task_progress'),
                          style: _smallStyle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task?.title ?? 'Chapter complete',
                      key: const Key('task_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _cream,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (task != null)
                SizedBox(
                  height: 32,
                  child: FilledButton(
                    key: const Key('task_button'),
                    onPressed: controller.canDoNext ? onDo : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: GamePalette.gold,
                      disabledBackgroundColor: const Color(0xFF3A2A10),
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                    ),
                    child: Text(
                      '${task.costBlessings} ✦  Go',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: controller.canDoNext
                            ? Colors.black
                            : GamePalette.muted,
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

const _smallStyle = TextStyle(color: GamePalette.muted, fontSize: 10);

/// A compact icon button for the task bar (40 wide so two fit on small phones).
class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.buttonKey,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        key: buttonKey,
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.8)),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
          ),
        ),
      ),
    );
  }
}
