import 'package:flutter_test/flutter_test.dart';
import 'package:whispers_of_joppa/domain/locations.dart';

void main() {
  final location = LocationModel.fromJson({
    'id': 'bakehouse',
    'name': "Esther's Bakehouse",
    'areas': [
      {
        'id': 'bakehouse_door',
        'name': 'Doorway',
        'before': 'loc_bakehouse_door_before',
        'after': 'loc_bakehouse_door_after',
      },
      {
        'id': 'bakehouse_oven',
        'name': 'Oven',
        'before': 'loc_bakehouse_oven_before',
        'after': 'loc_bakehouse_oven_after',
      },
    ],
  });

  test('fromJson reads the location and its areas', () {
    expect(location.id, 'bakehouse');
    expect(location.name, "Esther's Bakehouse");
    expect(location.areas.length, 2);
    expect(location.areas[1].id, 'bakehouse_oven');
    expect(location.areas[1].name, 'Oven');
  });

  test(
    'an area shows its before image until restored, then its after image',
    () {
      final door = location.areas.first;
      expect(door.imageId(restored: false), 'loc_bakehouse_door_before');
      expect(door.imageId(restored: true), 'loc_bakehouse_door_after');
    },
  );

  test('restoredCount counts only this location\'s restored areas', () {
    expect(location.restoredCount({}), 0);
    expect(location.restoredCount({'bakehouse_oven', 'somewhere_else'}), 1);
    expect(location.restoredCount({'bakehouse_oven', 'bakehouse_door'}), 2);
  });

  test('locationAssetFor finds delivered art in any allowed format', () {
    const available = {'assets/locations/loc_bakehouse_door_after.webp'};
    expect(
      locationAssetFor('loc_bakehouse_door_after', available),
      'assets/locations/loc_bakehouse_door_after.webp',
    );
    expect(locationAssetFor('loc_bakehouse_door_before', available), isNull);
  });
}
