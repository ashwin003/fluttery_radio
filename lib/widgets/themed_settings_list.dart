import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';

/// A [SettingsList] that follows the app's theme.
///
/// settings_ui 4 is built on the standalone `material_ui` package, whose
/// `Theme` is a different class from Flutter's, so it can't see the app's
/// [ThemeData]: on its own it always draws light, default-coloured tiles.
/// This passes the brightness and colours across explicitly, so dark mode,
/// the accent colour and the switch all match the rest of the app.
class ThemedSettingsList extends StatelessWidget {
  final List<AbstractSettingsSection> sections;
  const ThemedSettingsList({super.key, required this.sections});

  /// The app's [ColorScheme] as settings_ui colours.
  static SettingsThemeData themeFor(ColorScheme scheme) {
    final disabled = scheme.onSurface.withValues(alpha: 0.38);
    return SettingsThemeData(
      settingsListBackground: scheme.surface,
      settingsSectionBackground: scheme.surfaceContainerLow,
      titleTextColor: scheme.onSurface,
      settingsTileTextColor: scheme.onSurface,
      tileDescriptionTextColor: scheme.onSurfaceVariant,
      trailingTextColor: scheme.onSurfaceVariant,
      leadingIconsColor: scheme.onSurfaceVariant,
      dividerColor: scheme.outlineVariant,
      tileHighlightColor: scheme.onSurface.withValues(alpha: 0.08),
      inactiveTitleColor: disabled,
      inactiveSubtitleColor: disabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = themeFor(theme.colorScheme);
    return SettingsList(
      brightness: theme.brightness,
      lightTheme: colors,
      darkTheme: colors,
      sections: sections,
    );
  }
}
