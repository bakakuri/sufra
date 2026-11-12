// The Peera deck as on the site: cream cards, the suits drawn as shapes (every phone shows the same sign),
// and the court cards' painted half-figures (js/games-engines.js jCourtPaint): the king with a crown and a mantle over
// the chokha, the queen in a white veil over the chikhti-kopi, the jack in a papakhi with a drinking horn.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_parsing/path_parsing.dart';

import '../ui/icons.dart';
import 'engine.dart';

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

Path _svg(String d) {
  final p = Path();
  writeSvgPathDataToPath(d, _Proxy(p));
  return p;
}

/// the four suits in a 100×100 box
final Map<String, Path> _suitPaths = {
  'h': _svg('M50 90C22 68 5 52 5 31 5 15 17 5 31 5c9 0 16 5 19 13 3-8 10-13 19-13 14 0 26 10 26 26 0 21-17 37-45 59z'),
  'd': _svg('M50 3 88 50 50 97 12 50z'),
  's': _svg('M50 4c20 22 46 36 46 58 0 16-12 24-24 24-9 0-16-5-19-11 1 11 5 17 11 21H36c6-4 10-10 11-21-3 6-10 11-19 11C16 86 4 78 4 62 4 40 30 26 50 4z'),
  'c': Path()
    ..addOval(Rect.fromCircle(center: const Offset(50, 28), radius: 21))
    ..addOval(Rect.fromCircle(center: const Offset(27, 59), radius: 21))
    ..addOval(Rect.fromCircle(center: const Offset(73, 59), radius: 21))
    ..addPath(_svg('M44 54h12l5 42H39z'), Offset.zero),
};

/// The ink of a suit on a card: red and black, or with the four-colour deck spades black, clubs green, hearts red, diamonds blue.
Color suitInk(String s, {bool c4 = false}) {
  if (c4) return const {'s': Color(0xFF17110E), 'c': Color(0xFF1C7A3A), 'h': Color(0xFFCE1430), 'd': Color(0xFF1A55C4)}[s]!;
  return isRed(s) ? const Color(0xFFD3122E) : const Color(0xFF17110E);
}

/// The same on the dark table (black would not show): light tones.
Color suitInkOnDark(String s, {bool c4 = false}) {
  if (c4) return const {'s': Color(0xFFF2EEE6), 'c': Color(0xFF62D18E), 'h': Color(0xFFFF8A9A), 'd': Color(0xFF8DB0FF)}[s]!;
  return isRed(s) ? const Color(0xFFFF8A9A) : const Color(0xFFF2EEE6);
}

class SuitMark extends StatelessWidget {
  const SuitMark(this.s, {super.key, this.size = 18, this.color});
  final String s;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: size, child: CustomPaint(painter: _SuitPainter(s, color ?? suitInk(s))));
}

class _SuitPainter extends CustomPainter {
  _SuitPainter(this.s, this.color);
  final String s;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = _suitPaths[s];
    if (p == null) return;
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawPath(p, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SuitPainter o) => o.s != s || o.color != color;
}

const cardRatio = 1.43;
const _paper = Color(0xFFFFFDF8), _cardInk = Color(0xFF1F1612);

/// A card's face, [w] wide. [dim] greys it out (it may not be played now), [glow] rings it in gold (it took the trick).
class CardFace extends StatelessWidget {
  const CardFace(this.card, {super.key, this.w = 56, this.dim = false, this.glow = false, this.c4 = false});
  final JCard card;
  final double w;
  final bool dim, glow, c4;

  @override
  Widget build(BuildContext context) {
    final h = w * cardRatio, k = w / 56;
    final r = BorderRadius.circular(8 * k);
    Widget face;
    if (card.joker) {
      final ink = card.j == 2 ? const Color(0xFF1F2F6B) : const Color(0xFFB0123A);
      face = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [.4, 1],
            colors: [_paper, card.j == 2 ? const Color(0xFFDCE4F7) : const Color(0xFFF7DCE6)],
          ),
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Star(size: 22 * k, color: ink),
            SizedBox(height: 3 * k),
            FittedBox(
              child: Text('ჯოკერი', style: TextStyle(color: ink, fontSize: 11 * k, fontWeight: FontWeight.w800, height: 1.1)),
            ),
          ]),
        ),
      );
    } else {
      final ink = suitInk(card.s, c4: c4);
      final court = card.r >= 11 && card.r <= 13;
      final corner = Padding(
        padding: EdgeInsets.fromLTRB(5 * k, 5 * k, 0, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Text(card.rank,
              style: TextStyle(
                  color: ink,
                  fontSize: (card.r == 10 ? 17 : 19) * k,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: card.r == 10 ? -1.2 * k : 0,
                  fontFamily: 'NotoSans',
                  fontFamilyFallback: const ['Roboto'])),
          SizedBox(height: 2 * k),
          SuitMark(card.s, size: 15 * k, color: ink),
        ]),
      );
      face = Stack(children: [
        if (court)
          Positioned(
            left: w * .34,
            right: w * .08,
            top: h * .09,
            bottom: h * .09,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4 * k),
              child: CustomPaint(painter: CourtPainter(card.r, card.s, c4: c4), size: Size.infinite),
            ),
          )
        else
          Positioned(right: 5 * k, bottom: 5 * k, child: SuitMark(card.s, size: 28 * k, color: ink)),
        Positioned(left: 0, top: 0, child: corner),
      ]);
    }
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: r,
        border: Border.all(color: glow ? const Color(0xFFF5B544) : const Color(0x22000000), width: glow ? 2.5 : .8),
        boxShadow: [
          BoxShadow(color: glow ? const Color(0x99F5B544) : const Color(0x59000000), blurRadius: glow ? 12 : 6, offset: const Offset(0, 2)),
        ],
      ),
      foregroundDecoration: dim ? BoxDecoration(color: const Color(0x8C0B1424), borderRadius: r) : null,
      child: ClipRRect(borderRadius: r, child: face),
    );
  }
}

/// A card lying face down (the trump card's place before it is turned, the backs in the review).
class CardBack extends StatelessWidget {
  const CardBack({super.key, this.w = 56});
  final double w;
  @override
  Widget build(BuildContext context) {
    final k = w / 56;
    return Container(
      width: w,
      height: w * cardRatio,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8 * k),
        color: const Color(0xFF7A1630),
        border: Border.all(color: const Color(0xFFFFFDF8), width: 3 * k),
        boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Center(child: Star(size: 18 * k, color: const Color(0x99F5D08A))),
    );
  }
}

/// The court figures: drawn in a frame 100 units wide, the same half twice (the lower one turned around).
class CourtPainter extends CustomPainter {
  CourtPainter(this.r, this.s, {this.c4 = false});
  final int r;
  final String s;
  final bool c4;

  static const _coat = {'h': Color(0xFF9E1B32), 'd': Color(0xFFB5401E), 's': Color(0xFF1F2B4A), 'c': Color(0xFF18402D)};
  static const _coat4 = {'h': Color(0xFF9E1B32), 'd': Color(0xFF1E4FA0), 's': Color(0xFF1F2B4A), 'c': Color(0xFF1B6A3A)};
  static const gold = Color(0xFFD9A93E), dk = Color(0xFF2A1E18), skin = Color(0xFFF1C9A2), shirt = Color(0xFFF4E8CC);

  @override
  void paint(Canvas x, Size size) {
    final w = size.width, h = size.height;
    // the parchment panel and its frame in the suit's ink
    x.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBEFD2), Color(0xFFF3DFB2), Color(0xFFFBEFD2)],
        ).createShader(Offset.zero & size),
    );
    x.save();
    x.clipRect(Offset.zero & size);
    _half(x, w, h);
    x.translate(w, h);
    x.rotate(math.pi);
    _half(x, w, h);
    x.restore();
    x.drawRect(
      (Offset.zero & size).deflate(.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = suitInk(s, c4: c4),
    );
  }

  void _half(Canvas x, double w, double h) {
    final coat = (c4 ? _coat4 : _coat)[s]!, hh = h / 2, u = w / 100;
    final k = math.max(1.0, math.min(1.6, hh / u / 112));
    x.save();
    x.translate(50 * u, 0);
    x.scale(k, k);
    x.translate(-50 * u, 0);
    final b = hh / u / k; // the half's height in units (the centre line)

    Paint fillP(Color c) => Paint()..color = c;
    Paint strokeP(Color c, double lw) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = lw * u;
    void poly(List<List<double>> pts, Color? fill, [Color? stroke, double lw = 1.4]) {
      final p = Path()..moveTo(pts[0][0] * u, pts[0][1] * u);
      for (final q in pts.skip(1)) {
        p.lineTo(q[0] * u, q[1] * u);
      }
      p.close();
      if (fill != null) x.drawPath(p, fillP(fill));
      if (stroke != null) x.drawPath(p, strokeP(stroke, lw));
    }

    void ell(double cx, double cy, double rx, double ry, Color? fill, [Color? stroke]) {
      final rect = Rect.fromCenter(center: Offset(cx * u, cy * u), width: rx * 2 * u, height: ry * 2 * u);
      if (fill != null) x.drawOval(rect, fillP(fill));
      if (stroke != null) x.drawOval(rect, strokeP(stroke, 1.2));
    }

    void rect(double a, double c, double ww, double hh2, Color fill) => x.drawRect(Rect.fromLTWH(a * u, c * u, ww * u, hh2 * u), fillP(fill));
    Offset o(double a, double c) => Offset(a * u, c * u);
    Path pth(void Function(Path p) f) {
      final p = Path();
      f(p);
      return p;
    }

    void face(double cy, double rx, double ry) {
      ell(50, cy, rx, ry, skin, const Color(0x595A321E));
      for (final ex in const [44.5, 55.5]) {
        x.drawCircle(o(ex, cy - 1.5), 1.25 * u, fillP(dk));
      }
      final brow = strokeP(const Color(0xBF3C2314), 1.1);
      for (final ex in const [44.5, 55.5]) {
        x.drawPath(
            pth((p) => p
              ..moveTo((ex - 3) * u, (cy - 5) * u)
              ..quadraticBezierTo(ex * u, (cy - 6.5) * u, (ex + 3) * u, (cy - 5) * u)),
            brow);
      }
      x.drawPath(
          pth((p) => p
            ..moveTo(50 * u, (cy - 1) * u)
            ..quadraticBezierTo(48.5 * u, (cy + 3) * u, 50.5 * u, (cy + 3.5) * u)),
          strokeP(const Color(0x998C4632), 1.1));
    }

    void body(double top, Color col) {
      poly([
        [20, top],
        [80, top],
        [92, b],
        [8, b]
      ], col, const Color(0x59000000), 1);
      poly([
        [41, top],
        [59, top],
        [50, top + 22]
      ], shirt);
      x.drawPath(
          pth((p) => p
            ..moveTo(41 * u, top * u)
            ..lineTo(50 * u, (top + 22) * u)
            ..lineTo(59 * u, top * u)),
          strokeP(gold, 1.6));
    }

    void gazyri(double top) {
      for (final side in const [-1, 1]) {
        for (var i = 0; i < 5; i++) {
          final gx = 50 + side * (15 + i * 5.2) - 1.4;
          rect(gx, top + 6, 2.8, 11, gold);
          rect(gx - .3, top + 5, 3.4, 2, dk);
        }
      }
    }

    if (r == 13) {
      // the king
      poly([
        [22, 66],
        [78, 66],
        [96, b],
        [4, b]
      ], const Color(0xFF5E0F24)); // the mantle
      for (var i = 0; i < 9; i++) {
        ell(10 + i * 10.0, 67, 5.5, 3.6, const Color(0xFFF6F1E6), const Color(0x2E000000));
      }
      body(68, coat);
      gazyri(68);
      face(42, 13.5, 15.5);
      x.drawPath(
          pth((p) => p
            ..moveTo(37 * u, 46 * u)
            ..quadraticBezierTo(36 * u, 66 * u, 50 * u, 70 * u)
            ..quadraticBezierTo(64 * u, 66 * u, 63 * u, 46 * u)
            ..quadraticBezierTo(57 * u, 55 * u, 50 * u, 54 * u)
            ..quadraticBezierTo(43 * u, 55 * u, 37 * u, 46 * u)),
          fillP(const Color(0xFF5B3A22)));
      x.drawPath(
          pth((p) => p
            ..moveTo(50 * u, 49 * u)
            ..cubicTo(44 * u, 46 * u, 38 * u, 50 * u, 35 * u, 47 * u)
            ..cubicTo(39 * u, 53 * u, 46 * u, 52 * u, 50 * u, 51 * u)
            ..cubicTo(54 * u, 52 * u, 61 * u, 53 * u, 65 * u, 47 * u)
            ..cubicTo(62 * u, 50 * u, 56 * u, 46 * u, 50 * u, 49 * u)),
          fillP(const Color(0xFF4A2E1A)));
      poly([
        [33, 30],
        [31, 12],
        [40, 21],
        [50, 7],
        [60, 21],
        [69, 12],
        [67, 30]
      ], gold, const Color(0xFF8A6418), 1);
      rect(33, 27, 34, 5, const Color(0xFFB8862C));
      ell(40, 29.5, 2, 2, const Color(0xFFC8102E));
      ell(50, 29.5, 2, 2, const Color(0xFF1E6FD6));
      ell(60, 29.5, 2, 2, const Color(0xFFC8102E));
      ell(50, 9, 2.2, 2.2, const Color(0xFFF6F1E6));
      x.drawLine(o(84, 64), o(78, b), strokeP(gold, 2.6));
      ell(84.5, 61, 4, 4, gold, const Color(0xFF8A6418));
    } else if (r == 12) {
      // the queen
      final veil = pth((p) => p
        ..moveTo(27 * u, 30 * u)
        ..cubicTo(24 * u, 8 * u, 76 * u, 8 * u, 73 * u, 30 * u)
        ..cubicTo(80 * u, 48 * u, 86 * u, 62 * u, 88 * u, 74 * u)
        ..lineTo(12 * u, 74 * u)
        ..cubicTo(14 * u, 62 * u, 20 * u, 48 * u, 27 * u, 30 * u));
      x.drawPath(veil, fillP(const Color(0xF5FFFFFF)));
      x.drawPath(veil, strokeP(const Color(0x8078788C), 1));
      body(70, coat);
      for (final a in const [44.0, 56.0]) {
        x.drawLine(o(a, 92), o(a < 50 ? 40.0 : 60.0, b), strokeP(gold, 1.4));
      }
      for (var i = 0; i < 4; i++) {
        ell(50, 96 + i * 6.0, 1.4, 1.4, gold);
      }
      for (final a in const [36.5, 63.5]) {
        ell(a, 66, 3.6, 17, const Color(0xFF3B2416));
        final line = strokeP(const Color(0x38FFFFFF), .8);
        for (var i = 0; i < 5; i++) {
          x.drawLine(o(a - 3, 54 + i * 6.0), o(a + 3, 57 + i * 6.0), line);
        }
      }
      x.drawPath(
          pth((p) => p
            ..addArc(Rect.fromCenter(center: o(50, 33), width: 28 * u, height: 16 * u), math.pi, math.pi)
            ..close()),
          fillP(const Color(0xFF3B2416)));
      face(43, 12.5, 15);
      ell(50, 50.6, 3, 1.3, const Color(0xFFC2384A));
      x.drawPath(
          pth((p) => p
            ..moveTo(35 * u, 30 * u)
            ..quadraticBezierTo(50 * u, 22 * u, 65 * u, 30 * u)
            ..lineTo(65 * u, 24 * u)
            ..quadraticBezierTo(50 * u, 16 * u, 35 * u, 24 * u)
            ..close()),
          fillP(const Color(0xFF5E0F24)));
      for (var i = 0; i < 7; i++) {
        ell(37 + i * 4.3, 26.5 + (i - 3).abs() * .45, 1.2, 1.2, const Color(0xFFF4E3B0));
      }
      ell(76, 98, 5, 5, const Color(0xFFC8102E));
      ell(76, 98, 2.2, 2.2, const Color(0xFFF27C8A));
      x.drawLine(o(76, 103), o(72, b), strokeP(const Color(0xFF2E7D32), 1.4));
    } else {
      // the jack
      body(66, coat);
      gazyri(66);
      face(40, 12, 14);
      x.drawPath(
          pth((p) => p
            ..moveTo(50 * u, 47 * u)
            ..cubicTo(46 * u, 45.5 * u, 42 * u, 47.5 * u, 40 * u, 46 * u)
            ..cubicTo(43 * u, 50 * u, 47 * u, 49 * u, 50 * u, 48.5 * u)
            ..cubicTo(53 * u, 49 * u, 57 * u, 50 * u, 60 * u, 46 * u)
            ..cubicTo(58 * u, 47.5 * u, 54 * u, 45.5 * u, 50 * u, 47 * u)),
          fillP(const Color(0xFF4A2E1A)));
      x.drawPath(
          pth((p) => p
            ..moveTo(35 * u, 29 * u)
            ..quadraticBezierTo(34 * u, 9 * u, 50 * u, 9 * u)
            ..quadraticBezierTo(66 * u, 9 * u, 65 * u, 29 * u)
            ..close()),
          fillP(const Color(0xFF2B211C)));
      final fur = strokeP(const Color(0x29FFFFFF), .9);
      for (var i = 0; i < 14; i++) {
        final a = 37 + i * 2.0;
        x.drawLine(o(a, 13.0 + (i % 3)), o(a + 1, 27.0 - (i % 2)), fur);
      }
      rect(34, 27, 32, 4, const Color(0xFF3A2E28));
      final horn = pth((p) => p
        ..moveTo(70 * u, 96 * u)
        ..quadraticBezierTo(90 * u, 86 * u, 86 * u, 60 * u)
        ..lineTo(94 * u, 58 * u)
        ..quadraticBezierTo(98 * u, 90 * u, 74 * u, 101 * u)
        ..close());
      x.drawPath(horn, fillP(const Color(0xFF8A5A2B)));
      x.drawPath(horn, strokeP(const Color(0xFF4A2E14), 1));
      x.save();
      x.translate(90 * u, 59 * u);
      x.rotate(-.2);
      x.drawOval(Rect.fromCenter(center: Offset.zero, width: 8.4 * u, height: 3.2 * u), fillP(const Color(0xFFC9CDD6)));
      x.restore();
      ell(71, 97, 4.5, 4, skin, const Color(0x595A321E));
    }
    rect(-20, b - 1.2, 140, 1.2, const Color(0x40000000));
    x.restore();
  }

  @override
  bool shouldRepaint(CourtPainter o) => o.r != r || o.s != s || o.c4 != c4;
}

/// The trump as a little white tile with its sign (✕ without a trump, ? while it is being chosen).
class TrumpTile extends StatelessWidget {
  const TrumpTile({super.key, required this.trump, this.choosing = false, this.size = 34, this.c4 = false});
  final String? trump;
  final bool choosing, c4;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(size * .24),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: choosing
            ? Text('?', style: TextStyle(color: const Color(0xFF8A93AE), fontWeight: FontWeight.w800, fontSize: size * .55, height: 1, fontFamily: 'NotoSans'))
            : trump == null
                ? PIcon('x', size: size * .55, color: const Color(0xFF8A93AE), stroke: 3)
                : SuitMark(trump!, size: size * .66, color: suitInk(trump!, c4: c4)),
      );
}

/// The words for the trump.
String trumpName(String? t, {bool choosing = false}) => choosing ? 'ირჩევა…' : (t == null ? 'უკოზირო' : suitName[t]!);

/// a card's fixed paper colour, for anything drawn next to cards
const cardPaper = _paper;
const cardInk = _cardInk;

/// A five-pointed star (the joker's sign, the premium's), drawn so every phone shows the same one.
class Star extends StatelessWidget {
  const Star({super.key, this.size = 16, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: CustomPaint(painter: _StarPainter(color)));
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), ro = size.shortestSide / 2, ri = ro * .45;
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5, rr = i.isEven ? ro : ri;
      final q = c + Offset(math.cos(a) * rr, math.sin(a) * rr + ro * .06);
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(p..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StarPainter o) => o.color != color;
}
