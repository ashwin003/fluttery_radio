import 'package:flutter/material.dart';
import 'package:radio_browser_flutter/radio_browser_flutter.dart' show Station;

/// A station's favicon with a themed placeholder while loading or when the
/// station has no (or a broken) image.
class StationArtwork extends StatelessWidget {
  final Station station;
  final double borderRadius;
  const StationArtwork(this.station, {super.key, this.borderRadius = 8});

  static bool hasImage(Station station) =>
      station.favicon.toString().startsWith('http');

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(station.name);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: !hasImage(station)
          ? placeholder
          : Image.network(
              station.favicon.toString(),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => placeholder,
              frameBuilder: (_, child, frame, wasSyncLoaded) =>
                  wasSyncLoaded || frame != null ? child : placeholder,
            ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String name;
  const _Placeholder(this.name);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        return Container(
          color: scheme.primaryContainer,
          alignment: Alignment.center,
          child: Icon(
            Icons.radio,
            size: size.isFinite ? size * 0.45 : 24,
            color: scheme.onPrimaryContainer,
            semanticLabel: name,
          ),
        );
      },
    );
  }
}
