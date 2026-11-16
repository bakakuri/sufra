// A thought in a cloud (the bio, coming out of a profile picture): the cloud's bumpy edge goes round the words,
// however many there are (up to 300).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

class ThoughtCloud extends StatelessWidget {
  const ThoughtCloud({super.key, required this.text, this.placeholder = false, this.onTap});
  final String text;

  /// my empty thought: an invitation to write one
  final bool placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final fill = Color.alphaBlend(c.accent.withValues(alpha: .07), c.surface);
    final edge = Color.alphaBlend(c.accent.withValues(alpha: .18), c.line);
    final cloud = TweenAnimationBuilder<double>(
      tween: Tween(begin: .7, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (_, v, ch) => Transform.scale(scale: v, alignment: Alignment.bottomLeft, child: ch),
      child: CustomPaint(
        painter: _CloudPainter(fill: fill, edge: edge, shadow: c.accent.withValues(alpha: .22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: placeholder ? c.muted : c.ink,
              fontStyle: placeholder ? FontStyle.italic : FontStyle.normal,
              fontWeight: placeholder ? FontWeight.w400 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      label: placeholder ? 'ჩემი ფიქრის დაწერა' : null,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: cloud),
    );
  }
}

/// The cloud: a rounded body with bumps all round its edge, a soft shadow and a thin line. Drawn as plain shapes (the
/// lines first, twice as thick, then the opaque fill over them, so only the outer half of the outer edge stays), never
/// by joining paths.
class _CloudPainter extends CustomPainter {
  _CloudPainter({required this.fill, required this.edge, required this.shadow});
  final Color fill, edge, shadow;

  static const _r = 9.0;

  static (RRect, List<Offset>) _shape(Size s) {
    const r = _r;
    final w = s.width, h = s.height;
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(r * .55, r * .55, w - r * 1.1, h - r * 1.1), const Radius.circular(r * 1.6));
    final at = <Offset>[];
    void bumps(Offset a, Offset b) {
      final d = (b - a).distance;
      if (!d.isFinite) return;
      final n = math.min(60, math.max(1, (d / (r * 1.55)).round()));
      for (var i = 0; i < n; i++) {
        at.add(Offset.lerp(a, b, i / n)!);
      }
    }

    final tl = const Offset(r, r), tr = Offset(w - r, r), br = Offset(w - r, h - r), bl = Offset(r, h - r);
    bumps(tl, tr);
    bumps(tr, br);
    bumps(br, bl);
    bumps(bl, tl);
    return (body, at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 30 || size.height < 24 || !size.isFinite) return;
    final (body, at) = _shape(size);
    // a soft shadow under the whole cloud
    canvas.drawRRect(
      body.shift(const Offset(0, 4)).inflate(4),
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = edge;
    canvas.drawRRect(body, line);
    for (final o in at) {
      canvas.drawCircle(o, _r, line);
    }
    final f = Paint()..color = fill;
    canvas.drawRRect(body, f);
    for (final o in at) {
      canvas.drawCircle(o, _r, f);
    }
  }

  @override
  bool shouldRepaint(_CloudPainter o) => o.fill != fill || o.edge != edge || o.shadow != shadow;
}
