import 'package:flutter/material.dart';
import 'package:fluttery_radio/controllers/settings_controller.dart';
import 'package:fluttery_radio/widgets/detailed_player.dart';
import 'package:fluttery_radio/widgets/small_player.dart';
import 'package:miniplayer/miniplayer.dart';

const double playerMinHeight = 70;
const double playerMaxHeight = 370;
const miniplayerPercentageDeclaration = 0.2;

class Player extends StatefulWidget {
  final SettingsController _settingsController;
  const Player(this._settingsController, {Key? key}) : super(key: key);

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  final ValueNotifier<double> playerExpandProgress =
      ValueNotifier(playerMinHeight);
  bool _isPlaying = false;

  final MiniplayerController controller = MiniplayerController();

  void onTap() {
    _isPlaying = !_isPlaying;
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final maxImgSize = width * 0.4;
    final img = Image.network(
      widget._settingsController.station!.favicon,
      errorBuilder: (ctx, ex, st) => Image.network(
        "https://www.shareicon.net/data/256x256/2015/11/01/147855_music_256x256.png",
      ),
    );
    final text = Text(widget._settingsController.station!.name);
    final playButton = IconButton(
      icon: const Icon(Icons.play_arrow_outlined),
      onPressed: onTap,
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

        return !miniplayer
            ? _buildDetailedPlayer(
                height, percentage, width, maxImgSize, playButton, text, img)
            : _buildSmallPlayer(
                height, percentage, width, maxImgSize, playButton, text, img);
      },
    );
  }

  Widget _buildSmallPlayer(double height, double percentage, double width,
      double maxImgSize, IconButton playButton, Text text, Image img) {
    return SmallPlayer(
        widget._settingsController,
        controller,
        playerMaxHeight,
        playerMinHeight,
        miniplayerPercentageDeclaration,
        height,
        percentage,
        width,
        maxImgSize,
        playButton,
        text,
        img);
  }

  Widget _buildDetailedPlayer(double height, double percentage, double width,
      double maxImgSize, IconButton playButton, Text text, Image img) {
    return DetailedPlayer(
      playerMaxHeight,
      playerMinHeight,
      miniplayerPercentageDeclaration,
      height,
      percentage,
      width,
      maxImgSize,
      playButton,
      text,
      img,
    );
  }
}
