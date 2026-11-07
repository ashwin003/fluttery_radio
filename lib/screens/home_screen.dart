import 'package:flutter/material.dart';
import 'package:fluttery_radio/controllers/settings_controller.dart';
import 'package:fluttery_radio/dialogs/location_pickers.dart';
import 'package:fluttery_radio/screens/settings_screen.dart';
import 'package:fluttery_radio/screens/stations_list_screen.dart';
import 'package:fluttery_radio/widgets/player/player_panel.dart';

import '../models/location.dart';
import 'package:radio_browser_flutter/radio_browser_flutter.dart' show Station;

class HomeScreen extends StatefulWidget {
  const HomeScreen(this.settingsController, {super.key, required this.title});

  final String title;
  final SettingsController settingsController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _displayDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      pageBuilder: (c, a, s) => SettingsScreen(widget.settingsController),
      transitionDuration: const Duration(milliseconds: 500),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The panel sits above the Scaffold so the expanded player can cover the
    // app bar, like a full-screen "now playing" view.
    return ValueListenableBuilder(
      valueListenable: widget.settingsController.station,
      builder: (context, Station? station, _) => Stack(
        children: [
          _buildScaffold(context, station),
          if (station != null)
            Positioned.fill(
              child: PlayerPanel(
                controller: widget.settingsController,
                station: station,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, Station? station) {
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder(
          valueListenable: widget.settingsController.location,
          builder: (ctx, Location? location, _) =>
              Text(location == null ? "" : location.asString()),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _displayDialog(context);
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: (widget.settingsController.location.value?.country ?? '').isEmpty
          ? _buildNoLocationMessage()
          : _buildStationsListView(station),
    );
  }

  Widget _buildStationsListView(Station? station) {
    return StationsListScreen(
      station,
      widget.settingsController,
      bottomPadding: station == null ? 0 : PlayerPanel.collapsedHeight(context),
    );
  }

  Widget _buildNoLocationMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radio, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Choose a country to see its radio stations',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Choose country'),
              onPressed: () async {
                await chooseCountry(context, widget.settingsController);
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}
