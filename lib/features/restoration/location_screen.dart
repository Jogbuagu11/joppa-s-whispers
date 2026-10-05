// Shows a location and each of its areas, before or after restoration.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/domain/locations.dart';

const _gold = Color(0xFFD4802A);
const _cream = Color(0xFFF3E6C8);
const _ink = Color(0xFF1A1205);

class LocationScreen extends StatefulWidget {
  const LocationScreen({
    super.key,
    required this.location,
    required this.restoredAreaIds,
    required this.availableAssets,
    this.justRestoredAreaId,
  });

  /// An area restored a moment ago. It is shown in its old state first and
  /// then changes in front of the player.
  final String? justRestoredAreaId;

  final LocationModel location;

  /// Ids of the areas the player has restored so far.
  final Set<String> restoredAreaIds;

  /// Every bundled asset path, used to find art that has been delivered.
  final Set<String> availableAssets;

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  // False until the just-restored area has been revealed.
  late bool _revealed = widget.justRestoredAreaId == null;

  @override
  void initState() {
    super.initState();
    if (!_revealed) {
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _revealed = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final availableAssets = widget.availableAssets;
    final restoredAreaIds = _revealed
        ? widget.restoredAreaIds
        : widget.restoredAreaIds.difference({widget.justRestoredAreaId});
    final done = location.restoredCount(restoredAreaIds);
    return Scaffold(
      key: const Key('location_screen'),
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: _gold,
        title: Text(location.name, key: const Key('location_name')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '$done of ${location.areas.length} restored',
                key: const Key('location_progress'),
                style: const TextStyle(color: _cream, fontSize: 14),
              ),
            ),
            Expanded(
              // A location has only a handful of areas, so they are all
              // built at once (shrink-wrapped) inside one scrolling page.
              child: SingleChildScrollView(
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                  children: [
                    for (final area in location.areas)
                      _AreaCard(
                        area: area,
                        restored: restoredAreaIds.contains(area.id),
                        availableAssets: availableAssets,
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('location_continue'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: FilledButton.styleFrom(backgroundColor: _gold),
                  child: const Text(
                    'Back to the rooftop',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.area,
    required this.restored,
    required this.availableAssets,
  });

  final AreaModel area;
  final bool restored;
  final Set<String> availableAssets;

  @override
  Widget build(BuildContext context) {
    final imageId = area.imageId(restored: restored);
    final asset = locationAssetFor(imageId, availableAssets);
    return Container(
      key: Key('area_${area.id}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: restored ? _gold : const Color(0xFF5C3D0D),
          width: restored ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              // The key carries the image id: a new id means a new picture,
              // which the switcher fades in over the old one.
              child: SizedBox.expand(
                key: ValueKey(imageId),
                child: asset != null
                    ? Image.asset(
                        asset,
                        fit: BoxFit.cover,
                        // Cards are small; never decode the full-size picture.
                        cacheWidth: 600,
                        errorBuilder: (context, error, stack) =>
                            _Placeholder(restored: restored),
                      )
                    : _Placeholder(restored: restored),
              ),
            ),
          ),
          Container(
            color: const Color(0xFF2A1F08),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    area.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _cream,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  restored ? 'Restored' : 'Not yet',
                  key: Key('area_state_${area.id}'),
                  style: TextStyle(
                    color: restored ? _gold : const Color(0xFF8A7A5A),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stands in for location art that has not been delivered: a cold, boarded-up
/// look before restoration and a warm, lit look after.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.restored});

  final bool restored;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: restored
              ? const [Color(0xFFE8B66A), Color(0xFFB8652A)]
              : const [Color(0xFF4A4640), Color(0xFF26231F)],
        ),
      ),
      child: Center(
        child: Icon(
          restored ? Icons.wb_sunny_outlined : Icons.construction,
          color: restored ? const Color(0xFF5A2E0A) : const Color(0xFF8A857C),
          size: 36,
        ),
      ),
    );
  }
}
