import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:path_parsing/path_parsing.dart';

/// The site's icons (js/lib-icons.js): 24×24, a 1.8 stroke with round ends. Drawn here directly, without an SVG library,
/// so they look the same on the phone and in the test screenshots. A piece marked `fill` is filled instead of stroked.
const _ic = <String, String>{
  'home': '<path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z"/>',
  'users': '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.7-3.5 3.4-5.5 6.5-5.5s5.8 2 6.5 5.5M16 4.5a3.5 3.5 0 0 1 0 7M18 14.6c2 .8 3.2 2.6 3.5 5.4"/>',
  'heart': '<path d="M12 20s-7-4.4-9-9a5 5 0 0 1 9-3 5 5 0 0 1 9 3c-2 4.6-9 9-9 9z"/>',
  'msg': '<path d="M4 5h16v11H9l-5 4z"/>',
  'clips': '<rect x="4" y="3" width="16" height="18" rx="4"/><path d="M10 9l5 3-5 3z"/>',
  'dice': '<rect x="3" y="3" width="18" height="18" rx="4"/><circle cx="8.5" cy="8.5" r="1.3" fill="1"/><circle cx="12" cy="12" r="1.3" fill="1"/><circle cx="15.5" cy="15.5" r="1.3" fill="1"/>',
  'user': '<circle cx="12" cy="8" r="4"/><path d="M4 21c1-4 4.5-6 8-6s7 2 8 6"/>',
  'out': '<path d="M15 4h4a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-4M10 16l-4-4 4-4M6 12h10"/>',
  'globe': '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.7 3.8 5.7 3.8 9s-1.3 6.3-3.8 9c-2.5-2.7-3.8-5.7-3.8-9S9.5 5.7 12 3z"/>',
  'mail': '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="M4 7l8 6 8-6"/>',
  'lock': '<rect x="5" y="10" width="14" height="10" rx="2.5"/><path d="M8 10V7.5a4 4 0 0 1 8 0V10"/>',
  'eye': '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  'eyeoff': '<path d="M3 3l18 18M10.6 5.1A9.7 9.7 0 0 1 12 5c6.4 0 10 7 10 7a17 17 0 0 1-3.2 4M6.6 6.6C3.7 8.4 2 12 2 12s3.6 7 10 7a9.6 9.6 0 0 0 5.4-1.6M9.9 9.9a3 3 0 0 0 4.2 4.2"/>',
  'coin': '<circle cx="12" cy="12" r="9"/><path d="M12 7v10M9.5 9.5c0-1.1 1.1-2 2.5-2s2.5.9 2.5 2-1.1 1.7-2.5 2-2.5.9-2.5 2 1.1 2 2.5 2 2.5-.9 2.5-2"/>',
  'pin': '<path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
  'chev': '<path d="M9 6l6 6-6 6"/>',
  'back': '<path d="M15 6l-6 6 6 6"/>',
  'phone': '<rect x="7" y="2.5" width="10" height="19" rx="2.5"/><path d="M11 18.5h2"/>',
  'comment': '<path d="M20 12a8 8 0 0 1-11.6 7.1L4 20l1-4A8 8 0 1 1 20 12z"/>',
  'send': '<path d="M4 12l16-8-6 16-3-7z"/>',
  'image': '<rect x="3" y="4" width="18" height="16" rx="3"/><circle cx="9" cy="9.5" r="1.8"/><path d="M21 16l-5-5-9 9"/>',
  'plus': '<path d="M12 5v14M5 12h14"/>',
  'more': '<circle cx="5" cy="12" r="1.3" fill="1"/><circle cx="12" cy="12" r="1.3" fill="1"/><circle cx="19" cy="12" r="1.3" fill="1"/>',
  'x': '<path d="M6 6l12 12M18 6L6 18"/>',
  'search': '<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>',
  'check': '<path d="M5 12l4.5 4.5L19 7"/>',
  'camera': '<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>',
  'bookmark': '<path d="M6 3h12v18l-6-4.5L6 21z"/>',
  'bookmarked': '<path d="M6 3h12v18l-6-4.5L6 21z" fill="1"/>',
  'repost': '<path d="M7 7h11l-3-3M17 17H6l3 3"/>',
  'play': '<path d="M8 5.5v13a1 1 0 0 0 1.5.86l10.4-6.5a1 1 0 0 0 0-1.72L9.5 4.64A1 1 0 0 0 8 5.5z" fill="1"/>',
  'trash': '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v6M14 11v6"/>',
  'reply': '<path d="M10 7L4 12l6 5"/><path d="M4 12h10a6 6 0 0 1 6 6"/>',
  'bell': '<path d="M6 16v-5a6 6 0 0 1 12 0v5l2 2H4z"/><path d="M10 20a2 2 0 0 0 4 0"/>',
  'copy': '<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V6a2 2 0 0 1 2-2h9"/>',
  'uadd': '<circle cx="10" cy="8" r="4"/><path d="M3 21c1-4 3.8-6 7-6 1.6 0 3 .4 4.2 1.2M18 13v6M15 16h6"/>',
  'ucheck': '<circle cx="10" cy="8" r="4"/><path d="M3 21c1-4 3.8-6 7-6 1.6 0 3 .4 4.2 1.2M15 17.5l2 2 4-4"/>',
  'archive': '<rect x="3" y="4" width="18" height="5" rx="1.5"/><path d="M5 9v9a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V9"/><path d="M10 13h4"/>',
  'mute': '<path d="M6 8a6 6 0 0 1 9.5-4.9M18 9.5c0 4.5 2 6.5 2 6.5H8"/><path d="M4 16s2-2 2-7"/><path d="M10 20a2 2 0 0 0 4 0"/><path d="M3 3l18 18"/>',
  'edit': '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>',
  'vol': '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11"/>',
  'voloff': '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M16 9.5l5 5M21 9.5l-5 5"/>',
  'pause': '<rect x="6.5" y="5" width="3.6" height="14" rx="1.2" fill="1"/><rect x="13.9" y="5" width="3.6" height="14" rx="1.2" fill="1"/>',
  'star': '<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>',
  'gear': '<path d="M19.00 9.59 L21.35 9.84 L21.35 14.16 L19.00 14.41 L18.65 15.24 L20.14 17.09 L17.09 20.14 L15.24 18.65 L14.41 19.00 L14.16 21.35 L9.84 21.35 L9.59 19.00 L8.76 18.65 L6.91 20.14 L3.86 17.09 L5.35 15.24 L5.00 14.41 L2.65 14.16 L2.65 9.84 L5.00 9.59 L5.35 8.76 L3.86 6.91 L6.91 3.86 L8.76 5.35 L9.59 5.00 L9.84 2.65 L14.16 2.65 L14.41 5.00 L15.24 5.35 L17.09 3.86 L20.14 6.91 L18.65 8.76Z"/><circle cx="12" cy="12" r="3.2"/>',
  'cards': '<rect x="4" y="5" width="11" height="15" rx="2"/><path d="M15 7l4.5 1.2-3 12-3-.8"/>',
  'note': '<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M9 8h6M9 12h6M9 16h4"/>',
  'heartfill': '<path d="M12 20s-7-4.4-9-9a5 5 0 0 1 9-3 5 5 0 0 1 9 3c-2 4.6-9 9-9 9z" fill="1"/>',
};

class PIcon extends StatelessWidget {
  const PIcon(this.name, {super.key, this.size = 24, this.color, this.stroke = 1.8});

  final String name;
  final double size;
  final Color? color;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFF000000);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _IconPainter(_ic[name] ?? '', c, stroke)),
    );
  }
}

class _Piece {
  _Piece(this.path, this.fill);
  final Path path;
  final bool fill;
}

final _cache = <String, List<_Piece>>{};

double _a(String tag, String k, [double d = 0]) {
  final m = RegExp('\\b$k="([^"]*)"').firstMatch(tag);
  return m == null ? d : double.tryParse(m.group(1)!) ?? d;
}

List<_Piece> _parse(String src) => _cache.putIfAbsent(src, () {
      final out = <_Piece>[];
      for (final m in RegExp(r'<(path|circle|rect)\b([^>]*)/>').allMatches(src)) {
        final t = m.group(1)!, at = m.group(2)!, fill = at.contains('fill="');
        final p = Path();
        if (t == 'path') {
          final d = RegExp(r'\bd="([^"]*)"').firstMatch(at)?.group(1) ?? '';
          writeSvgPathDataToPath(d, _Proxy(p));
        } else if (t == 'circle') {
          p.addOval(Rect.fromCircle(center: Offset(_a(at, 'cx'), _a(at, 'cy')), radius: _a(at, 'r')));
        } else {
          final rx = _a(at, 'rx');
          p.addRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(_a(at, 'x'), _a(at, 'y'), _a(at, 'width'), _a(at, 'height')), Radius.circular(rx)));
        }
        out.add(_Piece(p, fill));
      }
      return out;
    });

class _Proxy extends PathProxy {
  _Proxy(this.p);
  final Path p;
  @override
  void close() => p.close();
  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) => p.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void lineTo(double x, double y) => p.lineTo(x, y);
  @override
  void moveTo(double x, double y) => p.moveTo(x, y);
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.src, this.color, this.stroke);
  final String src;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / 24;
    canvas.save();
    canvas.scale(s);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final p in _parse(src)) {
      canvas.drawPath(p.path, p.fill ? fill : line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter o) => o.src != src || o.color != color || o.stroke != stroke;
}

/// The Peera mark (icons/logo.svg): the speech bubble with the P and the graduation cap.
class PeeraMark extends StatelessWidget {
  const PeeraMark({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: CustomPaint(painter: _MarkPainter()));
}

Path _svg(String d) {
  final p = Path();
  writeSvgPathDataToPath(d, _Proxy(p));
  return p;
}

final _bubble = _svg('M15 12H49Q57 12 57 20V42Q57 50 49 50H27.5L16.2 58.6Q13 61 13 57V49.6Q5 48.6 5 41V20Q5 12 15 12Z');
final _pLetter = _svg(
    'M29.86 18.3Q34.85 18.3 37.27 20.41Q39.69 22.52 39.69 26.42Q39.69 28.17 39.18 29.77Q38.68 31.37 37.53 32.63Q36.38 33.89 34.45 34.61Q32.52 35.34 29.72 35.34H27.57V44.3H21.31V18.3ZM29.68 23.36H27.57V30.24H29.21Q30.45 30.24 31.41 29.9Q32.38 29.55 32.9 28.73Q33.43 27.91 33.43 26.6Q33.43 25.11 32.52 24.24Q31.61 23.36 29.68 23.36Z');
final _capBand = _svg('M40 13V17.6Q47.5 21.8 55 17.6V13L47.5 16.4Z');
final _capTop = _svg('M47.5 3.6L61.5 10L47.5 16.4L33.5 10Z');

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64);
    final g = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7B6CFF), Color(0xFF4F46E5), Color(0xFF3A2EC4)],
      stops: [0, .55, 1],
    ).createShader(const Rect.fromLTWH(0, 0, 64, 64));
    canvas.drawPath(_bubble, Paint()..shader = g);
    canvas.drawPath(_pLetter, Paint()..color = const Color(0xFFFFFFFF));
    canvas.translate(47.5, 11.5);
    canvas.rotate(-13 * math.pi / 180);
    canvas.translate(-47.5, -11.5);
    canvas.drawPath(_capBand, Paint()..color = const Color(0xFFF08C00));
    canvas.drawPath(_capTop, Paint()..color = const Color(0xFFFFB020));
    canvas.drawLine(
        const Offset(59, 11),
        const Offset(59, 17.2),
        Paint()
          ..color = const Color(0xFFFFB020)
          ..strokeWidth = 1.9
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(const Offset(59, 18.6), 2, Paint()..color = const Color(0xFFFFB020));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter o) => false;
}
