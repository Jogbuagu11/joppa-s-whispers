import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/manna_links.dart';

void main() {
  test('a typed code is cleaned; a pasted link gives its last part', () {
    expect(mannaLinkCode(' joppa25 '), 'JOPPA25');
    expect(mannaLinkCode('jop-pa 25'), 'JOPPA25');
    expect(
      mannaLinkCode('https://whispersofjoppa.com/gift/Harbor7'),
      'HARBOR7',
    );
    expect(mannaLinkCode('https://x.test/gift?code=bread10'), 'BREAD10');
    expect(mannaLinkCode('https://x.test/gift/bread10/'), 'BREAD10');
    expect(mannaLinkCode('https://x.test/g?code=bread10&utm=fb'), 'BREAD10');
    expect(mannaLinkCode(''), '');
  });

  test('only capitals and digits, 4 to 20 of them, look like a code', () {
    expect(mannaLinkCodeLooksRight('JOPPA25'), isTrue);
    expect(mannaLinkCodeLooksRight('ABC'), isFalse);
    expect(mannaLinkCodeLooksRight('A' * 21), isFalse);
    expect(mannaLinkCodeLooksRight('joppa'), isFalse);
  });

  test('the server\'s answer is read; only "ok" gives Manna', () {
    final ok = mannaLinkResult({'status': 'ok', 'manna': 25});
    expect((ok.status, ok.manna), (MannaLinkStatus.ok, 25));
    for (final (status, want) in [
      ('used', MannaLinkStatus.used),
      ('over', MannaLinkStatus.over),
      ('unknown', MannaLinkStatus.unknown),
    ]) {
      final result = mannaLinkResult({'status': status, 'manna': 25});
      expect((result.status, result.manna), (want, 0));
    }
  });

  test('an odd answer gives nothing; a huge gift is cut down', () {
    expect(mannaLinkResult(null).status, MannaLinkStatus.failed);
    expect(mannaLinkResult('ok').status, MannaLinkStatus.failed);
    expect(mannaLinkResult({'status': 'new'}).status, MannaLinkStatus.failed);
    expect(
      mannaLinkResult({'status': 'ok', 'manna': 0}).status,
      MannaLinkStatus.failed,
    );
    expect(mannaLinkResult({'status': 'ok', 'manna': -5}).manna, 0);
    expect(mannaLinkResult({'status': 'ok', 'manna': 99999}).manna, 100);
  });

  test('every outcome has words to show', () {
    expect({
      for (final s in MannaLinkStatus.values) mannaLinkTextKey(s),
    }, hasLength(MannaLinkStatus.values.length));
  });
}
