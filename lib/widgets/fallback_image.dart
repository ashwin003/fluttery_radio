import 'package:flutter/material.dart';

class FallbackImage extends StatelessWidget {
  final String uri;
  final double width;
  const FallbackImage(this.uri, this.width, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.network(
      uri,
      errorBuilder: (ctx, ex, st) => Image.network(
        "https://www.shareicon.net/data/256x256/2015/11/01/147855_music_256x256.png",
        width: width,
      ),
      width: width,
    );
  }
}
