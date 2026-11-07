import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:radio_browser_flutter/radio_browser_flutter.dart' show Station;
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/settings_controller.dart';
import '../../data/country_names.dart';
import '../../dialogs/location_pickers.dart' show flagEmoji;
import 'station_artwork.dart';
import 'station_theme.dart';
import 'visualizer.dart';

const double _miniHeight = 72;
const double _miniArtSize = 52;
const double _maxContentWidth = 560;

/// Bottom player that expands into a full-screen "now playing" view.
///
/// Tap the mini bar or drag it up to expand; drag down, press the chevron or
/// use system back to collapse. The station artwork morphs between the two
/// layouts, and both are themed from the station image.
class PlayerPanel extends StatefulWidget {
  final SettingsController controller;
  final Station station;
  const PlayerPanel({
    super.key,
    required this.controller,
    required this.station,
  });

  /// Height the panel occupies when collapsed, for padding content behind it.
  static double collapsedHeight(BuildContext context) =>
      _miniHeight + MediaQuery.paddingOf(context).bottom;

  @override
  State<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends State<PlayerPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _panel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  double _travel = 1;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  void _animateTo(double target) {
    if (_reduceMotion) {
      _panel.value = target;
    } else {
      _panel.animateTo(target, curve: Curves.easeOutCubic);
    }
  }

  void _expand() => _animateTo(1);
  void _collapse() => _animateTo(0);

  void _onDragUpdate(DragUpdateDetails details) {
    _panel.value -= (details.primaryDelta ?? 0) / _travel;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -400) {
      _expand();
    } else if (velocity > 400) {
      _collapse();
    } else {
      _panel.value > 0.5 ? _expand() : _collapse();
    }
  }

  @override
  void dispose() {
    _panel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StationTheme(
      imageUrl: widget.station.favicon,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final padding = MediaQuery.paddingOf(context);
          final collapsed = _miniHeight + padding.bottom;
          _travel = math.max(1, size.height - collapsed);
          final layout = _FullLayout.compute(size, padding);

          return AnimatedBuilder(
            // Settings too, so toggling the visualiser updates immediately.
            animation: Listenable.merge([_panel, widget.controller]),
            builder: (context, _) {
              final t = _panel.value;
              final scheme = Theme.of(context).colorScheme;
              final miniOpacity = (1 - t / 0.25).clamp(0.0, 1.0);
              final fullOpacity = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
              final artRect = Rect.lerp(
                const Rect.fromLTWH(
                  10,
                  (_miniHeight - _miniArtSize) / 2,
                  _miniArtSize,
                  _miniArtSize,
                ),
                layout.artwork,
                Curves.easeInOut.transform(t),
              )!;

              return PopScope(
                canPop: t == 0,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) _collapse();
                },
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: lerpDouble(collapsed, size.height, t),
                    width: size.width,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: _onDragUpdate,
                      onVerticalDragEnd: _onDragEnd,
                      child: Material(
                        color: Color.lerp(
                          scheme.surfaceContainerHigh,
                          scheme.surface,
                          t,
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          minHeight: size.height,
                          maxHeight: size.height,
                          child: Stack(
                            children: [
                              if (fullOpacity > 0)
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: fullOpacity,
                                    child: _Backdrop(scheme: scheme),
                                  ),
                                ),
                              if (fullOpacity > 0)
                                Opacity(
                                  opacity: fullOpacity,
                                  child: IgnorePointer(
                                    ignoring: t < 0.95,
                                    child: _FullPlayer(
                                      controller: widget.controller,
                                      station: widget.station,
                                      layout: layout,
                                      onCollapse: _collapse,
                                    ),
                                  ),
                                ),
                              if (miniOpacity > 0)
                                Opacity(
                                  opacity: miniOpacity,
                                  child: IgnorePointer(
                                    ignoring: t > 0.05,
                                    child: _MiniBar(
                                      controller: widget.controller,
                                      station: widget.station,
                                      onExpand: _expand,
                                    ),
                                  ),
                                ),
                              if (fullOpacity > 0)
                                Positioned.fromRect(
                                  rect: layout.artwork.inflate(
                                    layout.artwork.width * 0.18,
                                  ),
                                  child: Opacity(
                                    opacity: fullOpacity,
                                    child: _Glow(controller: widget.controller),
                                  ),
                                ),
                              if (t < 1)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: Opacity(
                                    opacity: 1 - t,
                                    child: Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                                ),
                              Positioned.fromRect(
                                rect: artRect,
                                child: IgnorePointer(
                                  ignoring: t < 0.95,
                                  child: StationArtwork(
                                    widget.station,
                                    borderRadius: lerpDouble(6, 12, t)!,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Breathing glow behind the full-screen artwork (part of the visualiser).
class _Glow extends StatelessWidget {
  final SettingsController controller;
  const _Glow({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!visualizerAllowed(context, controller.showVisualizer)) {
      return const SizedBox.shrink();
    }
    return _PlaybackBuilder(
      controller: controller,
      builder: (context, state, _) => VisualizerGlow(active: state.playing),
    );
  }
}

/// Geometry of the expanded player, shared by the artwork morph and layout.
///
/// * Narrow (phones, portrait): artwork on top, details below. The artwork
///   shrinks on short screens so the controls always keep their space.
/// * Wide (landscape tablets, desktop, landscape phones): artwork on the
///   left, details on the right, both centred.
class _FullLayout {
  /// Height the details need before they have to scroll.
  static const minInfoHeight = 300.0;
  static const _topBarHeight = 56.0;

  final Rect artwork;
  final double topBar;
  final Rect info;
  final bool wide;

  const _FullLayout({
    required this.artwork,
    required this.topBar,
    required this.info,
    required this.wide,
  });

  factory _FullLayout.compute(Size size, EdgeInsets padding) {
    final top = padding.top + _topBarHeight;
    final bottom = size.height - padding.bottom;
    final left = padding.left;
    final width = size.width - padding.horizontal;
    final height = bottom - top;
    final wide = width >= 600 && width > height * 1.2;

    if (wide) {
      const gutter = 32.0;
      const gap = 48.0;
      final infoWidth = ((width - gutter * 2 - gap) * 0.5).clamp(280.0, 480.0);
      final art = math.max(
        0.0,
        math.min(height - gutter * 2, width - gutter * 2 - gap - infoWidth),
      );
      final startX = left + (width - (art + gap + infoWidth)) / 2;
      final artTop = top + (height - art) / 2;
      return _FullLayout(
        artwork: Rect.fromLTWH(startX, artTop, art, art),
        topBar: padding.top,
        info: Rect.fromLTWH(
          startX + art + gap,
          top + 16,
          infoWidth,
          math.max(0, height - 32),
        ),
        wide: true,
      );
    }

    const horizontal = 24.0;
    final contentWidth = math.min(width, _maxContentWidth);
    final side = left + (width - contentWidth) / 2 + horizontal;
    final artTop = top + 16;
    var art = math.min(
      contentWidth - horizontal * 2,
      height - 16 - 24 - minInfoHeight - 16,
    );
    // Too small to be worth showing: give the space to the details.
    if (art < 96) art = 0;
    final infoTop = art == 0 ? artTop : artTop + art + 24;
    return _FullLayout(
      artwork: Rect.fromLTWH(left + (width - art) / 2, artTop, art, art),
      topBar: padding.top,
      info: Rect.fromLTRB(
        side,
        infoTop,
        size.width - padding.right - (side - left),
        math.max(infoTop, bottom - 16),
      ),
      wide: false,
    );
  }
}

class _Backdrop extends StatelessWidget {
  final ColorScheme scheme;
  const _Backdrop({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.primaryContainer, scheme.surface],
          stops: const [0, 0.75],
        ),
      ),
    );
  }
}

/// Rebuilds with the latest playback state and now-playing metadata.
class _PlaybackBuilder extends StatelessWidget {
  final SettingsController controller;
  final Widget Function(BuildContext, PlaybackState, MediaItem?) builder;
  const _PlaybackBuilder({required this.controller, required this.builder});

  @override
  Widget build(BuildContext context) {
    final audio = controller.audio;
    return StreamBuilder<PlaybackState>(
      stream: audio.playbackState,
      initialData: audio.playbackState.value,
      builder: (context, state) => StreamBuilder<MediaItem?>(
        stream: audio.mediaItem,
        initialData: audio.mediaItem.value,
        builder: (context, item) =>
            builder(context, state.data ?? PlaybackState(), item.data),
      ),
    );
  }
}

/// "🇩🇪 Germany" for the station's country, or null if unknown.
String? _countryLabel(Station station) {
  final code = station.countryCode.toUpperCase();
  // ignore: deprecated_member_use
  final name = countryNames[code] ?? station.country;
  if (name.isEmpty) return null;
  return code.length == 2 ? '${flagEmoji(code)} $name' : name;
}

extension on PlaybackState {
  bool get isBuffering =>
      playing &&
      (processingState == AudioProcessingState.loading ||
          processingState == AudioProcessingState.buffering);
}

String _stationSubtitle(Station station) {
  // ignore: deprecated_member_use
  final country = station.country;
  return [station.state, country].where((s) => s.isNotEmpty).join(', ');
}

/// Large play/pause button with a buffering ring.
class _PlayPauseButton extends StatelessWidget {
  final SettingsController controller;
  final PlaybackState state;
  final double size;
  final bool filled;
  const _PlayPauseButton({
    required this.controller,
    required this.state,
    required this.size,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = Icon(
      state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: size * (filled ? 0.55 : 0.75),
    );
    void onPressed() => controller.updatePlayingStatus(!state.playing);
    final tooltip = state.playing ? 'Pause' : 'Play';
    final button = filled
        ? IconButton.filled(
            onPressed: onPressed,
            tooltip: tooltip,
            icon: icon,
            style: IconButton.styleFrom(
              fixedSize: Size.square(size),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
          )
        : IconButton(onPressed: onPressed, tooltip: tooltip, icon: icon);
    return SizedBox.square(
      dimension: filled ? size + 8 : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          button,
          if (state.isBuffering)
            IgnorePointer(
              child: SizedBox.square(
                dimension: filled ? size + 8 : 36,
                child: CircularProgressIndicator(
                  strokeWidth: filled ? 3 : 2,
                  color: filled ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final SettingsController controller;
  final Station station;
  final VoidCallback onExpand;
  const _MiniBar({
    required this.controller,
    required this.station,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: _miniHeight,
      child: _PlaybackBuilder(
        controller: controller,
        builder: (context, state, item) {
          final nowPlaying = item?.artist;
          return Stack(
            children: [
              Semantics(
                button: true,
                label: 'Open player',
                onTap: onExpand,
                child: InkWell(
                  onTap: onExpand,
                  child: Row(
                    children: [
                      const SizedBox(width: 10 + _miniArtSize + 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              station.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nowPlaying ?? _stationSubtitle(station),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PlayPauseButton(
                        controller: controller,
                        state: state,
                        size: 32,
                      ),
                      IconButton(
                        tooltip: 'Stop',
                        icon: const Icon(Icons.stop_rounded),
                        onPressed: state.playing
                            ? controller.stopPlayback
                            : null,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
              if (state.isBuffering)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FullPlayer extends StatelessWidget {
  final SettingsController controller;
  final Station station;
  final _FullLayout layout;
  final VoidCallback onCollapse;
  const _FullPlayer({
    required this.controller,
    required this.station,
    required this.layout,
    required this.onCollapse,
  });

  bool get _hasHomepage => station.homePage.toString().startsWith('http');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Stack(
      children: [
        // Top bar
        Positioned(
          top: layout.topBar,
          left: 4,
          right: 4,
          height: 56,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Minimise player',
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                onPressed: onCollapse,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Now playing',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (_countryLabel(station) case final country?)
                      Text(
                        country,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                  ],
                ),
              ),
              // Balances the chevron so the title stays centred.
              const SizedBox(width: 48),
            ],
          ),
        ),
        // Details: below the artwork (narrow) or beside it (wide)
        Positioned.fromRect(
          rect: layout.info,
          child: _PlaybackBuilder(
            controller: controller,
            builder: (context, state, item) {
              final nowPlaying = item?.artist;
              final showVisualizer = visualizerAllowed(
                context,
                controller.showVisualizer,
              );
              Widget column({required bool fill}) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Text(
                    station.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nowPlaying ?? _stationSubtitle(station),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoChips(controller: controller, station: station),
                  if (fill)
                    Expanded(
                      child: showVisualizer
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              // Center loosens Expanded's tight height so
                              // the cap applies; otherwise the bars stretch
                              // to fill all spare space on wide layouts.
                              child: Center(
                                child: SizedBox(
                                  height: 72,
                                  child: Visualizer(active: state.playing),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    )
                  else
                    const SizedBox(height: 16),
                  _LiveBar(state: state),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        tooltip: 'Stop',
                        iconSize: 32,
                        icon: const Icon(Icons.stop_rounded),
                        onPressed: state.playing
                            ? controller.stopPlayback
                            : null,
                      ),
                      _PlayPauseButton(
                        controller: controller,
                        state: state,
                        size: 72,
                        filled: true,
                      ),
                      IconButton(
                        tooltip: 'Visit station website',
                        iconSize: 28,
                        icon: const Icon(Icons.open_in_new_rounded),
                        onPressed: _hasHomepage
                            ? () => launchUrl(
                                station.homePage,
                                mode: LaunchMode.externalApplication,
                              )
                            : null,
                      ),
                    ],
                  ),
                ],
              );

              // Fill the space when it fits (visualiser takes the slack);
              // scroll only on very short screens, so vertical drags still
              // collapse the panel normally.
              return LayoutBuilder(
                builder: (context, constraints) =>
                    constraints.maxHeight >= _FullLayout.minInfoHeight
                    ? column(fill: true)
                    : SingleChildScrollView(child: column(fill: false)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InfoChips extends StatelessWidget {
  final SettingsController controller;
  final Station station;
  const _InfoChips({required this.controller, required this.station});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _LikeButton(controller: controller, station: station),
      if (station.codec.isNotEmpty)
        _chip(
          context,
          const Icon(Icons.graphic_eq_rounded, size: 18),
          station.bitrate > 0
              ? '${station.codec} · ${station.bitrate} kbps'
              : station.codec,
        ),
      for (final tag in station.tags.where((t) => t.isNotEmpty).take(4))
        _chip(context, null, tag),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _chip(BuildContext context, Widget? avatar, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: avatar,
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    );
  }
}

/// YouTube Music-style like pill: heart plus the station's vote count.
class _LikeButton extends StatelessWidget {
  final SettingsController controller;
  final Station station;
  const _LikeButton({required this.controller, required this.station});

  static String _compact(int n) {
    if (n < 1000) return '$n';
    if (n < 1000000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k < 10 ? 1 : 0)}K';
    }
    final m = n / 1000000;
    return '${m.toStringAsFixed(m < 10 ? 1 : 0)}M';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final liked = controller.isLiked(station);
    final votes = controller.voteCount(station);
    return Semantics(
      toggled: liked,
      child: ActionChip(
        tooltip: liked ? 'Unlike' : 'Like this station',
        avatar: Icon(
          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 18,
          color: liked ? scheme.onPrimary : scheme.onSurface,
        ),
        label: Text(
          votes > 0 ? _compact(votes) : 'Like',
          style: TextStyle(color: liked ? scheme.onPrimary : null),
        ),
        onPressed: () => controller.toggleLike(station),
        visualDensity: VisualDensity.compact,
        backgroundColor: liked
            ? scheme.primary
            : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
    );
  }
}

/// LIVE badge and connection status, with a loading line while connecting.
/// (Live streams have no duration, so there's no seek bar.)
class _LiveBar extends StatelessWidget {
  final PlaybackState state;
  const _LiveBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = state.isBuffering
        ? 'Connecting…'
        : state.processingState == AudioProcessingState.error
        ? 'Stream unavailable'
        : state.playing
        ? 'Playing'
        : 'Stopped';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Only while connecting: a live stream has nothing to seek, so a
        // static bar would say nothing. The slot keeps its height so the
        // layout doesn't jump when the line fades out.
        SizedBox(
          height: 4,
          child: AnimatedOpacity(
            opacity: state.isBuffering ? 1 : 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
            child: state.isBuffering
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: scheme.onSurface.withValues(alpha: 0.12),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: state.playing ? scheme.error : scheme.outline,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'LIVE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: state.playing ? scheme.onError : scheme.surface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            Text(
              status,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
