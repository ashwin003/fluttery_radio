import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttery_radio/services/country_estimator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;

  tearDown(() {
    dispatcher.clearLocaleTestValue();
    dispatcher.clearLocalesTestValue();
  });

  void setLocales(List<Locale> locales) {
    dispatcher.localeTestValue = locales.first;
    dispatcher.localesTestValue = locales;
  }

  test('uses the region of the primary locale', () {
    setLocales([const Locale('en', 'IN')]);
    final location = estimateLocationFromDevice()!;
    expect(location.countryCode, 'IN');
    expect(location.country, 'India');
    expect(location.state, '');
  });

  test('falls back to a later locale when the first has no region', () {
    setLocales([const Locale('en'), const Locale('de', 'DE')]);
    expect(estimateLocationFromDevice()!.countryCode, 'DE');
  });

  test('ignores UN M.49 region codes', () {
    setLocales([const Locale('es', '419'), const Locale('es', 'MX')]);
    expect(estimateLocationFromDevice()!.countryCode, 'MX');
  });

  test('returns null when no locale has a country', () {
    setLocales([const Locale('en'), const Locale('fr')]);
    expect(estimateLocationFromDevice(), isNull);
  });
}
