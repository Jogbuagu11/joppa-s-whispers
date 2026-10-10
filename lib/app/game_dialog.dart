// The game's pop-up: a framed wooden panel with a headed title, an emblem
// set into its top edge and rounded buttons, used by every pop-up so they
// all look of a piece. It takes the same parts as Flutter's AlertDialog.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';

const _cream = Color(0xFFF3E5C8);
const _emblemSize = 54.0;

class GameDialog extends StatelessWidget {
  const GameDialog({
    super.key,
    this.icon = Icons.auto_awesome,
    this.title,
    this.content,
    this.actions = const [],
  });

  /// The emblem set into the top edge.
  final IconData icon;
  final Widget? title;
  final Widget? content;

  /// The buttons, the main one last.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final content = this.content;
    // Announced to screen readers as a pop-up when it opens.
    return Semantics(
      namesRoute: true,
      explicitChildNodes: true,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(top: _emblemSize / 2),
                decoration: BoxDecoration(
                  color: GamePalette.panel,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: GamePalette.gold, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xB3000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                // A second, finer line inside the frame.
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: GamePalette.panelEdge),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(title: title),
                      if (content != null)
                        Flexible(
                          // However much there is to say, it can be scrolled.
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                            child: DefaultTextStyle.merge(
                              style: const TextStyle(
                                color: _cream,
                                fontSize: 15,
                                height: 1.35,
                              ),
                              textAlign: TextAlign.center,
                              child: content,
                            ),
                          ),
                        ),
                      if (actions.isNotEmpty) _Buttons(actions: actions),
                    ],
                  ),
                ),
              ),
              _Emblem(icon: icon),
            ],
          ),
        ),
      ),
    );
  }
}

/// The title on a lighter band, with a small flourish under it.
class _Header extends StatelessWidget {
  const _Header({required this.title});

  final Widget? title;

  @override
  Widget build(BuildContext context) => Container(
    color: GamePalette.panelLight,
    padding: const EdgeInsets.fromLTRB(16, _emblemSize / 2 + 2, 16, 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title case final title?)
          DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GamePalette.talents,
              fontSize: 19,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
            child: title,
          ),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Rule(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.diamond, size: 10, color: GamePalette.gold),
            ),
            _Rule(),
          ],
        ),
      ],
    ),
  );
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 54,
    height: 1.5,
    child: ColoredBox(color: GamePalette.panelEdge),
  );
}

/// The round emblem that sits half over the top edge.
class _Emblem extends StatelessWidget {
  const _Emblem({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: _emblemSize,
    height: _emblemSize,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: GamePalette.gold,
      border: Border.all(color: GamePalette.talents, width: 2.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x99000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Icon(icon, color: GamePalette.backgroundBottom, size: 28),
  );
}

/// The buttons, all rounded: plain ones outlined, filled ones in gold. They
/// wrap onto further lines if they do not fit side by side.
class _Buttons extends StatelessWidget {
  const _Buttons({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    const shape = StadiumBorder();
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    return Theme(
      data: Theme.of(context).copyWith(
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: shape,
            padding: padding,
            backgroundColor: GamePalette.panelLight,
            foregroundColor: _cream,
            disabledForegroundColor: GamePalette.panelEdge,
            side: const BorderSide(color: GamePalette.panelEdge, width: 1.5),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: shape,
            padding: padding,
            backgroundColor: GamePalette.action,
            foregroundColor: GamePalette.onAction,
            disabledBackgroundColor: GamePalette.panelLight,
            disabledForegroundColor: GamePalette.muted,
            side: const BorderSide(color: GamePalette.actionEdge, width: 1.5),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: actions,
        ),
      ),
    );
  }
}
