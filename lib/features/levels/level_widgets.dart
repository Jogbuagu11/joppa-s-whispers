// The level badge on the board, and the message shown on reaching a level.
import 'package:whispers_of_joppa/app/game_dialog.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/levels.dart';
import 'package:whispers_of_joppa/features/levels/level_controller.dart';

const _gold = Color(0xFFD4802A);
const _cream = Color(0xFFF3E5C8);

String _fill(String? template, String key, Object value) =>
    (template ?? '').replaceAll('{$key}', '$value');

/// A small round badge: the level number inside a ring that fills as XP is
/// earned.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.controller});

  final LevelController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final (:into, :needed) = controller.progress;
      final level = controller.level;
      return Semantics(
        label: _fill(controller.config.text['badge'], 'level', level),
        child: SizedBox(
          key: const Key('level_badge'),
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // A gold disc with the number; the ring round it fills as
              // XP is earned.
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: GamePalette.level,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 28, height: 28),
              ),
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  key: const Key('level_progress'),
                  // A full ring at the highest level.
                  value: needed == 0 ? 1 : into / needed,
                  strokeWidth: 3,
                  color: GamePalette.manna,
                  backgroundColor: GamePalette.panelEdge,
                ),
              ),
              ExcludeSemantics(
                child: Text(
                  '$level',
                  key: const Key('level_number'),
                  // The number must stay inside its ring at any text size.
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    color: GamePalette.backgroundBottom,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Tells the player they reached a level and what it gave them.
Future<void> showLevelUp(
  BuildContext context,
  Map<String, String> text,
  LevelUp up, {

  /// The names of the gift items and generators that came with it.
  List<String> giftNames = const [],
}) => showDialog<void>(
  context: context,
  builder: (context) => GameDialog(
    key: const Key('level_up'),
    icon: Icons.military_tech,
    title: Text(
      _fill(text['title'], 'level', up.to),
      key: const Key('level_up_title'),
      textAlign: TextAlign.center,
      style: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text['manna'] ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _cream),
          ),
          if (up.talents > 0) ...[
            const SizedBox(height: 8),
            Text(
              _fill(text['talents'], 'talents', up.talents),
              key: const Key('level_up_talents'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
            ),
          ],
          for (final name in giftNames) ...[
            const SizedBox(height: 8),
            Text(
              _fill(text['gift'], 'name', name),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _gold),
            ),
          ],
          for (final unlock in up.unlocked) ...[
            const SizedBox(height: 8),
            Text(
              _fill(text['unlocked'], 'name', unlock.name),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _cream),
            ),
          ],
        ],
      ),
    ),
    actions: [
      FilledButton(
        key: const Key('level_up_continue'),
        onPressed: () => Navigator.of(context).pop(),
        style: FilledButton.styleFrom(backgroundColor: _gold),
        child: Text(
          text['continue'] ?? '',
          style: const TextStyle(color: Colors.black),
        ),
      ),
    ],
  ),
);
