// The people at the backgammon table, drawn in code in the manner of a 3D cartoon: round soft heads, big bright eyes,
// a look of their own (hair, hat, moustache, shirt), and a body that moves — breathes, blinks, thinks with a hand at the
// chin, shakes and throws the dice, reaches for a checker, cheers, sulks, fumes.
import 'dart:math' as math;

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

  /// the poses: head tilt, head drop, mouth curve (−1 frown … 1 smile), mouth open, brow lift (−1 angry … 1 raised),
  /// brow inner lift (sad), eyes shut, left arm and right arm (angle from down, reach) and a blush
  static const _poses = <Mood, List<double>>{
    //            tilt  drop  mouth open brow  inner shut  larm lreach rarm rreach blush
    Mood.idle: [0, 0, .35, 0, 0, 0, 0, .25, 0, -.25, 0, 0],
    Mood.think: [.08, .02, .1, 0, .5, 0, 0, .25, 0, -1.9, .9, 0],
    Mood.roll: [-.05, -.03, .5, .15, .3, 0, 0, .25, 0, -2.2, 1.0, 0],
    Mood.reach: [0, .06, .3, 0, 0, 0, 0, .25, 0, -.7, 1.4, 0],
    Mood.happy: [0, -.05, 1, .6, .8, 0, 1, 2.6, .6, -2.6, .6, .5],
    Mood.sad: [.12, .12, -.9, 0, .2, 1, .2, .15, 0, -.15, 0, 0],
    Mood.angry: [-.06, .03, -.5, .25, -1, 0, 0, .9, .3, -.9, .3, 1],
  };

  List<double> get _pose {
    final a = _poses[from]!, b = _poses[mood]!;
    final e = Curves.easeOutBack.transform(blend);
    return [for (var i = 0; i < a.length; i++) a[i] + (b[i] - a[i]) * e];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, u = w / 120;
    final p = _pose;
    final breath = math.sin(t * 2 * math.pi / 3.2) * .8 * u;
    var bounce = 0.0, shake = 0.0, wave = 0.0;
    if (mood == Mood.happy) bounce = (math.sin(since * 9).abs()) * 5 * u * math.max(0, 1 - since / 2.5);
    if (mood == Mood.angry) shake = math.sin(since * 40) * 1.6 * u * math.max(0, 1 - since / 1.2);
    if (mood == Mood.roll) wave = math.sin(since * 24) * .5 * math.max(0, 1 - since / 1.1);
    canvas.save();
    canvas.translate(w / 2 + shake, h - bounce);
    // the figure is drawn 140 units tall (from the hat to the waist); this fits it into the box
    canvas.scale(.78);

    // ---- the body ----
    final torso = Path()
      ..moveTo(-44 * u, 0)
      ..cubicTo(-44 * u, -34 * u, -30 * u, -46 * u, -16 * u, -48 * u)
      ..lineTo(16 * u, -48 * u)
      ..cubicTo(30 * u, -46 * u, 44 * u, -34 * u, 44 * u, 0)
      ..close();
    canvas.drawPath(torso.shift(Offset(0, 3 * u)), Paint()..color = Colors.black.withValues(alpha: .12));
    canvas.drawPath(
      torso,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(shirt, Colors.white, .28)!, shirt, Color.lerp(shirt, Colors.black, .25)!])
            .createShader(Rect.fromLTWH(-44 * u, -48 * u, 88 * u, 48 * u)),
    );
    // the collar
    canvas.drawPath(
      Path()
        ..moveTo(-12 * u, -48 * u)
        ..lineTo(0, -36 * u)
        ..lineTo(12 * u, -48 * u),
      Paint()
        ..color = Color.lerp(skin, Colors.black, .18)!
        ..style = PaintingStyle.fill,
    );
    // the neck
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-9 * u, -62 * u, 18 * u, 20 * u), Radius.circular(6 * u)),
        Paint()..color = Color.lerp(skin, Colors.black, .12)!);

    // ---- the arms (from the shoulders; a reach lengthens the forearm toward the board) ----
    void arm(bool left, double angle, double reach) {
      final sx = (left ? -38 : 38) * u, sy = -38 * u;
      final a = (left ? 1 : -1) * angle + wave * (left ? 0 : 1);
      // the arm hangs down (angle 0) and swings out and up with the angle; a reach stretches the hand toward the
      // board, which is above me at the bottom of the screen and below the one at the top
      final ex = sx + math.sin(a) * 26 * u, ey = sy + math.cos(a) * 26 * u;
      final hx = ex + math.sin(a) * 14 * u * (1 - reach) - (left ? 1 : -1) * reach * 10 * u,
          hy = ey + math.cos(a) * 14 * u * (1 - reach) + reach * (down ? 22 : -26) * u;
      final sleeve = Paint()
        ..color = Color.lerp(shirt, Colors.black, .1)!
        ..strokeWidth = 15 * u
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), sleeve);
      canvas.drawLine(
          Offset(ex, ey),
          Offset(hx, hy),
          Paint()
            ..color = skin
            ..strokeWidth = 11 * u
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke);
      canvas.drawCircle(Offset(hx, hy), 7.5 * u, Paint()..shader = RadialGradient(center: const Alignment(-.4, -.4), colors: [Color.lerp(skin, Colors.white, .25)!, skin]).createShader(Rect.fromCircle(center: Offset(hx, hy), radius: 8 * u)));
      if (mood == Mood.roll && !left) {
        // two dice in the shaking hand
        for (final o in [Offset(-4 * u, -3 * u), Offset(4 * u, 1 * u)]) {
          final r = Rect.fromCenter(center: Offset(hx, hy) + o, width: 7 * u, height: 7 * u);
          canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(1.6 * u)), Paint()..color = const Color(0xFFFFFDF5));
          canvas.drawCircle(r.center, .9 * u, Paint()..color = const Color(0xFF1F1612));
        }
      }
    }

    arm(true, p[7], p[8]);
    arm(false, -p[9], p[10]);

    // ---- the head ----
    canvas.save();
    canvas.translate(0, -62 * u + breath + p[1] * 10 * u);
    canvas.rotate(p[0]);
    final hr = 34 * u;
    final headC = Offset(0, -hr);
    canvas.drawOval(Rect.fromCenter(center: headC + Offset(0, 4 * u), width: hr * 2, height: hr * 2.1), Paint()..color = Colors.black.withValues(alpha: .1));
    canvas.drawOval(
      Rect.fromCenter(center: headC, width: hr * 2, height: hr * 2.1),
      Paint()..shader = RadialGradient(center: const Alignment(-.35, -.4), radius: .95, colors: [Color.lerp(skin, Colors.white, .3)!, skin, Color.lerp(skin, const Color(0xFF7A3B2A), .22)!], stops: const [0, .6, 1]).createShader(Rect.fromCircle(center: headC, radius: hr)),
    );
    // the ears
    for (final sgn in [-1, 1]) {
      canvas.drawOval(Rect.fromCenter(center: headC + Offset(sgn * hr * .98, 2 * u), width: 11 * u, height: 15 * u), Paint()..color = Color.lerp(skin, Colors.black, .06)!);
    }
    // the hair behind (long) and the cap of hair
    final hairPaint = Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(hair, Colors.white, .22)!, hair]).createShader(Rect.fromCircle(center: headC, radius: hr * 1.2));
    if (look.style == 'long') {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: headC + Offset(0, hr * .45), width: hr * 2.25, height: hr * 2.2), Radius.circular(hr * .6)), hairPaint);
    }
    if (look.style != 'bald') {
      final cap = Path()
        ..moveTo(-hr * 1.02, -hr * .1 - hr)
        ..cubicTo(-hr * 1.02, -hr * 1.05 - hr, hr * 1.02, -hr * 1.05 - hr, hr * 1.02, -hr * .1 - hr)
        ..cubicTo(hr * .7, -hr * .55 - hr, hr * .2, -hr * .35 - hr, -hr * .25, -hr * .6 - hr)
        ..cubicTo(-hr * .6, -hr * .5 - hr, -hr * .9, -hr * .25 - hr, -hr * 1.02, -hr * .1 - hr)
        ..close();
      canvas.drawPath(cap, hairPaint);
      if (look.style == 'curly') {
        for (var i = 0; i < 7; i++) {
          final a = math.pi * (0.1 + .8 * i / 6);
          canvas.drawCircle(headC + Offset(math.cos(a) * hr * .95, -math.sin(a) * hr * .95 - hr * .08), hr * .22, hairPaint);
        }
      }
    } else {
      canvas.drawOval(Rect.fromCenter(center: headC + Offset(-hr * .3, -hr * .55), width: hr * .5, height: hr * .25), Paint()..color = Colors.white.withValues(alpha: .35));
    }
    // the hat: a flat cap
    if (look.hat) {
      final hc = Color.lerp(shirt, Colors.black, .35)!;
      canvas.drawOval(Rect.fromCenter(center: headC + Offset(0, -hr * .78), width: hr * 2.25, height: hr * .9), Paint()..color = hc);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: headC + Offset(hr * .25, -hr * .58), width: hr * 1.3, height: hr * .3), Radius.circular(hr * .15)), Paint()..color = Color.lerp(hc, Colors.black, .3)!);
    }
    // the eyes
    final shut = math.max(blink, p[6]);
    for (final sgn in [-1, 1]) {
      final ec = headC + Offset(sgn * hr * .38, hr * .02);
      final ew = hr * .3, eh = hr * .36 * (1 - shut);
      if (shut > .85) {
        // closed: a happy arc or a line
        canvas.drawArc(Rect.fromCenter(center: ec, width: ew * 2, height: hr * .3), p[2] > .5 ? math.pi : 0, math.pi, false,
            Paint()
              ..color = Color.lerp(skin, Colors.black, .55)!
              ..strokeWidth = 2.2 * u
              ..strokeCap = StrokeCap.round
              ..style = PaintingStyle.stroke);
      } else {
        canvas.drawOval(Rect.fromCenter(center: ec, width: ew * 2, height: math.max(eh * 2, 1)), Paint()..color = Colors.white);
        // the gaze: up for a thought, down for a reach
        final gaze = mood == Mood.think ? Offset(-ew * .3, -eh * .45) : (mood == Mood.reach ? Offset(0, eh * .4) : Offset(math.sin(t * .7) * ew * .12, 0));
        final ic = ec + gaze;
        canvas.drawCircle(ic, ew * .62, Paint()..shader = RadialGradient(colors: [const Color(0xFF6A9BD8), const Color(0xFF2C4F8A)]).createShader(Rect.fromCircle(center: ic, radius: ew * .62)));
        canvas.drawCircle(ic, ew * .34, Paint()..color = const Color(0xFF14101C));
        canvas.drawCircle(ic + Offset(-ew * .2, -ew * .22), ew * .14, Paint()..color = Colors.white);
        // the lid
        canvas.drawArc(Rect.fromCenter(center: ec, width: ew * 2.1, height: eh * 2.1), math.pi, math.pi, false,
            Paint()
              ..color = Color.lerp(skin, Colors.black, .35)!
              ..strokeWidth = 1.6 * u
              ..style = PaintingStyle.stroke);
      }
      // the brow
      final bl = p[4], inner = p[5];
      final by = ec.dy - hr * .36 - math.max(0, bl) * hr * .08;
      // the inner end: up when sad, down when angry
      final innerEnd = Offset(ec.dx - sgn * ew * .95, by - inner * hr * .08 + (bl < 0 ? -bl * hr * .12 : 0));
      final outerEnd = Offset(ec.dx + sgn * ew * .95, by);
      canvas.drawLine(
          innerEnd,
          outerEnd,
          Paint()
            ..color = hair
            ..strokeWidth = 3 * u
            ..strokeCap = StrokeCap.round);
    }
    // the nose
    canvas.drawArc(Rect.fromCenter(center: headC + Offset(0, hr * .3), width: hr * .22, height: hr * .25), 0, math.pi, false,
        Paint()
          ..color = Color.lerp(skin, const Color(0xFF7A3B2A), .35)!
          ..strokeWidth = 2 * u
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);
    // the cheeks
    final blush = .25 + p[11] * .45;
    for (final sgn in [-1, 1]) {
      canvas.drawOval(Rect.fromCenter(center: headC + Offset(sgn * hr * .55, hr * .35), width: hr * .4, height: hr * .22), Paint()..color = const Color(0xFFE8757A).withValues(alpha: blush * .45));
    }
    // the mouth
    final my = headC.dy + hr * .62, mw = hr * .42 * (1 + p[3] * .2), curve = p[2];
    final mouth = Path()
      ..moveTo(-mw, my - curve * hr * .06)
      ..quadraticBezierTo(0, my + curve * hr * .3 + p[3] * hr * .1, mw, my - curve * hr * .06);
    if (p[3] > .05) {
      final open = Path.from(mouth)..quadraticBezierTo(0, my + curve * hr * .3 + p[3] * hr * .45, -mw, my - curve * hr * .06);
      canvas.drawPath(open, Paint()..color = const Color(0xFF7A2A33));
      canvas.drawPath(open, Paint()..color = Colors.white.withValues(alpha: .9 * math.min(1, p[3] * 1.5))..style = PaintingStyle.stroke..strokeWidth = 2.6 * u);
    }
    canvas.drawPath(
        mouth,
        Paint()
          ..color = Color.lerp(skin, const Color(0xFF6B2B2B), .6)!
          ..strokeWidth = 2.4 * u
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);
    // the moustache and the beard
    if (look.beard) {
      canvas.drawArc(Rect.fromCenter(center: headC + Offset(0, hr * .5), width: hr * 1.5, height: hr * 1.2), 0.15, math.pi - .3, false,
          Paint()
            ..color = hair.withValues(alpha: .85)
            ..strokeWidth = 7 * u
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke);
    }
    if (look.mus) {
      for (final sgn in [-1, 1]) {
        final path = Path()
          ..moveTo(0, my - hr * .1)
          ..quadraticBezierTo(sgn * hr * .22, my - hr * .22, sgn * hr * .4, my - hr * .08);
        canvas.drawPath(
            path,
            Paint()
              ..color = hair
              ..strokeWidth = 4.5 * u
              ..strokeCap = StrokeCap.round
              ..style = PaintingStyle.stroke);
      }
    }
    // the fringe over the forehead (short hair)
    if (look.style == 'short' && !look.hat) {
      canvas.drawArc(Rect.fromCenter(center: headC + Offset(hr * .15, -hr * .62), width: hr * 1.1, height: hr * .5), math.pi, math.pi * .9, false,
          Paint()
            ..color = hair
            ..strokeWidth = 5 * u
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke);
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CharacterPainter o) => true;
}
