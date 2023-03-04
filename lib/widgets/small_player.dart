import 'package:flutter/material.dart';
import 'package:miniplayer/miniplayer.dart';

import '../controllers/settings_controller.dart';
import '../utils/utils.dart';

class SmallPlayer extends StatelessWidget {
  final SettingsController _settingsController;
  final double playerMaxHeight,
      playerMinHeight,
      miniplayerPercentageDeclaration,
      height,
      percentage,
      width,
      maxImgSize;
  final IconButton playButton;
  final Text text;
  final Image img;
  final MiniplayerController controller;
  const SmallPlayer(
      this._settingsController,
      this.controller,
      this.playerMaxHeight,
      this.playerMinHeight,
      this.miniplayerPercentageDeclaration,
      this.height,
      this.percentage,
      this.width,
      this.maxImgSize,
      this.playButton,
      this.text,
      this.img,
      {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentageMiniplayer = percentageFromValueInRange(
        min: playerMinHeight,
        max:
            playerMaxHeight * miniplayerPercentageDeclaration + playerMinHeight,
        value: height);

    final elementOpacity = 1 - 1 * percentageMiniplayer;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxImgSize),
                child: img,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Opacity(
                    opacity: elementOpacity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_settingsController.station!.name,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(fontSize: 16)),
                        Text(
                          _settingsController.station!.country,
                          style:
                              Theme.of(context).textTheme.bodyMedium!.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .color!
                                        .withOpacity(0.55),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: () {
                    controller.animateToHeight(state: PanelState.MAX);
                  }),
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Opacity(
                  opacity: elementOpacity,
                  child: playButton,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
