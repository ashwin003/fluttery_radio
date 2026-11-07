import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Whether the visualiser should be shown: the user setting is on and the
/// platform hasn't asked to reduce motion.
bool visualizerAllowed(BuildContext context, bool userSetting) =>
    userSetting && !MediaQuery.disableAnimationsOf(context);

/// A soft glow in the station's colours that breathes while playing.
/// Decorative, like [Visualizer]; shown behind the full-screen artwork.
class VisualizerGlow extends StatefulWidget {
  final bool active;
  const VisualizerGlow({super.key, required this.active});

  @override
  State<VisualizerGlow> createState() => _VisualizerGlowState();
}

class _VisualizerGlowState extends State<VisualizerGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(VisualizerGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.active && _pulse.isAnimating) {
      // Settle to the dim end rather than freezing mid-pulse.
      _pulse.animateTo(0, duration: const Duration(milliseconds: 600));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_pulse.value);
          return Transform.scale(
            scale: 0.92 + 0.12 * t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.25 + 0.3 * t),
                    scheme.tertiary.withValues(alpha: 0.12 + 0.12 * t),
                    scheme.primary.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Animated equaliser-style bars.
///
/// This is decorative: just_audio doesn't expose spectrum data, so the bars
/// are driven by layered sine waves and ease in/out with playback rather
/// than reacting to the actual audio.
class Visualizer extends StatefulWidget {
  /// Animate while true; bars settle flat when false.
  final bool active;
  final int barCount;

  /// Bar width relative to its slot (the rest is spacing).
  final double barFill;
  const Visualizer({
    super.key,
    required this.active,
    this.barCount = 32,
    this.barFill = 0.6,
  });

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  late List<double> _speeds;
  late List<double> _phases;
  Duration _elapsed = Duration.zero;
  Duration _last = Duration.zero;

  /// 0 = flat, 1 = fully animated. Eases towards the target.
  double _level = 0;

  @override
  void initState() {
    super.initState();
    _seed();
    if (widget.active) _ticker.start();
  }

  void _seed() {
    final random = math.Random(widget.barCount);
    _speeds = List.generate(
      widget.barCount,
      (_) => 1.5 + random.nextDouble() * 3,
    );
    _phases = List.generate(
      widget.barCount,
      (_) => random.nextDouble() * math.pi * 2,
    );
  }

  @override
  void didUpdateWidget(Visualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barCount != widget.barCount) _seed();
    if (widget.active && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _elapsed += Duration(microseconds: (dt * 1e6).round());
    final target = widget.active ? 1.0 : 0.0;
    _level += (target - _level) * math.min(1, dt * 4);
    if (!widget.active && _level < 0.01) {
      _level = 0;
      _ticker.stop();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  List<double> _heights() {
    final t = _elapsed.inMicroseconds / 1e6;
    return List.generate(widget.barCount, (i) {
      final a = math.sin(t * _speeds[i] + _phases[i]);
      final b = math.sin(t * _speeds[i] * 0.37 + _phases[i] * 1.7);
      // Taper the edges so the shape reads as a spectrum.
      final x = widget.barCount == 1 ? 0.5 : i / (widget.barCount - 1);
      final envelope = 0.55 + 0.45 * math.sin(x * math.pi);
      final raw = (0.5 + 0.3 * a + 0.2 * b).clamp(0.0, 1.0) * envelope;
      return 0.08 + raw * 0.92 * _level;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _BarsPainter(
            heights: _heights(),
            fill: widget.barFill,
            colors: [scheme.primary, scheme.tertiary],
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> heights;
  final double fill;
  final List<Color> colors;
  _BarsPainter({
    required this.heights,
    required this.fill,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty || size.isEmpty) return;
    final slot = size.width / heights.length;
    final barWidth = slot * fill;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: colors,
      ).createShader(Offset.zero & size);
    final radius = Radius.circular(barWidth / 2);
    for (var i = 0; i < heights.length; i++) {
      final h = math.max(barWidth, heights[i] * size.height);
      final left = i * slot + (slot - barWidth) / 2;
      // Centred vertically, growing up and down.
      final top = (size.height - h) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top, barWidth, h), radius),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => true;
}
