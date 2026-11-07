import 'package:flutter_test/flutter_test.dart';

/// Saves a screenshot to `test/goldens/<name>.png` for visual review.
///
/// Only runs with `flutter test --update-goldens`: the images aren't
/// committed (test fonts render text as boxes, so they're not useful as
/// regression baselines), and a normal test run shouldn't depend on them.
Future<void> captureScreenshot(Finder finder, String name) async {
  if (!autoUpdateGoldenFiles) return;
  await expectLater(finder, matchesGoldenFile('goldens/$name.png'));
}
