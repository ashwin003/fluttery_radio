import 'package:flutter/material.dart';

extension ThemeStrings on ThemeMode {
  String asString() => label;

  String get label => switch (this) {
    ThemeMode.system => 'System default',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  String get description => switch (this) {
    ThemeMode.system => 'Follow your device setting',
    ThemeMode.light => 'Always use the light theme',
    ThemeMode.dark => 'Always use the dark theme',
  };

  IconData get icon => switch (this) {
    ThemeMode.system => Icons.brightness_auto,
    ThemeMode.light => Icons.light_mode,
    ThemeMode.dark => Icons.dark_mode,
  };
}
