import 'package:flutter/material.dart';
import 'package:fluttery_radio/controllers/settings_controller.dart';
import 'package:fluttery_radio/dialogs/location_pickers.dart';
import 'package:fluttery_radio/screens/settings_screen.dart';
import 'package:fluttery_radio/screens/stations_list_screen.dart';
import 'package:fluttery_radio/widgets/player.dart';

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
          : _buildLocationAvailableView(),
    );
  }

  Widget _buildLocationAvailableView() {
    return ValueListenableBuilder(
      valueListenable: widget.settingsController.station,
      builder: (ctx, Station? station, _) => Stack(
        children: [_buildStationsListView(station), _buildPlayer(station)],
      ),
    );
  }

  Widget _buildPlayer(Station? station) {
    return station != null
        ? Player(widget.settingsController, station)
        : Container();
  }

  Widget _buildStationsListView(Station? station) {
    return StationsListScreen(station, widget.settingsController);
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
