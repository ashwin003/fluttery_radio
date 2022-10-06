import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttery_radio/services/audio_player_handler.dart';
import 'app.dart';
import 'controllers/settings_controller.dart';
import 'services/settings_service.dart';

late AudioHandler audioHandler;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.fluttery_radio.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    ),
  );
  final settingsController = SettingsController(SettingsService());
  await settingsController.loadSettings();
  runApp(MyApp(
    settingsController,
  ));
}
