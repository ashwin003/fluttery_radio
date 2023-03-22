import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttery_radio/models/location.dart';
import 'package:fluttery_radio/services/settings_service.dart';
import 'package:language_picker/languages.dart';

import '../models/station.dart';

class SettingsController with ChangeNotifier {
  final SettingsService _settingsService;
  SettingsController(this._settingsService);

  late ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  late Language _language;

  Language get language => _language;

  late ValueNotifier<Location?> _location;

  ValueListenable<Location?> get location => _location;

  late ValueNotifier<Station?> _station;

  ValueListenable<Station?> get station => _station;

  late ValueNotifier<bool> _isPlaying;

  ValueListenable<bool> get isPlaying => _isPlaying;

  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();
    _language = await _settingsService.language();
    _location = ValueNotifier(await _settingsService.location());
    _station = ValueNotifier(await _settingsService.station());
    _isPlaying = ValueNotifier(false);

    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null) return;

    if (newThemeMode == _themeMode) return;

    _themeMode = newThemeMode;

    await _settingsService.updateThemeMode(newThemeMode);

    notifyListeners();
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

    _location.value = newLocation;
    _location.notifyListeners();

    await _settingsService.updateLocation(newLocation);

    notifyListeners();
  }

  Future<void> updateStation(Station? newStation) async {
    if (newStation == null) return;
    if (newStation == _station.value) return;

    _station.value = newStation;
    _station.notifyListeners();

    await _settingsService.updateStation(newStation);

    await updatePlayingStatus(true);

    notifyListeners();
  }

  Future<void> updatePlayingStatus(bool newPlayingStatus) async {
    if (newPlayingStatus == _isPlaying.value) return;

    _isPlaying = ValueNotifier(newPlayingStatus);
    _isPlaying.notifyListeners();

    await _settingsService.updatePlayingStatus(newPlayingStatus);

    notifyListeners();
  }
}
