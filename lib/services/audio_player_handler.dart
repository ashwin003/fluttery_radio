import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:radio_browser_flutter/radio_browser_flutter.dart'
    show RadioBrowserClient, Station;

/// Audio handler tuned for live internet radio, backed by `audioplayers`
/// (ExoPlayer on Android, AVPlayer on iOS/macOS, GStreamer on Linux, Media
/// Foundation on Windows, HTML audio on web) so no extra native libraries
/// need installing.
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

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Created on first playback so startup (and tests) don't touch the
  /// native player until it's needed.
  AudioPlayer? _playerInstance;
  AudioPlayer get _player => _playerInstance ??= _createPlayer();

  /// Whether the user wants audio to be playing. Distinct from the player's
  /// actual state, which may be loading/erroring.
  bool _wantsToPlay = false;

  /// True between asking the player to start and it reporting `playing`.
  bool _connecting = false;

  /// Incremented on every new load so stale async work can bail out.
  int _loadGeneration = 0;

  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  AudioPlayerHandler() {
    _broadcastState();
  }

  AudioPlayer _createPlayer() {
    final player = AudioPlayer();
    _subscriptions
      ..add(player.onPlayerStateChanged.listen(_onPlayerState))
      // A live stream "completing" means the server closed the connection.
      ..add(player.onPlayerComplete.listen((_) => _onStreamEnded()))
      ..add(
        player.eventStream.listen(
          (_) {},
          onError: (Object e, [StackTrace? st]) => _onPlaybackError(e),
        ),
      );
    return player;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

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
      extras: {'stationUUID': station.stationUUID},
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
      playMediaItem(MediaItem(id: uri.toString(), title: uri.host, isLive: true));

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

  Future<void> _halt() async {
    _wantsToPlay = false;
    _connecting = false;
    _loadGeneration++;
    _resetReconnect();
    _broadcastState();
    await _playerInstance?.stop();
  }

  Future<void> _connectAndPlay() async {
    final item = mediaItem.value;
    if (item == null) return;
    final generation = ++_loadGeneration;
    _connecting = true;
    _broadcastState();

    try {
      await _player.stop();
      if (generation != _loadGeneration || !_wantsToPlay) return;
      await _player.play(UrlSource(item.id));
      if (generation != _loadGeneration) return;
      _connecting = false;
      _reconnectAttempts = 0;
      _broadcastState();
    } catch (e) {
      if (generation != _loadGeneration) return;
      _onPlaybackError(e);
    }
  }

  void _onPlayerState(PlayerState state) {
    if (state == PlayerState.playing) {
      _connecting = false;
      _reconnectAttempts = 0;
    }
    _broadcastState();
  }

  void _onStreamEnded() {
    if (_wantsToPlay) _scheduleReconnect();
  }

  void _onPlaybackError(Object error) {
    debugPrint('Playback error: $error');
    if (_wantsToPlay && _reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
      return;
    }
    _wantsToPlay = false;
    _connecting = false;
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
    await _playerInstance?.dispose();
  }
}
