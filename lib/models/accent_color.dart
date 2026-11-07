import 'package:flutter/material.dart';

/// A selectable accent colour. The settings store only the ARGB value; a
/// `null` accent means "use the system accent colour when available".
class AccentColor {
  final String name;
  final Color color;
  const AccentColor(this.name, this.color);

  /// Used when "System" is selected but the platform has no accent colour
  /// (iOS, web, Android < 12).
  static const fallback = AccentColor('Indigo', Colors.indigo);

  static const presets = <AccentColor>[
    fallback,
    AccentColor('Blue', Colors.blue),
    AccentColor('Teal', Colors.teal),
    AccentColor('Green', Colors.green),
    AccentColor('Lime', Colors.lime),
    AccentColor('Amber', Colors.amber),
    AccentColor('Orange', Colors.deepOrange),
    AccentColor('Red', Colors.red),
    AccentColor('Pink', Colors.pink),
    AccentColor('Purple', Colors.deepPurple),
    AccentColor('Brown', Colors.brown),
    AccentColor('Grey', Colors.blueGrey),
  ];

  /// Display name for a stored accent (`null` → "System").
  static String nameOf(Color? color) {
    if (color == null) return 'System';
    for (final preset in presets) {
      if (preset.color.toARGB32() == color.toARGB32()) return preset.name;
    }
    return 'Custom';
  }
}
