// How a race stands: the player and the townsfolk, leader first, the
// prizes, and the place once the player is home.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/goal_events.dart';
import 'package:whispers_of_joppa/domain/race.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';

const _cream = Color(0xFFF3E5C8);

class RaceStanding extends StatelessWidget {
  const RaceStanding({
    super.key,
    required this.event,
    required this.progress,
    required this.now,
    required this.text,
    required this.rewardWords,
  });

  final GoalEvent event;
  final GoalProgress progress;
  final DateTime now;
  final Map<String, String> text;
  final String Function(PassReward reward) rewardWords;

  @override
  Widget build(BuildContext context) {
    final joined = progress.joinedAt;
    final since = joined == null ? null : now.difference(joined);
    final goal = event.raceGoal;
    final mine = progress.points > goal ? goal : progress.points;
    final runners = <({String name, int count, bool me})>[
      (name: text['goal_race_you'] ?? '', count: mine, me: true),
      for (final RaceRival rival in event.rivals)
        (name: rival.name, count: rivalCount(rival, goal, since), me: false),
    ]..sort((a, b) => b.count.compareTo(a.count));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text['goal_race_rivals'] ?? '',
          style: const TextStyle(color: GamePalette.muted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        for (final runner in runners)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    runner.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: runner.me ? GamePalette.talents : _cream,
                      fontSize: 13,
                      fontWeight: runner.me ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: goal == 0 ? 0 : runner.count / goal,
                      minHeight: 8,
                      backgroundColor: GamePalette.panel,
                      color: runner.me ? GamePalette.ready : GamePalette.muted,
                    ),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${runner.count}/$goal',
                    key: runner.me ? Key('goal_count_${event.id}') : null,
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: _cream, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(
          progress.place > 0
              ? (text['goal_race_place'] ?? '').replaceAll(
                  '{place}',
                  '${progress.place}',
                )
              : joined == null
              ? text['goal_race_start'] ?? ''
              : (text['goal_race_prizes'] ?? '')
                    .replaceAll('{first}', rewardWords(event.prizes[0]))
                    .replaceAll('{second}', rewardWords(event.prizes[1]))
                    .replaceAll('{third}', rewardWords(event.prizes[2])),
          key: Key('goal_next_${event.id}'),
          style: const TextStyle(color: GamePalette.muted, fontSize: 12),
        ),
      ],
    );
  }
}
