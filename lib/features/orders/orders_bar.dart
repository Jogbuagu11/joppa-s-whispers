// The row of order cards above the board, and the Talents / Blessings count.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/features/orders/order_card.dart';
import 'package:whispers_of_joppa/features/orders/orders_controller.dart';
import 'package:whispers_of_joppa/features/story/face_portrait.dart';

/// The row of order cards is as tall as the screen can spare, within these
/// limits: the board below it comes first.
const double orderCardsMinHeight = 118;
const double orderCardsMaxHeight = 140;

class OrdersBar extends StatelessWidget {
  const OrdersBar({
    super.key,
    required this.controller,
    required this.items,
    required this.characterNames,
    required this.placeholderColors,
    this.looks = const {},
    this.height = orderCardsMaxHeight,
  });

  /// How tall the cards are.
  final double height;

  /// character_id -> their colour and portrait framing, from content.
  final Map<String, CharacterLook> looks;

  final OrdersController controller;
  final Map<String, ItemModel> items;
  final Map<String, String> characterNames;
  final Map<String, int> placeholderColors;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final orders = controller.activeOrders;
        final counts = controller.board.itemCounts();
        return SizedBox(
          height: height,
          child: Row(
            children: [
              for (final order in orders)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OrderCard(
                      order: order,
                      characterName:
                          characterNames[order.characterId] ??
                          order.characterId,
                      items: items,
                      placeholderColors: placeholderColors,
                      haveCounts: counts,
                      canDeliver: controller.canDeliver(order),
                      canSkip: controller.canSkip,
                      onDeliver: () => controller.deliver(order.id),
                      onSkip: () => controller.skip(order.id),
                      look: looks[order.characterId],
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

/// Shows how many Talents and Blessings the player has.
class WalletChips extends StatelessWidget {
  const WalletChips({
    super.key,
    required this.controller,
    this.pearls,
    this.onOpenShop,
  });

  final OrdersController controller;

  /// Shows the Pearls count; null hides it.
  final ValueListenable<int>? pearls;

  /// Opens the Pearl shop when the Pearls count is tapped; null means the
  /// shop is not offered (for example during the tutorial).
  final VoidCallback? onOpenShop;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Row(
        children: [
          Expanded(
            child: _chip(
              'Talents',
              controller.talents,
              const Key('talents_count'),
              GamePalette.talents,
              Icons.paid,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _chip(
              'Blessings',
              controller.blessings,
              const Key('blessings_count'),
              GamePalette.blessings,
              Icons.auto_awesome,
            ),
          ),
          if (pearls case final pearls?) ...[
            const SizedBox(width: 4),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: pearls,
                builder: (context, count, _) => GestureDetector(
                  key: const Key('pearls_chip'),
                  onTap: onOpenShop,
                  child: _chip(
                    'Pearls',
                    count,
                    const Key('pearls_count'),
                    GamePalette.pearls,
                    Icons.bubble_chart,
                    // A plus sign where the shop can be opened.
                    more: onOpenShop != null,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(
    String label,
    int value,
    Key key,
    Color color,
    IconData icon, {
    bool more = false,
  }) => Semantics(
    label: label,
    child: Container(
      height: 36,
      padding: const EdgeInsets.only(left: 3, right: 6),
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: GamePalette.panel),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '$value',
                key: key,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFFF3E6C8),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (more) ...[
            const SizedBox(width: 2),
            Icon(Icons.add_circle, size: 14, color: color),
          ],
        ],
      ),
    ),
  );
}
