import 'package:flutter/material.dart';
import 'package:fluttery_radio/app_scope.dart';
import 'package:fluttery_radio/controllers/settings_controller.dart';
import 'package:fluttery_radio/dialogs/accent_color_dialog.dart';
import 'package:fluttery_radio/dialogs/location_pickers.dart';
import 'package:fluttery_radio/dialogs/theme_selector_dialog.dart';
import 'package:fluttery_radio/extensions/theme_extensions.dart';
import 'package:fluttery_radio/models/accent_color.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:url_launcher/url_launcher.dart';

const _radioBrowserUrl = 'https://www.radio-browser.info';
const _sourceCodeUrl = 'https://github.com/ashwin003/fluttery_radio';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen(this._settingsController, {super.key});
  final SettingsController _settingsController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      // Rebuild whenever a setting changes so tile values stay current.
      body: ListenableBuilder(
        listenable: Listenable.merge([
          _settingsController,
          _settingsController.location,
        ]),
        builder: (context, _) => SettingsList(
          sections: [
            SettingsSection(
              title: const Text('Appearance'),
              tiles: [
                _buildThemeSettingsTile(),
                _buildAccentColorSettingsTile(context),
                _buildVisualizerSettingsTile(context),
              ],
            ),
            SettingsSection(
              title: const Text('Stations'),
              tiles: [_buildCountrySettingsTile(), _buildStateSettingsTile()],
            ),
            SettingsSection(
              title: const Text('About'),
              tiles: _buildAboutTiles(context),
            ),
          ],
        ),
      ),
    );
  }

  SettingsTile _buildCountrySettingsTile() {
    final location = _settingsController.location.value;
    final hasCountry = location != null && location.country.isNotEmpty;
    return SettingsTile.navigation(
      leading: hasCountry && location.countryCode.isNotEmpty
          ? Text(
              flagEmoji(location.countryCode),
              style: const TextStyle(fontSize: 22),
            )
          : const Icon(Icons.flag_outlined),
      title: const Text('Country'),
      titleDescription: _settingsController.isLocationEstimated
          ? const Text('Estimated from your device settings')
          : null,
      value: Text(hasCountry ? location.country : 'Not set'),
      onPressed: (ctx) => chooseCountry(ctx, _settingsController),
    );
  }

  SettingsTile _buildStateSettingsTile() {
    final location = _settingsController.location.value;
    final hasCountry = location != null && location.country.isNotEmpty;
    return SettingsTile.navigation(
      enabled: hasCountry,
      leading: const Icon(Icons.location_on_outlined),
      title: const Text('State / region'),
      value: Text(
        !hasCountry
            ? 'Choose a country first'
            : location.state.isEmpty
            ? 'All regions'
            : location.state,
      ),
      onPressed: (ctx) => chooseState(ctx, _settingsController),
    );
  }

  List<SettingsTile> _buildAboutTiles(BuildContext context) {
    final info = AppScope.of(context).packageInfo;
    final version = info.buildNumber.isEmpty
        ? info.version
        : '${info.version} (build ${info.buildNumber})';
    return [
      SettingsTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Version'),
        value: Text(version),
      ),
      SettingsTile(
        leading: const Icon(Icons.public),
        title: const Text('Station data'),
        titleDescription: const Text(
          'Provided by radio-browser.info, a free, community-maintained '
          'directory of radio stations.\n$_radioBrowserUrl',
        ),
        onPressed: (_) => _openUrl(_radioBrowserUrl),
      ),
      SettingsTile(
        leading: const Icon(Icons.flag_outlined),
        title: const Text('Country detection'),
        titleDescription: const Text(
          'Your country is guessed from your device language and region '
          'settings. No location data is used or sent anywhere.',
        ),
      ),
      SettingsTile(
        leading: const Icon(Icons.code),
        title: const Text('Source code'),
        titleDescription: const Text(_sourceCodeUrl),
        onPressed: (_) => _openUrl(_sourceCodeUrl),
      ),
      SettingsTile.navigation(
        leading: const Icon(Icons.description_outlined),
        title: const Text('Open source licences'),
        onPressed: (ctx) => showLicensePage(
          context: ctx,
          applicationName: 'Fluttery Radio',
          applicationVersion: version,
        ),
      ),
    ];
  }

  static Future<void> _openUrl(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  SettingsTile _buildThemeSettingsTile() {
    final mode = _settingsController.themeMode;
    return SettingsTile.navigation(
      leading: Icon(mode.icon),
      title: const Text('Theme'),
      value: Text(mode.label),
      onPressed: (ctx) {
        showDialog(
          context: ctx,
          builder: (ctx) =>
              ThemeSelectorDialog(mode, _settingsController.updateThemeMode),
        );
      },
    );
  }

  SettingsTile _buildAccentColorSettingsTile(BuildContext context) {
    final scope = AppScope.of(context);
    final settings = scope.settings;
    final deviceColorAvailable = scope.deviceAccent != null;
    final accent = settings.accentColor;
    return SettingsTile.navigation(
      // Shows the colour actually in use (resolves "System" too).
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
      title: const Text('Accent colour'),
      value: Text(
        accent == null && !deviceColorAvailable
            ? AccentColor.fallback.name
            : AccentColor.nameOf(accent),
      ),
      onPressed: (ctx) {
        showDialog(context: ctx, builder: (_) => const AccentColorDialog());
      },
    );
  }

  SettingsTile _buildVisualizerSettingsTile(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SettingsTile.switchTile(
      leading: const Icon(Icons.graphic_eq),
      title: const Text('Visualiser'),
      description: const Text(
        'Animated bars and glow in the full-screen player. For most '
        'stations the bars follow the audio. Off when your system asks to '
        'reduce motion.',
      ),
      enabled: !reduceMotion,
      initialValue: _settingsController.showVisualizer && !reduceMotion,
      onToggle: _settingsController.updateShowVisualizer,
    );
  }
}
