// Free Manna links (EXPANSION section 25): a code posted on Facebook or
// Instagram gives a little Manna, once to each player. The server keeps
// the claims; this is what the game makes of its answer. Pure Dart.

/// How a claim went.
enum MannaLinkStatus {
  /// Claimed now: the Manna is the player's.
  ok,

  /// This player had it already.
  used,

  /// Not started yet, or ended.
  over,

  /// No such code.
  unknown,

  /// The player is not signed in (claims are counted per account).
  signedOut,

  /// The server could not be reached.
  failed,
}

class MannaLinkResult {
  final MannaLinkStatus status;

  /// The Manna to give (more than 0 only when [status] is ok).
  final int manna;

  const MannaLinkResult(this.status, [this.manna = 0]);
}

/// The most Manna one link may give, whatever the server says.
const mannaLinkMost = 100;

/// A code as the server knows it: capitals and digits only. Anything
/// else typed (spaces, a pasted link's other parts) is dropped; a pasted
/// link gives its last part (after the last "/" or "=", up to any "&").
String mannaLinkCode(String typed) {
  final parts = typed.trim().split('&').first.split(RegExp('[/=]'))
    ..removeWhere((part) => part.isEmpty);
  final last = parts.isEmpty ? '' : parts.last;
  return last.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
}

/// Whether [code] (already cleaned) could be a code at all.
bool mannaLinkCodeLooksRight(String code) =>
    RegExp(r'^[A-Z0-9]{4,20}$').hasMatch(code);

/// What the server's answer means. Anything odd counts as failed, and
/// gives nothing.
MannaLinkResult mannaLinkResult(Object? answer) {
  if (answer case {'status': final String status}) {
    final manna = switch (answer['manna']) {
      final int n when n > 0 => n > mannaLinkMost ? mannaLinkMost : n,
      _ => 0,
    };
    return switch (status) {
      'ok' when manna > 0 => MannaLinkResult(MannaLinkStatus.ok, manna),
      'used' => const MannaLinkResult(MannaLinkStatus.used),
      'over' => const MannaLinkResult(MannaLinkStatus.over),
      'unknown' => const MannaLinkResult(MannaLinkStatus.unknown),
      _ => const MannaLinkResult(MannaLinkStatus.failed),
    };
  }
  return const MannaLinkResult(MannaLinkStatus.failed);
}

/// The server that keeps the claims.
abstract class MannaLinkServer {
  bool get signedIn;

  /// Claims [code] for the signed-in player; the server's raw answer.
  Future<Object?> claim(String code);
}

/// The name of the text (in content/board_text.json) that tells the
/// player how a claim went.
String mannaLinkTextKey(MannaLinkStatus status) => switch (status) {
  MannaLinkStatus.ok => 'link_ok',
  MannaLinkStatus.used => 'link_used',
  MannaLinkStatus.over => 'link_over',
  MannaLinkStatus.unknown => 'link_unknown',
  MannaLinkStatus.signedOut => 'link_signed_out',
  MannaLinkStatus.failed => 'link_failed',
};
