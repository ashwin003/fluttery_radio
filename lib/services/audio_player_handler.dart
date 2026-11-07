import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart' show SoLoudException;
import 'package:radio_browser_flutter/radio_browser_flutter.dart'
    show RadioBrowserClient, Station;

import 'playback/audioplayers_engine.dart';
import 'playback/playback_engine.dart';
import 'playback/soloud_engine.dart';

/// Audio handler tuned for live internet radio.
///
/// Streams play through [SoloudEngine] where possible, which also provides
/// the spectrum for the visualiser. HLS, web, and anything SoLoud can't
/// decode fall back to [AudioplayersEngine] (the platform player).
///
/// * Broadcasts [playbackState] and [mediaItem] so that the Android/iOS
///   notification & lock screen, Linux MPRIS, Windows SMTC and the in-app UI
///   all stay in sync.
/// * Treats "pause" as "disconnect" – resuming a live stream should jump back
///   to live, not replay a stale buffer (or fail on a timed-out socket).
/// * Automatically reconnects (with exponential back-off) when a stream drops
///   while the user still wants to listen.
class AudioPlayerHandler extends BaseAudioHandler {
  static const _maxReconnectAttempts = 6;

  final SoloudEngine? _soloud;
  final AudioplayersEngine _fallback = AudioplayersEngine();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Streams SoLoud couldn't play this session; they go to the fallback.
  final Set<String> _soloudUnsupported = {};

  PlaybackEngine? _active;

  /// Whether the user wants audio to be playing. Distinct from the player's
  /// actual state, which may be loading/erroring.
  bool _wantsToPlay = false;

  /// True between asking the player to start and it reporting `playing`.
  bool _connecting = false;

  /// Incremented on every new load so stale async work can bail out.
  int _loadGeneration = 0;

  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  /// [useSoloud] is off on web (CORS limits which stations can be read, and
  /// the HTML player handles everything) and can be turned off in tests.
  AudioPlayerHandler({String userAgent = 'FlutteryRadio', bool? useSoloud})
    : _soloud = (useSoloud ?? !kIsWeb)
          ? SoloudEngine(userAgent: userAgent)
          : null {
    for (final engine in [?_soloud, _fallback]) {
      _subscriptions.add(
        engine.status.listen(
          (s) {
            if (identical(engine, _active)) _onEngineStatus(s);
          },
          onError: (Object e) {
            if (identical(engine, _active)) _onPlaybackError(e);
          },
        ),
      );
    }
    _broadcastState();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// FFT magnitudes of what's playing, while it plays through SoLoud.
  /// Nothing is emitted on the fallback engine; analysis only runs while
  /// this has listeners.
  Stream<Float32List> get spectrum => _soloud?.spectrum ?? const Stream.empty();

  static MediaItem mediaItemFromStation(Station station) {
    final favicon = station.favicon.toString();
    return MediaItem(
      id: station.urlResolved.toString(),
      title: station.name,
      // ignore: deprecated_member_use
      album: station.country,
      genre: station.tags.isEmpty ? null : station.tags.first,
      artUri: favicon.startsWith('http') ? station.favicon : null,
      isLive: true,
      extras: {'stationUUID': station.stationUUID, 'hls': station.hls},
    );
  }

  /// Sets the current station without starting playback (e.g. on app start).
  void setStation(Station station) {
    mediaItem.add(mediaItemFromStation(station));
    _broadcastState();
  }

  Future<void> playStation(Station station) async {
    await playMediaItem(mediaItemFromStation(station));
    // radio-browser asks clients to report plays; it feeds station rankings.
    unawaited(
      RadioBrowserClient.instance.stations
          .registerClick(stationUUID: station.stationUUID)
          .then((_) {}, onError: (_) {}),
    );
  }

  // ---------------------------------------------------------------------------
  // AudioHandler overrides
  // ---------------------------------------------------------------------------

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
    _wantsToPlay = true;
    _resetReconnect();
    await _connectAndPlay();
  }

  @override
  Future<void> playFromUri(Uri uri, [Map<String, dynamic>? extras]) =>
      playMediaItem(
        MediaItem(id: uri.toString(), title: uri.host, isLive: true),
      );

  @override
  Future<void> play() async {
    if (mediaItem.value == null) return;
    _wantsToPlay = true;
    _resetReconnect();
    // Always reconnect: resuming a stale live buffer is worse than a short
    // reload, and the server has often closed the socket anyway.
    await _connectAndPlay();
  }

  @override
  Future<void> pause() => _halt();

  @override
  Future<void> stop() async {
    await _halt();
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() => stop();

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    if (button == MediaButton.media) {
      _wantsToPlay ? await pause() : await play();
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  PlaybackEngine _engineFor(MediaItem item) {
    final soloud = _soloud;
    if (soloud == null || _soloudUnsupported.contains(item.id)) {
      return _fallback;
    }
    final isHls =
        item.extras?['hls'] == true ||
        Uri.tryParse(item.id)?.path.toLowerCase().endsWith('.m3u8') == true;
    return isHls ? _fallback : soloud;
  }

  Future<void> _halt() async {
    _wantsToPlay = false;
    _connecting = false;
    _loadGeneration++;
    _resetReconnect();
    _broadcastState();
    await _active?.stop();
  }

  Future<void> _connectAndPlay() async {
    final item = mediaItem.value;
    if (item == null) return;
    final generation = ++_loadGeneration;
    _connecting = true;
    _broadcastState();

    final engine = _engineFor(item);
    final previous = _active;
    _active = engine;
    try {
      if (previous != null && !identical(previous, engine)) {
        await previous.stop();
      }
      if (generation != _loadGeneration || !_wantsToPlay) return;
      await engine.play(item.id);
    } catch (e) {
      if (generation != _loadGeneration) return;
      _onPlaybackError(e);
    }
  }

  void _onEngineStatus(EngineStatus status) {
    switch (status) {
      case EngineStatus.playing:
        _connecting = false;
        _reconnectAttempts = 0;
      case EngineStatus.buffering:
        _connecting = _wantsToPlay;
      case EngineStatus.ended:
        if (_wantsToPlay) _scheduleReconnect();
        return;
    }
    _broadcastState();
  }

  void _onPlaybackError(Object error) {
    debugPrint('Playback error: $error');
    final item = mediaItem.value;
    // SoLoud can't play this one: hand it to the platform player right away
    // instead of burning reconnect attempts on it.
    if (_wantsToPlay &&
        item != null &&
        identical(_active, _soloud) &&
        (error is UnsupportedStreamException || error is SoLoudException)) {
      _soloudUnsupported.add(item.id);
      unawaited(_connectAndPlay());
      return;
    }
    if (_wantsToPlay && _reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
      return;
    }
    _wantsToPlay = false;
    _connecting = false;
    unawaited(_active?.stop());
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
        controls: [MediaControl.play],
        errorMessage: error.toString(),
      ),
    );
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    final delay = Duration(
      milliseconds: 500 * math.pow(2, _reconnectAttempts).toInt(),
    );
    _reconnectAttempts++;
    debugPrint('Reconnecting in $delay (attempt $_reconnectAttempts)');
    _connecting = true;
    _broadcastState();
    _reconnectTimer = Timer(delay, () {
      if (_wantsToPlay) _connectAndPlay();
    });
  }

  void _resetReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
  }

  void _broadcastState() {
    // Report the user's intent as "playing" while (re)connecting so UIs and
    // OS controls show a pause/stop button rather than flickering.
    final playing = _wantsToPlay;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.playPause,
          MediaAction.stop,
        },
        androidCompactActionIndices: const [0, 1],
        processingState: !playing
            ? AudioProcessingState.idle
            : _connecting
            ? AudioProcessingState.loading
            : AudioProcessingState.ready,
        playing: playing,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
      ),
    );
  }

  Future<void> dispose() async {
    _resetReconnect();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _soloud?.dispose();
    await _fallback.dispose();
  }
}
