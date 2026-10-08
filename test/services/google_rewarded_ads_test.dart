import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/services/google_rewarded_ads.dart';

void main() {
  test('without consent no ad is requested, and the next start asks '
      'again', () async {
    var asked = 0;
    final ads = GoogleRewardedAds(
      consent: () async {
        asked++;
        return false;
      },
    );
    ads.start();
    // A second start while the first is still asking does nothing.
    ads.start();
    await Future<void>.delayed(Duration.zero);
    expect(asked, 1);
    expect(ads.ready.value, isFalse);

    // Later (the player comes back to the game): it asks again.
    ads.start();
    await Future<void>.delayed(Duration.zero);
    expect(asked, 2);
    expect(ads.ready.value, isFalse);
  });

  test('a consent check that breaks is not the end of ads either', () async {
    var asked = 0;
    final ads = GoogleRewardedAds(
      consent: () async {
        asked++;
        throw StateError('no consent service');
      },
    );
    ads.start();
    await Future<void>.delayed(Duration.zero);
    ads.start();
    await Future<void>.delayed(Duration.zero);
    expect(asked, 2);
    expect(ads.ready.value, isFalse);
  });
}
