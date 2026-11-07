import 'package:audio_service/audio_service.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttery_radio/controllers/settings_controller.dart';
import 'package:fluttery_radio/services/audio_player_handler.dart';
import 'package:fluttery_radio/services/settings_service.dart';
import 'package:fluttery_radio/widgets/player/player_panel.dart';
import 'package:fluttery_radio/widgets/player/visualizer.dart';
import 'package:radio_browser_flutter/radio_browser_flutter.dart' show Station;
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/screenshot.dart';

void main() {
  late Station station;
  late SettingsController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    station = Station.fromJson(
      json.decode(File('test/fixtures/station.json').readAsStringSync()),
    );
    controller = SettingsController(
      SettingsService(),
      AudioPlayerHandler(useSoloud: false),
    );
    await controller.loadSettings();
  });

  Widget app({bool reduceMotion = false, Brightness? brightness}) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: brightness ?? Brightness.light,
        ),
      ),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: Stack(
            children: [
              Scaffold(
                appBar: AppBar(title: const Text('Stations')),
                body: const SizedBox.expand(),
              ),
              Positioned.fill(
                child: PlayerPanel(controller: controller, station: station),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
  }

  testWidgets('mini bar shows the station and expands on tap', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('MANGORADIO'), findsOneWidget);
    expect(find.text('Now playing'), findsNothing);
    await captureScreenshot(find.byType(MaterialApp), 'panel_collapsed');

    await tester.tap(find.text('MANGORADIO'));
    await tester.pumpAndSettle();

    expect(find.text('Now playing'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('MP3 · 128 kbps'), findsOneWidget);
    await captureScreenshot(find.byType(MaterialApp), 'panel_expanded');
  });

  testWidgets('dragging up expands and dragging down collapses', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.fling(find.text('MANGORADIO'), const Offset(0, -400), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Now playing'), findsOneWidget);

    await tester.fling(find.text('Now playing'), const Offset(0, 400), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Now playing'), findsNothing);
  });

  testWidgets('chevron collapses the expanded player', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.tap(find.text('MANGORADIO'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Minimise player'));
    await tester.pumpAndSettle();
    expect(find.text('Now playing'), findsNothing);
  });

  testWidgets('visualiser respects the setting and reduce motion', (
    tester,
  ) async {
    await setPhoneSize(tester);

    await tester.pumpWidget(app());
    await tester.pump();
    await tester.tap(find.text('MANGORADIO'));
    await tester.pumpAndSettle();
    expect(find.byType(Visualizer), findsOneWidget);

    await tester.runAsync(() => controller.updateShowVisualizer(false));
    await tester.pumpAndSettle();
    expect(find.byType(Visualizer), findsNothing);

    await tester.runAsync(() => controller.updateShowVisualizer(true));
    await tester.pumpWidget(app(reduceMotion: true));
    await tester.pumpAndSettle();
    expect(find.byType(Visualizer), findsNothing);
  });

  testWidgets('dark theme expanded', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(app(brightness: Brightness.dark));
    await tester.pump();
    await tester.tap(find.text('MANGORADIO'));
    await tester.pumpAndSettle();
    await captureScreenshot(find.byType(MaterialApp), 'panel_expanded_dark');
  });

  testWidgets('header shows the station country', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.tap(find.text('MANGORADIO'));
    await tester.pumpAndSettle();
    expect(find.text('🇩🇪 Germany'), findsOneWidget);
  });

  testWidgets('liking a station toggles and is saved', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.tap(find.text('MANGORADIO'));
    await tester.pumpAndSettle();

    expect(controller.isLiked(station), isFalse);
    // Vote registration fails offline in tests; the like must still stick.
    await tester.runAsync(() => controller.toggleLike(station));
    await tester.pump();
    expect(controller.isLiked(station), isTrue);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(
      await tester.runAsync(() => SettingsService().likedStations()),
      contains(station.stationUUID),
    );

    await tester.tap(find.byTooltip('Unlike'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(controller.isLiked(station), isFalse);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
  });

  testWidgets('wide screens put details beside the artwork', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.tap(find.text('MANGORADIO'));
    await tester.pumpAndSettle();

    final title = tester.getRect(find.text('MANGORADIO'));
    final play = tester.getRect(find.byTooltip('Play'));
    expect(title.left, greaterThan(800), reason: 'details on the right half');
    expect(play.left, greaterThan(800));
    expect(
      tester.getSize(find.byType(Visualizer)).height,
      lessThanOrEqualTo(72),
      reason: 'visualiser stays capped on wide layouts',
    );
    await captureScreenshot(find.byType(MaterialApp), 'panel_expanded_wide');
  });

  testWidgets('short landscape phone keeps controls reachable', (tester) async {
    tester.view.physicalSize = const Size(2340, 1080);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.tap(find.text('MANGORADIO'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'no overflow');
    await tester.ensureVisible(find.byTooltip('Play'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Play').hitTestable(), findsOneWidget);
    await captureScreenshot(
      find.byType(MaterialApp),
      'panel_expanded_landscape_phone',
    );
  });

  test('player text stays readable over any artwork colour', () {
    double contrast(Color a, Color b) {
      final (la, lb) = (a.computeLuminance(), b.computeLuminance());
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    // Includes the charcoal from a real logo that made text unreadable.
    const artwork = [
      Colors.black,
      Colors.white,
      Color(0xFF2A2F2E),
      Colors.red,
      Colors.yellow,
      Colors.blue,
      Colors.green,
      Color(0xFF800080),
    ];
    for (final colour in artwork) {
      for (final brightness in Brightness.values) {
        final scheme = ColorScheme.fromSeed(
          seedColor: colour,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.content,
        );
        final background = playerBackdropTint(scheme);
        for (final text in [scheme.onSurface, scheme.onSurfaceVariant]) {
          expect(
            contrast(text, background),
            greaterThanOrEqualTo(4.5),
            reason: '$colour, $brightness',
          );
        }
      }
    }
  });

  testWidgets('track title replaces the region line and falls back', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final audio = controller.audio;
    audio.setStation(station);
    await tester.pumpWidget(app());
    await tester.pump();
    final region = find.textContaining(
      station.state.isNotEmpty
          ? station.state
          // ignore: deprecated_member_use
          : station.country,
    );
    expect(region, findsOneWidget);

    audio.mediaItem.add(
      audio.mediaItem.value!.copyWith(artist: 'Nina Simone – Feeling Good'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nina Simone – Feeling Good'), findsOneWidget);
    expect(region, findsNothing);

    audio.mediaItem.add(audio.mediaItem.value!.copyWith(artist: null));
    await tester.pumpAndSettle();
    expect(find.text('Nina Simone – Feeling Good'), findsNothing);
    expect(region, findsOneWidget);
  });

  testWidgets('loading line shows only while connecting', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.tap(find.text('MANGORADIO'));
    await tester.pumpAndSettle();

    final line = find.byType(LinearProgressIndicator);
    expect(line, findsNothing, reason: 'stopped: no line');
    expect(find.text('Stopped'), findsOneWidget);

    controller.audio.playbackState.add(
      PlaybackState(
        playing: true,
        processingState: AudioProcessingState.loading,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    // Mini bar is hidden when expanded, so this is the full player's line.
    expect(line.hitTestable(), findsOneWidget);
    expect(find.text('Connecting…'), findsOneWidget);

    controller.audio.playbackState.add(
      PlaybackState(playing: true, processingState: AudioProcessingState.ready),
    );
    // Visualiser animates while playing, so pump frames instead of settling.
    await tester.pump(const Duration(milliseconds: 300));
    expect(line, findsNothing, reason: 'playing: line removed');
    expect(find.text('Playing'), findsOneWidget);

    controller.audio.playbackState.add(PlaybackState());
    await tester.pump(const Duration(seconds: 1));
  });
}
