import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/accent_color.dart';

/// Picks an accent colour. "System" follows the OS accent where supported;
/// tapping any option applies it immediately and closes the dialog.
class AccentColorDialog extends StatelessWidget {
  const AccentColorDialog({super.key});

  void _select(BuildContext context, Color? color) {
    AppScope.of(context).settings.updateAccentColor(color);
    Navigator.of(context).pop();
  }

  Widget _buildCustomSwatch(BuildContext context, Color? current) {
    final isCustom = current != null && AccentColor.nameOf(current) == 'Custom';
    return Tooltip(
      message: 'Custom colour',
      child: Semantics(
        button: true,
        selected: isCustom,
        label: 'Custom colour',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            final picked = await showDialog<Color>(
              context: context,
              builder: (_) => _CustomColorDialog(
                initial: current ?? AccentColor.fallback.color,
              ),
            );
            if (picked != null && context.mounted) _select(context, picked);
          },
          child: isCustom
              ? _Swatch(color: current, size: 44, icon: Icons.check)
              : Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(colors: _hueStops),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final settings = scope.settings;
    final deviceColorAvailable = scope.deviceAccent != null;
    final current = settings.accentColor;
    return AlertDialog(
      title: const Text('Accent colour'),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                // Unsupported platforms can't pick System, but it stays
                // shown (and checked) when it's the stored default.
                enabled: deviceColorAvailable || current == null,
                leading: _Swatch(
                  color: scope.deviceAccent ?? AccentColor.fallback.color,
                  icon: Icons.auto_awesome,
                ),
                title: const Text('System'),
                subtitle: Text(
                  deviceColorAvailable
                      ? 'Match your device accent colour'
                      : 'Not available on this device; using '
                            '${AccentColor.fallback.name}. Pick a colour below.',
                ),
                selected: current == null,
                trailing: current == null ? const Icon(Icons.check) : null,
                onTap: () => _select(context, null),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final preset in AccentColor.presets)
                      Tooltip(
                        message: preset.name,
                        child: Semantics(
                          button: true,
                          selected:
                              preset.color.toARGB32() == current?.toARGB32(),
                          label: preset.name,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _select(context, preset.color),
                            child: _Swatch(
                              color: preset.color,
                              size: 44,
                              icon:
                                  preset.color.toARGB32() == current?.toARGB32()
                                  ? Icons.check
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    _buildCustomSwatch(context, current),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final double size;
  final IconData? icon;
  const _Swatch({required this.color, this.size = 40, this.icon});

  @override
  Widget build(BuildContext context) {
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: icon == null ? null : Icon(icon, color: onColor, size: size * 0.5),
    );
  }
}

const _hueStops = [
  Color(0xFFFF0000),
  Color(0xFFFFFF00),
  Color(0xFF00FF00),
  Color(0xFF00FFFF),
  Color(0xFF0000FF),
  Color(0xFFFF00FF),
  Color(0xFFFF0000),
];

/// Hue + saturation picker for a custom accent. Lightness is fixed because
/// Material 3 derives light/dark tones from the seed itself.
class _CustomColorDialog extends StatefulWidget {
  final Color initial;
  const _CustomColorDialog({required this.initial});

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late double _hue;
  late double _saturation;

  @override
  void initState() {
    super.initState();
    final hsl = HSLColor.fromColor(widget.initial);
    _hue = hsl.hue;
    _saturation = hsl.saturation.clamp(0.2, 1.0);
  }

  Color get _color => HSLColor.fromAHSL(1, _hue, _saturation, 0.5).toColor();

  @override
  Widget build(BuildContext context) {
    final preview = ColorScheme.fromSeed(
      seedColor: _color,
      brightness: Theme.of(context).brightness,
    );
    return AlertDialog(
      title: const Text('Custom colour'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview using the scheme the app will actually derive.
            Row(
              children: [
                _Swatch(color: _color, size: 48),
                const SizedBox(width: 16),
                for (final c in [
                  preview.primary,
                  preview.secondary,
                  preview.tertiary,
                  preview.primaryContainer,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Swatch(color: c, size: 28),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Hue'),
            Container(
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(colors: _hueStops),
              ),
            ),
            Slider(
              value: _hue,
              max: 360,
              label: '${_hue.round()}°',
              onChanged: (v) => setState(() => _hue = v),
            ),
            const Text('Intensity'),
            Slider(
              value: _saturation,
              min: 0.2,
              max: 1,
              onChanged: (v) => setState(() => _saturation = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_color),
          child: const Text('Use colour'),
        ),
      ],
    );
  }
}
