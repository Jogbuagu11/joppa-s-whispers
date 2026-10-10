// What gets written to the save file — pure Dart, fully unit tested.
import 'package:whispers_of_joppa/domain/generator_types.dart';
import 'package:whispers_of_joppa/domain/save_migrations.dart';

export 'package:whispers_of_joppa/domain/save_migrations.dart';

/// The save format this build writes. Raise it, and add a step to
/// [migrateSave], whenever the format changes. Never break an existing save.

const currentSaveVersion = 7;

/// The most bought or gifted Manna a game may hold above its bar.
const maxBonusManna = 100000;

/// A tutorial position meaning "finished", whatever the number of steps.
const tutorialFinished = 1 << 20;

/// An item and the cell it sits in.
class SavedItem {
  final String itemId;
  final int col;
  final int row;

  const SavedItem({required this.itemId, required this.col, required this.row});

  Map<String, dynamic> toJson() => {'item_id': itemId, 'col': col, 'row': row};

  factory SavedItem.fromJson(Map<String, dynamic> json) => SavedItem(
    itemId: json['item_id'] as String,
    col: json['col'] as int,
    row: json['row'] as int,
  );
}

/// A generator, its level and the cell it sits in.
class SavedGenerator {
  final String generatorId;
  final int level;
  final int col;
  final int row;

  /// Its charges or countdown; null for a generator with no clock.
  final GeneratorTimer? timer;

  const SavedGenerator({
    required this.generatorId,
    required this.level,
    required this.col,
    required this.row,
    this.timer,
  });

  Map<String, dynamic> toJson() => {
    'generator_id': generatorId,
    'level': level,
    'col': col,
    'row': row,
    if (timer case final timer?) 'timer': timer.toJson(),
  };

  factory SavedGenerator.fromJson(Map<String, dynamic> json) => SavedGenerator(
    generatorId: json['generator_id'] as String,
    level: json['level'] as int,
    col: json['col'] as int,
    row: json['row'] as int,
    // Added without a new save version: absent in older saves.
    timer: GeneratorTimer.fromJson(json['timer']),
  );
}

/// Everything needed to put the player back exactly where they were.
class SaveState {
  final List<SavedItem> items;
  final List<SavedGenerator> generators;
  final int manna;
  final DateTime mannaLastRegen;
  final int talents;
  final int blessings;

  /// Pearls (bought currency).
  final int pearls;

  /// Store transactions whose contents are already in this game, so none is
  /// ever applied twice.
  final List<String> appliedTransactions;

  /// One-time products this game has received (for example the starter pack).
  final List<String> ownedProducts;
  final List<String> activeOrders;
  final List<String> pendingOrders;

  /// Orders already delivered, so they are never handed out again.
  final List<String> completedOrders;

  /// Story tasks already done.
  final List<String> completedTasks;

  /// Which tutorial hint is showing; [tutorialFinished] once it is over.
  final int tutorialStep;

  /// Free generator taps the tutorial has already given.
  final int tutorialFreeTapsUsed;

  /// Chapters whose closing message has been shown.
  final List<String> endingsSeen;

  /// The newest content version this game has been played with. A phone
  /// running older content must not take over or upload this game, because
  /// it would have to throw away the parts it does not know.
  final int contentVersion;
  final DateTime? lastOrderSkip;

  /// The day (yyyy-mm-dd) Manna ads were last watched, and how many that day.
  final String adDay;
  final int adMannaWatched;

  /// The last player level whose rewards were given. 0 means not recorded
  /// (a game saved before levels existed): nothing is owed for past levels.
  final int levelRewarded;

  /// Gifts (items, temporary generators) still waiting for room on the
  /// board, as `item:<id>` or `gen:<id>`.
  final List<String> pendingGrants;

  /// The generator boost switched on (0 = none).
  final int boost;

  /// Small records kept by later features, by name ("wheel", "jars"…).
  /// Each feature reads and writes its own; an unknown one is kept as is.
  final Map<String, dynamic> extras;

  const SaveState({
    required this.items,
    required this.generators,
    required this.manna,
    required this.mannaLastRegen,
    required this.talents,
    required this.blessings,
    this.pearls = 0,
    this.appliedTransactions = const [],
    this.ownedProducts = const [],
    required this.activeOrders,
    required this.pendingOrders,
    required this.completedOrders,
    required this.completedTasks,
    required this.tutorialStep,
    this.tutorialFreeTapsUsed = 0,
    this.endingsSeen = const [],
    this.contentVersion = 0,
    required this.lastOrderSkip,
    this.adDay = '',
    this.adMannaWatched = 0,
    this.levelRewarded = 0,
    this.pendingGrants = const [],
    this.boost = 0,
    this.extras = const {},
  });

  Map<String, dynamic> toJson() => {
    'save_version': currentSaveVersion,
    'items': [for (final i in items) i.toJson()],
    'generators': [for (final g in generators) g.toJson()],
    'manna': manna,
    'manna_last_regen': mannaLastRegen.toUtc().toIso8601String(),
    'talents': talents,
    'blessings': blessings,
    'pearls': pearls,
    'applied_transactions': appliedTransactions,
    'owned_products': ownedProducts,
    'active_orders': activeOrders,
    'pending_orders': pendingOrders,
    'completed_orders': completedOrders,
    'completed_tasks': completedTasks,
    'tutorial_step': tutorialStep,
    'tutorial_free_taps_used': tutorialFreeTapsUsed,
    'endings_seen': endingsSeen,
    'content_version': contentVersion,
    'last_order_skip': lastOrderSkip?.toUtc().toIso8601String(),
    'level_rewarded': levelRewarded,
    'pending_grants': pendingGrants,
    'boost': boost,
    if (extras.isNotEmpty) 'extras': extras,
    'ad_day': adDay,
    'ad_manna_watched': adMannaWatched,
  };

  /// Reads a save of any known version. Throws [FormatException] if the data
  /// is not a save this build understands.
  factory SaveState.fromJson(Map<String, dynamic> raw) {
    final json = migrateSave(raw);
    try {
      final skip = json['last_order_skip'] as String?;
      return SaveState(
        items: [
          for (final i in json['items'] as List<dynamic>)
            SavedItem.fromJson(i as Map<String, dynamic>),
        ],
        generators: [
          for (final g in json['generators'] as List<dynamic>)
            SavedGenerator.fromJson(g as Map<String, dynamic>),
        ],
        manna: json['manna'] as int,
        mannaLastRegen: DateTime.parse(json['manna_last_regen'] as String),
        talents: json['talents'] as int,
        blessings: json['blessings'] as int,
        pearls: json['pearls'] as int,
        appliedTransactions: List<String>.from(
          json['applied_transactions'] as List<dynamic>,
        ),
        ownedProducts: List<String>.from(
          json['owned_products'] as List<dynamic>,
        ),
        activeOrders: List<String>.from(json['active_orders'] as List<dynamic>),
        pendingOrders: List<String>.from(
          json['pending_orders'] as List<dynamic>,
        ),
        completedOrders: List<String>.from(
          json['completed_orders'] as List<dynamic>,
        ),
        completedTasks: List<String>.from(
          json['completed_tasks'] as List<dynamic>,
        ),
        tutorialStep: json['tutorial_step'] as int,
        // Added within version 4; absent in the earliest version 4 saves.
        tutorialFreeTapsUsed: json['tutorial_free_taps_used'] as int? ?? 0,
        endingsSeen: List<String>.from(
          json['endings_seen'] as List<dynamic>? ?? const [],
        ),
        contentVersion: json['content_version'] as int? ?? 0,
        lastOrderSkip: skip == null ? null : DateTime.parse(skip),
        adDay: json['ad_day'] as String,
        adMannaWatched: json['ad_manna_watched'] as int,
        levelRewarded: json['level_rewarded'] as int,
        // Added without a new save version: absent in older saves.
        pendingGrants: List<String>.from(
          json['pending_grants'] as List<dynamic>? ?? const [],
        ),
        boost: json['boost'] as int? ?? 0,
        // Anything that is not a set of records counts as none.
        extras: switch (json['extras']) {
          final Map<String, dynamic> records => Map.of(records),
          _ => const {},
        },
      );
    } on TypeError catch (e) {
      throw FormatException('Save file is missing or has a wrong field: $e');
    }
  }
}
