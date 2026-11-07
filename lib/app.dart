import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_scope.dart';
import 'controllers/settings_controller.dart';
import 'models/accent_color.dart';
import 'screens/home_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp(this._settingsController, this._packageInfo, {super.key});

  final SettingsController _settingsController;
  final PackageInfo _packageInfo;

  static ThemeData _theme(Color seed, Brightness brightness) => ThemeData(
    // Re-derive a full scheme from the seed rather than using the platform
    // scheme directly: some platforms return schemes missing newer M3 roles.
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
  );

  @override
  Widget build(BuildContext context) {
    // DynamicColorBuilder reads the system accent: Material You on
    // Android 12+, the accent colour on Windows/macOS and the GTK theme on
    // Linux. It yields null where unsupported (iOS, web, older Android).
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => ListenableBuilder(
        listenable: _settingsController,
        builder: (context, _) {
          final chosen = _settingsController.accentColor;
          final lightSeed =
              chosen ?? lightDynamic?.primary ?? AccentColor.fallback.color;
          final darkSeed =
              chosen ??
              darkDynamic?.primary ??
              lightDynamic?.primary ??
              AccentColor.fallback.color;
          return MaterialApp(
            title: 'Fluttery Radio',
            theme: _theme(lightSeed, Brightness.light),
            darkTheme: _theme(darkSeed, Brightness.dark),
            // Wrap the navigator so every route and dialog can reach it.
            builder: (context, child) {
              final dynamicScheme =
                  Theme.of(context).brightness == Brightness.dark
                  ? (darkDynamic ?? lightDynamic)
                  : lightDynamic;
              return AppScope(
                settings: _settingsController,
                packageInfo: _packageInfo,
                deviceAccent: dynamicScheme?.primary,
                child: child!,
              );
            },
            home: HomeScreen(_settingsController, title: 'Flutter Radio'),
            themeMode: _settingsController.themeMode,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
