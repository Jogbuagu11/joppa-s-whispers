// Locations and the areas the player restores — pure Dart, fully unit tested.

/// One part of a location that changes when its task is done.
class AreaModel {
  final String id;
  final String name;

  /// Image ids for the area before and after it is restored.
  final String before;
  final String after;

  const AreaModel({
    required this.id,
    required this.name,
    required this.before,
    required this.after,
  });

  /// The image id to show, depending on whether the area is restored.
  String imageId({required bool restored}) => restored ? after : before;
}

/// A place in Joppa, loaded from content/locations.json.
class LocationModel {
  final String id;
  final String name;
  final List<AreaModel> areas;

  const LocationModel({
    required this.id,
    required this.name,
    required this.areas,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
    id: json['id'] as String,
    name: json['name'] as String,
    areas: [
      for (final a in json['areas'] as List<dynamic>)
        AreaModel(
          id: (a as Map<String, dynamic>)['id'] as String,
          name: a['name'] as String,
          before: a['before'] as String,
          after: a['after'] as String,
        ),
    ],
  );

  /// How many of this location's areas are in [restoredAreaIds].
  int restoredCount(Set<String> restoredAreaIds) =>
      areas.where((a) => restoredAreaIds.contains(a.id)).length;
}

/// The picture file for a location image id in assets/locations/, or null if
/// that art has not been delivered yet.
String? locationAssetFor(String imageId, Set<String> availableAssets) {
  for (final ext in const ['png', 'webp', 'jpg']) {
    final path = 'assets/locations/$imageId.$ext';
    if (availableAssets.contains(path)) return path;
  }
  return null;
}
