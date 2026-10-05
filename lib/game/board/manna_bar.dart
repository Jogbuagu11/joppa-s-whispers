// The Manna (energy) bar shown above the board, and the out-of-Manna popup.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/domain/economy.dart';
import 'package:whispers_of_joppa/game/board/manna_controller.dart';

const _gold = Color(0xFFD4802A);
const _dark = Color(0xFF1A1205);

class MannaBar extends StatelessWidget {
  const MannaBar({super.key, required this.controller});

  final MannaController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final seconds = controller.secondsUntilNext;
        return Container(
          width: 170,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _dark.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Manna', style: _labelStyle),
                  Text(
                    '${controller.manna}/${controller.maxManna}',
                    key: const Key('manna_count'),
                    style: _labelStyle,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (controller.manna / controller.maxManna).clamp(0, 1),
                  minHeight: 8,
                  color: _gold,
                  backgroundColor: const Color(0xFF3A2A10),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                seconds == null ? 'Full' : '+1 in ${formatCountdown(seconds)}',
                key: const Key('manna_timer'),
                style: const TextStyle(color: Color(0xFFBFA77A), fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }
}

const _labelStyle = TextStyle(
  color: _gold,
  fontSize: 14,
  fontWeight: FontWeight.bold,
);

/// Tells the player they are out of Manna and when more arrives.
Future<void> showOutOfMannaPopup(
  BuildContext context,
  MannaController controller,
) {
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
            seconds == null
                ? 'Your Manna is full again.'
                : 'Manna returns with time. '
                      'Next Manna in ${formatCountdown(seconds)}.',
            style: const TextStyle(color: Colors.white),
          );
        },
      ),
      actions: [
        TextButton(
          key: const Key('out_of_manna_ok'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK', style: TextStyle(color: _gold)),
        ),
      ],
    ),
  );
}
