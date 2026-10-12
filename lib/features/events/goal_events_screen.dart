// The list of goal events that are on: for each, what to do, how far the
// player has come, the next reward and the time left.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_dialog.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/events.dart';
import 'package:whispers_of_joppa/domain/goal_events.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/features/events/goal_events_controller.dart';
import 'package:whispers_of_joppa/features/events/goal_race_card.dart';

const _cream = Color(0xFFF3E5C8);

/// A reward in the game's own words ("5 Pearls + Hourglass"). [text] is
/// the board's wording; [itemName] names an item.
String goalRewardWords(
  PassReward reward,
  Map<String, String> text,
  String Function(String itemId) itemName,
) {
  String say(String key, int n) => (text[key] ?? '').replaceAll('{n}', '$n');
  return [
    if (reward.pearls > 0) say('goal_pearls', reward.pearls),
    if (reward.manna > 0) say('goal_manna', reward.manna),
    if (reward.talents > 0) say('goal_talents', reward.talents),
    for (final id in reward.items) itemName(id),
  ].join(' + ');
}

Future<void> showGoalEvents(
  BuildContext context, {
  required GoalEventsController controller,
  required Map<String, String> text,
  required String Function(String itemId) itemName,
  DateTime Function()? clock,
}) => showDialog<void>(
  context: context,
  builder: (context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final live = controller.live;
      final now = (clock ?? DateTime.now)();
      return GameDialog(
        key: const Key('goal_events_popup'),
        icon: Icons.emoji_events,
        title: Text(
          text['goal_title'] ?? '',
          style: const TextStyle(color: GamePalette.gold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: live.isEmpty
              ? Text(
                  text['goal_none'] ?? '',
                  key: const Key('goal_none'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _cream),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final event in live)
                        _GoalCard(
                          event: event,
                          progress: controller.progressOf(event),
                          left: event.endsAt.difference(now),
                          now: now,
                          mine: event.kind == GoalKind.global
                              ? controller.globalOf(event).mine
                              : null,
                          text: text,
                          itemName: itemName,
                        ),
                    ],
                  ),
                ),
        ),
        actions: [
          FilledButton(
            key: const Key('goal_close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(text['goal_close'] ?? ''),
          ),
        ],
      );
    },
  ),
);

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.event,
    required this.progress,
    required this.left,
    required this.now,
    this.mine,
    required this.text,
    required this.itemName,
  });

  final GoalEvent event;
  final GoalProgress progress;
  final Duration left;
  final DateTime now;

  /// A global goal: this player's own part in the total.
  final int? mine;
  final Map<String, String> text;
  final String Function(String itemId) itemName;

  static const _icons = {
    GoalKind.milestone: Icons.paid,
    GoalKind.energy: Icons.bolt,
    GoalKind.collect: Icons.spa,
    GoalKind.order: Icons.local_shipping,
    GoalKind.race: Icons.sailing,
    GoalKind.global: Icons.groups,
  };

  @override
  Widget build(BuildContext context) {
    final next = nextGoal(event, progress);
    return Container(
      key: Key('goal_${event.id}'),
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(10),
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
              Icon(_icons[event.kind], color: GamePalette.talents, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.name,
                  style: const TextStyle(
                    color: GamePalette.talents,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                (text['goal_left'] ?? '').replaceAll(
                  '{time}',
                  formatTimeLeft(left.isNegative ? Duration.zero : left),
                ),
                style: const TextStyle(color: GamePalette.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            event.blurb,
            style: const TextStyle(color: _cream, fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (mine != null)
            Text(
              (text['goal_global_mine'] ?? '').replaceAll('{n}', '$mine'),
              key: Key('goal_mine_${event.id}'),
              style: const TextStyle(color: GamePalette.talents, fontSize: 12),
            ),
          if (event.kind == GoalKind.race)
            RaceStanding(
              event: event,
              progress: progress,
              now: now,
              text: text,
              rewardWords: (r) => goalRewardWords(r, text, itemName),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: goalFraction(event, progress).clamp(0, 1).toDouble(),
                minHeight: 10,
                backgroundColor: GamePalette.panel,
                color: GamePalette.ready,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              (text['goal_count'] ?? '')
                  .replaceAll('{points}', '${progress.points}')
                  .replaceAll('{token}', event.token),
              key: Key('goal_count_${event.id}'),
              style: const TextStyle(
                color: _cream,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              next == null
                  ? text['goal_done'] ?? ''
                  : (text['goal_next'] ?? '')
                        .replaceAll(
                          '{reward}',
                          goalRewardWords(next.reward, text, itemName),
                        )
                        .replaceAll('{points}', '${next.points}'),
              key: Key('goal_next_${event.id}'),
              style: const TextStyle(color: GamePalette.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
