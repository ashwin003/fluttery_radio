import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttery_radio/widgets/themed_settings_list.dart';
import 'package:settings_ui/settings_ui.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'follows the app theme: $brightness',
      (tester) async {
        final scheme = ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: brightness,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(colorScheme: scheme),
            home: Scaffold(
              body: ThemedSettingsList(
                sections: [
                  SettingsSection(
                    title: const Text('Appearance'),
                    tiles: [SettingsTile(title: const Text('Theme'))],
                  ),
                ],
              ),
            ),
          ),
        );

        final list = find.byType(SettingsList);
        expect(
          tester
              .widget<SettingsList>(list)
              .calculateBrightness(tester.element(list)),
          brightness,
        );
        // The list paints the app's own surface, not settings_ui's default.
        final painted = [
          ...tester
              .widgetList<ColoredBox>(
                find.descendant(of: list, matching: find.byType(ColoredBox)),
              )
              .map((b) => b.color),
          ...tester
              .widgetList<Container>(
                find.descendant(of: list, matching: find.byType(Container)),
              )
              .map((c) => c.color),
          ...tester
              .widgetList<DecoratedBox>(
                find.descendant(of: list, matching: find.byType(DecoratedBox)),
              )
              .map((d) => (d.decoration as BoxDecoration?)?.color),
        ];
        expect(painted, contains(scheme.surface));
      },
      // Android uses settings_ui's Material style, Linux its GNOME style.
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.linux,
      }),
    );
  }
}
