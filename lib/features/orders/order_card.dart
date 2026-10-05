// One order card: who is asking, what they want, the reward and the buttons.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/orders.dart';

const _gold = Color(0xFFD4802A);
const _cream = Color(0xFFF3E6C8);

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.characterName,
    required this.items,
    required this.placeholderColors,
    required this.haveCounts,
    required this.canDeliver,
    required this.canSkip,
    required this.onDeliver,
    required this.onSkip,
  });

  final OrderModel order;
  final String characterName;

  /// item_id -> item, for names and art.
  final Map<String, ItemModel> items;

  /// chain_id -> ARGB placeholder colour.
  final Map<String, int> placeholderColors;

  /// item_id -> how many are on the board.
  final Map<String, int> haveCounts;
  final bool canDeliver;
  final bool canSkip;
  final VoidCallback onDeliver;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('order_card_${order.id}'),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1F08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: canDeliver ? _gold : const Color(0xFF5C3D0D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: _gold,
                child: Text(
                  characterName.isEmpty ? '?' : characterName[0],
                  style: const TextStyle(fontSize: 11, color: Colors.black),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  characterName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Text(
              order.text,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _cream, fontSize: 9.5, height: 1.2),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final wanted in order.items) _wantedItem(wanted)],
          ),
          const SizedBox(height: 3),
          Text(
            '+${order.talents} Talents  +${order.blessings} ✦',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _cream, fontSize: 9),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 24,
                  child: FilledButton(
                    key: Key('order_deliver_${order.id}'),
                    onPressed: canDeliver ? onDeliver : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      disabledBackgroundColor: const Color(0xFF3A2A10),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'Deliver',
                      style: TextStyle(fontSize: 11, color: Colors.black),
                    ),
                  ),
                ),
              ),
              if (canSkip)
                SizedBox(
                  height: 24,
                  width: 34,
                  child: TextButton(
                    key: Key('order_skip_${order.id}'),
                    onPressed: onSkip,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Text(
                      'Skip',
                      style: TextStyle(fontSize: 9, color: _cream),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wantedItem(OrderItem wanted) {
    final item = items[wanted.itemId];
    final have = (haveCounts[wanted.itemId] ?? 0).clamp(0, wanted.count);
    final asset = item?.asset ?? '';
    final Widget picture = asset.isEmpty
        ? Container(
            color: Color(placeholderColors[item?.chainId] ?? 0xFF888888),
            alignment: Alignment.center,
            child: Text(
              '${item?.tier ?? '?'}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          )
        : Image.asset(asset, fit: BoxFit.cover);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(width: 26, height: 26, child: picture),
          ),
          Text(
            '$have/${wanted.count}',
            key: Key('order_have_${order.id}_${wanted.itemId}'),
            style: TextStyle(
              fontSize: 9,
              color: have >= wanted.count ? const Color(0xFF8BC34A) : _cream,
            ),
          ),
        ],
      ),
    );
  }
}
