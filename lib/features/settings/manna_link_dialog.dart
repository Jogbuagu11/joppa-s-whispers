// The free Manna code pop-up: the player types (or pastes) a code from
// the game's Facebook or Instagram page and is told how it went.
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:whispers_of_joppa/app/game_dialog.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/manna_links.dart';

final _log = Logger('MannaLink');

const _cream = Color(0xFFF3E5C8);

/// Claims [typed] with [server]. Never throws: a server that cannot be
/// reached gives "failed".
Future<MannaLinkResult> claimMannaLink(
  MannaLinkServer? server,
  String typed,
) async {
  final code = mannaLinkCode(typed);
  if (!mannaLinkCodeLooksRight(code)) {
    return const MannaLinkResult(MannaLinkStatus.unknown);
  }
  if (server == null || !server.signedIn) {
    return const MannaLinkResult(MannaLinkStatus.signedOut);
  }
  try {
    return mannaLinkResult(await server.claim(code));
  } on Object catch (error, stack) {
    _log.warning('Could not claim a Manna code', error, stack);
    return const MannaLinkResult(MannaLinkStatus.failed);
  }
}

/// [give] hands the player the Manna of a claim that went through; it
/// answers false if it could not (the game in play has changed).
Future<void> showMannaLink(
  BuildContext context, {
  required MannaLinkServer? server,
  required bool Function(int manna) give,
  required Map<String, String> text,
}) => showDialog<void>(
  context: context,
  builder: (context) =>
      _MannaLinkDialog(server: server, give: give, text: text),
);

class _MannaLinkDialog extends StatefulWidget {
  const _MannaLinkDialog({
    required this.server,
    required this.give,
    required this.text,
  });

  final MannaLinkServer? server;
  final bool Function(int manna) give;
  final Map<String, String> text;

  @override
  State<_MannaLinkDialog> createState() => _MannaLinkDialogState();
}

class _MannaLinkDialogState extends State<_MannaLinkDialog> {
  final _code = TextEditingController();
  bool _asking = false;
  MannaLinkResult? _result;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    if (_asking) return;
    setState(() => _asking = true);
    var result = await claimMannaLink(widget.server, _code.text);
    if (result.status == MannaLinkStatus.ok && !widget.give(result.manna)) {
      _log.warning('A claimed Manna code could not be handed over');
      result = const MannaLinkResult(MannaLinkStatus.failed);
    }
    if (!mounted) return;
    setState(() {
      _asking = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final result = _result;
    return GameDialog(
      key: const Key('manna_link_popup'),
      icon: Icons.card_giftcard,
      title: Text(
        text['link_title'] ?? '',
        style: const TextStyle(color: GamePalette.gold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text['link_body'] ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _cream, fontSize: 14),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('manna_link_code'),
            controller: _code,
            enabled: !_asking,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: _cream),
            decoration: InputDecoration(
              hintText: text['link_hint'] ?? '',
              hintStyle: const TextStyle(color: Color(0x99F3E5C8)),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: GamePalette.gold),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: GamePalette.gold, width: 2),
              ),
            ),
            onSubmitted: (_) => _claim(),
          ),
          if (result != null) ...[
            const SizedBox(height: 10),
            Text(
              (text[mannaLinkTextKey(result.status)] ?? '').replaceAll(
                '{manna}',
                '${result.manna}',
              ),
              key: const Key('manna_link_said'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: GamePalette.talents),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('manna_link_close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(text['link_close'] ?? ''),
        ),
        FilledButton(
          key: const Key('manna_link_claim'),
          onPressed: _asking ? null : _claim,
          child: Text(text['link_claim'] ?? ''),
        ),
      ],
    );
  }
}
