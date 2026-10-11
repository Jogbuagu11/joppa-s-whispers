// The top of the event screen: points, time left, the next reward, and the
// way into the season pass.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/events.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';
import 'package:whispers_of_joppa/features/events/event_controller.dart';

const _cream = Color(0xFFF3E5C8);

class EventHeader extends StatelessWidget {
  const EventHeader(
    this.controller, {
    super.key,
    this.passLabel,
    this.onOpenPass,
  });

  final EventController controller;

  /// The season pass button's words; null for an event with no pass.
  final String? passLabel;
  final VoidCallback? onOpenPass;

  @override
  Widget build(BuildContext context) {
    final next = controller.next;
    final passLabel = this.passLabel;
    final reward = next == null
        ? null
        : [
            if (next.manna > 0) '${next.manna} Manna',
            if (next.talents > 0) '${next.talents} Talents',
          ].join(' + ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${controller.points} points',
                key: const Key('event_points'),
                style: const TextStyle(
                  color: GamePalette.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${formatTimeLeft(controller.timeLeft)} left',
                key: const Key('event_time_left'),
                style: const TextStyle(color: _cream, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            next == null
                ? 'Every reward earned. Well done!'
                : 'Next reward at ${next.points}: $reward',
            key: const Key('event_next'),
            style: const TextStyle(color: _cream, fontSize: 13),
          ),
          if (passLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton.icon(
                key: const Key('event_pass_button'),
                onPressed: onOpenPass,
                icon: Icon(
                  controller.tier() == PassTier.free
                      ? Icons.workspace_premium_outlined
                      : Icons.workspace_premium,
                  size: 18,
                ),
                label: Text(passLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GamePalette.talents,
                  side: const BorderSide(color: GamePalette.panelEdge),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
