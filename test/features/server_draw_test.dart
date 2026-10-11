// A prize the player staked Pearls on is drawn by the server where it can
// be; the game accepts only a prize that try could have given, and draws
// for itself whenever the server cannot.
import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/chance.dart';
import 'package:whispers_of_joppa/domain/wheel.dart';
import 'package:whispers_of_joppa/features/wheel/wheel_controller.dart';
import 'package:whispers_of_joppa/game/board/save_extras.dart';

const _prizes = [
  Prize(id: 'pearls', name: '3 Pearls', weight: 1, pearls: 3, freeOnly: true),
  Prize(id: 'manna', name: '20 Manna', weight: 1, manna: 20),
  Prize(id: 'talents', name: '30 Talents', weight: 1, talents: 30),
];
const _rules = WheelRules(
  freeSpinsPerDay: 1,
  adSpinsPerDay: 0,
  pearlSpinBase: 5,
  pearlSpinStep: 0,
  pearlSpinsPerDay: 5,
  prizes: _prizes,
);

/// Luck that always lands at the very start of the wheel.
class _First implements Random {
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
}

void main() {
  test('a draw made elsewhere is accepted only if this try could give it', () {
    expect(prizeNamed(_prizes, 'talents', paid: true)?.id, 'talents');
    expect(prizeNamed(_prizes, 'pearls', paid: false)?.id, 'pearls');
    // Never Pearls for a paid try, whoever says so.
    expect(prizeNamed(_prizes, 'pearls', paid: true), isNull);
    expect(prizeNamed(_prizes, 'no_such', paid: true), isNull);
    expect(prizeNamed(_prizes, null, paid: true), isNull);
  });

  group('the wheel', () {
    late SaveExtras extras;
    late int pearls;
    late List<String> given;
    late int asked;
    String? answer;

    WheelController wheel({bool server = true}) => WheelController(
      rules: _rules,
      extras: extras,
      paidAllowed: true,
      pearls: () => pearls,
      spendPearls: (n) {
        if (n > pearls) return false;
        pearls -= n;
        return true;
      },
      grant: (prize) => given.add(prize.id),
      adReady: () => false,
      watchAd: () async => false,
      serverDraw: server
          ? () async {
              asked++;
              return answer;
            }
          : null,
      random: _First(),
      clock: () => DateTime(2026, 10, 12, 9),
    );

    setUp(() {
      extras = SaveExtras();
      pearls = 20;
      given = [];
      asked = 0;
      answer = null;
    });
    tearDown(() => extras.dispose());

    test('a Pearl spin gives the prize the server drew', () async {
      answer = 'talents';
      final w = wheel();
      // Left to itself (luck at the start of the wheel) it would be Manna.
      expect((await w.spin(SpinKind.pearls))?.id, 'talents');
      expect(asked, 1);
      expect(pearls, 15);
      expect(given, ['talents']);
      expect(w.busy, isFalse);
      w.dispose();
    });

    test('a free spin is never sent to the server', () async {
      answer = 'talents';
      final w = wheel();
      expect((await w.spin(SpinKind.free))?.id, 'pearls');
      expect(asked, 0);
      w.dispose();
    });

    test('with no answer from the server the wheel draws for itself, and '
        'the player still gets a prize for their Pearls', () async {
      final w = wheel();
      expect((await w.spin(SpinKind.pearls))?.id, 'manna');
      expect(asked, 1);
      expect(pearls, 15);
      expect(given, ['manna']);
      w.dispose();
    });

    test('an answer this spin could not give is not accepted', () async {
      // Pearls are never won on a Pearl spin; nor a prize not on the wheel.
      for (final odd in ['pearls', 'a_fortune']) {
        answer = odd;
        final w = wheel();
        expect((await w.spin(SpinKind.pearls))?.id, 'manna');
        w.dispose();
      }
      expect(given, ['manna', 'manna']);
    });

    test('no Pearls are taken until the server has answered, and none at '
        'all if the wheel is closed while waiting', () async {
      final waiting = Completer<String?>();
      final w = WheelController(
        rules: _rules,
        extras: extras,
        paidAllowed: true,
        pearls: () => pearls,
        spendPearls: (n) {
          pearls -= n;
          return true;
        },
        grant: (prize) => given.add(prize.id),
        adReady: () => false,
        watchAd: () async => false,
        serverDraw: () => waiting.future,
        random: _First(),
        clock: () => DateTime(2026, 10, 12, 9),
      );
      final spinning = w.spin(SpinKind.pearls);
      await Future<void>.delayed(Duration.zero);
      expect(w.busy, isTrue);
      expect(pearls, 20);
      expect(extras.read(wheelRecord), isNull);
      // A second tap while waiting does nothing.
      expect(await w.spin(SpinKind.pearls), isNull);
      w.dispose();
      waiting.complete('talents');
      expect(await spinning, isNull);
      expect(pearls, 20);
      expect(given, isEmpty);
      expect(extras.read(wheelRecord), isNull);
    });

    test(
      'a Pearl spin the player cannot pay for is not sent anywhere',
      () async {
        pearls = 2;
        final w = wheel();
        expect(await w.spin(SpinKind.pearls), isNull);
        expect(asked, 0);
        expect(pearls, 2);
        w.dispose();
      },
    );

    test('where there is no server to ask, nothing changes', () async {
      final w = wheel(server: false);
      expect((await w.spin(SpinKind.pearls))?.id, 'manna');
      expect(asked, 0);
      w.dispose();
    });
  });
}
