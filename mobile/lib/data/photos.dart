import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A photo ready to upload, the way the site keeps photos: the full one (up to 2048 px), a ~1080 px copy
/// for lists (md, only when the photo is bigger than 1200) and a ~480 px one (sm, when bigger than 560).
class PreparedPhoto {
  const PreparedPhoto(this.full, this.w, this.h, {this.md, this.sm});
  final Uint8List full;
  final Uint8List? md, sm;

  /// the size of the list copy, saved with the post so the frame has the right shape before it loads
  final int w, h;
}

/// Turned upright (the camera's orientation tag), resized and saved as JPEG, away from the screen's thread.
Future<PreparedPhoto> preparePhoto(Uint8List src) => compute(preparePhotoNow, src);

PreparedPhoto preparePhotoNow(Uint8List src) {
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

  final full = fit(im, 2048), md = fit(full, 1080);
  final big = full.width > full.height ? full.width : full.height;
  return PreparedPhoto(
    img.encodeJpg(full, quality: 86, chroma: img.JpegChroma.yuv420),
    md.width,
    md.height,
    md: big > 1200 ? img.encodeJpg(md, quality: 82, chroma: img.JpegChroma.yuv420) : null,
    sm: big > 560 ? img.encodeJpg(fit(md, 480), quality: 74, chroma: img.JpegChroma.yuv420) : null,
  );
}
