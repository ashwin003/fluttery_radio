import 'package:flutter/material.dart';
import 'package:radio_browser_flutter/radio_browser_flutter.dart' show Station;

import 'player/station_artwork.dart';

/// "jazz, swing · MP3 128 kbps"
String stationDetails(Station station, {int maxTags = 2}) {
  final tags = station.tags.where((t) => t.isNotEmpty).take(maxTags).join(', ');
  final codec = station.codec.isEmpty || station.codec == 'UNKNOWN'
      ? ''
      : station.bitrate > 0
      ? '${station.codec} ${station.bitrate} kbps'
      : station.codec;
  return [tags, codec].where((s) => s.isNotEmpty).join(' · ');
}

/// Shown on the station that's currently selected in the player.
class _NowPlayingBadge extends StatelessWidget {
  final double size;
  const _NowPlayingBadge({this.size = 20});

  @override
  Widget build(BuildContext context) => Icon(
    Icons.graphic_eq_rounded,
    size: size,
    color: Theme.of(context).colorScheme.primary,
    semanticLabel: 'Now playing',
  );
}

class StationTile extends StatelessWidget {
  final Station station;
  final bool selected;
  final bool liked;
  final VoidCallback onTap;
  const StationTile({
    super.key,
    required this.station,
    required this.selected,
    required this.liked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = stationDetails(station);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SizedBox.square(
        dimension: 56,
        child: StationArtwork(station, borderRadius: 10),
      ),
      title: Text(
        station.name.trim(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? theme.colorScheme.primary : null,
        ),
      ),
      subtitle: details.isEmpty
          ? null
          : Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (liked)
            Icon(
              Icons.favorite_rounded,
              size: 18,
              color: theme.colorScheme.primary,
              semanticLabel: 'Liked',
            ),
          if (selected) ...[const SizedBox(width: 8), const _NowPlayingBadge()],
        ],
      ),
      onTap: onTap,
    );
  }
}

class StationCard extends StatelessWidget {
  static const _textPadding = EdgeInsets.fromLTRB(12, 10, 12, 10);

  static TextStyle? _titleStyle(ThemeData theme) =>
      theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);
  static TextStyle? _detailsStyle(ThemeData theme) => theme.textTheme.bodySmall;

  /// Height of the text below the artwork (two-line name plus a details
  /// line) at the current text scale. Grids use it to size cards exactly.
  static double textAreaHeight(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    double lines(TextStyle? style, int count) {
      final painter = TextPainter(
        text: TextSpan(text: List.filled(count, 'Ag').join('\n'), style: style),
        textScaler: scaler,
        textDirection: TextDirection.ltr,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    return _textPadding.vertical +
        lines(_titleStyle(theme), 2) +
        2 +
        lines(_detailsStyle(theme), 1) +
        1; // rounding slack
  }

  final Station station;
  final bool selected;
  final bool liked;
  final VoidCallback onTap;
  const StationCard({
    super.key,
    required this.station,
    required this.selected,
    required this.liked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final details = stationDetails(station, maxTags: 1);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  StationArtwork(station, borderRadius: 0),
                  if (liked || selected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (liked)
                              Icon(
                                Icons.favorite_rounded,
                                size: 16,
                                color: scheme.primary,
                                semanticLabel: 'Liked',
                              ),
                            if (liked && selected) const SizedBox(width: 4),
                            if (selected) const _NowPlayingBadge(size: 16),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: _textPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle(theme),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _detailsStyle(
                          theme,
                        )?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
