// A character's face in a ring: their full-length portrait, zoomed in on
// the head.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/data/content_loader.dart';

/// The zoom that frames an adult's head and shoulders.
const double defaultFaceZoom = 2.3;

/// How one character is shown in a ring: their colour and their framing.
typedef CharacterLook = ({Color? color, double zoom});

/// character_id -> their look, read from content/characters.json.
Map<String, CharacterLook> characterLooks(Object? json) => {
  if (json is List<dynamic>)
    for (final c in json)
      if (c case {'id': final String id})
        id: (
          color: switch (parseHexColor(c['color'] as String?)) {
            final int argb => Color(argb),
            null => null,
          },
          zoom: (c['face_zoom'] as num?)?.toDouble() ?? defaultFaceZoom,
        ),
};

class FacePortrait extends StatelessWidget {
  const FacePortrait({
    super.key,
    required this.asset,
    required this.size,
    required this.name,
    this.ring = GamePalette.person,
    this.zoom = defaultFaceZoom,
  });

  /// The portrait file (a tall, full-length picture with the head at the top).
  final String asset;
  final double size;

  /// Used for the initial shown when the picture is missing.
  final String name;
  final Color ring;

  /// How far to zoom in on the top of the picture: 2 shows its top half.
  /// A child, whose head is larger in the picture, needs less.
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final inner = size - 4;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
      child: ClipOval(
        child: OverflowBox(
          // The picture is laid out larger than the ring and hung from its
          // top, so the ring shows the head and shoulders only.
          alignment: const Alignment(0, -0.92),
          minWidth: inner * zoom,
          maxWidth: inner * zoom,
          minHeight: inner * zoom,
          maxHeight: inner * zoom,
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            // A character with no portrait yet shows their initial.
            errorBuilder: (context, error, stack) => ColoredBox(
              color: GamePalette.panelLight,
              child: Align(
                alignment: const Alignment(0, -0.68),
                child: Text(
                  name.isEmpty ? '?' : name[0],
                  style: TextStyle(
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.bold,
                    color: ring,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
