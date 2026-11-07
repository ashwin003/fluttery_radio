import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttery_radio/models/location.dart';
import 'package:fluttery_radio/services/audio_player_handler.dart';
import 'package:fluttery_radio/services/country_estimator.dart';
import 'package:fluttery_radio/services/settings_service.dart';
import 'package:language_picker/languages.dart';

import 'package:radio_browser_flutter/radio_browser_flutter.dart' show Station;

class SettingsController with ChangeNotifier {
  final SettingsService _settingsService;
  final AudioPlayerHandler _audioHandler;
  SettingsController(this._settingsService, this._audioHandler);

  StreamSubscription<bool>? _playbackSubscription;

  late ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  Color? _accentColor;

  /// The chosen accent colour, or `null` to follow the system accent.
  Color? get accentColor => _accentColor;

  late Language _language;

  Language get language => _language;

  late ValueNotifier<Location?> _location;

  bool _locationEstimated = false;

  /// True while the location is a guess from device settings that the user
  /// hasn't confirmed or changed.
  bool get isLocationEstimated => _locationEstimated;

  ValueListenable<Location?> get location => _location;

  late ValueNotifier<Station?> _station;

  ValueListenable<Station?> get station => _station;

  late ValueNotifier<bool> _isPlaying;

  ValueListenable<bool> get isPlaying => _isPlaying;

  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();
    _accentColor = await _settingsService.accentColor();
    _language = await _settingsService.language();
    var location = await _settingsService.location();
    if (location.country.isEmpty) {
      // Not persisted: keeps following the device until the user chooses.
      final estimate = estimateLocationFromDevice();
      if (estimate != null) {
        location = estimate;
        _locationEstimated = true;
      }
    }
    _location = ValueNotifier(location);
    _station = ValueNotifier(await _settingsService.station());
    _isPlaying = ValueNotifier(false);

    final station = _station.value;
    if (station != null) _audioHandler.setStation(station);

    // The audio handler is the source of truth: playback may be changed from
    // the notification, lock screen, headset buttons, MPRIS, SMTC, or by
    // errors/interruptions, so mirror its state rather than our own intent.
    _playbackSubscription = _audioHandler.playbackState
        .map((state) => state.playing)
        .distinct()
        .listen((playing) => _isPlaying.value = playing);

    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null) return;

    if (newThemeMode == _themeMode) return;

    _themeMode = newThemeMode;

    await _settingsService.updateThemeMode(newThemeMode);

    notifyListeners();
  }

  Future<void> updateAccentColor(Color? newAccentColor) async {
    if (newAccentColor?.toARGB32() == _accentColor?.toARGB32()) return;

    _accentColor = newAccentColor;
    notifyListeners();

    await _settingsService.updateAccentColor(newAccentColor);
  }

  Future<void> updateLanguage(Language? newLanguage) async {
    if (newLanguage == null) return;
    if (newLanguage == _language) return;

    _language = newLanguage;

    await _settingsService.updateLanguage(newLanguage);

    notifyListeners();
  }

  Future<void> updateLocation(Location? newLocation) async {
    if (newLocation == null) return;
    if (newLocation == _location.value) return;

    _locationEstimated = false;
    _location.value = newLocation;
    _location.notifyListeners();

    await _settingsService.updateLocation(newLocation);

    notifyListeners();
  }

  Future<void> updateStation(Station? newStation) async {
    if (newStation == null) return;
    if (newStation == _station.value) {
      if (!_isPlaying.value) await updatePlayingStatus(true);
      return;
    }

    _station.value = newStation;
    _station.notifyListeners();

    await _settingsService.updateStation(newStation);

    await _audioHandler.playStation(newStation);

    notifyListeners();
  }

  Future<void> updatePlayingStatus(bool newPlayingStatus) async {
    if (newPlayingStatus == _isPlaying.value) return;

    // Update optimistically; the playback state stream will correct it.
    _isPlaying.value = newPlayingStatus;
    if (newPlayingStatus) {
      await _audioHandler.play();
    } else {
      await _audioHandler.pause();
    }

    await _settingsService.updatePlayingStatus(newPlayingStatus);
  }

  @override
  void dispose() {
    _playbackSubscription?.cancel();
    super.dispose();
  }
}
