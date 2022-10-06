import 'package:flutter/material.dart';
import 'package:fluttery_radio/controllers/settings_controller.dart';
import 'package:fluttery_radio/screens/settings_screen.dart';
import 'package:fluttery_radio/screens/stations_list_screen.dart';
import 'package:fluttery_radio/widgets/player.dart';

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

  String _getTitle() {
    late String title = widget.settingsController.location.asString();
    return title == "" ? widget.title : title;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
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
      body: widget.settingsController.location.asString() == ""
          ? _buildNoLocationMessage()
          : Stack(
              children: [
                _buildStationsListView(),
                _buildPlayer(),
              ],
            ),
    );
  }

  Widget _buildPlayer() {
    return widget.settingsController.station != null
        ? Player(widget.settingsController)
        : Container();
  }

  Widget _buildStationsListView() {
    return StationsListScreen(
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
