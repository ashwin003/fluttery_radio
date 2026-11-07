import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

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
/// When [spectrum] delivers frequency data (streams played through SoLoud)
/// the bars follow the audio, lowest frequencies on the left. Otherwise
/// (platform-player fallback, buffering) they fall back to a decorative
/// animation of layered sine waves. The two blend so switching never jumps.
class Visualizer extends StatefulWidget {
  /// Animate while true; bars settle flat when false.
  final bool active;
  final int barCount;

  /// Bar width relative to its slot (the rest is spacing).
  final double barFill;

  /// FFT magnitudes in `[0, 1]`, lowest frequency first. Only listened to
  /// while [active].
  final Stream<Float32List>? spectrum;

  const Visualizer({
    super.key,
    required this.active,
    this.barCount = 32,
    this.barFill = 0.6,
    this.spectrum,
  });

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer>
    with SingleTickerProviderStateMixin {
  /// Spectrum older than this counts as "no data" and the bars blend back
  /// to the decorative animation.
  static const _staleAfter = Duration(milliseconds: 300);

  late final Ticker _ticker = createTicker(_onTick);
  late List<double> _speeds;
  late List<double> _phases;
  Duration _elapsed = Duration.zero;
  Duration _last = Duration.zero;

  /// 0 = flat, 1 = fully animated. Eases towards the target.
  double _level = 0;

  StreamSubscription<Float32List>? _subscription;
  Float32List? _latest;
  Duration _latestAt = Duration.zero;

  /// Per-bar smoothed spectrum levels, and the FFT bin each bar starts at.
  late List<double> _bars;
  List<int> _bandEdges = const [];

  /// 0 = decorative, 1 = spectrum. Eases towards the target.
  double _real = 0;

  @override
  void initState() {
    super.initState();
    _seed();
    _syncSubscription();
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
    _bars = List.filled(widget.barCount, 0);
    _bandEdges = const [];
  }

  @override
  void didUpdateWidget(Visualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barCount != widget.barCount) _seed();
    if (oldWidget.spectrum != widget.spectrum) {
      _subscription?.cancel();
      _subscription = null;
    }
    _syncSubscription();
    if (widget.active && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  /// Listen only while animating, so the analyser stops when paused.
  void _syncSubscription() {
    final spectrum = widget.spectrum;
    if (widget.active && spectrum != null && _subscription == null) {
      _subscription = spectrum.listen((fft) {
        _latest = fft;
        _latestAt = _elapsed;
      });
    } else if (!widget.active && _subscription != null) {
      _subscription!.cancel();
      _subscription = null;
      _latest = null;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _elapsed += Duration(microseconds: (dt * 1e6).round());
    final target = widget.active ? 1.0 : 0.0;
    _level += (target - _level) * math.min(1, dt * 4);

    final fft = _latest;
    final fresh = fft != null && _elapsed - _latestAt < _staleAfter;
    _real += ((fresh ? 1.0 : 0.0) - _real) * math.min(1, dt * 3);
    if (fresh) _updateBars(fft, dt);

    if (!widget.active && _level < 0.01) {
      _level = 0;
      _ticker.stop();
    }
    setState(() {});
  }

  /// Groups FFT bins into bars on a log scale (as hearing is), taking each
  /// band's peak. Bars rise instantly and fall gently so they read as
  /// motion rather than flicker.
  void _updateBars(Float32List fft, double dt) {
    if (_bandEdges.length != widget.barCount + 1 ||
        _bandEdges.last > fft.length) {
      _bandEdges = _logBands(fft.length, widget.barCount);
    }
    // Rise over ~40 ms and fall over ~125 ms: spectrum packets arrive
    // ~20 times a second, so this glides between them instead of stepping.
    final rise = math.min(1.0, dt * 25);
    final fall = math.min(1.0, dt * 8);
    for (var i = 0; i < widget.barCount; i++) {
      var peak = 0.0;
      for (var b = _bandEdges[i]; b < _bandEdges[i + 1]; b++) {
        if (fft[b] > peak) peak = fft[b];
      }
      final current = _bars[i];
      _bars[i] = current + (peak - current) * (peak >= current ? rise : fall);
    }
  }

  /// Bin edges for [bars] bands spanning bin 1 (skipping DC) to ~16 kHz,
  /// each at least one bin wide.
  static List<int> _logBands(int bins, int bars) {
    final first = 1.0;
    final last = math.max(first + bars, bins * 0.73); // ~16 kHz of 22 kHz
    final edges = List<int>.filled(bars + 1, 0);
    edges[0] = first.toInt();
    for (var i = 1; i <= bars; i++) {
      final f = first * math.pow(last / first, i / bars);
      edges[i] = math.max(edges[i - 1] + 1, f.round()).clamp(0, bins);
    }
    return edges;
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
      final decorative = (0.5 + 0.3 * a + 0.2 * b).clamp(0.0, 1.0) * envelope;
      final raw = decorative * (1 - _real) + _bars[i] * _real;
      return 0.08 + raw * 0.92 * _level;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Following the audio is shown two quiet ways, both blending with
    // [_real]: bars settle onto a baseline like an analyser (decorative bars
    // stay centred), and a faint equaliser mark fades in at the corner.
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: _BarsPainter(
                heights: _heights(),
                fill: widget.barFill,
                grounded: Curves.easeInOut.transform(_real.clamp(0.0, 1.0)),
                colors: [scheme.primary, scheme.tertiary],
              ),
            ),
          ),
        ),
        if (_real > 0.01)
          Align(
            alignment: Alignment.topRight,
            child: Opacity(
              opacity: (_real * _level * 0.6).clamp(0.0, 1.0),
              child: Tooltip(
                message: 'Following the audio',
                child: Icon(
                  Icons.graphic_eq,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                  semanticLabel: 'Visualiser following the audio',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> heights;
  final double fill;

  /// 0 = bars centred, growing up and down; 1 = bars rise from the bottom.
  final double grounded;
  final List<Color> colors;
  _BarsPainter({
    required this.heights,
    required this.fill,
    required this.grounded,
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
      // Centred (decorative) blending to bottom-anchored (real spectrum).
      final spare = size.height - h;
      final top = spare / 2 + spare / 2 * grounded;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top, barWidth, h), radius),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => true;
}
