import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttery_radio/models/location.dart';
import 'package:fluttery_radio/models/station_query.dart';
import 'package:radio_browser_flutter/radio_browser_flutter.dart' show Station;
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  final String _themePreferencesKey = 'radio-browser-theme',
      _locationPreferencesKey = 'radio-browser-location',
      _isPlayingPreferenceKey = 'radio-browser-playing',
      _activeStationPreferencesKey = 'radio-browser-station',
      _accentColorPreferencesKey = 'radio-browser-accent-color',
      _visualizerPreferencesKey = 'radio-browser-visualizer',
      _likedStationsPreferencesKey = 'radio-browser-liked-stations',
      _likedStationDataPreferencesKey = 'radio-browser-liked-station-data',
      _sortPreferencesKey = 'radio-browser-sort',
      _layoutPreferencesKey = 'radio-browser-layout',
          // A new key: the old "radio-browser-language" setting defaulted to
          // English for everyone, so it's deliberately not migrated.
          _languageFilterPreferencesKey =
          'radio-browser-language-filter';
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

  /// Full data for liked stations, so they can be listed offline and
  /// regardless of the selected location.
  Future<List<Station>> likedStationData() async {
    final SharedPreferences prefs = await _prefs;
    final stations = <Station>[];
    for (final raw
        in prefs.getStringList(_likedStationDataPreferencesKey) ?? []) {
      try {
        stations.add(Station.fromJson(json.decode(raw)));
      } catch (_) {
        // Skip entries written by an incompatible version.
      }
    }
    return stations;
  }

  Future<void> updateLikedStationData(Iterable<Station> stations) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setStringList(
      _likedStationDataPreferencesKey,
      stations.map((s) => json.encode(_stationToApiJson(s))).toList(),
    );
  }

  Future<StationSort> stationSort() async {
    final SharedPreferences prefs = await _prefs;
    final name = prefs.getString(_sortPreferencesKey);
    return StationSort.values.asNameMap()[name] ?? StationSort.popular;
  }

  Future<void> updateStationSort(StationSort sort) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(_sortPreferencesKey, sort.name);
  }

  Future<StationLayout> stationLayout() async {
    final SharedPreferences prefs = await _prefs;
    final name = prefs.getString(_layoutPreferencesKey);
    return StationLayout.values.asNameMap()[name] ?? StationLayout.list;
  }

  Future<void> updateStationLayout(StationLayout layout) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(_layoutPreferencesKey, layout.name);
  }

  /// The remembered language filter; null = any language.
  Future<String?> languageFilter() async {
    final SharedPreferences prefs = await _prefs;
    return prefs.getString(_languageFilterPreferencesKey);
  }

  Future<void> updateLanguageFilter(String? language) async {
    final SharedPreferences prefs = await _prefs;
    if (language == null) {
      await prefs.remove(_languageFilterPreferencesKey);
    } else {
      await prefs.setString(_languageFilterPreferencesKey, language);
    }
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
