import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttery_radio/extensions/language_extensions.dart';
import 'package:fluttery_radio/models/location.dart';
import 'package:radio_browser_flutter/radio_browser_flutter.dart' show Station;
import 'package:language_picker/languages.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  final String _themePreferencesKey = 'radio-browser-theme',
      _languagePreferencesKey = 'radio-browser-language',
      _locationPreferencesKey = 'radio-browser-location',
      _isPlayingPreferenceKey = 'radio-browser-playing',
      _activeStationPreferencesKey = 'radio-browser-station',
      _accentColorPreferencesKey = 'radio-browser-accent-color',
      _visualizerPreferencesKey = 'radio-browser-visualizer',
      _likedStationsPreferencesKey = 'radio-browser-liked-stations';
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  Future<ThemeMode> themeMode() async {
    final SharedPreferences prefs = await _prefs;
    try {
      return ThemeMode.values[prefs.getInt(_themePreferencesKey)!];
    } catch (e) {
      return ThemeMode.system;
    }
  }

  Future<void> updateThemeMode(ThemeMode theme) async {
    final SharedPreferences prefs = await _prefs;
    prefs.setInt(_themePreferencesKey, theme.index);
  }

  /// `null` means follow the system accent colour.
  Future<Color?> accentColor() async {
    final SharedPreferences prefs = await _prefs;
    final value = prefs.getInt(_accentColorPreferencesKey);
    return value == null ? null : Color(value);
  }

  Future<void> updateAccentColor(Color? color) async {
    final SharedPreferences prefs = await _prefs;
    if (color == null) {
      await prefs.remove(_accentColorPreferencesKey);
    } else {
      await prefs.setInt(_accentColorPreferencesKey, color.toARGB32());
    }
  }

  Future<bool> showVisualizer() async {
    final SharedPreferences prefs = await _prefs;
    return prefs.getBool(_visualizerPreferencesKey) ?? true;
  }

  Future<void> updateShowVisualizer(bool value) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setBool(_visualizerPreferencesKey, value);
  }

  /// UUIDs of stations the user has liked.
  Future<Set<String>> likedStations() async {
    final SharedPreferences prefs = await _prefs;
    return (prefs.getStringList(_likedStationsPreferencesKey) ?? []).toSet();
  }

  Future<void> updateLikedStations(Set<String> stationUUIDs) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setStringList(
      _likedStationsPreferencesKey,
      stationUUIDs.toList(),
    );
  }

  Future<Language> language() async {
    final SharedPreferences prefs = await _prefs;
    try {
      final jsonObject = json.decode(prefs.getString(_languagePreferencesKey)!);
      return Language.fromMap(jsonObject);
    } catch (e) {
      return Languages.english;
    }
  }

  Future<void> updateLanguage(Language newLanguage) async {
    final SharedPreferences prefs = await _prefs;
    prefs.setString(_languagePreferencesKey, json.encode(newLanguage.toJson()));
  }

  Future<Location> location() async {
    final SharedPreferences prefs = await _prefs;
    try {
      final jsonObject = json.decode(prefs.getString(_locationPreferencesKey)!);
      return Location.fromJson(jsonObject);
    } catch (e) {
      return Location();
    }
  }

  Future<void> updateLocation(Location newLocation) async {
    final SharedPreferences prefs = await _prefs;
    prefs.setString(_locationPreferencesKey, json.encode(newLocation));
  }

  Future<bool> isPlaying() async {
    final SharedPreferences prefs = await _prefs;
    try {
      final jsonObject = json.decode(prefs.getString(_isPlayingPreferenceKey)!);
      return jsonObject == true;
    } catch (e) {
      return false;
    }
  }

  Future<void> updatePlayingStatus(bool isPlaying) async {
    final SharedPreferences prefs = await _prefs;
    prefs.setString(_isPlayingPreferenceKey, isPlaying.toString());
  }

  Future<Station?> station() async {
    final SharedPreferences prefs = await _prefs;
    try {
      final jsonObject = json.decode(
        prefs.getString(_activeStationPreferencesKey)!,
      );
      return Station.fromJson(jsonObject);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateStation(Station station) async {
    final SharedPreferences prefs = await _prefs;
    prefs.setString(
      _activeStationPreferencesKey,
      json.encode(_stationToApiJson(station)),
    );
  }

  /// [Station.toJson] writes lists and booleans, but [Station.fromJson] expects
  /// the API's format (comma-separated strings and 0/1 integers), so convert
  /// before persisting to allow the station to be read back.
  Map<String, dynamic> _stationToApiJson(Station station) {
    final jsonObject = station.toJson();
    for (final key in ['tags', 'language', 'languagecodes']) {
      jsonObject[key] = (jsonObject[key] as List).join(',');
    }
    for (final key in ['hls', 'lastcheckok', 'ssl_error']) {
      jsonObject[key] = jsonObject[key] == true ? 1 : 0;
    }
    return jsonObject;
  }
}
