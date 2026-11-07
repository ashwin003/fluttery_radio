import 'package:radio_browser_flutter/radio_browser_flutter.dart';

import '../models/location.dart';

class StationService {
  Future<List<Station>> searchStations(
    Location location,
    String language,
    int pageNumber,
    int pageSize,
  ) {
    final hasCode = location.countryCode.isNotEmpty;
    return RadioBrowserClient.instance.stations.search(
      // Prefer the exact country code; fall back to name for old settings.
      country: hasCode ? null : location.country,
      countryCode: hasCode ? location.countryCode : null,
      state: location.state.isEmpty ? null : location.state,
      // States picked from radio-browser's own list match exactly.
      stateExact: hasCode && location.state.isNotEmpty ? true : null,
      language: language.toLowerCase(),
      offset: (pageNumber - 1) * pageSize,
      limit: pageSize,
      hideBroken: true,
      order: StationSortOrder.clickcount,
      reverse: true,
    );
  }
}
