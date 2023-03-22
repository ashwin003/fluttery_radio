import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttery_radio/extensions/language_extensions.dart';
import 'package:fluttery_radio/models/location.dart';
import 'package:fluttery_radio/models/station.dart';
import 'package:language_picker/languages.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  final String _themePreferencesKey = 'radio-browser-theme',
      _languagePreferencesKey = 'radio-browser-language',
      _locationPreferencesKey = 'radio-browser-location',
      _isPlayingPreferenceKey = 'radio-browser-playing',
      _activeStationPreferencesKey = 'radio-browser-station';
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
      final jsonObject =
          json.decode(prefs.getString(_activeStationPreferencesKey)!);
      return Station.fromJson(jsonObject);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateStation(Station station) async {
    final SharedPreferences prefs = await _prefs;
    prefs.setString(
      _activeStationPreferencesKey,
      json.encode(station.toJson()),
    );
  }
}
