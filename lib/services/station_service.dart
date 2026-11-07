import 'package:radio_browser_flutter/radio_browser_flutter.dart';

class StationService {
  Future<List<Station>> searchStations(
    String country,
    String state,
    String language,
    int pageNumber,
    int pageSize,
  ) {
    return RadioBrowserClient.instance.stations.search(
      country: country,
      state: state,
      language: language.toLowerCase(),
      offset: (pageNumber - 1) * pageSize,
      limit: pageSize,
      hideBroken: true,
      order: StationSortOrder.clickcount,
      reverse: true,
    );
  }
}
