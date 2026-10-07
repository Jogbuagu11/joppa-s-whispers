// One order card: who is asking, what they want, the reward and the buttons.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/data/asset_names.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/orders.dart';

const _gold = Color(0xFFD4802A);
const _cream = Color(0xFFF3E6C8);
const _textSize = 9.5;
const _textLineHeight = 1.2;

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
    this.compact = false,
  });

  /// On a short phone the card is lower: fewer lines of the request, no
  /// reward line (tapping the request shows it all).
  final bool compact;

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
              ClipOval(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: Image.asset(
                    'assets/characters/'
                    '${portraitBaseName(order.characterId, 'neutral')}.jpg',
                    fit: BoxFit.cover,
                    // Portraits are tall; show the face, not the feet.
                    alignment: const Alignment(0, -0.85),
                    // A character with no portrait yet shows their initial.
                    errorBuilder: (context, error, stack) => ColoredBox(
                      color: _gold,
                      child: Center(
                        child: Text(
                          characterName.isEmpty ? '?' : characterName[0],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
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
            // Tapping the request shows all of it.
            child: Semantics(
              button: true,
              child: GestureDetector(
                key: Key('order_text_${order.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _showDetails(context),
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Only whole lines: a long request ends in "…", never in
                    // a line cut in half.
                    final lineHeight =
                        MediaQuery.textScalerOf(context).scale(_textSize) *
                        _textLineHeight;
                    final lines = (box.maxHeight / lineHeight).floor();
                    return Text(
                      order.text,
                      maxLines: lines < 1 ? 1 : lines,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _cream,
                        fontSize: _textSize,
                        height: _textLineHeight,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // Three wanted items are wider than a card on a narrow phone:
          // they shrink to fit instead of spilling over its edge.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final wanted in order.items) _wantedItem(wanted)],
            ),
          ),
          const SizedBox(height: 3),
          if (!compact) ...[
            Text(
              _rewardLine,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _cream, fontSize: 9),
            ),
            const SizedBox(height: 3),
          ],
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

  String get _rewardLine => '+${order.talents} Talents  +${order.blessings} ✦';

  /// The whole request and its reward, in a small window.
  Future<void> _showDetails(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('order_details'),
      backgroundColor: const Color(0xFF2A1F08),
      title: Text(characterName, style: const TextStyle(color: _gold)),
      // However long the request, it can be scrolled.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.text, style: const TextStyle(color: _cream)),
            const SizedBox(height: 12),
            Text(_rewardLine, style: const TextStyle(color: _gold)),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('order_details_close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: _gold)),
        ),
      ],
    ),
  );

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
