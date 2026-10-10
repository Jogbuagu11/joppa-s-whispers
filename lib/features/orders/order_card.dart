// One order card: who is asking (their face), what they want, a line or two
// of what they say, and the Deliver button. It fits whatever height it is
// given; tapping the words shows the whole request and its reward.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/data/asset_names.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/orders.dart';
import 'package:whispers_of_joppa/features/story/face_portrait.dart';

const _cream = Color(0xFFF3E6C8);
const _textSize = 10.0;
const _textLineHeight = 1.2;

/// The most lines of a request shown on the card itself.
const _maxLines = 2;

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
    this.characterColor,
    this.faceZoom = defaultFaceZoom,
  });

  /// How far the portrait is zoomed in on this character's face.
  final double faceZoom;

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

  /// The character's own colour, from content.
  final Color? characterColor;

  @override
  Widget build(BuildContext context) {
    final theirs = characterColor ?? GamePalette.person;
    return Container(
      key: Key('order_card_${order.id}'),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
      decoration: BoxDecoration(
        color: GamePalette.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canDeliver ? GamePalette.ready : theirs.withValues(alpha: 0.7),
          width: canDeliver ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Semantics(
                label: characterName,
                child: FacePortrait(
                  asset:
                      'assets/characters/'
                      '${portraitBaseName(order.characterId, 'neutral')}.jpg',
                  // Three wanted items need the room more than the face.
                  size: order.items.length > 2 ? 40 : 54,
                  zoom: faceZoom,
                  name: characterName,
                  ring: theirs,
                ),
              ),
              const SizedBox(width: 4),
              // Three wanted items are wider than the space beside the
              // face on a narrow phone: they shrink to fit.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final wanted in order.items) _wantedItem(wanted),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Expanded(
            // Tapping the words shows all of them, and the reward.
            child: Semantics(
              button: true,
              child: GestureDetector(
                key: Key('order_text_${order.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _showDetails(context),
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Only whole lines: a long request ends in "…", never
                    // in a line cut in half.
                    final lineHeight =
                        MediaQuery.textScalerOf(context).scale(_textSize) *
                        _textLineHeight;
                    final fits = (box.maxHeight / lineHeight).floor();
                    if (fits < 1) return const SizedBox.shrink();
                    return Text(
                      order.text,
                      maxLines: fits > _maxLines ? _maxLines : fits,
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
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 26,
                  child: FilledButton(
                    key: Key('order_deliver_${order.id}'),
                    onPressed: canDeliver ? onDeliver : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: GamePalette.ready,
                      disabledBackgroundColor: GamePalette.panelLight,
                      padding: EdgeInsets.zero,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Deliver',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          // Dark on green: easy to read.
                          color: canDeliver
                              ? GamePalette.backgroundBottom
                              : GamePalette.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (canSkip)
                SizedBox(
                  height: 26,
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
      backgroundColor: GamePalette.panel,
      title: Text(
        characterName,
        style: const TextStyle(color: GamePalette.level),
      ),
      // However long the request, it can be scrolled.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.text, style: const TextStyle(color: _cream)),
            const SizedBox(height: 12),
            Text(
              _rewardLine,
              style: const TextStyle(color: GamePalette.talents),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('order_details_close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Close',
            style: TextStyle(color: GamePalette.level),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(width: 30, height: 30, child: picture),
          ),
          Text(
            '$have/${wanted.count}',
            key: Key('order_have_${order.id}_${wanted.itemId}'),
            style: TextStyle(
              fontSize: 9,
              height: 1.2,
              fontWeight: FontWeight.bold,
              color: have >= wanted.count ? GamePalette.ready : _cream,
            ),
          ),
        ],
      ),
    );
  }
}
