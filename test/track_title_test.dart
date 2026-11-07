import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttery_radio/services/playback/soloud_engine.dart';

AudioMetadata mp3({String artist = '', String title = ''}) => AudioMetadata(
  detectedType: DetectedType.mp3Stream,
  mp3Metadata: Mp3Metadata(
    title: title,
    artist: artist,
    album: '',
    date: '',
    genre: '',
  ),
);

void main() {
  test('ICY StreamTitle is used as is', () {
    expect(
      SoloudEngine.trackTitle(mp3(title: 'Daft Punk - One More Time')),
      'Daft Punk - One More Time',
    );
  });

  test('separate artist and title are joined', () {
    expect(
      SoloudEngine.trackTitle(mp3(artist: 'Björk', title: 'Jóga')),
      'Björk – Jóga',
    );
  });

  test('artist already in the title is not repeated', () {
    expect(
      SoloudEngine.trackTitle(mp3(artist: 'Muse', title: 'Muse - Uprising')),
      'Muse - Uprising',
    );
  });

  test('empty sections for other formats are skipped', () {
    // SoLoud fills every section; only the AAC one has data here.
    final metadata = mp3()
      ..aacMetadata = AacMetadata(
        sampleRate: 44100,
        channels: 2,
        profile: 'LC',
        bitrate: 128000,
        frameLength: 1024,
        title: 'Nina Simone - Feeling Good',
      );
    expect(SoloudEngine.trackTitle(metadata), 'Nina Simone - Feeling Good');
  });

  test('blank and placeholder titles mean no track', () {
    expect(SoloudEngine.trackTitle(mp3()), isNull);
    expect(SoloudEngine.trackTitle(mp3(title: ' - ')), isNull);
    expect(SoloudEngine.trackTitle(mp3(title: '   ')), isNull);
    expect(
      SoloudEngine.trackTitle(AudioMetadata(detectedType: DetectedType.wav)),
      isNull,
    );
  });
}
