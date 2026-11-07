# Fluttery Radio

An internet radio player for Android, iOS, macOS, Windows, Linux and the web, built with Flutter. Fluttery Radio streams thousands of stations from the community-run [radio-browser.info](https://www.radio-browser.info) directory.

## Features

- **Stations near you:** guesses your country from the device's language and region settings, with no location access or network lookup. You can change the country and state in Settings.
- **Browse your way:** switch between a list and a card grid. Sort by popular, trending, most liked, name or quality, and filter by liked stations, secure (HTTPS) streams, language, genre, format and minimum bitrate.
- **Player:** a mini player that you tap or drag up into a full-screen player. The full player is coloured from the station's artwork, works on phones and wide screens, and shows the current song when the station sends it.
- **Live visualiser (optional):** bars that follow the audio on most stations, with a decorative animation where audio data isn't available. It turns off when your system asks to reduce motion.
- **Likes:** like a station to vote for it on radio-browser and save it on your device.
- **System media controls:** notification and lock screen controls on Android and iOS, MPRIS on Linux and the media overlay (SMTC) on Windows. Playback continues in the background.
- **Reliable streaming:** reconnects automatically when a stream drops. Pausing a stream and resuming it returns you to the live broadcast.
- **Appearance:** light, dark or system theme, and an accent colour that follows your system where supported, or one you pick.

## Requirements

- Flutter 3.41 or later (Dart 3.11 or later).
- Supported platforms: Android 9 (API 28), iOS 15, macOS 12, Windows 10, and current Linux distributions and browsers.

### Linux

To build on Linux you need the usual Flutter desktop toolchain, plus GStreamer for the fallback player:

```sh
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-good gstreamer1.0-plugins-bad
```

MP3, Ogg (Vorbis and Opus) and FLAC streams are decoded by codec libraries bundled with the app. AAC streams on Linux also need FFmpeg:

```sh
sudo apt install ffmpeg
```

Without FFmpeg, AAC stations switch to GStreamer after a few seconds and play without the live visualiser.

## Getting started

```sh
flutter pub get
flutter run
```

To build a release, use `flutter build <platform>`, for example `flutter build apk` or `flutter build linux`.

## How playback works

Most stations play through [flutter_soloud](https://pub.dev/packages/flutter_soloud). The app downloads the stream itself and decodes it, which gives it the audio data for the visualiser and the song titles that stations embed in the stream. Memory use stays low: the app keeps only a few seconds of audio ahead of what's playing.

HLS (`.m3u8`) stations, web builds, and any stream that soloud can't decode play through the platform's own player via [audioplayers](https://pub.dev/packages/audioplayers). The app switches automatically. [audio_service](https://pub.dev/packages/audio_service) connects both to the system media controls.

## Project layout

```
lib/
  main.dart, app.dart   start-up, theming (accent and dynamic colour)
  controllers/          app state: settings, likes, current station
  data/                 country names
  dialogs/              theme, accent colour, location and filter pickers
  models/               station query (sort and filters), location, accents
  screens/              home, station list and settings screens
  services/             audio handler and playback engines, station search,
                        country estimate, saved settings
  widgets/              player panel and visualiser, station tiles and cards
test/                   widget and unit tests
```

## Tests

```sh
flutter analyze
flutter test
```

The widget tests can also save screenshots of the player and station list for review. These are written to `test/goldens/` (not committed) only when you run:

```sh
flutter test --update-goldens
```

## Credits

- Station data: [radio-browser.info](https://www.radio-browser.info), through the [radio_browser_flutter](https://pub.dev/packages/radio_browser_flutter) package.
- Open source licences for all dependencies are listed in the app under **Settings › About › Open source licences**.
