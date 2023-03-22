import 'package:flutter/material.dart';
import 'package:fluttery_radio/controllers/settings_controller.dart';
import 'package:fluttery_radio/screens/settings_screen.dart';
import 'package:fluttery_radio/screens/stations_list_screen.dart';
import 'package:fluttery_radio/widgets/player.dart';

import '../models/location.dart';
import '../models/station.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen(this.settingsController, {Key? key, required this.title})
      : super(key: key);

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
      transitionDuration: const Duration(
        milliseconds: 500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder(
          valueListenable: widget.settingsController.location,
          builder: (ctx, Location? location, _) => Text(
            location == null ? "" : location.asString(),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _displayDialog(context);
            },
            icon: const Icon(
              Icons.settings,
            ),
          ),
        ],
      ),
      body: widget.settingsController.location.value == null
          ? _buildNoLocationMessage()
          : _buildLocationAvailableView(),
    );
  }

  Widget _buildLocationAvailableView() {
    return ValueListenableBuilder(
      valueListenable: widget.settingsController.station,
      builder: (ctx, Station? station, _) => Stack(children: [
        _buildStationsListView(station),
        _buildPlayer(station),
      ]),
    );
  }

  Widget _buildPlayer(Station? station) {
    return station != null
        ? Player(widget.settingsController, station)
        : Container();
  }

  Widget _buildStationsListView(Station? station) {
    return StationsListScreen(
      station,
      widget.settingsController,
    );
  }

  Widget _buildNoLocationMessage() {
    return const Center(
      child: Text(
        'Please select a country for listing radio stations',
      ),
    );
  }
}
