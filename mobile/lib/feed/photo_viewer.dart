import 'package:flutter/material.dart';

import '../data/models.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';

/// Photos over the whole screen: swipe between them, pinch to zoom; back closes it.
Future<void> openPhotos(BuildContext context, List<Media> photos, {int start = 0}) =>
    Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => PhotoViewer(photos: photos, start: start),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));

class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.photos, this.start = 0});
  final List<Media> photos;
  final int start;
  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final pages = PageController(initialPage: widget.start);
  late int at = widget.start;

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.photos.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        PageView.builder(
          controller: pages,
          itemCount: n,
          onPageChanged: (i) => setState(() => at = i),
          itemBuilder: (_, i) {
            final m = widget.photos[i];
            return InteractiveViewer(
              maxScale: 5,
              child: Stack(fit: StackFit.expand, children: [
                if (m.mid != m.url) PImage(m.mid, fit: BoxFit.contain, background: Colors.transparent),
                PImage(m.url, fit: BoxFit.contain, background: Colors.transparent),
              ]),
            );
          },
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(children: [
              IconButton(
                tooltip: 'დახურვა',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const PIcon('x', size: 26, color: Colors.white, stroke: 2.2),
              ),
              const Spacer(),
              if (n > 1)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text('${at + 1} / $n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
