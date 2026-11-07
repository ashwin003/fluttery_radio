import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'controllers/settings_controller.dart';

/// App-wide dependencies available to every route and dialog.
class AppScope extends InheritedWidget {
  final SettingsController settings;

  /// App name/version/build read from the platform at startup, so the
  /// version only lives in pubspec.yaml.
  final PackageInfo packageInfo;

  /// The platform accent colour for the current brightness, or `null` when the
  /// platform doesn't expose one (iOS, web, Android < 12). Use this to decide
  /// whether "System" accent colour support is available.
  final Color? deviceAccent;

  const AppScope({
    super.key,
    required this.settings,
    required this.packageInfo,
    required this.deviceAccent,
    required super.child,
  });

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      settings != oldWidget.settings ||
      deviceAccent?.toARGB32() != oldWidget.deviceAccent?.toARGB32();
}
