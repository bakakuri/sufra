// A small SVG painter for the drawings the site makes itself (the services' pictures): rect, circle, ellipse, path and
// text, in groups with rotate and translate, with fill, stroke, opacity, round ends and dashes. Nothing is fetched or
// decoded off the screen, so it draws on the first frame (and in the tests).
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'icons.dart';

class _Op {
  _Op(this.tag, this.a, this.tf, [this.text = '']);
  final String tag;
  final Map<String, String> a;
  final List<(String, List<double>)> tf;
  final String text;
}

final _cache = <String, List<_Op>>{};
final _tagRe = RegExp(r'<(/?)([a-zA-Z]+)((?:\s+[a-zA-Z-]+="[^"]*")*)\s*(/?)>|([^<]+)');
final _attrRe = RegExp(r'([a-zA-Z-]+)="([^"]*)"');
final _tfRe = RegExp(r'([a-zA-Z]+)\(([^)]*)\)');
const _inherit = {'fill', 'fill-opacity', 'stroke', 'stroke-width', 'stroke-opacity', 'stroke-linecap', 'stroke-linejoin', 'font-size', 'font-weight', 'text-anchor', 'opacity', 'paint-order'};

List<(String, List<double>)> _tfs(String? v) => v == null
    ? const []
    : [for (final m in _tfRe.allMatches(v)) (m.group(1)!, m.group(2)!.split(RegExp(r'[\s,]+')).where((x) => x.isNotEmpty).map((x) => double.tryParse(x) ?? 0).toList())];

List<_Op> _parse(String svg) => _cache.putIfAbsent(svg, () {
      final out = <_Op>[];
      final stack = <(Map<String, String>, List<(String, List<double>)>)>[(const {}, const [])];
      _Op? openText;
      for (final m in _tagRe.allMatches(svg)) {
        if (m.group(5) != null) {
          final t = openText;
          if (t != null) openText = _Op(t.tag, t.a, t.tf, t.text + m.group(5)!.replaceAll('&amp;', '&'));
          continue;
        }
        final close = m.group(1) == '/', tag = m.group(2)!, self = m.group(4) == '/';
        if (close) {
          if (tag == 'g' && stack.length > 1) stack.removeLast();
          if (tag == 'text' && openText != null) {
            out.add(openText);
            openText = null;
          }
          continue;
        }
        final own = {for (final a in _attrRe.allMatches(m.group(3) ?? '')) a.group(1)!: a.group(2)!};
        final (inh, tf) = stack.last;
        final merged = {...inh, ...own};
        final allTf = [...tf, ..._tfs(own['transform'])];
        if (tag == 'g') {
          if (!self) stack.add(({for (final e in merged.entries) if (_inherit.contains(e.key)) e.key: e.value}, allTf));
        } else if (tag == 'text') {
          openText = _Op(tag, merged, allTf);
          if (self) {
            out.add(openText);
            openText = null;
          }
        } else if (tag != 'svg') {
          out.add(_Op(tag, merged, allTf));
        }
      }
      return out;
    });

Color? _color(String? v, double opacity) {
  if (v == null || v == 'none' || v == 'transparent') return null;
  var h = v.trim();
  if (h == 'white' || h == 'currentColor') h = '#fff';
  if (h == 'black') h = '#000';
  if (!h.startsWith('#')) return null;
  h = h.substring(1);
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  final n = int.tryParse(h, radix: 16);
  if (n == null) return null;
  return Color(0xFF000000 | n).withValues(alpha: opacity.clamp(0, 1).toDouble());
}

double _n(Map<String, String> a, String k, [double d = 0]) => double.tryParse(a[k] ?? '') ?? d;

/// Draws [svg] (the inside of an <svg> with a [view] box) covering its box, as preserveAspectRatio="xMidYMid slice".
class MiniSvg extends StatelessWidget {
  const MiniSvg(this.svg, {super.key, this.view = const Size(150, 96)});
  final String svg;
  final Size view;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _SvgPainter(svg, view, DefaultTextStyle.of(context).style), size: Size.infinite);
}

class _SvgPainter extends CustomPainter {
  _SvgPainter(this.svg, this.view, this.font);
  final String svg;
  final Size view;

  /// the app's text style, for its font and the fonts behind it (digits, emoji)
  final TextStyle font;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.max(size.width / view.width, size.height / view.height);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - view.width * s) / 2, (size.height - view.height * s) / 2);
    canvas.scale(s);
    for (final op in _parse(svg)) {
      canvas.save();
      for (final (k, v) in op.tf) {
        if (k == 'translate') {
          canvas.translate(v.isNotEmpty ? v[0] : 0, v.length > 1 ? v[1] : 0);
        } else if (k == 'rotate' && v.isNotEmpty) {
          final cx = v.length > 2 ? v[1] : 0.0, cy = v.length > 2 ? v[2] : 0.0;
          canvas.translate(cx, cy);
          canvas.rotate(v[0] * math.pi / 180);
          canvas.translate(-cx, -cy);
        } else if (k == 'scale' && v.isNotEmpty) {
          canvas.scale(v[0], v.length > 1 ? v[1] : v[0]);
        }
      }
      _draw(canvas, op);
      canvas.restore();
    }
    canvas.restore();
  }

  void _draw(Canvas canvas, _Op op) {
    final a = op.a, op0 = _n(a, 'opacity', 1);
    final fill = _color(a['fill'] ?? (op.tag == 'line' ? 'none' : '#000'), _n(a, 'fill-opacity', 1) * op0);
    final stroke = _color(a['stroke'], _n(a, 'stroke-opacity', 1) * op0);
    if (op.tag == 'text') {
      if (fill == null) return;
      final w = int.tryParse(a['font-weight'] ?? '') ?? (a['font-weight'] == 'bold' ? 700 : 400);
      final st = font.copyWith(fontSize: _n(a, 'font-size', 16), fontWeight: FontWeight.values[((w ~/ 100) - 1).clamp(0, 8)], height: 1, decoration: TextDecoration.none);
      TextPainter painter(TextStyle ts) => TextPainter(text: TextSpan(text: op.text.trim(), style: ts), textDirection: TextDirection.ltr)..layout();
      final tp = painter(st.copyWith(color: fill));
      final anchor = a['text-anchor'];
      final dx = anchor == 'middle' ? tp.width / 2 : (anchor == 'end' ? tp.width : 0);
      final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final at = Offset(_n(a, 'x') - dx, _n(a, 'y') - base);
      // a stroke under the letters (the stickers' white outline)
      if (stroke != null) {
        painter(st.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _n(a, 'stroke-width', 1)
            ..strokeJoin = StrokeJoin.round
            ..color = stroke,
        )).paint(canvas, at);
      }
      tp.paint(canvas, at);
      return;
    }
    Path path;
    switch (op.tag) {
      case 'rect':
        final rx = _n(a, 'rx', _n(a, 'ry'));
        path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(_n(a, 'x'), _n(a, 'y'), _n(a, 'width'), _n(a, 'height')), Radius.circular(rx)));
      case 'circle':
        path = Path()..addOval(Rect.fromCircle(center: Offset(_n(a, 'cx'), _n(a, 'cy')), radius: _n(a, 'r')));
      case 'ellipse':
        path = Path()..addOval(Rect.fromCenter(center: Offset(_n(a, 'cx'), _n(a, 'cy')), width: _n(a, 'rx') * 2, height: _n(a, 'ry') * 2));
      case 'line':
        path = Path()
          ..moveTo(_n(a, 'x1'), _n(a, 'y1'))
          ..lineTo(_n(a, 'x2'), _n(a, 'y2'));
      case 'path':
        path = svgPath(a['d'] ?? '');
      default:
        return;
    }
    // paint-order="stroke": the outline first, the fill over it
    final under = (a['paint-order'] ?? '').startsWith('stroke');
    if (fill != null && !under) canvas.drawPath(path, Paint()..color = fill);
    if (stroke != null) {
      final p = Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = _n(a, 'stroke-width', 1)
        ..strokeCap = switch (a['stroke-linecap']) { 'round' => StrokeCap.round, 'square' => StrokeCap.square, _ => StrokeCap.butt }
        ..strokeJoin = switch (a['stroke-linejoin']) { 'round' => StrokeJoin.round, 'bevel' => StrokeJoin.bevel, _ => StrokeJoin.miter };
      final dash = (a['stroke-dasharray'] ?? '').split(RegExp(r'[\s,]+')).map(double.tryParse).whereType<double>().where((x) => x > 0).toList();
      if (dash.length < 2) {
        canvas.drawPath(path, p);
      } else {
        for (final m in path.computeMetrics()) {
          var d = 0.0, i = 0;
          while (d < m.length) {
            final len = dash[i % dash.length];
            if (i.isEven) canvas.drawPath(m.extractPath(d, math.min(d + len, m.length)), p);
            d += len;
            i++;
          }
        }
      }
    }
    if (fill != null && under) canvas.drawPath(path, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_SvgPainter old) => old.svg != svg || old.font != font;
}
