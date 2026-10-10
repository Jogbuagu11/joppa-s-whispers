// The swipeable row above the board. At rest it shows the three order
// cards; to their left are the story card and round buttons (the place
// being restored, Esther's letters, the event), with room for more. It
// slides to the story card by itself when the next task can be done.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/features/story/story_controller.dart';
import 'package:whispers_of_joppa/features/story/task_bar.dart';

const _gap = 5.0;
const _menuWidth = 46.0;
const _gutter = 16.0;

class BoardStrip extends StatefulWidget {
  const BoardStrip({
    super.key,
    required this.story,
    required this.onDoTask,
    required this.onOpenLocation,
    required this.onOpenLetters,
    required this.orders,
    required this.height,
    this.onOpenEvent,
    this.eventLabel,
    this.ordersChanged,
    this.readyOrders,
    this.storyPicture,
  });

  /// A picture for the story card: what its task restores.
  final String? storyPicture;

  /// Fires when the orders or the board change, and how many orders can
  /// be delivered right now: when another becomes ready, the row slides
  /// back to the orders.
  final Listenable? ordersChanged;
  final int Function()? readyOrders;

  final StoryController story;
  final VoidCallback onDoTask;
  final VoidCallback onOpenLocation;
  final VoidCallback onOpenLetters;

  /// Opens the event board; null while no event is on (or offered).
  final VoidCallback? onOpenEvent;

  /// The time the event has left, shown under its button.
  final String? eventLabel;

  /// The order cards (they fill the width they are given).
  final Widget orders;
  final double height;

  @override
  State<BoardStrip> createState() => _BoardStripState();
}

class _BoardStripState extends State<BoardStrip> {
  final ScrollController _scroll = ScrollController();
  bool _placed = false;
  bool _couldDo = false;
  int _ready = 0;

  @override
  void initState() {
    super.initState();
    _couldDo = widget.story.canDoNext;
    _ready = widget.readyOrders?.call() ?? 0;
    widget.story.addListener(_onStory);
    widget.ordersChanged?.addListener(_onOrders);
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(BoardStrip old) {
    super.didUpdateWidget(old);
    if (old.ordersChanged != widget.ordersChanged) {
      old.ordersChanged?.removeListener(_onOrders);
      widget.ordersChanged?.addListener(_onOrders);
    }
    if (old.story != widget.story) {
      old.story.removeListener(_onStory);
      widget.story.addListener(_onStory);
      _couldDo = widget.story.canDoNext;
    }
  }

  @override
  void dispose() {
    widget.story.removeListener(_onStory);
    widget.ordersChanged?.removeListener(_onOrders);
    _scroll.dispose();
    super.dispose();
  }

  bool get _atStart => !_scroll.hasClients || _scroll.offset < 8;

  void _onScroll() {
    // The "more this way" arrow comes and goes with the scroll position.
    if (mounted) setState(() {});
  }

  /// The story card slides into view when its task can be done, and the
  /// orders slide back once it has been.
  void _onStory() {
    final canDo = widget.story.canDoNext;
    if (canDo == _couldDo) return;
    _couldDo = canDo;
    _slide(toStory: canDo);
  }

  /// Another order can now be delivered: show the orders, unless the story
  /// card is waiting to be tapped.
  void _onOrders() {
    final ready = widget.readyOrders?.call() ?? 0;
    final more = ready > _ready;
    _ready = ready;
    if (more && !_couldDo) _slide(toStory: false);
  }

  void _slide({required bool toStory}) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      toStory ? 0 : _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    child: Row(
      children: [
        // A narrow gutter at the left edge holds the "more this way"
        // arrow, so it never covers a card.
        SizedBox(
          width: _gutter,
          child: _atStart
              ? null
              : GestureDetector(
                  key: const Key('strip_more'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _slide(toStory: true),
                  child: const Center(
                    child: Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 22,
                      shadows: [Shadow(blurRadius: 4)],
                    ),
                  ),
                ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth;
              // Three order cards fill the row exactly; the story card is
              // the width of one of them.
              final card = (width - 2 * _gap) / 3;
              if (!_placed) {
                // Once laid out: start on the orders, or on the story card
                // if its task is already waiting to be done.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || !_scroll.hasClients || _placed) return;
                  _placed = true;
                  if (!_couldDo) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });
              }
              return SingleChildScrollView(
                key: const Key('board_strip'),
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(width: _menuWidth, child: _menu()),
                    const SizedBox(width: _gap),
                    SizedBox(
                      width: card,
                      height: widget.height,
                      child: StoryCard(
                        controller: widget.story,
                        onDo: widget.onDoTask,
                        picture: widget.storyPicture,
                      ),
                    ),
                    const SizedBox(width: _gap),
                    SizedBox(width: width, child: widget.orders),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  /// The round buttons at the far left, one under another.
  Widget _menu() => Column(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _RoundIcon(
        buttonKey: const Key('location_button'),
        icon: Icons.home_work,
        tooltip: 'See what you have restored',
        onTap: widget.onOpenLocation,
      ),
      _RoundIcon(
        buttonKey: const Key('letters_button'),
        icon: Icons.mail,
        tooltip: "Esther's letters",
        onTap: widget.onOpenLetters,
      ),
      if (widget.onOpenEvent != null)
        _RoundIcon(
          buttonKey: const Key('event_banner'),
          icon: Icons.celebration,
          tooltip: widget.eventLabel ?? '',
          onTap: widget.onOpenEvent,
          lit: true,
        ),
    ],
  );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.lit = false,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  /// A gold button rather than a dark one (something is on now).
  final bool lit;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    child: Material(
      color: lit ? GamePalette.gold : GamePalette.panel.withValues(alpha: 0.92),
      shape: const CircleBorder(side: BorderSide(color: GamePalette.panelEdge)),
      child: InkWell(
        key: buttonKey,
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            icon,
            size: 20,
            color: lit ? GamePalette.backgroundBottom : GamePalette.level,
          ),
        ),
      ),
    ),
  );
}
