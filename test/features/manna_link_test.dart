import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/manna_links.dart';
import 'package:whispers_of_joppa/features/settings/manna_link_dialog.dart';

class _Server implements MannaLinkServer {
  _Server({this.signedIn = true, this.answer, this.breaks = false});
  @override
  final bool signedIn;
  final Object? answer;
  final bool breaks;
  final asked = <String>[];

  @override
  Future<Object?> claim(String code) async {
    asked.add(code);
    if (breaks) throw StateError('offline');
    return answer;
  }
}

const _text = {
  'link_title': 'Free Manna',
  'link_body': 'Type the code',
  'link_hint': 'Code',
  'link_claim': 'Claim',
  'link_close': 'Close',
  'link_ok': 'You got {manna} Manna!',
  'link_used': 'Already claimed',
  'link_over': 'Ended',
  'link_unknown': 'No such code',
  'link_signed_out': 'Sign in first',
  'link_failed': 'Try again later',
};

void main() {
  test('a code that cannot be one never reaches the server', () async {
    final server = _Server(answer: {'status': 'ok', 'manna': 25});
    final result = await claimMannaLink(server, 'ab');
    expect(result.status, MannaLinkStatus.unknown);
    expect(server.asked, isEmpty);
  });

  test('a player not signed in is told so, and nothing is asked', () async {
    final server = _Server(signedIn: false);
    expect(
      (await claimMannaLink(server, 'JOPPA25')).status,
      MannaLinkStatus.signedOut,
    );
    expect(
      (await claimMannaLink(null, 'JOPPA25')).status,
      MannaLinkStatus.signedOut,
    );
    expect(server.asked, isEmpty);
  });

  test('a server that breaks gives "failed", not an error', () async {
    final result = await claimMannaLink(_Server(breaks: true), 'JOPPA25');
    expect((result.status, result.manna), (MannaLinkStatus.failed, 0));
  });

  testWidgets('a good code gives its Manna once and says so', (tester) async {
    final server = _Server(answer: {'status': 'ok', 'manna': 25});
    final given = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMannaLink(
              context,
              server: server,
              give: (manna) {
                given.add(manna);
                return true;
              },
              text: _text,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('manna_link_code')), 'joppa25');
    await tester.tap(find.byKey(const Key('manna_link_claim')));
    await tester.pumpAndSettle();
    expect(server.asked, ['JOPPA25']);
    expect(given, [25]);
    expect(find.text('You got 25 Manna!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a used code gives nothing', (tester) async {
    final given = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMannaLink(
              context,
              server: _Server(answer: {'status': 'used', 'manna': 0}),
              give: (manna) {
                given.add(manna);
                return true;
              },
              text: _text,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('manna_link_code')), 'JOPPA25');
    await tester.tap(find.byKey(const Key('manna_link_claim')));
    await tester.pumpAndSettle();
    expect(given, isEmpty);
    expect(find.text('Already claimed'), findsOneWidget);
  });
}
