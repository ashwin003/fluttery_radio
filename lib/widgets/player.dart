import 'package:flutter/material.dart';
import 'package:fluttery_radio/controllers/settings_controller.dart';
import 'package:fluttery_radio/main.dart';
import 'package:fluttery_radio/widgets/detailed_player.dart';
import 'package:fluttery_radio/widgets/small_player.dart';
import 'package:miniplayer/miniplayer.dart';

import '../models/station.dart';

const double playerMinHeight = 70;
const double playerMaxHeight = 370;
const miniplayerPercentageDeclaration = 0.2;

class Player extends StatefulWidget {
  final SettingsController _settingsController;
  final Station station;
  const Player(this._settingsController, this.station, {Key? key})
      : super(key: key);

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  final ValueNotifier<double> playerExpandProgress =
      ValueNotifier(playerMinHeight);
  final MiniplayerController controller = MiniplayerController();

  @override
  void initState() {
    super.initState();
    widget._settingsController.isPlaying.addListener(_playingStationListener);
    widget._settingsController.station.addListener(_playingStationListener);
    _playingStationListener();
  }

  void _playingStationListener() {
    if (widget._settingsController.isPlaying.value) {
      audioHandler.playFromUri(
          Uri.parse(widget._settingsController.station.value!.url));
    } else {
      audioHandler.stop();
    }
  }

  void _onTap() {
    widget._settingsController
        .updatePlayingStatus(!widget._settingsController.isPlaying.value);
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return ValueListenableBuilder(
      valueListenable: widget._settingsController.isPlaying,
      builder: (ctx, bool? value, _) => _buildMusicPlayer(
        width,
        value ?? false,
        widget.station,
      ),
    );
  }

  Miniplayer _buildMusicPlayer(double width, bool isPlaying, Station station) {
    final maxImgSize = width * 0.4;
    final img = Image.network(
      station.favicon,
      errorBuilder: (ctx, ex, st) => Image.network(
        "https://www.shareicon.net/data/256x256/2015/11/01/147855_music_256x256.png",
      ),
    );
    if (!isPlaying) {
      audioHandler.stop();
    }
    final playButton = IconButton(
      icon: Icon(
        isPlaying ? Icons.pause_outlined : Icons.play_arrow_outlined,
      ),
      onPressed: _onTap,
    );
    return Miniplayer(
      valueNotifier: playerExpandProgress,
      minHeight: playerMinHeight,
      maxHeight: playerMaxHeight,
      controller: controller,
      elevation: 4,
      curve: Curves.easeOut,
      builder: (height, percentage) {
        final bool miniplayer = percentage < miniplayerPercentageDeclaration;

        return miniplayer
            ? _buildSmallPlayer(
                height,
                maxImgSize,
                playButton,
                img,
                station,
              )
            : _buildDetailedPlayer(
                height,
                width,
                maxImgSize,
                playButton,
                img,
                station,
              );
      },
    );
  }

  Widget _buildSmallPlayer(double height, double maxImgSize,
      IconButton playButton, Image img, Station station) {
    return SmallPlayer(
      controller,
      playerMaxHeight,
      playerMinHeight,
      miniplayerPercentageDeclaration,
      height,
      maxImgSize,
      playButton,
      img,
      station,
    );
  }

  Widget _buildDetailedPlayer(double height, double width, double maxImgSize,
      IconButton playButton, Image img, Station station) {
    return DetailedPlayer(
      playerMaxHeight,
      playerMinHeight,
      miniplayerPercentageDeclaration,
      height,
      width,
      maxImgSize,
      playButton,
      img,
      station,
    );
  }
}
