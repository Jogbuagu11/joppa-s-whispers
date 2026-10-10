// The Manna (energy) bar shown above the board, and the out-of-Manna popup.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/features/ads/ad_rewards_controller.dart';
import 'package:whispers_of_joppa/game/board/manna_controller.dart';

const _gold = Color(0xFFD4802A);

class MannaBar extends StatelessWidget {
  const MannaBar({super.key, required this.controller, this.width});

  /// A fixed width, or null to fill the space it is given.
  final double? width;

  final MannaController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final seconds = controller.secondsUntilNext;
        final full = (controller.manna / controller.maxManna).clamp(0.0, 1.0);
        return Semantics(
          label: 'Manna',
          child: Container(
            width: width,
            height: 36,
            padding: const EdgeInsets.only(left: 3, right: 7),
            decoration: BoxDecoration(
              color: GamePalette.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GamePalette.panelEdge),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: GamePalette.manna,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bolt,
                    color: GamePalette.backgroundBottom,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The count, with the wait for the next one beside
                      // it; both shrink before anything spills.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${controller.manna}/${controller.maxManna}',
                              key: const Key('manna_count'),
                              maxLines: 1,
                              style: _labelStyle,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              seconds == null
                                  ? 'Full'
                                  : '+1 in ${formatCountdown(seconds)}',
                              key: const Key('manna_timer'),
                              maxLines: 1,
                              style: const TextStyle(
                                color: GamePalette.muted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 5,
                          child: Stack(
                            children: [
                              const ColoredBox(
                                color: Color(0xFF4A3716),
                                child: SizedBox.expand(),
                              ),
                              FractionallySizedBox(
                                widthFactor: full,
                                child: const ColoredBox(
                                  color: GamePalette.manna,
                                  child: SizedBox.expand(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

const _labelStyle = TextStyle(
  color: Color(0xFFF3E6C8),
  fontSize: 13,
  fontWeight: FontWeight.bold,
);

/// Tells the player they are out of Manna and when more arrives. If a
/// rewarded ad is ready and allowed, offers it as a choice; it is never
/// required and never shown unless the player taps it.
Future<void> showOutOfMannaPopup(
  BuildContext context,
  MannaController controller, {
  AdRewardsController? ads,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('out_of_manna_popup'),
      backgroundColor: const Color(0xFF2A1F08),
      title: const Text('Out of Manna', style: TextStyle(color: _gold)),
      content: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final seconds = controller.secondsUntilNext;
          return Text(
            controller.manna > 0 || seconds == null
                ? 'Your Manna is back. Tap OK to keep playing.'
                : 'Manna returns with time. '
                      'Next Manna in ${formatCountdown(seconds)}.',
            style: const TextStyle(color: Colors.white),
          );
        },
      ),
      actionsOverflowAlignment: OverflowBarAlignment.end,
      actions: [
        if (ads != null)
          ListenableBuilder(
            listenable: ads,
            builder: (context, _) => ads.mannaAdOffered
                ? TextButton(
                    key: const Key('out_of_manna_watch_ad'),
                    onPressed: ads.watchForManna,
                    child: Text(
                      'Watch an ad for +${ads.mannaReward} Manna '
                      '(${ads.mannaAdsLeft} left today)',
                      style: const TextStyle(color: _gold),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        TextButton(
          key: const Key('out_of_manna_ok'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK', style: TextStyle(color: _gold)),
        ),
      ],
    ),
  );
}
