// The strip above the orders that shows the next story task and its cost.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/features/story/story_controller.dart';

const _gold = Color(0xFFD4802A);
const _cream = Color(0xFFF3E6C8);

class TaskBar extends StatelessWidget {
  const TaskBar({
    super.key,
    required this.controller,
    required this.onDo,
    required this.onOpenLocation,
  });

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
          margin: const EdgeInsets.fromLTRB(9, 0, 9, 6),
          padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
          decoration: BoxDecoration(
            color: const Color(0xFF2A1F08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: controller.canDoNext ? _gold : const Color(0xFF5C3D0D),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                key: const Key('location_button'),
                onPressed: onOpenLocation,
                tooltip: 'See what you have restored',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(Icons.home_work_outlined, color: _gold),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chapter ${chapter.number} · ${chapter.title}   '
                      '${controller.doneInChapter}/${chapter.tasks.length}',
                      key: const Key('task_progress'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFBFA77A),
                        fontSize: 10,
                      ),
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
                      backgroundColor: _gold,
                      disabledBackgroundColor: const Color(0xFF3A2A10),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      '${task.costBlessings} ✦  Go',
                      style: TextStyle(
                        fontSize: 12,
                        color: controller.canDoNext ? Colors.black : _cream,
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
