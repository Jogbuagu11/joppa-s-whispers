// Asks Google's consent service whether ads may be requested, showing its
// consent message first where the law (or Apple) requires one. The message
// itself is written and switched on in the AdMob console, not here.
import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';

final _log = Logger('AdConsent');

const _updateWait = Duration(seconds: 10);

/// Refreshes the player's consent state, shows the consent message if one
/// is due, and returns whether ads may now be requested. Never throws.
Future<bool> gatherAdConsent() async {
  try {
    final info = ConsentInformation.instance;
    final updated = Completer<void>();
    info.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!updated.isCompleted) updated.complete();
      },
      (error) {
        // Offline, or no message set up: carry on with what was last known.
        _log.info('Consent state not refreshed: ${error.message}');
        if (!updated.isCompleted) updated.complete();
      },
    );
    await updated.future.timeout(_updateWait, onTimeout: () {});
    final shown = Completer<void>();
    await ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error != null) _log.info('Consent message: ${error.message}');
      if (!shown.isCompleted) shown.complete();
    });
    await shown.future;
    return await info.canRequestAds();
  } on Object catch (e) {
    _log.warning('Consent could not be checked: $e');
    return false;
  }
}

/// Whether the player must be given a way to change their ad privacy choice
/// later (true where a consent message applies to them).
Future<bool> adPrivacyOptionsRequired() async {
  try {
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  } on Object catch (e) {
    _log.warning('Privacy options state unknown: $e');
    return false;
  }
}

/// Shows Google's privacy choices again.
Future<void> showAdPrivacyOptions() async {
  try {
    final closed = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) _log.info('Privacy choices: ${error.message}');
      if (!closed.isCompleted) closed.complete();
    });
    await closed.future;
  } on Object catch (e) {
    _log.warning('Privacy choices could not be shown: $e');
  }
}
