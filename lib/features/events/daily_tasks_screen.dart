// Today's tasks: each with how far it has come and what it gives, the
// day's chest, and the week's.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_dialog.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/events.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/features/events/daily_tasks_controller.dart';

const _cream = Color(0xFFF3E5C8);

Future<void> showDailyTasks(
  BuildContext context, {
  required DailyTasksController controller,
  required Map<String, String> text,
  required String Function(PassReward reward) rewardWords,
}) => showDialog<void>(
  context: context,
  builder: (context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final state = controller.state;
      final tasks = controller.today;
      final config = controller.config;
      String say(String key, Map<String, Object> places) {
        var words = text[key] ?? '';
        for (final e in places.entries) {
          words = words.replaceAll('{${e.key}}', '${e.value}');
        }
        return words;
      }

      return GameDialog(
        key: const Key('daily_tasks_popup'),
        icon: Icons.checklist,
        title: Text(
          text['title'] ?? '',
          style: const TextStyle(color: GamePalette.gold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  say('new_in', {'time': formatTimeLeft(controller.untilNew)}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: GamePalette.muted,
                    fontSize: 12,
                  ),
                ),
                for (final task in tasks)
                  _TaskRow(
                    id: task.id,
                    words: task.text,
                    done: state.counts[task.id] ?? 0,
                    target: task.target,
                    finished: state.paid.contains(task.id),
                    progress: say('progress', {
                      'done': state.counts[task.id] ?? 0,
                      'target': task.target,
                    }),
                    reward: state.paid.contains(task.id)
                        ? text['done'] ?? ''
                        : say('reward', {'reward': rewardWords(task.reward)}),
                  ),
                const SizedBox(height: 6),
                Text(
                  state.chest
                      ? text['chest_done'] ?? ''
                      : say('chest', {
                          'n': tasks.length,
                          'reward': rewardWords(config.chest),
                        }),
                  key: const Key('daily_chest'),
                  style: const TextStyle(
                    color: GamePalette.talents,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.weekPaid
                      ? text['weekly_done'] ?? ''
                      : say('weekly', {
                          'done': state.daysDone,
                          'days': config.weeklyDays,
                          'reward': rewardWords(config.weekly),
                        }),
                  key: const Key('daily_weekly'),
                  style: const TextStyle(color: _cream, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            key: const Key('daily_close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(text['close'] ?? ''),
          ),
        ],
      );
    },
  ),
);

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.id,
    required this.words,
    required this.done,
    required this.target,
    required this.finished,
    required this.progress,
    required this.reward,
  });

  final String id;
  final String words;
  final int done;
  final int target;
  final bool finished;
  final String progress;
  final String reward;

  @override
  Widget build(BuildContext context) => Container(
    key: Key('daily_$id'),
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: GamePalette.panelLight,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: GamePalette.panelEdge),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              finished ? Icons.check_circle : Icons.radio_button_unchecked,
              color: finished ? GamePalette.ready : GamePalette.muted,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                words,
                style: const TextStyle(
                  color: _cream,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              progress,
              key: Key('daily_count_$id'),
              style: const TextStyle(color: GamePalette.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (done / target).clamp(0, 1).toDouble(),
            minHeight: 8,
            backgroundColor: GamePalette.panel,
            color: GamePalette.ready,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          reward,
          style: const TextStyle(color: GamePalette.muted, fontSize: 12),
        ),
      ],
    ),
  );
}
