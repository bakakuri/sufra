// Framing a new profile picture or cover, as the site's picker does: the photo under a frame of the right shape,
// moved and pinched until the right part is inside; "მზადაა" cuts it out. Back leaves it unchanged.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/photos.dart';
import '../ui/widgets.dart';

typedef Framed = ({Uint8List bytes, int w, int h});

Future<Framed?> framePhoto(BuildContext context, Uint8List src, {required double aspect, required int max, required String title}) =>
    Navigator.of(context, rootNavigator: true).push<Framed>(MaterialPageRoute(builder: (_) => _FrameScreen(src: src, aspect: aspect, max: max, title: title)));

/// the tests skip the framing and take the photo as it is
Future<Framed?> Function(BuildContext context, Uint8List src, {required double aspect, required int max, required String title}) photoFrame = framePhoto;

class _FrameScreen extends StatefulWidget {
  const _FrameScreen({required this.src, required this.aspect, required this.max, required this.title});
  final Uint8List src;
  final double aspect;
  final int max;
  final String title;
  @override
  State<_FrameScreen> createState() => _FrameScreenState();
}

class _FrameScreenState extends State<_FrameScreen> {
  final tc = TransformationController();
  Size? image; // the upright photo's size
  Size? frame, child; // the frame on the screen, the photo laid under it (covering it)
  bool busy = false;
  Object? error;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.src);
      final f = await codec.getNextFrame();
      final s = Size(f.image.width.toDouble(), f.image.height.toDouble());
      f.image.dispose();
      codec.dispose();
      if (mounted) setState(() => image = s);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  void dispose() {
    tc.dispose();
    super.dispose();
  }

  void _lay(Size f) {
    if (frame == f || image == null) return;
    final im = image!, k = (f.width / im.width) > (f.height / im.height) ? f.width / im.width : f.height / im.height;
    frame = f;
    child = Size(im.width * k, im.height * k);
    tc.value = Matrix4.translationValues((f.width - child!.width) / 2, (f.height - child!.height) / 2, 0);
  }

  Future<void> _done() async {
    final f = frame, ch = child;
    if (f == null || ch == null || busy) return;
    final m = tc.value, s = m.getMaxScaleOnAxis(), tx = m.storage[12], ty = m.storage[13];
    // what of the photo the frame shows, as parts of it
    final area = ((-tx / s) / ch.width, (-ty / s) / ch.height, (f.width / s) / ch.width, (f.height / s) / ch.height);
    setState(() => busy = true);
    try {
      final out = await cropPhoto(widget.src, widget.aspect, widget.max, area);
      if (mounted) Navigator.of(context).pop(out);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, 'ფოტო ვერ დამუშავდა');
    }
  }

  @override
  Widget build(BuildContext context) {
    final round = widget.aspect == 1;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton(
              key: const ValueKey('frame-done'),
              onPressed: image == null || busy ? null : _done,
              child: busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('მზადაა'),
            ),
          ),
        ],
      ),
      body: error != null
          ? const Center(child: Text('ფოტო ვერ გაიხსნა', style: TextStyle(color: Colors.white)))
          : image == null
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : LayoutBuilder(builder: (context, box) {
                  var fw = box.maxWidth - 32, fh = fw / widget.aspect;
                  if (fh > box.maxHeight - 120) {
                    fh = box.maxHeight - 120;
                    fw = fh * widget.aspect;
                  }
                  _lay(Size(fw, fh));
                  return Column(children: [
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: fw,
                          height: fh,
                          child: Stack(children: [
                            Positioned.fill(
                              child: ClipRect(
                                child: InteractiveViewer(
                                  transformationController: tc,
                                  constrained: false,
                                  minScale: 1,
                                  maxScale: 5,
                                  boundaryMargin: EdgeInsets.zero,
                                  child: SizedBox(width: child!.width, height: child!.height, child: Image.memory(widget.src, fit: BoxFit.fill, gaplessPlayback: true)),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white, width: 2),
                                  shape: round ? BoxShape.circle : BoxShape.rectangle,
                                  borderRadius: round ? null : BorderRadius.circular(6),
                                ),
                              ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
                      child: Text('გადაწიე და გაადიდე, რომ საჭირო ნაწილი ჩარჩოში მოექცეს.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ),
                  ]);
                }),
    );
  }
}
