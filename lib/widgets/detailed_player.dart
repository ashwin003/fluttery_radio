import 'package:flutter/material.dart';

import '../models/station.dart';
import '../utils/utils.dart';

class DetailedPlayer extends StatelessWidget {
  final double playerMaxHeight,
      playerMinHeight,
      miniplayerPercentageDeclaration,
      height,
      width,
      maxImgSize;
  final IconButton playButton;
  final Image img;
  final Station station;
  const DetailedPlayer(
      this.playerMaxHeight,
      this.playerMinHeight,
      this.miniplayerPercentageDeclaration,
      this.height,
      this.width,
      this.maxImgSize,
      this.playButton,
      this.img,
      this.station,
      {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    var percentageExpandedPlayer = percentageFromValueInRange(
        min:
            playerMaxHeight * miniplayerPercentageDeclaration + playerMinHeight,
        max: playerMaxHeight,
        value: height);
    if (percentageExpandedPlayer < 0) percentageExpandedPlayer = 0;
    final paddingVertical = valueFromPercentageInRange(
        min: 0, max: 10, percentage: percentageExpandedPlayer);
    final double heightWithoutPadding = height - paddingVertical * 2;
    final double imageSize =
        heightWithoutPadding > maxImgSize ? maxImgSize : heightWithoutPadding;
    final paddingLeft = valueFromPercentageInRange(
          min: 0,
          max: width - imageSize,
          percentage: percentageExpandedPlayer,
        ) /
        2;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(
                left: paddingLeft,
                top: paddingVertical,
                bottom: paddingVertical),
            child: SizedBox(
              height: imageSize,
              child: img,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 33),
            child: Opacity(
              opacity: percentageExpandedPlayer,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Flexible(child: Text(station.name)),
                  Flexible(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        playButton,
                      ],
                    ),
                  ),
                  Container(),
                  Container(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
