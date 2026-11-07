import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'playback_engine.dart';

/// Platform players via `audioplayers` (ExoPlayer, AVPlayer, GStreamer,
/// Media Foundation, HTML audio). Plays everything the OS can, including
/// HLS, but exposes no audio data.
class AudioplayersEngine implements PlaybackEngine {
  final _status = StreamController<EngineStatus>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Created on first playback so startup (and tests) don't touch the
  /// native player until it's needed.
  AudioPlayer? _playerInstance;
  AudioPlayer get _player => _playerInstance ??= _createPlayer();

  AudioPlayer _createPlayer() {
    final player = AudioPlayer();
    _subscriptions
      ..add(
        player.onPlayerStateChanged.listen((state) {
          if (state == PlayerState.playing) _status.add(EngineStatus.playing);
        }),
      )
      // A live stream "completing" means the server closed the connection.
      ..add(
        player.onPlayerComplete.listen((_) => _status.add(EngineStatus.ended)),
      )
      ..add(
        player.eventStream.listen(
          (_) {},
          onError: (Object e, [StackTrace? st]) => _status.addError(e, st),
        ),
      );
    return player;
  }

  @override
  Stream<EngineStatus> get status => _status.stream;

  @override
  Future<void> play(String url) async {
    _status.add(EngineStatus.buffering);
    await _player.stop();
    await _player.play(UrlSource(url));
    _status.add(EngineStatus.playing);
  }

  @override
  Future<void> stop() async => _playerInstance?.stop();

  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _playerInstance?.dispose();
    await _status.close();
  }
}
