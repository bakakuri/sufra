import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Where pictures come from: the internet, kept on the phone after the first look (the tests swap in their own).
ImageProvider Function(String url) netImage = (u) => CachedNetworkImageProvider(u);

/// A picture from a link, faded in once it is there, on a quiet background until then.
class PImage extends StatelessWidget {
  const PImage(this.url, {super.key, this.fit = BoxFit.cover, this.width, this.height, this.radius = 0, this.background});
  final String url;

  /// behind the picture while it loads; the theme's quiet grey unless given
  final Color? background;
  final BoxFit fit;
  final double? width, height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    Widget im = Image(
      image: netImage(url),
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      frameBuilder: (_, child, frame, sync) => sync
          ? child
          : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 220), child: child),
      errorBuilder: (_, __, ___) => Container(width: width, height: height, color: background ?? c.sunk),
    );
    im = DecoratedBox(decoration: BoxDecoration(color: background ?? c.sunk), child: im);
    if (radius > 0) im = ClipRRect(borderRadius: BorderRadius.circular(radius), child: im);
    return im;
  }
}
