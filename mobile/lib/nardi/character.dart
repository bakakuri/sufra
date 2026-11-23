// The people at the backgammon table, drawn in code in the manner of a 3D cartoon: round soft heads, big bright eyes,
// a look of their own (hair, hat, moustache, shirt), and a body that moves — breathes, blinks, thinks with a hand at the
// chin, shakes and throws the dice, reaches for a checker, cheers, sulks, fumes.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'table_model.dart';

/// the characters move (off in the tests, where an endless movement would never let a screen settle)
bool charactersMove = true;

class CharacterView extends StatefulWidget {
  const CharacterView({super.key, required this.look, required this.mood, this.size = 120, this.facingDown = false, this.still = false});
  final CharacterLook look;
  final Mood mood;
  final double size;

  /// sits at the top of the table, facing down to the board (the arms reach downward)
  final bool facingDown;

  /// no movement (the tests, less-motion phones)
  final bool still;

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 20));
  Mood _from = Mood.idle;
  double _moodAt = 0;
  final _rnd = math.Random();
  double _blinkAt = 1.2;

  bool get _still => widget.still || !charactersMove;

  @override
  void initState() {
    super.initState();
    if (!_still) _c.repeat();
  }

  @override
  void didUpdateWidget(CharacterView old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      _from = old.mood;
      _moodAt = _c.value * 20;
    }
    if (old.still != widget.still && charactersMove) {
      if (widget.still) {
        _c.stop();
      } else {
        _c.repeat();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * 20;
          // the blink: closed for 120 ms, every 2.5–5 s
          var blink = 0.0;
          if (!_still) {
            if (t > _blinkAt + .14 || t < _blinkAt - 10) _blinkAt = t + 2.5 + _rnd.nextDouble() * 2.5;
            if (t >= _blinkAt && t < _blinkAt + .14) blink = math.sin((t - _blinkAt) / .14 * math.pi);
          }
          final since = ((t - _moodAt) % 20 + 20) % 20;
          return CustomPaint(
            size: Size(widget.size, widget.size * .92),
            painter: _CharacterPainter(
              look: widget.look,
              mood: widget.mood,
              from: _from,
              blend: _still ? 1 : (since / .35).clamp(0.0, 1.0),
              t: _still ? 0 : t,
              since: since,
              blink: blink,
              down: widget.facingDown,
            ),
          );
        },
      );
}

class _CharacterPainter extends CustomPainter {
  _CharacterPainter({
    required this.look,
    required this.mood,
    required this.from,
    required this.blend,
    required this.t,
    required this.since,
    required this.blink,
    required this.down,
  });
  final CharacterLook look;
  final Mood mood, from;
  final double blend, t, since, blink;
  final bool down;

  Color get skin => Color(look.skin);
  Color get hair => Color(look.hair);
  Color get shirt => Color(look.shirt);

  /// the faces: head tilt, head drop, mouth curve (−1 frown … 1 smile), mouth open, brow lift (−1 angry … 1 raised),
  /// brow inner lift (sad), eyes shut, blush
  static const _faces = <Mood, List<double>>{
    //            tilt  drop  mouth open brow  inner shut blush
    Mood.idle: [0, 0, .35, 0, 0, 0, 0, 0],
    Mood.think: [.08, .02, .1, 0, .5, 0, 0, 0],
    Mood.roll: [-.05, -.03, .5, .15, .3, 0, 0, 0],
    Mood.reach: [0, .06, .3, 0, 0, 0, 0, 0],
    Mood.happy: [0, -.05, 1, .6, .8, 0, 1, .5],
    Mood.sad: [.12, .12, -.9, 0, .2, 1, .2, 0],
    Mood.angry: [-.06, .03, -.5, .25, -1, 0, 0, 1],
  };

  /// where the hands are (the left one, the right one; x of the right side, mirrored for the left), in the figure's
  /// units: resting on the table, one at the chin, one by the head shaking the dice, one reaching for the board (up to
  /// it from the bottom of the screen, down to it from the top), both up, both low, both fists down
  Offset _hand(Mood m, bool right) => switch (m) {
        Mood.idle => const Offset(34, -8),
        Mood.think => right ? const Offset(9, -47) : const Offset(34, -8),
        Mood.roll => right ? const Offset(46, -74) : const Offset(34, -8),
        Mood.reach => right ? Offset(26, down ? -4 : -92) : const Offset(34, -8),
        Mood.happy => const Offset(50, -100),
        Mood.sad => const Offset(26, -6),
        Mood.angry => const Offset(22, -16),
      };

  double get _e => Curves.easeOutBack.transform(blend);

  List<double> get _face {
    final a = _faces[from]!, b = _faces[mood]!, e = _e;
    return [for (var i = 0; i < a.length; i++) a[i] + (b[i] - a[i]) * e];
  }

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
  static Color _a(Color c, double a) => c.withValues(alpha: a);
  static const _white = Color(0xFFFFFFFF), _black = Color(0xFF000000), _warm = Color(0xFF7A3B2A);

  static void _oval(Canvas c, Offset o, double w, double h, Paint p) => c.drawOval(Rect.fromCenter(center: o, width: w, height: h), p);
  static Paint _fill(Color c) => Paint()..color = c;
  static Paint _stroke(double w, Color c) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..color = c
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static Paint _radial(Offset c, double r, List<Color> colors, List<double> stops, {Offset? focal}) =>
      Paint()..shader = ui.Gradient.radial(c, r, colors, stops, TileMode.clamp, null, focal, 0);
  static Paint _linear(Offset a, Offset b, List<Color> colors, [List<double>? stops]) => Paint()..shader = ui.Gradient.linear(a, b, colors, stops);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, u = w / 140;
    final f = _face;
    final breath = math.sin(t * 2 * math.pi / 3.2) * .9;
    var bounce = 0.0, shake = 0.0;
    if (mood == Mood.happy) bounce = (math.sin(since * 9).abs()) * 5 * math.max(0, 1 - since / 2.5);
    if (mood == Mood.angry) shake = math.sin(since * 40) * 1.6 * math.max(0, 1 - since / 1.2);
    final skinL = _mix(skin, _white, .35), skinD = _mix(skin, _warm, .28);
    canvas.save();
    // the figure is drawn 140 units wide and 128 tall, from its waist (0) up
    canvas.translate(w / 2 + shake * u, h - bounce * u);
    canvas.scale(u);

    // ---- the body ----
    final torso = Path()
      ..moveTo(-52, 0)
      ..cubicTo(-52, -22, -48, -34, -34, -38)
      ..lineTo(34, -38)
      ..cubicTo(48, -34, 52, -22, 52, 0)
      ..close();
    canvas.drawPath(torso.shift(const Offset(0, 3)), _fill(_a(_black, .1)));
    canvas.drawPath(torso, _linear(const Offset(-52, -38), const Offset(52, 0), [_mix(shirt, _white, .25), shirt, _mix(shirt, _black, .3)], const [0, .55, 1]));
    canvas.drawPath(torso, _radial(const Offset(-14, -30), 40, [_a(_white, .18), _a(_white, 0)], const [0, 1]));
    // the neckline and the neck
    canvas.drawPath(
        Path()
          ..moveTo(-12, -38)
          ..quadraticBezierTo(0, -24, 12, -38)
          ..close(),
        _fill(_mix(skin, _black, .12)));
    canvas.drawPath(
        Path()
          ..moveTo(-13, -38.5)
          ..quadraticBezierTo(0, -22, 13, -38.5),
        _stroke(2.6, _mix(shirt, _black, .25)));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -56, 18, 22), const Radius.circular(6)),
        _linear(const Offset(-9, 0), const Offset(9, 0), [_mix(skin, _black, .08), _mix(skin, _black, .2)]));

    // ---- the arms: each hand goes where the pose puts it, the elbow bends outward ----
    final e = _e;
    void arm(bool right) {
      final s = right ? 1.0 : -1.0;
      final a = _hand(from, right), b = _hand(mood, right);
      var hx = s * (a.dx + (b.dx - a.dx) * e), hy = a.dy + (b.dy - a.dy) * e;
      if (right && mood == Mood.roll) {
        hx += math.sin(since * 24) * 3;
        hy += math.cos(since * 24) * 2;
      }
      const l1 = 21.0, l2 = 21.0;
      final sx = s * 38, sy = -31.0;
      var dx = hx - sx, dy = hy - sy, d = math.sqrt(dx * dx + dy * dy);
      const most = l1 + l2 - .5;
      if (d > most) {
        hx = sx + dx / d * most;
        hy = sy + dy / d * most;
        dx = hx - sx;
        dy = hy - sy;
        d = most;
      }
      final base = math.atan2(dy, dx);
      final k = math.acos(((l1 * l1 + d * d - l2 * l2) / (2 * l1 * math.max(d, .001))).clamp(-1.0, 1.0));
      final ang = base + s * (dy < 0 ? k : -k);
      final ex = sx + math.cos(ang) * l1, ey = sy + math.sin(ang) * l1;
      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), _stroke(15, _mix(shirt, _black, .12)));
      canvas.drawLine(Offset(ex, ey), Offset(hx, hy), _stroke(12, _mix(shirt, _black, .06)));
      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), _stroke(6, _a(_white, .07)));
      final hc = Offset(hx, hy);
      _oval(canvas, hc, 15, 14, _radial(hc, 8, [skinL, skin, _mix(skin, _warm, .15)], const [0, .7, 1], focal: hc + const Offset(-2.5, -2.5)));
      _oval(canvas, hc + Offset(-s * 5, -1.5), 6, 8, _fill(_mix(skin, _white, .12)));
      if (right && mood == Mood.roll) {
        // two dice in the shaking hand
        for (final o in const [Offset(-5, -9), Offset(4, -7)]) {
          canvas.save();
          canvas.translate(hx + o.dx, hy + o.dy);
          canvas.rotate(o.dx * .12);
          final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 9, height: 9), const Radius.circular(2));
          canvas.drawRRect(r, _fill(const Color(0xFFFFFDF5)));
          canvas.drawRRect(r, _stroke(.8, const Color(0xFFCFC6B4)));
          _oval(canvas, const Offset(-2, -2), 2, 2, _fill(const Color(0xFF1F1612)));
          _oval(canvas, const Offset(2, 2), 2, 2, _fill(const Color(0xFF1F1612)));
          canvas.restore();
        }
      }
    }

    arm(false);
    arm(true);

    // ---- the head ----
    canvas.save();
    canvas.translate(0, -84 + f[1] * 8 + breath);
    canvas.rotate(f[0]);
    final hairD = _mix(hair, _black, .25);
    if (look.style == 'long') {
      canvas.drawPath(
          Path()
            ..moveTo(-30, -26)
            ..cubicTo(-44, -6, -42, 30, -36, 44)
            ..quadraticBezierTo(0, 52, 36, 44)
            ..cubicTo(42, 30, 44, -6, 30, -26)
            ..close(),
          _linear(const Offset(-40, -20), const Offset(40, 44), [_mix(hair, _white, .12), hairD]));
    }
    if (look.style == 'pony') _oval(canvas, const Offset(30, -26), 22, 30, _fill(_mix(hair, _black, .1)));
    // the ears
    for (final s in const [-1.0, 1.0]) {
      _oval(canvas, Offset(s * 31.5, 2), 11, 15, _fill(_mix(skin, _warm, .12)));
      _oval(canvas, Offset(s * 31.5, 2), 5, 8, _fill(_mix(skin, _warm, .3)));
    }
    // the face: a round skull and full cheeks under one light
    final face = _radial(Offset.zero, 40, [skinL, skin, skinD], const [0, .55, 1], focal: const Offset(-11, -12));
    _oval(canvas, const Offset(0, -3), 64, 60, face);
    _oval(canvas, const Offset(0, 9), 58, 46, face);
    _oval(canvas, const Offset(-7, -17), 28, 16, _fill(_a(_white, .16)));
    // the cheeks
    final blush = .22 + f[7] * .5;
    for (final s in const [-1.0, 1.0]) {
      final c = Offset(s * 19, 13);
      _oval(canvas, c, 15, 9, _radial(c, 9, [_a(const Color(0xFFE8757A), .55 * blush), _a(const Color(0xFFE8757A), 0)], const [0, 1]));
    }
    // the eyes
    final shut = math.max(blink, f[6]);
    final lash = _mix(hair, _black, .4);
    for (final s in const [-1.0, 1.0]) {
      final ex = s * 12.5;
      const ey = -1.0;
      if (shut > .85) {
        final path = Path();
        if (f[2] > .5) {
          path.addArc(Rect.fromCircle(center: Offset(ex, ey + 3), radius: 7), math.pi * 1.15, math.pi * .7);
        } else {
          path
            ..moveTo(ex - 7, ey + 1)
            ..quadraticBezierTo(ex, ey + 4, ex + 7, ey + 1);
        }
        canvas.drawPath(path, _stroke(2.4, _mix(skin, _black, .6)));
      } else {
        final white = Rect.fromCenter(center: Offset(ex, ey), width: 17.2, height: 19.6);
        canvas.save();
        canvas.clipPath(Path()..addOval(white));
        canvas.drawRect(white.inflate(1), _linear(Offset(0, ey - 10), Offset(0, ey + 10), const [Color(0xFFDCDFE8), Color(0xFFFFFFFF), Color(0xFFF4F4F8)], const [0, .35, 1]));
        // the gaze: up and aside in a thought, to the board in a reach, wandering a little otherwise
        final gaze = switch (mood) {
          Mood.think => const Offset(-2.4, -3.2),
          Mood.reach => Offset(0, down ? 3 : 2.6),
          _ => Offset(math.sin(t * .7) * 1.2, .6),
        };
        final ic = Offset(ex, ey) + gaze;
        _oval(canvas, ic, 14, 14, _radial(ic, 7, const [Color(0xFF8A5A32), Color(0xFF5A3518), Color(0xFF2A1608)], const [0, .65, 1]));
        _oval(canvas, ic, 7.4, 7.4, _fill(const Color(0xFF120C10)));
        _oval(canvas, ic + const Offset(-2.6, -2.8), 4.6, 4.6, _fill(_white));
        _oval(canvas, ic + const Offset(2.6, 2.4), 1.8, 1.8, _fill(_a(_white, .85)));
        // the lid coming down
        if (shut > 0) canvas.drawRect(Rect.fromLTWH(ex - 10, ey - 11, 20, 22 * shut), _fill(skin));
        canvas.restore();
        canvas.drawPath(Path()..addArc(Rect.fromCenter(center: Offset(ex, ey), width: 17.6, height: 20), math.pi * 1.08, math.pi * .84), _stroke(look.fem ? 2.4 : 1.8, lash));
        if (look.fem) canvas.drawLine(Offset(ex + s * 7.6, ey - 5), Offset(ex + s * 10.6, ey - 7.6), _stroke(1.8, lash));
      }
      // the brow: up when surprised or glad, its inner end up when sad and down when angry
      final bl = f[4], inner = f[5];
      final by = ey - 15 - math.max(0, bl) * 2.6;
      final i0 = Offset(ex - s * 7, by - inner * 2.8 + (bl < 0 ? -bl * 4 : 0) + 2);
      canvas.drawPath(
          Path()
            ..moveTo(i0.dx, i0.dy)
            ..quadraticBezierTo(ex, by - 2.6, ex + s * 7.5, by + 1),
          _stroke(look.fem ? 2.6 : 3.8, _mix(hair, _black, .1)));
    }
    if (look.glasses) {
      final rim = _stroke(2, const Color(0xFF2A2A30));
      for (final s in const [-1.0, 1.0]) {
        canvas.drawCircle(Offset(s * 12.5, -1), 11, rim);
      }
      canvas.drawPath(
          Path()
            ..moveTo(-2, -2)
            ..quadraticBezierTo(0, -4, 2, -2),
          rim);
    }
    // the nose
    _oval(canvas, const Offset(0, 9), 9, 7, _radial(const Offset(0, 9), 6, [_mix(skin, _warm, .18), _a(skin, 0)], const [0, 1]));
    canvas.drawPath(
        Path()
          ..moveTo(-3.2, 10.5)
          ..quadraticBezierTo(0, 13, 3.2, 10.5),
        _stroke(1.8, _mix(skin, _warm, .4)));
    _oval(canvas, const Offset(-1, 6), 3, 3, _fill(_a(_white, .35)));
    // the beard
    if (look.beard) {
      canvas.drawPath(
          Path()
            ..moveTo(-31, 4)
            ..cubicTo(-30, 30, -14, 40, 0, 40)
            ..cubicTo(14, 40, 30, 30, 31, 4)
            ..cubicTo(26, 22, 16, 24, 10, 20)
            ..quadraticBezierTo(0, 16, -10, 20)
            ..cubicTo(-16, 24, -26, 22, -31, 4)
            ..close(),
          _linear(const Offset(0, 4), const Offset(0, 40), [_mix(hair, _white, .08), _mix(hair, _black, .2)]));
    }
    // the mouth
    const my = 21.0;
    final curve = f[2], open = f[3], mw = 8.5 * (1 + open * .25);
    if (open > .05) {
      final m = Path()
        ..moveTo(-mw, my - curve * 2)
        ..quadraticBezierTo(0, my + curve * 6 + open * 12, mw, my - curve * 2)
        ..quadraticBezierTo(0, my + curve * 1.5, -mw, my - curve * 2)
        ..close();
      canvas.drawPath(m, _fill(const Color(0xFF6E2430)));
      canvas.save();
      canvas.clipPath(m);
      _oval(canvas, const Offset(0, my - 1), mw * 1.6, 5, _fill(_white));
      _oval(canvas, Offset(0, my + curve * 6 + open * 10), mw, 6, _fill(const Color(0xFFD4636C)));
      canvas.restore();
    } else {
      canvas.drawPath(
          Path()
            ..moveTo(-mw, my - curve * 2)
            ..quadraticBezierTo(0, my + curve * 7, mw, my - curve * 2),
          _stroke(2.4, _mix(skin, const Color(0xFF6B2B2B), .65)));
    }
    if (look.mus) {
      for (final s in const [-1.0, 1.0]) {
        canvas.drawPath(
            Path()
              ..moveTo(0, my - 6)
              ..cubicTo(s * 6, my - 10, s * 12, my - 8, s * 14, my - 2)
              ..cubicTo(s * 10, my - 4, s * 5, my - 3, 0, my - 3)
              ..close(),
            _fill(_mix(hair, _black, .05)));
      }
    }
    // ---- the hair in front ----
    final hg = _linear(const Offset(-30, -36), const Offset(30, 0), [_mix(hair, _white, .22), hair, hairD], const [0, .5, 1]);
    if (look.style != 'bald') {
      final cap = Path();
      if (look.style == 'long' || look.style == 'pony') {
        cap
          ..moveTo(-33, 6)
          ..cubicTo(-36, -30, -20, -38, 0, -37)
          ..cubicTo(20, -38, 36, -30, 33, 6)
          ..cubicTo(30, -6, 26, -14, 20, -20)
          ..quadraticBezierTo(8, -16, 2, -25)
          ..quadraticBezierTo(-8, -14, -20, -20)
          ..cubicTo(-26, -14, -30, -6, -33, 6);
      } else {
        cap
          ..moveTo(-32, -2)
          ..cubicTo(-36, -30, -20, -39, 0, -38)
          ..cubicTo(22, -39, 36, -28, 32, -2)
          ..cubicTo(30, -12, 27, -17, 22, -20)
          ..cubicTo(10, -14, -4, -22, -10, -20)
          ..cubicTo(-18, -17, -24, -18, -27, -14)
          ..cubicTo(-29, -10, -30, -6, -32, -2);
      }
      canvas.drawPath(cap..close(), hg);
      canvas.drawPath(
          Path()
            ..moveTo(-18, -33)
            ..quadraticBezierTo(-4, -37, 8, -34),
          _stroke(3, _a(_white, .18)));
      if (look.style == 'curly') {
        if (look.hat) {
          for (final s in const [-1.0, 1.0]) {
            _oval(canvas, Offset(s * 29, -6), 10, 10, hg);
            _oval(canvas, Offset(s * 31, 2), 10, 10, hg);
          }
        } else {
          for (var i = 0; i < 9; i++) {
            final a = math.pi * (.05 + .9 * i / 8);
            _oval(canvas, Offset(math.cos(a) * 30, -6 - math.sin(a) * 30), 15, 15, hg);
          }
        }
      }
    } else {
      _oval(canvas, const Offset(-8, -26), 16, 7, _fill(_a(_white, .35)));
      for (final s in const [-1.0, 1.0]) {
        canvas.drawPath(
            Path()
              ..moveTo(s * 31, -12)
              ..quadraticBezierTo(s * 34, -2, s * 30, 8),
            _stroke(5, hair));
      }
    }
    // the hat: a flat cap
    if (look.hat) {
      final hc = _mix(shirt, _black, .35);
      canvas.drawPath(
          Path()
            ..moveTo(-35, -14)
            ..cubicTo(-38, -40, -14, -46, 6, -44)
            ..cubicTo(28, -42, 38, -30, 35, -14)
            ..quadraticBezierTo(0, -20, -35, -14)
            ..close(),
          _linear(const Offset(-30, -44), const Offset(30, -14), [_mix(hc, _white, .18), _mix(hc, _black, .2)]));
      canvas.drawPath(
          Path()
            ..moveTo(-30, -16)
            ..quadraticBezierTo(0, -24, 30, -16)
            ..quadraticBezierTo(10, -8, -30, -16)
            ..close(),
          _fill(_mix(hc, _black, .35)));
      _oval(canvas, const Offset(4, -44), 6, 3, _fill(_mix(hc, _black, .2)));
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CharacterPainter o) => true;
}
