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

/// The cloud: a rounded body with bumps all round its edge, a soft shadow and a thin line.
class _CloudPainter extends CustomPainter {
  _CloudPainter({required this.fill, required this.edge, required this.shadow});
  final Color fill, edge, shadow;

  static final _cache = <Size, Path>{};

  static Path _shape(Size s) {
    final hit = _cache[s];
    if (hit != null) return hit;
    const r = 9.0;
    final w = s.width, h = s.height;
    var p = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r * .55, r * .55, w - r * 1.1, h - r * 1.1), const Radius.circular(r * 1.6)));
    void bumps(Offset a, Offset b) {
      final n = math.max(1, ((b - a).distance / (r * 1.55)).round());
      for (var i = 0; i < n; i++) {
        final at = Offset.lerp(a, b, i / n)!;
        p = Path.combine(PathOperation.union, p, Path()..addOval(Rect.fromCircle(center: at, radius: r)));
      }
    }

    final tl = const Offset(r, r), tr = Offset(w - r, r), br = Offset(w - r, h - r), bl = Offset(r, h - r);
    bumps(tl, tr);
    bumps(tr, br);
    bumps(br, bl);
    bumps(bl, tl);
    if (_cache.length > 40) _cache.clear();
    return _cache[s] = p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 30 || size.height < 24) return;
    final p = _shape(size);
    canvas.drawShadow(p, shadow, 5, true);
    canvas.drawPath(p, Paint()..color = fill);
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(_CloudPainter o) => o.fill != fill || o.edge != edge || o.shadow != shadow;
}
