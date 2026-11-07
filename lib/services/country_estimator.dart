import 'package:flutter/widgets.dart';

import '../data/country_names.dart';
import '../models/location.dart';

/// Guesses the user's country from the device's locale/region settings
/// (e.g. `en_IN` → India). Works fully offline and uses no location data.
/// Returns `null` when no locale carries a recognisable region.
Location? estimateLocationFromDevice() {
  final dispatcher = WidgetsBinding.instance.platformDispatcher;
  for (final locale in [dispatcher.locale, ...dispatcher.locales]) {
    final code = locale.countryCode?.toUpperCase();
    // Skips missing regions and UN M.49 codes such as "419" (Latin America).
    final name = code == null ? null : countryNames[code];
    if (name != null) return Location(country: name, countryCode: code!);
  }
  return null;
}
