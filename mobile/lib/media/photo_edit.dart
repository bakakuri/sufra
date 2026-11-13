// The photo editor (core.js editImage): a shape to cut (as it is, 1:1, 4:5, 16:9, 9:16), a filter, brightness and a
// quarter turn. The screen shows it at once with a colour matrix; "მზადაა" makes the JPEG away from the screen's
// thread. Back leaves the photo as it was.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

typedef _M = List<double>;

/// 4×5 colour matrices (rows r, g, b, a; the last column 0–255), as CSS's filters
_M _rgb(List<double> m3) => [m3[0], m3[1], m3[2], 0, 0, m3[3], m3[4], m3[5], 0, 0, m3[6], m3[7], m3[8], 0, 0, 0, 0, 0, 1, 0];
_M _sepia(double a) {
  final s = 1 - a;
  return _rgb([.393 + .607 * s, .769 - .769 * s, .189 - .189 * s, .349 - .349 * s, .686 + .314 * s, .168 - .168 * s, .272 - .272 * s, .534 - .534 * s, .131 + .869 * s]);
}

_M _saturate(double s) => _rgb([.213 + .787 * s, .715 - .715 * s, .072 - .072 * s, .213 - .213 * s, .715 + .285 * s, .072 - .072 * s, .213 - .213 * s, .715 - .715 * s, .072 + .928 * s]);
_M _gray(double a) {
  final s = 1 - a;
  return _rgb([.2126 + .7874 * s, .7152 - .7152 * s, .0722 - .0722 * s, .2126 - .2126 * s, .7152 + .2848 * s, .0722 - .0722 * s, .2126 - .2126 * s, .7152 - .7152 * s, .0722 + .9278 * s]);
}

_M _hue(double deg) {
  final r = deg * math.pi / 180, c = math.cos(r), s = math.sin(r);
  return _rgb([
    .213 + c * .787 - s * .213, .715 - c * .715 - s * .715, .072 - c * .072 + s * .928, //
    .213 - c * .213 + s * .143, .715 + c * .285 + s * .140, .072 - c * .072 - s * .283,
    .213 - c * .213 - s * .787, .715 - c * .715 + s * .715, .072 + c * .928 + s * .072,
  ]);
}

_M _bright(double b) => _rgb([b, 0, 0, 0, b, 0, 0, 0, b]);
_M _contrast(double k) {
  final o = (.5 - .5 * k) * 255;
  return [k, 0, 0, 0, o, 0, k, 0, 0, o, 0, 0, k, 0, o, 0, 0, 0, 1, 0];
}

/// [a] then [b]
_M _then(_M a, _M b) {
  final out = List<double>.filled(20, 0);
  for (var i = 0; i < 4; i++) {
    for (var j = 0; j < 5; j++) {
      var v = j == 4 ? b[i * 5 + 4] : 0.0;
      for (var k = 0; k < 4; k++) {
        v += b[i * 5 + k] * a[k * 5 + j];
      }
      out[i * 5 + j] = v;
    }
  }
  return out;
}

_M _chain(List<_M> ms) => ms.fold(_bright(1), _then);

/// the site's filters: key, name, matrix
final photoFilters = <(String, String, List<double>)>[
  ('none', 'ბუნებრივი', _bright(1)),
  ('warm', 'თბილი', _chain([_sepia(.25), _saturate(1.3), _hue(-8)])),
  ('cool', 'ცივი', _chain([_saturate(1.1), _hue(12), _bright(1.03)])),
  ('bw', 'შავ-თეთრი', _chain([_gray(1), _contrast(1.1)])),
  ('vintage', 'ვინტაჟი', _chain([_sepia(.45), _contrast(.95), _bright(1.05), _saturate(.85)])),
  ('vivid', 'კაშკაშა', _chain([_saturate(1.6), _contrast(1.08)])),
  ('fade', 'მქრქალი', _chain([_contrast(.85), _bright(1.1), _saturate(.8)])),
];

/// the shapes to cut: key, name, width / height (0: as it is)
const photoRatios = <(String, String, double)>[('orig', 'ორიგინალი', 0), ('1', '1:1', 1), ('45', '4:5', .8), ('169', '16:9', 16 / 9), ('916', '9:16', 9 / 16)];

/// Opens the editor; the edited JPEG, or null when left unchanged (the tests put in their own).
Future<Uint8List?> Function(BuildContext context, Uint8List src) photoEdit = (context, src) =>
    Navigator.of(context, rootNavigator: true).push<Uint8List>(MaterialPageRoute(builder: (_) => PhotoEditScreen(src: src)));

class PhotoEditScreen extends StatefulWidget {
  const PhotoEditScreen({super.key, required this.src, this.size});
  final Uint8List src;

  /// the photo's size when already known (the tests)
  final Size? size;
  @override
  State<PhotoEditScreen> createState() => _PhotoEditScreenState();
}

class _PhotoEditScreenState extends State<PhotoEditScreen> {
  String filter = 'none', ratio = 'orig';
  int turns = 0;
  double bright = 1;
  Size? size;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    size = widget.size;
    if (size == null) _measure();
  }

  Future<void> _measure() async {
    try {
      final buf = await ui.ImmutableBuffer.fromUint8List(widget.src);
      final d = await ui.ImageDescriptor.encoded(buf);
      if (mounted) setState(() => size = Size(d.width.toDouble(), d.height.toDouble()));
      d.dispose();
      buf.dispose();
    } catch (_) {
      if (mounted) setState(() => size = const Size(4, 3));
    }
  }

  _M get matrix => _then(photoFilters.firstWhere((f) => f.$1 == filter).$3, _bright(bright));

  double get aspect {
    final s = size ?? const Size(4, 3), r = photoRatios.firstWhere((x) => x.$1 == ratio).$3;
    if (r > 0) return r;
    return turns.isOdd ? s.height / s.width : s.width / s.height;
  }

  Future<void> _done() async {
    setState(() => busy = true);
    try {
      final r = photoRatios.firstWhere((x) => x.$1 == ratio).$3;
      final out = await compute(bakePhoto, (widget.src, turns, r, matrix, 1600));
      if (mounted) Navigator.of(context).pop(out);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, 'ფოტო ვერ დამუშავდა');
    }
  }

  Widget _chip(String key, String label, bool on, VoidCallback tap) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        key: ValueKey(key),
        label: Text(label),
        selected: on,
        onSelected: busy ? null : (_) => tap(),
        selectedColor: c.accentSoft,
        side: BorderSide(color: on ? c.accent : c.line),
        showCheckmark: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final pic = RotatedBox(quarterTurns: turns, child: Image.memory(widget.src, gaplessPlayback: true));
    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: 0,
        leading: IconBtn('x', label: 'დახურვა', onTap: busy ? null : () => Navigator.of(context).maybePop()),
        title: const Text('ფოტოს რედაქტირება'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              key: const ValueKey('ed-done'),
              onPressed: busy || size == null ? null : _done,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 18)),
              child: const Text('მზადაა'),
            ),
          ),
        ],
      ),
      body: Column(children: [
        if (busy) LinearProgressIndicator(minHeight: 3, color: c.accent, backgroundColor: c.accentSoft),
        Expanded(
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(12),
            alignment: Alignment.center,
            child: size == null
                ? const CircularProgressIndicator()
                : AspectRatio(
                    aspectRatio: aspect,
                    child: ClipRect(child: FittedBox(fit: BoxFit.cover, child: ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: pic))),
                  ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  PIcon('crop', size: 18, color: c.muted),
                  const SizedBox(width: 8),
                  for (final r in photoRatios) _chip('ed-r-${r.$1}', r.$2, ratio == r.$1, () => setState(() => ratio = r.$1)),
                ]),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 92,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final f in photoFilters)
                    GestureDetector(
                      key: ValueKey('ed-f-${f.$1}'),
                      onTap: busy ? null : () => setState(() => filter = f.$1),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Column(children: [
                          Container(
                            width: 62,
                            height: 62,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: filter == f.$1 ? c.accent : c.line, width: filter == f.$1 ? 2.4 : 1)),
                            child: ColorFiltered(colorFilter: ColorFilter.matrix(f.$3), child: Image.memory(widget.src, fit: BoxFit.cover, cacheWidth: 160, gaplessPlayback: true)),
                          ),
                          const SizedBox(height: 4),
                          Text(f.$2, style: TextStyle(fontSize: 11.5, fontWeight: filter == f.$1 ? FontWeight.w800 : FontWeight.w500)),
                        ]),
                      ),
                    ),
                ]),
              ),
              Row(children: [
                PIcon('sun', size: 20, color: c.muted),
                Expanded(
                  child: Slider(
                    key: const ValueKey('ed-bright'),
                    value: bright,
                    min: .6,
                    max: 1.4,
                    onChanged: busy ? null : (v) => setState(() => bright = v),
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('ed-rot'),
                  onPressed: busy ? null : () => setState(() => turns = (turns + 1) % 4),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  icon: PIcon('rotate', size: 18, color: c.ink),
                  label: const Text('მობრუნება'),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// The edited photo: upright, turned, cut to [ratio] in the middle, at most [max] px, the colour matrix on every
/// pixel; JPEG.
Uint8List bakePhoto((Uint8List, int, double, List<double>, int) a) {
  final (src, turns, ratio, m, max) = a;
  final d = img.decodeImage(src);
  if (d == null) throw const FormatException('photo');
  var im = img.bakeOrientation(d);
  if (turns % 4 != 0) im = img.copyRotate(im, angle: 90 * (turns % 4));
  if (ratio > 0) {
    var w = im.width, h = (im.width / ratio).round();
    if (h > im.height) {
      h = im.height;
      w = (im.height * ratio).round();
    }
    im = img.copyCrop(im, x: (im.width - w) ~/ 2, y: (im.height - h) ~/ 2, width: w, height: h);
  }
  final big = math.max(im.width, im.height);
  if (big > max) im = im.width >= im.height ? img.copyResize(im, width: max, interpolation: img.Interpolation.average) : img.copyResize(im, height: max, interpolation: img.Interpolation.average);
  final plain = List.generate(20, (i) => i % 6 == 0 ? 1.0 : 0.0);
  if (!listEquals(m, plain)) {
    int cl(double v) => v < 0 ? 0 : (v > 255 ? 255 : v.round());
    for (final p in im) {
      final r = p.r.toDouble(), g = p.g.toDouble(), b = p.b.toDouble();
      p
        ..r = cl(m[0] * r + m[1] * g + m[2] * b + m[4])
        ..g = cl(m[5] * r + m[6] * g + m[7] * b + m[9])
        ..b = cl(m[10] * r + m[11] * g + m[12] * b + m[14]);
    }
  }
  return img.encodeJpg(im, quality: 86, chroma: img.JpegChroma.yuv420);
}
