// The row of order cards above the board, and the Talents / Blessings count.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/features/orders/order_card.dart';
import 'package:whispers_of_joppa/features/orders/orders_controller.dart';

class OrdersBar extends StatelessWidget {
  const OrdersBar({
    super.key,
    required this.controller,
    required this.items,
    required this.characterNames,
    required this.placeholderColors,
  });

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
          height: 178,
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
  const WalletChips({super.key, required this.controller});

  final OrdersController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip('Talents', controller.talents, const Key('talents_count')),
          const SizedBox(height: 4),
          _chip(
            'Blessings',
            controller.blessings,
            const Key('blessings_count'),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int value, Key key) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF2A1F08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF5C3D0D)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(color: Color(0xFFBFA77A), fontSize: 12),
        ),
        Text(
          '$value',
          key: key,
          style: const TextStyle(
            color: Color(0xFFD4802A),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
