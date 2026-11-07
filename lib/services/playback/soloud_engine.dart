import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:http/http.dart' as http;

import 'playback_engine.dart';

/// Streams radio through SoLoud: we download the stream ourselves and feed
/// it to a buffer stream, which decodes MP3, AAC (ADTS), Ogg Vorbis/Opus and
/// FLAC. Unlike platform players this gives us the decoded audio, so the
/// visualiser can show the real spectrum.
///
/// Memory stays bounded: the buffer is in `released` mode (played audio is
/// freed), downloading pauses when more than a few seconds are queued, and
/// the hard cap is only a safety net.
class SoloudEngine implements PlaybackEngine, SpectrumSource {
  /// Decoded audio is float32 stereo: ~350 KB/s at 44.1 kHz, ~384 KB/s at
  /// 48 kHz. These are in bytes of decoded audio.
  static const _pauseDownloadAbove = 4 << 20; // ~11 s
  static const _resumeDownloadBelow = 2 << 20; // ~5 s

  /// If this fills, SoLoud ends the stream, so it sits well above the
  /// pause threshold to absorb a server's initial burst.
  static const _maxBuffer = 12 << 20; // ~32 s

  /// No audio within this long of connecting means SoLoud can't decode the
  /// stream (e.g. AAC on Linux without FFmpeg), so let another engine try.
  static const _startTimeout = Duration(seconds: 12);
  static const _connectTimeout = Duration(seconds: 15);

  static const _fftWindow = 256;

  final String userAgent;
  SoloudEngine({required this.userAgent});

  final _status = StreamController<EngineStatus>.broadcast();
  late final _spectrum = StreamController<Float32List>.broadcast(
    onListen: _syncVisualization,
    onCancel: _syncVisualization,
  );

  Future<void>? _initialization;
  StreamSubscription<AudioVisualizationData>? _visualization;

  /// Bumped on every play/stop so callbacks from an old stream are ignored.
  int _session = 0;
  http.Client? _client;
  StreamSubscription<List<int>>? _download;
  AudioSource? _source;
  SoundHandle? _handle;
  Timer? _flowControl;
  Timer? _startWatchdog;
  bool _started = false;

  @override
  Stream<EngineStatus> get status => _status.stream;

  @override
  Stream<Float32List> get spectrum => _spectrum.stream;

  SoLoud get _soloud => SoLoud.instance;

  Future<void> _ensureInitialized() => _initialization ??=
      () async {
        if (!_soloud.isInitialized) {
          // Radio needs no low latency: the conservative profile saves
          // battery. The default 2048-frame buffer gives the visualiser ~20
          // spectrum updates a second; 4096 halves wakeups but looks choppy.
          await _soloud.init(lowLatency: false);
        }
        _syncVisualization();
      }().catchError((Object e) {
        _initialization = null; // allow a retry
        throw UnsupportedStreamException('audio engine failed to start: $e');
      });

  @override
  Future<void> play(String url) async {
    await stop();
    final session = _session;
    await _ensureInitialized();
    if (session != _session) return;
    _status.add(EngineStatus.buffering);

    final client = _client = http.Client();
    final request = http.Request('GET', Uri.parse(url))
      ..headers['User-Agent'] = userAgent;
    final http.StreamedResponse response;
    try {
      response = await client.send(request).timeout(_connectTimeout);
    } catch (_) {
      if (session != _session) return;
      rethrow;
    }
    if (session != _session) return;

    if (response.statusCode != 200) {
      throw http.ClientException(
        'HTTP ${response.statusCode} ${response.reasonPhrase ?? ''}'.trim(),
        request.url,
      );
    }
    final contentType = response.headers['content-type'] ?? '';
    if (!_isDecodable(contentType)) {
      throw UnsupportedStreamException('content type "$contentType"');
    }

    _started = false;
    final source = _source = _soloud.setBufferStream(
      maxBufferSizeBytes: _maxBuffer,
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: 1.5,
      format: BufferType.auto,
      channels: Channels.stereo,
      onBuffering: (isBuffering, _, _) {
        if (session != _session) return;
        if (!isBuffering) _markStarted();
        _status.add(
          isBuffering ? EngineStatus.buffering : EngineStatus.playing,
        );
      },
    );
    _handle = _soloud.play(source);

    _download = response.stream.listen(
      (chunk) => _onChunk(session, source, chunk),
      onError: (Object e, StackTrace st) => _fail(session, e, st),
      onDone: () {
        if (session == _session) _status.add(EngineStatus.ended);
      },
      cancelOnError: true,
    );
    _flowControl = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _regulateDownload(source),
    );
    _startWatchdog = Timer(_startTimeout, () {
      if (!_started) {
        _fail(session, const UnsupportedStreamException('no audio decoded'));
      }
    });
  }

  void _markStarted() {
    _started = true;
    _startWatchdog?.cancel();
  }

  void _onChunk(int session, AudioSource source, List<int> chunk) {
    if (session != _session) return;
    try {
      _soloud.addAudioDataStream(
        source,
        chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
      );
    } on SoLoudStreamEndedAlreadyCppException {
      // The safety cap was hit; treat it like the server dropping us.
      _status.add(EngineStatus.ended);
      _download?.cancel();
    } on SoLoudPcmBufferFullCppException {
      _status.add(EngineStatus.ended);
      _download?.cancel();
    } catch (e, st) {
      _fail(session, UnsupportedStreamException('decode failed: $e'), st);
    }
  }

  /// Keeps only a few seconds of decoded audio queued. Pausing the
  /// subscription applies TCP back-pressure, so the server just waits.
  void _regulateDownload(AudioSource source) {
    final download = _download;
    if (download == null) return;
    final int queued;
    try {
      queued = _soloud.getBufferSize(source);
    } catch (_) {
      return;
    }
    if (!download.isPaused && queued > _pauseDownloadAbove) {
      download.pause();
    } else if (download.isPaused && queued < _resumeDownloadBelow) {
      download.resume();
    }
  }

  void _fail(int session, Object error, [StackTrace? st]) {
    if (session != _session) return;
    _status.addError(error, st);
  }

  /// Formats SoLoud's buffer stream can decode. Unknown or generic types
  /// are tried (many servers send `application/octet-stream`); the start
  /// watchdog catches anything that turns out undecodable.
  static bool _isDecodable(String contentType) {
    final type = contentType.split(';').first.trim().toLowerCase();
    const unsupported = {
      'application/vnd.apple.mpegurl',
      'application/x-mpegurl',
      'audio/mpegurl',
      'audio/x-mpegurl',
      'audio/x-scpls',
      'text/html',
      'text/plain',
    };
    if (unsupported.contains(type)) return false;
    return !type.startsWith('video/') && !type.startsWith('text/');
  }

  @override
  Future<void> stop() async {
    _session++;
    _flowControl?.cancel();
    _flowControl = null;
    _startWatchdog?.cancel();
    _startWatchdog = null;
    final download = _download;
    final client = _client;
    final handle = _handle;
    final source = _source;
    _download = null;
    _client = null;
    _handle = null;
    _source = null;
    await download?.cancel();
    client?.close();
    if (!_soloud.isInitialized) return;
    try {
      if (handle != null) await _soloud.stop(handle);
      if (source != null) await _soloud.disposeSource(source);
    } catch (e) {
      debugPrint('SoLoud cleanup: $e');
    }
  }

  /// Runs the analyser only while someone is watching.
  void _syncVisualization() {
    // Don't touch the native engine before the first stream needs it.
    if (_initialization == null || !_soloud.isInitialized) return;
    final wanted = _spectrum.hasListener;
    if (wanted == (_visualization != null)) return;
    try {
      _soloud.setVisualizationEnabled(
        wanted,
        windowSize: _fftWindow,
        kind: VisualizationKind.fft,
      );
    } catch (e) {
      debugPrint('Visualisation unavailable: $e');
      return;
    }
    if (wanted) {
      _visualization = _soloud.audioVisualizationEvents.listen((data) {
        final fft = data.fftData;
        if (fft != null) _spectrum.add(fft);
      });
    } else {
      _visualization?.cancel();
      _visualization = null;
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _visualization?.cancel();
    await _status.close();
    await _spectrum.close();
  }
}
