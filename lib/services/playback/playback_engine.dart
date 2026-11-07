import 'dart:typed_data';

/// What an engine reports while a stream plays. Errors arrive on the
/// same stream via `addError`.
enum EngineStatus {
  /// Waiting for (more) audio data.
  buffering,

  /// Audio is coming out of the speakers.
  playing,

  /// The server closed the stream.
  ended,
}

/// Plays one live stream at a time. [AudioPlayerHandler] owns the
/// user-facing state (intent, reconnects, OS media controls); an engine
/// only knows how to turn a URL into sound.
abstract class PlaybackEngine {
  Stream<EngineStatus> get status;

  /// Starts [url]. Completes once connected; [status] reports when audio
  /// actually starts. Throws if the stream can't be opened.
  Future<void> play(String url);

  Future<void> stop();

  Future<void> dispose();
}

/// An engine that can provide frequency data for what it is playing.
abstract class SpectrumSource {
  /// FFT magnitudes in `[0, 1]`, lowest frequency first. Analysis only runs
  /// while this stream has listeners.
  Stream<Float32List> get spectrum;
}

/// An engine that can report the track a station is currently playing.
abstract class TrackInfoSource {
  /// The current track, e.g. "Artist – Title", or null when the station
  /// reports none (or stops). Only emits on change.
  Stream<String?> get track;
}

/// The engine can't play this stream (format, protocol or missing codec),
/// so another engine should try it. Not worth a reconnect.
class UnsupportedStreamException implements Exception {
  final String reason;
  const UnsupportedStreamException(this.reason);

  @override
  String toString() => 'UnsupportedStreamException: $reason';
}
