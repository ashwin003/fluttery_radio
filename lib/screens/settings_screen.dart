import 'package:flutter/material.dart';
import 'package:fluttery_radio/controllers/settings_controller.dart';
import 'package:fluttery_radio/dialogs/language_selector_dialog.dart';
import 'package:fluttery_radio/dialogs/location_selector_dialog.dart';
import 'package:fluttery_radio/dialogs/theme_selector_dialog.dart';
import 'package:fluttery_radio/extensions/theme_extensions.dart';
import 'package:fluttery_radio/models/location.dart';
import 'package:settings_ui/settings_ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen(this._settingsController, {Key? key}) : super(key: key);
  final SettingsController _settingsController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Settings',
          ),
        ),
        body: SettingsList(
          sections: [
            SettingsSection(
              title: const Text('Appearance'),
              tiles: [
                _buildThemeSettingsTile(),
              ],
            ),
            SettingsSection(
              title: const Text(
                'General',
              ),
              tiles: [
                _buildLanguageSettingsTile(),
                _buildLocationSettingsTile()
              ],
            ),
            SettingsSection(
              title: const Text(
                'About',
              ),
              tiles: [
                _buildVersionSettingsTile(),
              ],
            )
          ],
        ));
  }

  SettingsTile _buildLocationSettingsTile() {
    return SettingsTile.navigation(
      leading: const Icon(Icons.location_pin),
      title: const Text(
        'Location',
      ),
      value: Text(_settingsController.location.asString()),
      onPressed: (ctx) => showDialog(
        context: ctx,
        builder: (ctx) => LocationSelectorDialog(_settingsController.location,
            (country, state) async {
          final location = Location(country: country, state: state ?? "");
          await _settingsController.updateLocation(location);
        }),
        barrierDismissible: false,
      ),
    );
  }

  SettingsTile _buildVersionSettingsTile() {
    return SettingsTile.navigation(
      leading: const Icon(Icons.info),
      title: const Text('Version'),
      value: const Text('1.0.0'),
      onPressed: (ctx) {
        showAboutDialog(context: ctx);
      },
    );
  }

  SettingsTile _buildThemeSettingsTile() {
    return SettingsTile.navigation(
      leading: const Icon(Icons.dark_mode),
      title: const Text('Theme'),
      value: Text(_settingsController.themeMode.asString()),
      onPressed: (ctx) {
        showDialog(
          context: ctx,
          builder: (ctx) => ThemeSelectorDialog(
            _settingsController.themeMode,
            _settingsController.updateThemeMode,
          ),
        );
      },
    );
  }

  SettingsTile _buildLanguageSettingsTile() {
    return SettingsTile.navigation(
      leading: const Icon(Icons.language),
      title: const Text('Language'),
      value: Text(_settingsController.language.name),
      onPressed: (ctx) {
        showDialog(
          context: ctx,
          builder: (ctx) => LanguageSelectorDialog(
              _settingsController.updateLanguage, _settingsController.language),
        );
      },
    );
  }
}
