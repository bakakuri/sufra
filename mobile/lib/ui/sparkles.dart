// The little stars and Peera marks that scatter, now and then, from a profile picture in its ring (on the tab bar,
// in the stories, and every small picture of a person).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'icons.dart';
import 'look.dart';
import 'theme.dart';

/// whether the bursts come at all (the tests turn them off: they wait for a still screen; one test watches a burst)
bool sparklesOn = true;

final _rng = math.Random();

/// [child] (a picture in its ring, [size] across) with a burst from time to time: the first after [first], then one
/// every [every]; when not given they are a little different for each picture, so they do not all go at once.
/// [now] turning true sets one off at once.
class Sparkles extends StatefulWidget {
  const Sparkles({super.key, required this.size, required this.child, this.first, this.every, this.now = false});
  final double size;
  final Widget child;
  final Duration? first, every;
  final bool now;
  @override
  State<Sparkles> createState() => _SparklesState();
}

class _SparklesState extends State<Sparkles> with SingleTickerProviderStateMixin {
  AnimationController? _burst;
  Timer? _next;

  AnimationController get burst => _burst ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _later(widget.every ?? Duration(milliseconds: 7000 + _rng.nextInt(7000)));
    });

  @override
  void initState() {
    super.initState();
    if (sparklesOn) _later(widget.first ?? Duration(milliseconds: 1200 + _rng.nextInt(8000)));
  }

  @override
  void didUpdateWidget(Sparkles old) {
    super.didUpdateWidget(old);
    if (widget.now && !old.now) _go();
  }

  void _later(Duration d) {
    _next?.cancel();
    _next = Timer(d, _go);
  }

  void _go() {
    if (!mounted || !sparklesOn) return;
    // a phone asked for less movement, or the battery saver, gets none (the next one is still asked for)
    if ((MediaQuery.maybeDisableAnimationsOf(context) ?? false) || ecoMode.value) {
      _later(widget.every ?? const Duration(seconds: 12));
      return;
    }
    if (_burst?.isAnimating ?? false) return;
    _next?.cancel();
    final first = _burst == null;
    burst.forward(from: 0);
    // the painter joins the first time
    if (first) setState(() {});
  }

  @override
  void dispose() {
    _next?.cancel();
    _burst?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.size,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          widget.child,
          if (_burst != null)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(key: const ValueKey('sparkles'), painter: _Burst(burst, context.pc.accent, widget.size / 40)),
                ),
              ),
            ),
        ]),
      );
}

/// The burst: each piece leaves the ring at its own moment, flies out, turns a little and fades.
class _Burst extends CustomPainter {
  _Burst(this.t, this.accent, this.scale) : super(repaint: t);
  final Animation<double> t;
  final Color accent;
  final double scale;

  static final _pieces = () {
    final r = math.Random(7);
    return [
      for (var i = 0; i < 11; i++)
        (
          angle: -math.pi / 2 + i / 11 * 2 * math.pi + (r.nextDouble() - .5) * .5,
          far: 13 + r.nextDouble() * 12,
          size: 3.2 + r.nextDouble() * 2.6,
          delay: i * .05 + r.nextDouble() * .06,
          spin: (r.nextBool() ? 1 : -1) * (.6 + r.nextDouble()),
          mark: i % 3 == 1,
          tint: i % 3,
        ),
    ];
  }();

  static Path _star(double s) => Path()
    ..moveTo(0, -s)
    ..quadraticBezierTo(0, 0, s, 0)
    ..quadraticBezierTo(0, 0, 0, s)
    ..quadraticBezierTo(0, 0, -s, 0)
    ..quadraticBezierTo(0, 0, 0, -s)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    if (v <= 0 || v >= 1) return;
    final center = size.center(Offset.zero), r0 = size.shortestSide / 2;
    // the pieces grow with the picture, but stay visible on a small one
    final k = scale.clamp(.75, 1.6).toDouble(), far = scale.clamp(.6, 1.8).toDouble();
    final tints = [const Color(0xFFFFB020), const Color(0xFFC026D3), accent];
    for (final p in _pieces) {
      final u = ((v - p.delay) / .55).clamp(0.0, 1.0);
      if (u <= 0 || u >= 1) continue;
      final fade = math.sin(math.pi * u), d = r0 + p.far * far * Curves.easeOutCubic.transform(u);
      final at = center + Offset(math.cos(p.angle), math.sin(p.angle)) * d;
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(p.spin * u);
      if (p.mark) {
        final s = p.size * 2.3 * k * (.7 + .3 * fade);
        canvas.translate(-s / 2, -s / 2);
        drawPeeraMark(canvas, s, opacity: fade);
      } else {
        final s = p.size * k * (.6 + .5 * fade);
        canvas.drawPath(_star(s), Paint()..color = tints[p.tint].withValues(alpha: fade));
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Burst o) => o.accent != accent || o.scale != scale;
}

/// The coloured ring round a small picture.
class RingPainter extends CustomPainter {
  const RingPainter({required this.accent, required this.width});
  final Color accent;
  final double width;
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 - width / 2;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    canvas.drawCircle(
      rect.center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = SweepGradient(colors: [accent, const Color(0xFFC026D3), const Color(0xFFFFB020), const Color(0xFF22C3A6), accent]).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(RingPainter o) => o.accent != accent || o.width != width;
}
