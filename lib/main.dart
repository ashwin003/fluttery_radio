import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttery_radio/services/audio_player_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:radio_browser_flutter/radio_browser_flutter.dart';
import 'app.dart';
import 'controllers/settings_controller.dart';
import 'services/settings_service.dart';

late AudioPlayerHandler audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Version comes from pubspec.yaml via the platform build metadata.
  final packageInfo = await PackageInfo.fromPlatform();
  final userAgent = 'FlutteryRadio/${packageInfo.version}';

  await RadioBrowserClient.initialize(userAgent);
  // If OS media controls can't be registered (e.g. no D-Bus session on
  // Linux), keep the handler anyway so in-app playback still works.
  final handler = AudioPlayerHandler(userAgent: userAgent);
  try {
    audioHandler = await AudioService.init(
      builder: () => handler,
      config: _audioServiceConfig,
    );
  } catch (e) {
    debugPrint('OS media controls unavailable: $e');
    audioHandler = handler;
  }
  final settingsController = SettingsController(
    SettingsService(),
    audioHandler,
  );
  await settingsController.loadSettings();
  runApp(MyApp(settingsController, packageInfo));
}

const _audioServiceConfig = AudioServiceConfig(
  // Also used as the MPRIS identity on Linux and SMTC id on Windows.
  androidNotificationChannelId: 'com.example.fluttery_radio.channel.audio',
  androidNotificationChannelName: 'Audio Playback',
  androidNotificationOngoing: true,
  androidStopForegroundOnPause: true,
);
