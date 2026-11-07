import 'dart:async';

import 'package:flutter/material.dart';

/// Re-themes [child] with a colour scheme derived from the station's image,
/// so the player's accent matches the station artwork. Falls back to the
/// app theme while loading or if the image can't be read (no favicon, broken
/// URL, or cross-origin restrictions on web).
class StationTheme extends StatefulWidget {
  final Uri? imageUrl;
  final Widget child;
  const StationTheme({super.key, required this.imageUrl, required this.child});

  @override
  State<StationTheme> createState() => _StationThemeState();
}

class _StationThemeState extends State<StationTheme> {
  // Shared across instances: one extraction per image and brightness.
  static final Map<String, Future<ColorScheme?>> _cache = {};

  ColorScheme? _scheme;
  String? _key;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(StationTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _resolve();
  }

  void _resolve() {
    final url = widget.imageUrl?.toString() ?? '';
    final brightness = Theme.of(context).brightness;
    final key = '$url|${brightness.name}';
    if (key == _key) return;
    _key = key;

    if (!url.startsWith('http')) {
      setState(() => _scheme = null);
      return;
    }

    _cache[key] ??=
        ColorScheme.fromImageProvider(
              provider: NetworkImage(url),
              brightness: brightness,
              // Keeps the scheme close to the artwork's own colours.
              dynamicSchemeVariant: DynamicSchemeVariant.content,
            )
            .then<ColorScheme?>((s) => s)
            .timeout(const Duration(seconds: 8))
            .catchError((Object _) => null);

    _cache[key]!.then((scheme) {
      if (mounted && _key == key) setState(() => _scheme = scheme);
    });
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return AnimatedTheme(
      data: _scheme == null ? base : base.copyWith(colorScheme: _scheme),
      duration: const Duration(milliseconds: 400),
      child: widget.child,
    );
  }
}
