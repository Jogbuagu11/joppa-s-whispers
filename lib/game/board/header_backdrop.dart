// The picture behind everything above the board (the harbor and its
// lighthouse). It reaches from the top of the screen down to the top of
// the board, wherever that is on this phone at this moment.
import 'package:flutter/material.dart';

class HeaderBackdrop extends StatefulWidget {
  const HeaderBackdrop({
    super.key,
    required this.asset,
    required this.boardKey,
    required this.relayout,
  });

  final String asset;

  /// Marks the board: the picture ends where it begins.
  final GlobalKey boardKey;

  /// Fires when something above the board may have changed height.
  final Listenable relayout;

  @override
  State<HeaderBackdrop> createState() => _HeaderBackdropState();
}

class _HeaderBackdropState extends State<HeaderBackdrop> {
  double _height = 0;

  @override
  void initState() {
    super.initState();
    widget.relayout.addListener(_measureSoon);
  }

  @override
  void didUpdateWidget(HeaderBackdrop old) {
    super.didUpdateWidget(old);
    if (old.relayout != widget.relayout) {
      old.relayout.removeListener(_measureSoon);
      widget.relayout.addListener(_measureSoon);
    }
  }

  @override
  void dispose() {
    widget.relayout.removeListener(_measureSoon);
    super.dispose();
  }

  void _measureSoon() {
    if (mounted) setState(() {});
  }

  /// After each layout, finds where the board starts.
  void _measure() {
    if (!mounted) return;
    final board = widget.boardKey.currentContext?.findRenderObject();
    final mine = context.findRenderObject();
    if (board is! RenderBox || mine is! RenderBox || !board.hasSize) return;
    final top = board.localToGlobal(Offset.zero, ancestor: mine).dy;
    if ((top - _height).abs() > 0.5) setState(() => _height = top);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        key: const Key('header_backdrop'),
        width: double.infinity,
        height: _height,
        child: _height <= 0
            ? null
            : Image.asset(
                widget.asset,
                fit: BoxFit.cover,
                // Keep the tower and the town in view on a narrow screen.
                alignment: const Alignment(-0.25, -0.1),
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
      ),
    );
  }
}
