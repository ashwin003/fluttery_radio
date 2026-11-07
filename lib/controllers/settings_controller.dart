import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttery_radio/models/location.dart';
import 'package:fluttery_radio/models/station_query.dart';
import 'package:fluttery_radio/services/audio_player_handler.dart';
import 'package:fluttery_radio/services/country_estimator.dart';
import 'package:fluttery_radio/services/settings_service.dart';

import 'package:radio_browser_flutter/radio_browser_flutter.dart'
    show RadioBrowserClient, Station;

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

  bool _showVisualizer = true;

  /// User preference for the player visualiser. Widgets must also respect
  /// the platform's reduce-motion setting (MediaQuery.disableAnimations).
  bool get showVisualizer => _showVisualizer;

  /// Playback state and now-playing metadata for the player UI.
  AudioPlayerHandler get audio => _audioHandler;

  Set<String> _likedStations = {};

  /// Liked stations' data, most recently liked first.
  List<Station> _likedStationData = [];
  List<Station> get likedStations => List.unmodifiable(_likedStationData);

  late ValueNotifier<StationQuery> _query;

  /// Sort, search and filters for the station list. Sort is remembered;
  /// search and filters reset on launch.
  ValueListenable<StationQuery> get query => _query;

  late ValueNotifier<StationLayout> _layout;
  ValueListenable<StationLayout> get layout => _layout;

  /// Stations whose vote radio-browser accepted this session, so the shown
  /// vote count can include it without refetching the station.
  final Set<String> _votedThisSession = {};

  bool isLiked(Station station) => _likedStations.contains(station.stationUUID);

  /// The station's radio-browser vote count, including the user's own vote
  /// if it was registered this session.
  int voteCount(Station station) =>
      station.votes + (_votedThisSession.contains(station.stationUUID) ? 1 : 0);

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
    _showVisualizer = await _settingsService.showVisualizer();
    _likedStations = await _settingsService.likedStations();
    _likedStationData = await _settingsService.likedStationData();
    _query = ValueNotifier(
      StationQuery(
        sort: await _settingsService.stationSort(),
        language: await _settingsService.languageFilter(),
      ),
    );
    _layout = ValueNotifier(await _settingsService.stationLayout());
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

  Future<void> updateShowVisualizer(bool value) async {
    if (value == _showVisualizer) return;
    _showVisualizer = value;
    notifyListeners();
    await _settingsService.updateShowVisualizer(value);
  }

  /// Likes or unlikes [station]. Likes are stored locally; liking also
  /// upvotes the station on radio-browser (best effort: the API has no
  /// "unvote", and allows one vote per IP every 10 minutes).
  Future<void> toggleLike(Station station) async {
    final id = station.stationUUID;
    final liked = !_likedStations.contains(id);
    _likedStations = {..._likedStations};
    liked ? _likedStations.add(id) : _likedStations.remove(id);
    _likedStationData = [
      if (liked) station,
      ..._likedStationData.where((s) => s.stationUUID != id),
    ];
    notifyListeners();
    await _settingsService.updateLikedStations(_likedStations);
    await _settingsService.updateLikedStationData(_likedStationData);

    if (!liked || _votedThisSession.contains(id)) return;
    try {
      final result = await RadioBrowserClient.instance.stations.registerVote(
        stationUUID: id,
      );
      if (result.ok) {
        _votedThisSession.add(id);
        notifyListeners();
      } else {
        debugPrint('Vote not counted: ${result.message}');
      }
    } catch (e) {
      debugPrint('Vote failed: $e');
    }
  }

  Future<void> updateQuery(StationQuery newQuery) async {
    if (newQuery == _query.value) return;
    final old = _query.value;
    _query.value = newQuery;
    // Sort and language are remembered; other filters reset on launch.
    if (newQuery.sort != old.sort) {
      await _settingsService.updateStationSort(newQuery.sort);
    }
    if (newQuery.language != old.language) {
      await _settingsService.updateLanguageFilter(newQuery.language);
    }
  }

  Future<void> updateLayout(StationLayout newLayout) async {
    if (newLayout == _layout.value) return;
    _layout.value = newLayout;
    await _settingsService.updateStationLayout(newLayout);
  }

  /// Stops playback entirely (vs. pause, which the UI toggles).
  Future<void> stopPlayback() => _audioHandler.stop();

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
