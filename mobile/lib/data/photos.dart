import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../ui/look.dart';

/// A photo ready to upload, the way the site keeps photos: the full one (up to 2048 px), a ~1080 px copy
/// for lists (md, only when the photo is bigger than 1200) and a ~480 px one (sm, when bigger than 560).
class PreparedPhoto {
  const PreparedPhoto(this.full, this.w, this.h, {this.md, this.sm});
  final Uint8List full;
  final Uint8List? md, sm;

  /// the size of the list copy, saved with the post so the frame has the right shape before it loads
  final int w, h;
}

/// A photo in a form the picture library reads: as it is when it can, else (HEIC, the way many phones' cameras keep
/// photos, and the like) drawn by the phone's own decoder, upright, about [max] px at most, as PNG.
Future<Uint8List> readablePhoto(Uint8List src, {int max = 2048}) async {
  if (img.findDecoderForData(src) != null) return src;
  final buf = await ui.ImmutableBuffer.fromUint8List(src);
  final desc = await ui.ImageDescriptor.encoded(buf);
  final wide = desc.width >= desc.height;
  // one side only, so the shape stays whichever way the photo is turned
  final codec = await desc.instantiateCodec(
    targetWidth: wide && desc.width > max ? max : null,
    targetHeight: !wide && desc.height > max ? max : null,
  );
  try {
    final f = await codec.getNextFrame();
    final png = await f.image.toByteData(format: ui.ImageByteFormat.png);
    f.image.dispose();
    if (png == null) throw const FormatException('photo');
    return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
  } finally {
    codec.dispose();
    desc.dispose();
    buf.dispose();
  }
}

/// Turned upright (the camera's orientation tag), resized and saved as JPEG, away from the screen's thread.
/// In the economy mode the full one is at most 1080 px.
Future<PreparedPhoto> preparePhoto(Uint8List src) async {
  final s = await readablePhoto(src);
  return ecoMode.value ? compute(_prepareEco, s) : compute(preparePhotoNow, s);
}

PreparedPhoto _prepareEco(Uint8List src) => preparePhotoNow(src, max: 1080);

PreparedPhoto preparePhotoNow(Uint8List src, {int max = 2048}) {
  final d = img.decodeImage(src);
  if (d == null) throw const FormatException('photo');
  final im = img.bakeOrientation(d);
  img.Image fit(img.Image a, int max) {
    final big = a.width > a.height ? a.width : a.height;
    if (big <= max) return a;
    return a.width >= a.height
        ? img.copyResize(a, width: max, interpolation: img.Interpolation.average)
        : img.copyResize(a, height: max, interpolation: img.Interpolation.average);
  }

  final full = fit(im, max), md = fit(full, 1080);
  final big = full.width > full.height ? full.width : full.height;
  return PreparedPhoto(
    img.encodeJpg(full, quality: 86, chroma: img.JpegChroma.yuv420),
    md.width,
    md.height,
    md: big > 1200 ? img.encodeJpg(md, quality: 82, chroma: img.JpegChroma.yuv420) : null,
    sm: big > 560 ? img.encodeJpg(fit(md, 480), quality: 74, chroma: img.JpegChroma.yuv420) : null,
  );
}

/// A picture cut to [aspect] (width / height: 1 for the profile picture, 16/9 for the cover), at most [max] px
/// wide, as JPEG, away from the screen's thread. [area] is the part chosen in the frame (left, top, width, height,
/// as parts of the upright picture); without it, the middle.
Future<({Uint8List bytes, int w, int h})> cropPhoto(Uint8List src, double aspect, int max, [(double, double, double, double)? area]) async =>
    compute(cropPhotoNow, (await readablePhoto(src), aspect, max, area));

({Uint8List bytes, int w, int h}) cropPhotoNow((Uint8List, double, int, (double, double, double, double)?) a) {
  final (src, aspect, max, area) = a;
  final d = img.decodeImage(src);
  if (d == null) throw const FormatException('photo');
  final im = img.bakeOrientation(d);
  int x, y, w, h;
  if (area != null) {
    x = (area.$1 * im.width).round().clamp(0, im.width - 1);
    y = (area.$2 * im.height).round().clamp(0, im.height - 1);
    w = (area.$3 * im.width).round().clamp(1, im.width - x);
    h = (area.$4 * im.height).round().clamp(1, im.height - y);
  } else {
    w = im.width;
    h = (im.width / aspect).round();
    if (h > im.height) {
      h = im.height;
      w = (im.height * aspect).round();
    }
    x = (im.width - w) ~/ 2;
    y = (im.height - h) ~/ 2;
  }
  var out = img.copyCrop(im, x: x, y: y, width: w, height: h);
  if (out.width > max) out = img.copyResize(out, width: max, height: (max / aspect).round(), interpolation: img.Interpolation.average);
  return (bytes: img.encodeJpg(out, quality: 86, chroma: img.JpegChroma.yuv420), w: out.width, h: out.height);
}
