import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/generator_types.dart';

const _charged = GeneratorRules(
  kind: GeneratorKind.charged,
  charges: 3,
  cooldownSeconds: 7200,
);
const _free = GeneratorRules(
  kind: GeneratorKind.free,
  intervalSeconds: 600,
  maxWaiting: 3,
);
const _temporary = GeneratorRules(kind: GeneratorKind.temporary, taps: 2);
final _t0 = DateTime.utc(2026, 10, 10, 12);

DateTime _after(int seconds) => _t0.add(Duration(seconds: seconds));

void main() {
  test('rules are read from content; a generator with no type is standard', () {
    expect(GeneratorRules.fromJson({'id': 'x'}).kind, GeneratorKind.standard);
    final r = GeneratorRules.fromJson({
      'type': 'charged',
      'charges': 6,
      'cooldown_seconds': 7200,
    });
    expect(r.kind, GeneratorKind.charged);
    expect(r.charges, 6);
    expect(r.costsManna, isFalse);
    expect(GeneratorRules.standard.costsManna, isTrue);
  });

  group('charged', () {
    test('gives its charges, then rests for the whole cooldown', () {
      var t = freshTimer(_charged, _t0);
      expect(t.left, 3);
      expect(secondsToWait(_charged, t, _t0), isNull);
      for (var i = 0; i < 3; i++) {
        expect(canGive(_charged, t, _t0), isTrue);
        t = afterGiving(_charged, t, _t0);
      }
      expect(t.left, 0);
      expect(canGive(_charged, t, _t0), isFalse);
      expect(secondsToWait(_charged, t, _t0), 7200);
      expect(canGive(_charged, t, _after(7199)), isFalse);
      expect(secondsToWait(_charged, t, _after(7199)), 1);
    });

    test('after the rest it is full again', () {
      final resting = GeneratorTimer(left: 0, at: _after(7200));
      expect(canGive(_charged, resting, _after(7200)), isTrue);
      expect(settled(_charged, resting, _after(7200)).left, 3);
      // And giving from a just-rested generator starts from full.
      expect(afterGiving(_charged, resting, _after(9000)).left, 2);
    });

    test('a phone clock set back cannot lock it for longer than a '
        'cooldown', () {
      final farOff = GeneratorTimer(left: 0, at: _after(90000));
      expect(secondsToWait(_charged, farOff, _t0), 7200);
    });

    test('a saved clock with more charges than the content allows starts '
        'fresh', () {
      expect(settled(_charged, const GeneratorTimer(left: 9), _t0).left, 3);
    });

    test('an hourglass shortens the rest, or ends it', () {
      final resting = GeneratorTimer(left: 0, at: _after(7200));
      final shorter = skipped(_charged, resting, _t0, seconds: 900);
      expect(secondsToWait(_charged, shorter ?? resting, _t0), 6300);
      // More than is left: the rest is over and it is full.
      expect(skipped(_charged, resting, _t0, seconds: 99999)?.left, 3);
      expect(skipped(_charged, resting, _t0)?.left, 3);
      // Nothing to shorten: the hourglass is not used.
      expect(skipped(_charged, const GeneratorTimer(left: 2), _t0), isNull);
      expect(skipped(_charged, resting, _after(7200)), isNull);
    });
  });

  group('free', () {
    test('makes one item each interval while there is room', () {
      final t = freshTimer(_free, _t0);
      expect(secondsToWait(_free, t, _t0), 600);
      expect(freeItemsDue(_free, t, _after(599), room: 5).items, 0);
      final due = freeItemsDue(_free, t, _after(600), room: 5);
      expect(due.items, 1);
      expect(secondsToWait(_free, due.timer, _after(600)), 600);
    });

    test('after a long time away it makes a few, never more than its limit '
        'or the room there is', () {
      final t = freshTimer(_free, _t0);
      expect(freeItemsDue(_free, t, _after(100000), room: 5).items, 3);
      expect(freeItemsDue(_free, t, _after(100000), room: 2).items, 2);
      expect(freeItemsDue(_free, t, _after(1300), room: 5).items, 2);
    });

    test('with no room it makes nothing and stays ready', () {
      final t = freshTimer(_free, _t0);
      final none = freeItemsDue(_free, t, _after(700), room: 0);
      expect(none.items, 0);
      // Room opens: the item comes at once.
      expect(freeItemsDue(_free, none.timer, _after(701), room: 1).items, 1);
    });

    test('it is never tapped for items; an hourglass brings the next one '
        'closer', () {
      final t = freshTimer(_free, _t0);
      expect(canGive(_free, t, _after(900)), isFalse);
      final sooner = skipped(_free, t, _t0, seconds: 500);
      expect(secondsToWait(_free, sooner ?? t, _t0), 100);
      final now = skipped(_free, t, _t0);
      expect(freeItemsDue(_free, now ?? t, _t0, room: 1).items, 1);
    });

    test('a missing or far-off clock starts fresh', () {
      expect(secondsToWait(_free, const GeneratorTimer(left: 0), _t0), 600);
      expect(
        secondsToWait(_free, GeneratorTimer(left: 0, at: _after(99999)), _t0),
        600,
      );
    });
  });

  group('temporary', () {
    test('gives its items and is then used up', () {
      var t = freshTimer(_temporary, _t0);
      expect(isUsedUp(_temporary, t), isFalse);
      t = afterGiving(_temporary, t, _t0);
      expect(canGive(_temporary, t, _t0), isTrue);
      t = afterGiving(_temporary, t, _t0);
      expect(canGive(_temporary, t, _t0), isFalse);
      expect(isUsedUp(_temporary, t), isTrue);
      expect(skipped(_temporary, t, _t0), isNull);
    });
  });

  test('a standard generator has no clock to speak of', () {
    final t = freshTimer(GeneratorRules.standard, _t0);
    expect(canGive(GeneratorRules.standard, t, _t0), isTrue);
    expect(afterGiving(GeneratorRules.standard, t, _t0).left, 0);
    expect(secondsToWait(GeneratorRules.standard, t, _t0), isNull);
    expect(isUsedUp(GeneratorRules.standard, t), isFalse);
  });

  test('clocks survive being saved and read back; damage means fresh', () {
    final t = GeneratorTimer(left: 0, at: _after(60));
    final back = GeneratorTimer.fromJson(t.toJson());
    expect(back?.left, 0);
    expect(back?.at, _after(60));
    expect(GeneratorTimer.fromJson(null), isNull);
    expect(GeneratorTimer.fromJson({'left': -1}), isNull);
    expect(GeneratorTimer.fromJson({'left': 2, 'at': 'soon'})?.at, isNull);
  });

  test('waits read naturally', () {
    expect(formatWait(7), '0:07');
    expect(formatWait(270), '4:30');
    expect(formatWait(3909), '1:05:09');
  });
}
