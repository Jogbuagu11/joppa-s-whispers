// The analytics events the game sends, and the rules about them. Pure Dart,
// fully unit tested. Events never carry personal data: only game ids
// (an order, a task, a product) and small numbers.
abstract final class AnalyticsEvent {
  static const tutorialStep = 'tutorial_step';
  static const tutorialComplete = 'tutorial_complete';
  static const merge = 'merge';
  static const generatorTap = 'generator_tap';
  static const orderComplete = 'order_complete';
  static const taskComplete = 'task_complete';
  static const chapterComplete = 'chapter_complete';
  static const outOfEnergy = 'out_of_energy';
  static const purchaseStarted = 'purchase_started';
  static const purchaseComplete = 'purchase_complete';
  static const adWatched = 'ad_watched';
  static const letterOpened = 'letter_opened';
  static const sessionStart = 'session_start';
  static const sessionEnd = 'session_end';
}

/// Events Firebase records by itself. Its library refuses these names from
/// an app, so the game does not send its own copy.
const sentByFirebaseItself = {AnalyticsEvent.sessionStart};

/// Every event name the game uses.
const allAnalyticsEvents = [
  AnalyticsEvent.tutorialStep,
  AnalyticsEvent.tutorialComplete,
  AnalyticsEvent.merge,
  AnalyticsEvent.generatorTap,
  AnalyticsEvent.orderComplete,
  AnalyticsEvent.taskComplete,
  AnalyticsEvent.chapterComplete,
  AnalyticsEvent.outOfEnergy,
  AnalyticsEvent.purchaseStarted,
  AnalyticsEvent.purchaseComplete,
  AnalyticsEvent.adWatched,
  AnalyticsEvent.letterOpened,
  AnalyticsEvent.sessionStart,
  AnalyticsEvent.sessionEnd,
];

/// Whether Firebase accepts [name] as an app's own event: letters, digits
/// and underscores, starting with a letter, at most 40 characters, and not
/// one of the prefixes it keeps for itself.
bool isValidEventName(String name) =>
    RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,39}$').hasMatch(name) &&
    !name.startsWith('firebase_') &&
    !name.startsWith('google_') &&
    !name.startsWith('ga_');

/// Merges and generator taps happen constantly, so only one in this many is
/// sent.
const sampleEvery = 10;

/// Whether the [count]th occurrence (counting from 1) of a frequent event is
/// one of those sent: the first, then every [every]th after it.
bool isSampled(int count, {int every = sampleEvery}) =>
    every <= 1 || (count >= 1 && (count - 1) % every == 0);

/// The parameter keys an event may carry. Anything else is dropped, so a
/// mistake elsewhere can never send a name, an email or an account id.
const allowedParamKeys = {
  'step',
  'order_id',
  'task_id',
  'chapter_id',
  'product_id',
  'letter_id',
  'reward',
  'seconds',
  'sampled_1_in',
};

/// [params] reduced to what may be sent: allowed keys only, values that are
/// numbers or short text.
Map<String, Object> safeParams(Map<String, Object?> params) => {
  for (final entry in params.entries)
    if (allowedParamKeys.contains(entry.key))
      if (entry.value case final num n)
        entry.key: n
      else if (entry.value case final String s when s.length <= 100)
        entry.key: s,
};

/// The product ids of purchases newly put into the game: those in [after]
/// but not in [before], looked up in what the server listed.
List<String> newlyAppliedProducts(
  Set<String> before,
  Set<String> after,
  Map<String, String> productByTransaction,
) => [
  for (final id in after)
    if (!before.contains(id)) ?productByTransaction[id],
];
