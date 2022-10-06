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

  late Location _location;

  Location get location => _location;

  Station? _station;

  Station? get station => _station;

  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();
    _language = await _settingsService.language();
    _location = await _settingsService.location();
    _station = await _settingsService.station();

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
    if (newLocation == _location) return;

    _location = newLocation;

    await _settingsService.updateLocation(newLocation);

    notifyListeners();
  }

  Future<void> updateStation(Station? newStation) async {
    if (newStation == null) return;
    if (newStation == _station) return;

    _station = newStation;

    await _settingsService.updateStation(newStation);

    notifyListeners();
  }
}
