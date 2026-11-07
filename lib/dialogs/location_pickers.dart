import 'package:flutter/material.dart';
import 'package:radio_browser_flutter/radio_browser_flutter.dart';

import '../controllers/settings_controller.dart';
import '../models/location.dart';
import '../widgets/searchable_picker_page.dart';

/// Converts an ISO 3166-1 alpha-2 code to its flag emoji ("DE" → 🇩🇪).
String flagEmoji(String countryCode) {
  if (countryCode.length != 2) return '🏳️';
  const base = 0x1F1E6 - 0x41; // Regional indicator 'A' minus ASCII 'A'
  final upper = countryCode.toUpperCase();
  return String.fromCharCodes([
    base + upper.codeUnitAt(0),
    base + upper.codeUnitAt(1),
  ]);
}

String _stationCount(int n) => n == 1 ? '1 station' : '$n stations';

Future<List<Country>>? _countriesCache;

Future<List<Country>> _fetchCountries() {
  return _countriesCache ??= RadioBrowserClient.instance.countries
      .fetchCountries(hideBroken: true)
      .then(
        (list) =>
            list.where((c) => c.name.isNotEmpty && c.stationCount > 0).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      )
      .catchError((Object e) {
        _countriesCache = null; // allow retry
        throw e;
      });
}

/// Opens a searchable list of countries that have radio stations.
Future<Country?> pickCountry(BuildContext context, {String? currentCode}) {
  return SearchablePickerPage.show<Country>(
    context,
    title: 'Choose country',
    searchHint: 'Search countries',
    isSelected: (c) =>
        currentCode != null &&
        c.countryCode.toUpperCase() == currentCode.toUpperCase(),
    loader: () async => (await _fetchCountries())
        .map(
          (c) => PickerOption(
            value: c,
            label: c.name,
            subtitle: _stationCount(c.stationCount),
            leading: Text(
              flagEmoji(c.countryCode),
              style: const TextStyle(fontSize: 24),
            ),
            searchTerms: c.countryCode,
          ),
        )
        .toList(),
  );
}

/// Sentinel returned by [pickState] when the user chooses the whole country.
const allRegions = '';

/// Opens a searchable list of states/regions in [country]. Returns
/// [allRegions] when the user picks "All regions", or null when dismissed.
Future<String?> pickState(
  BuildContext context, {
  required String country,
  String countryCode = '',
  String? current,
}) {
  return SearchablePickerPage.show<String>(
    context,
    title: 'Choose state / region',
    searchHint: 'Search in $country',
    isSelected: (s) => s == (current ?? allRegions),
    pinned: [
      PickerOption(
        value: allRegions,
        label: 'All regions',
        subtitle: 'Show stations from all of $country',
        leading: const Icon(Icons.public),
      ),
    ],
    loader: () async {
      // Names may differ from radio-browser's (e.g. an estimated "United
      // States" vs "The United States Of America"), so resolve by code.
      var apiCountry = country;
      if (countryCode.isNotEmpty) {
        final match = (await _fetchCountries()).where(
          (c) => c.countryCode.toUpperCase() == countryCode.toUpperCase(),
        );
        if (match.isNotEmpty) apiCountry = match.first.name;
      }
      final states = await RadioBrowserClient.instance.countries.fetchStates(
        country: apiCountry,
        hideBroken: true,
      );
      // The API matches country names loosely; keep exact matches only.
      final filtered =
          states
              .where(
                (s) =>
                    s.name.trim().isNotEmpty &&
                    s.stationCount > 0 &&
                    s.country.toLowerCase() == apiCountry.toLowerCase(),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      return filtered
          .map(
            (s) => PickerOption(
              value: s.name,
              label: s.name,
              subtitle: _stationCount(s.stationCount),
              leading: const Icon(Icons.place_outlined),
            ),
          )
          .toList();
    },
  );
}

/// Country → state flow. After choosing a new country the state list opens
/// straight away; backing out of it keeps "All regions".
Future<void> chooseCountry(
  BuildContext context,
  SettingsController controller,
) async {
  final current = controller.location.value;
  final country = await pickCountry(
    context,
    currentCode: current?.countryCode,
  );
  if (country == null || !context.mounted) return;

  final sameCountry =
      current != null &&
      (current.countryCode.isNotEmpty
          ? current.countryCode.toUpperCase() ==
                country.countryCode.toUpperCase()
          : current.country == country.name);
  // Re-picking an estimated country confirms (and saves) it.
  if (sameCountry && !controller.isLocationEstimated) return;

  await controller.updateLocation(
    Location(country: country.name, countryCode: country.countryCode),
  );
  if (!context.mounted) return;
  await chooseState(context, controller);
}

Future<void> chooseState(
  BuildContext context,
  SettingsController controller,
) async {
  final current = controller.location.value;
  if (current == null || current.country.isEmpty) return;
  final state = await pickState(
    context,
    country: current.country,
    countryCode: current.countryCode,
    current: current.state,
  );
  if (state == null || state == current.state) return;
  await controller.updateLocation(
    Location(
      country: current.country,
      countryCode: current.countryCode,
      state: state,
    ),
  );
}
