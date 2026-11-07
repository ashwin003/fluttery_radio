import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttery_radio/controllers/settings_controller.dart';
import 'package:fluttery_radio/models/station_query.dart';
import 'package:fluttery_radio/screens/stations_list_screen.dart';
import 'package:fluttery_radio/services/audio_player_handler.dart';
import 'package:fluttery_radio/services/settings_service.dart';
import 'package:fluttery_radio/services/station_service.dart';
import 'package:fluttery_radio/models/location.dart';
import 'package:fluttery_radio/widgets/station_items.dart';
import 'package:radio_browser_flutter/radio_browser_flutter.dart' show Station;
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/screenshot.dart';

Station _station(String name, {String uuid = '', int votes = 0}) {
  final data =
      json.decode(File('test/fixtures/station.json').readAsStringSync())
          as Map<String, dynamic>;
  data['name'] = name;
  data['stationuuid'] = uuid.isEmpty ? name : uuid;
  data['votes'] = votes;
  return Station.fromJson(data);
}

/// Stands in for radio-browser so tests run offline.
class _FakeStationService extends StationService {
  final List<Station> stations;
  _FakeStationService([this.stations = const []]);

  @override
  Future<List<Station>> searchStations(
    Location location,
    StationQuery query,
    int pageNumber,
    int pageSize,
  ) async => pageNumber == 1 ? stations : [];
}

void main() {
  late SettingsController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = SettingsController(
      SettingsService(),
      AudioPlayerHandler(useSoloud: false),
    );
    await controller.loadSettings();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Station> remote = const [],
    Size size = const Size(1080, 2340),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2.75;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        home: Scaffold(
          body: StationsListScreen(
            null,
            controller,
            onOpenSettings: () {},
            stationService: _FakeStationService(remote),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> likeAll(WidgetTester tester, List<Station> stations) async {
    await tester.runAsync(() async {
      for (final s in stations) {
        await controller.toggleLike(s);
      }
    });
  }

  Future<void> setQuery(WidgetTester tester, StationQuery query) async {
    await tester.runAsync(() => controller.updateQuery(query));
    await tester.pumpAndSettle();
  }

  testWidgets('liked filter lists liked stations, sorted', (tester) async {
    await likeAll(tester, [
      _station('Beta FM', votes: 5),
      _station('Alpha Radio', votes: 50),
      _station('Gamma Jazz', votes: 1),
    ]);
    await pumpScreen(tester);
    await setQuery(
      tester,
      const StationQuery(likedOnly: true, sort: StationSort.mostLiked),
    );

    // The large app bar renders its title expanded and collapsed.
    expect(find.text('Liked stations'), findsWidgets);
    final names = tester
        .widgetList<StationTile>(find.byType(StationTile))
        .map((t) => t.station.name)
        .toList();
    expect(names, ['Alpha Radio', 'Beta FM', 'Gamma Jazz']);

    await setQuery(
      tester,
      const StationQuery(likedOnly: true, sort: StationSort.name),
    );
    expect(
      tester
          .widgetList<StationTile>(find.byType(StationTile))
          .map((t) => t.station.name),
      ['Alpha Radio', 'Beta FM', 'Gamma Jazz'],
    );
    await captureScreenshot(find.byType(MaterialApp), 'stations_list');
  });

  testWidgets('search filters liked stations', (tester) async {
    await likeAll(tester, [_station('Alpha Radio'), _station('Beta FM')]);
    await pumpScreen(tester);
    await setQuery(tester, const StationQuery(likedOnly: true));

    await tester.enterText(find.byType(SearchBar), 'beta');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(controller.query.value.search, 'beta');
    expect(find.byType(StationTile), findsOneWidget);
    expect(find.text('Beta FM'), findsOneWidget);
  });

  testWidgets('switching to cards shows a grid and is remembered', (
    tester,
  ) async {
    await likeAll(tester, [
      _station('Alpha Radio'),
      _station('Beta FM'),
      _station('Gamma Jazz'),
      _station('Delta News'),
    ]);
    await pumpScreen(tester);
    await setQuery(tester, const StationQuery(likedOnly: true));

    await tester.tap(find.byTooltip('Cards'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.byType(StationCard), findsNWidgets(4));
    expect(find.byType(StationTile), findsNothing);
    expect(
      await tester.runAsync(() => SettingsService().stationLayout()),
      StationLayout.grid,
    );
    await captureScreenshot(find.byType(MaterialApp), 'stations_grid');
  });

  testWidgets('filter sheet applies filters shown as removable chips', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'jazz'));
    final chip128 = find.widgetWithText(ChoiceChip, '128 kbps');
    final sheetList = find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(chip128, 100, scrollable: sheetList);
    // Clear the pinned "Show results" footer.
    await tester.drag(sheetList, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(chip128);
    await tester.pump();
    await captureScreenshot(find.byType(MaterialApp), 'filter_sheet');
    await tester.tap(find.text('Show results'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(controller.query.value.genre, 'jazz');
    expect(controller.query.value.minBitrate, 128);
    expect(find.widgetWithText(InputChip, 'jazz'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(InputChip, '128+ kbps'),
      100,
      scrollable: find
          .ancestor(
            of: find.widgetWithText(InputChip, 'jazz'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.widgetWithText(InputChip, '128+ kbps'), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: 'filter badge count');

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'jazz'),
        matching: find.byTooltip('Remove filter'),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(controller.query.value.genre, isNull);
    expect(find.widgetWithText(InputChip, 'jazz'), findsNothing);
  });

  testWidgets('sort menu changes and remembers the order', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trending'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(controller.query.value.sort, StationSort.trending);
    expect(
      await tester.runAsync(() => SettingsService().stationSort()),
      StationSort.trending,
    );
  });

  testWidgets('no likes yet shows a helpful empty state', (tester) async {
    await pumpScreen(tester);
    await setQuery(tester, const StationQuery(likedOnly: true));
    expect(find.text('No liked stations yet'), findsOneWidget);
    expect(find.text('Clear filters'), findsNothing);
  });

  testWidgets('cards never overflow, even with large text', (tester) async {
    final stations = [
      for (var i = 0; i < 6; i++)
        _station('A station with a really very long name number $i that wraps'),
    ];
    for (final scale in [1.0, 1.3, 2.0]) {
      await tester.runAsync(() => controller.updateLayout(StationLayout.grid));
      await pumpScreen(tester, remote: stations, textScale: scale);
      expect(find.byType(StationCard), findsWidgets);
      expect(tester.takeException(), isNull, reason: 'text scale $scale');
    }
  });

  testWidgets('language defaults to any and is remembered as a filter', (
    tester,
  ) async {
    expect(controller.query.value.language, isNull);
    await pumpScreen(tester);
    await setQuery(tester, const StationQuery(language: 'hindi'));

    expect(find.widgetWithText(InputChip, 'Hindi'), findsOneWidget);
    expect(
      await tester.runAsync(() => SettingsService().languageFilter()),
      'hindi',
    );

    await tester.ensureVisible(find.widgetWithText(InputChip, 'Hindi'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'Hindi'),
        matching: find.byTooltip('Remove filter'),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(controller.query.value.language, isNull);
    expect(
      await tester.runAsync(() => SettingsService().languageFilter()),
      isNull,
    );
  });
}
