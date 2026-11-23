// The backgammon board, drawn in code with the look of a warm wooden set under soft light: the frame, the felt, the
// points, the bar, the trays for the checkers borne off, the checkers with their shine and shadow, the dice. My
// checkers always move down to the bottom right; a step glides across the board, a hit checker hops to the bar, and
// the dice tumble when thrown.
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Step;

import 'engine.dart';

/// the colours of the set
const _frame = Color(0xFF7A4A24), _frameDark = Color(0xFF4A2A10), _felt = Color(0xFFF1E3C4), _red = Color(0xFFB8432E), _dark = Color(0xFF2C4A3A);
const _mine = Color(0xFFFBF7EE), _theirs = Color(0xFF2B2A33);

/// Where everything sits for a board of [size]: points, bar, trays; all in VIEW points (1–24 as I see them: my home
/// at the bottom right).
class BoardGeo {
  BoardGeo(this.size) {
    f = math.min(size.width, size.height) * .045;
    tray = size.width * .09;
    w = size.width - 2 * f - tray;
    h = size.height - 2 * f;
    barW = w * .085;
    pw = (w - barW) / 12;
    r = math.min(pw * .46, h * .07);
  }
  final Size size;
  late final double f, tray, w, h, barW, pw, r;

  Rect get inner => Rect.fromLTWH(f, f, w, h);
  Rect get barRect => Rect.fromLTWH(f + 6 * pw, f, barW, h);
  Rect get trayRect => Rect.fromLTWH(f + w + f * .4, f, tray - f * .4, h);

  /// the centre line of a point, and whether it hangs from the top
  (double, bool) point(int v) {
    final top = v > 12;
    int col;
    bool right;
    if (v <= 6) {
      col = 6 - v;
      right = true;
    } else if (v <= 12) {
      col = 12 - v;
      right = false;
    } else if (v <= 18) {
      col = v - 13;
      right = false;
    } else {
      col = v - 19;
      right = true;
    }
    return (f + col * pw + (right ? 6 * pw + barW : 0) + pw / 2, top);
  }

  double get gap => r * 1.85;

  /// the centre of checker [k] (0 the first) on view point [v]
  Offset checker(int v, int k) {
    final (x, top) = point(v);
    final kk = math.min(k, 4) + (k > 4 ? (k - 4) * .25 : 0);
    return Offset(x, top ? f + r + kk * gap : f + h - r - kk * gap);
  }

  /// the centre of checker [k] on the bar: mine below the middle, theirs above
  Offset barChecker(bool mine, int k) => Offset(f + 6 * pw + barW / 2, size.height / 2 + (mine ? 1 : -1) * (r * 1.6 + math.min(k, 3) * r * .6));

  /// the centre of a checker in the tray: mine at the bottom, theirs at the top, flat and stacked
  Offset trayAt(bool mine, int k) => Offset(trayRect.center.dx, mine ? f + h - r * .4 - k * r * .5 : f + r * .4 + k * r * .5);

  /// the view point under [o] (0 the bar; -2 the tray; -1 nothing)
  int hit(Offset o) {
    if (barRect.inflate(4).contains(o)) return bar;
    if (trayRect.inflate(6).contains(o)) return -2;
    if (!inner.contains(o)) return -1;
    final top = o.dy < size.height / 2;
    final right = o.dx > f + 6 * pw + barW / 2;
    final x = o.dx - f - (right ? 6 * pw + barW : 0);
    final col = (x / pw).floor().clamp(0, 5);
    if (top) return right ? 19 + col : 13 + col;
    return right ? 6 - col : 12 - col;
  }

  /// the centre of the dice of [mine] (my side of the board is the right half)
  Offset dice(bool mine, int i) => Offset(f + (mine ? 6 * pw + barW + 3 * pw : 3 * pw) + (i == 0 ? -r * 1.35 : r * 1.35), size.height / 2);
}

class NardiBoardView extends StatefulWidget {
  const NardiBoardView({
    super.key,
    required this.board,
    required this.me,
    required this.selected,
    required this.options,
    required this.onTap,
    required this.onTray,
    required this.dice,
    required this.left,
    required this.diceOf,
    required this.rolling,
    required this.stepTick,
    required this.lastStep,
    this.movable = const {},
    this.still = false,
  });
  final Board board;

  /// which player I am (0 or 1); the board is shown from my side
  final int me;

  /// the real point whose checker is picked up (null none; 0 the bar)
  final int? selected;

  /// the steps open from [selected]
  final List<Step> options;

  /// the real points that can be moved from now
  final Set<int> movable;
  final void Function(int realPoint) onTap;

  /// the tray tapped: bearing off
  final VoidCallback onTray;

  /// the dice shown (this turn's), the ones still to play, whose they are (0/1, −1 none)
  final List<int> dice, left;
  final int diceOf;

  /// the dice are being thrown
  final bool rolling;

  /// grows with every step; with [lastStep] it tells the board what to animate
  final int stepTick;
  final (int, Step)? lastStep;
  final bool still;

  @override
  State<NardiBoardView> createState() => _NardiBoardViewState();
}

class _NardiBoardViewState extends State<NardiBoardView> with TickerProviderStateMixin {
  late final AnimationController _fly = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final AnimationController _dice = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  (int, Step)? _anim;
  int _seed = 0;

  @override
  void initState() {
    super.initState();
    _fly.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _anim = null);
    });
    if (widget.rolling && !widget.still) _dice.forward(from: 0);
  }

  @override
  void didUpdateWidget(NardiBoardView old) {
    super.didUpdateWidget(old);
    if (old.stepTick != widget.stepTick && widget.lastStep != null && !widget.still) {
      _anim = widget.lastStep;
      _fly.forward(from: 0);
    }
    if (widget.rolling && !old.rolling && !widget.still) {
      _seed = DateTime.now().millisecondsSinceEpoch;
      _dice.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fly.dispose();
    _dice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final geo = BoardGeo(size);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final v = geo.hit(d.localPosition);
            if (v == -2) {
              widget.onTray();
            } else if (v >= 0) {
              widget.onTap(_real(v));
            }
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([_fly, _dice]),
            builder: (context, _) => CustomPaint(
              size: size,
              painter: _BoardPainter(
                geo: geo,
                board: widget.board,
                me: widget.me,
                selected: widget.selected,
                options: widget.options,
                movable: widget.movable,
                dice: widget.dice,
                left: widget.left,
                diceOf: widget.diceOf,
                roll: _dice.isAnimating ? _dice.value : 1,
                seed: _seed,
                anim: _anim,
                flyT: Curves.easeInOutCubic.transform(_fly.value),
              ),
            ),
          ),
        );
      });

  int _real(int v) => widget.me == 0 || v == bar ? v : 25 - v;
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.geo,
    required this.board,
    required this.me,
    required this.selected,
    required this.options,
    required this.movable,
    required this.dice,
    required this.left,
    required this.diceOf,
    required this.roll,
    required this.seed,
    required this.anim,
    required this.flyT,
  });
  final BoardGeo geo;
  final Board board;
  final int me;
  final int? selected;
  final List<Step> options;
  final Set<int> movable;
  final List<int> dice, left;
  final int diceOf;
  final double roll, flyT;
  final int seed;
  final (int, Step)? anim;

  /// a real point as I see it
  int _view(int p) => me == 0 || p == bar || p == 25 ? p : 25 - p;
  bool _isMine(int pl) => pl == me;

  @override
  void paint(Canvas canvas, Size size) {
    final g = geo;
    // ---- the frame ----
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(g.f * 1.4));
    canvas.drawRRect(outer.shift(Offset(0, g.f * .35)), Paint()..color = Colors.black.withValues(alpha: .25));
    canvas.drawRRect(
      outer,
      Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF9A6130), _frame, _frameDark]).createShader(Offset.zero & size),
    );
    // the grain
    final grain = Paint()
      ..color = Colors.black.withValues(alpha: .07)
      ..strokeWidth = 1;
    for (var y = 3.0; y < size.height; y += 7) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 2), grain);
    }
    // ---- the felt ----
    final inner = g.inner;
    canvas.drawRect(inner, Paint()..color = _felt);
    canvas.drawRect(
      inner,
      Paint()..shader = RadialGradient(center: Alignment.center, radius: 1.1, colors: [Colors.white.withValues(alpha: .18), Colors.transparent, Colors.black.withValues(alpha: .18)]).createShader(inner),
    );
    // ---- the points ----
    final ph = g.h * .42;
    for (var v = 1; v <= 24; v++) {
      final (x, top) = g.point(v);
      final dark = (v.isEven) ^ top;
      final c = dark ? _dark : _red;
      final tip = top ? g.f + ph : g.f + g.h - ph;
      final base = top ? g.f : g.f + g.h;
      final tri = Path()
        ..moveTo(x - g.pw * .47, base)
        ..lineTo(x + g.pw * .47, base)
        ..lineTo(x, tip)
        ..close();
      canvas.drawPath(tri, Paint()..shader = LinearGradient(begin: top ? Alignment.topCenter : Alignment.bottomCenter, end: top ? Alignment.bottomCenter : Alignment.topCenter, colors: [c, Color.lerp(c, Colors.white, .18)!]).createShader(tri.getBounds()));
      canvas.drawPath(
          tri,
          Paint()
            ..color = Colors.black.withValues(alpha: .12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .8);
      // a point I may move from, or may move to
      final real = me == 0 ? v : 25 - v;
      final canGo = options.any((s) => s.to == real);
      if (canGo || (selected == null && movable.contains(real))) {
        final y = top ? g.f + ph + g.r * .9 : g.f + g.h - ph - g.r * .9;
        canvas.drawCircle(Offset(x, y), g.r * (canGo ? .42 : .26), Paint()..color = (canGo ? const Color(0xFF22C3A6) : const Color(0xFFFFB020)).withValues(alpha: .95));
        if (canGo) canvas.drawCircle(Offset(x, y), g.r * .7, Paint()..color = const Color(0xFF22C3A6).withValues(alpha: .25));
      }
    }
    // off the board: the tray is a target when bearing off is open
    if (options.any((s) => s.to == offPoint(me))) {
      final t = g.trayRect;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(t.left, t.center.dy + 4, t.width, t.height / 2 - 4), Radius.circular(g.f * .5)), Paint()..color = const Color(0xFF22C3A6).withValues(alpha: .28));
    }
    // ---- the bar ----
    final br = g.barRect;
    canvas.drawRect(br, Paint()..shader = const LinearGradient(colors: [_frameDark, _frame, _frameDark]).createShader(br));
    if (selected == bar || (selected == null && movable.contains(bar))) {
      canvas.drawRRect(RRect.fromRectAndRadius(br.deflate(2), Radius.circular(g.f * .4)), Paint()..color = const Color(0xFFFFB020).withValues(alpha: .35));
    }
    // ---- the trays ----
    final tr = g.trayRect;
    canvas.drawRRect(RRect.fromRectAndRadius(tr, Radius.circular(g.f * .5)), Paint()..color = const Color(0xFF3A2010));
    canvas.drawRRect(RRect.fromRectAndRadius(tr.deflate(2), Radius.circular(g.f * .4)), Paint()..color = Colors.white.withValues(alpha: .05));
    for (final pl in [0, 1]) {
      final mine = _isMine(pl);
      for (var k = 0; k < board.offs[pl]; k++) {
        final o = g.trayAt(mine, k);
        final rr = RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: tr.width * .8, height: g.r * .42), Radius.circular(3));
        canvas.drawRRect(rr.shift(const Offset(0, 1.5)), Paint()..color = Colors.black.withValues(alpha: .35));
        canvas.drawRRect(rr, Paint()..color = mine ? _mine : _theirs);
      }
      if (board.offs[pl] > 0) {
        _label(canvas, '${board.offs[pl]}', Offset(tr.center.dx, mine ? tr.bottom - g.r * .5 - board.offs[pl] * g.r * .5 - g.r * .8 : tr.top + g.r * .5 + board.offs[pl] * g.r * .5 + g.r * .8),
            size: g.r * .95, color: Colors.white.withValues(alpha: .9));
      }
    }
    // ---- the checkers ----
    final (int, Step)? a = anim;
    for (var p = 1; p <= 24; p++) {
      final owner = board.owner(p);
      if (owner == null) continue;
      var n = board.cnt(p, owner);
      // the one on its way is not there yet
      if (a != null && a.$2.to == p && flyT < 1) n--;
      final mine = _isMine(owner);
      for (var k = 0; k < math.min(n, 5); k++) {
        _checker(canvas, g.checker(_view(p), k), mine, lifted: selected == p && k == math.min(n, 5) - 1);
      }
      if (n > 5) {
        _label(canvas, '$n', g.checker(_view(p), 4), size: g.r * 1.05, color: mine ? _theirs : _mine);
      }
    }
    for (final pl in [0, 1]) {
      final mine = _isMine(pl);
      var n = board.bars[pl];
      if (a != null && a.$2.hit && a.$1 != pl && flyT < 1) n--;
      for (var k = 0; k < math.min(n, 4); k++) {
        _checker(canvas, g.barChecker(mine, k), mine, lifted: selected == bar && mine && k == math.min(n, 4) - 1);
      }
      if (n > 4) _label(canvas, '$n', g.barChecker(mine, 3), size: g.r, color: mine ? _theirs : _mine);
    }
    // the one flying
    if (a != null && flyT < 1) {
      final (pl, s) = a;
      final mine = _isMine(pl);
      final from = s.from == bar ? g.barChecker(mine, board.bars[pl]) : g.checker(_view(s.from), board.cnt(s.from, pl));
      final to = s.to == offPoint(pl) ? g.trayAt(mine, board.offs[pl] - 1) : g.checker(_view(s.to), math.max(0, board.cnt(s.to, pl) - 1));
      final lift = math.sin(flyT * math.pi) * g.r * 1.2;
      final at = Offset.lerp(from, to, flyT)! - Offset(0, lift);
      _checker(canvas, at, mine, lifted: true, scale: 1 + math.sin(flyT * math.pi) * .18);
      // the hit checker is still on its point until the other lands, then hops to the bar
      if (s.hit) _checker(canvas, g.checker(_view(s.to), 0), !mine);
    }
    // ---- the dice ----
    if (dice.isNotEmpty && diceOf >= 0) {
      final mine = _isMine(diceOf);
      final rnd = math.Random(seed);
      for (var i = 0; i < dice.length; i++) {
        final o = g.dice(mine, i);
        final used = !_stillLeft(i);
        if (roll < 1) {
          // tumbling: random faces, a turn and a hop, settling with a little bounce
          final face = roll > .8 ? dice[i] : rnd.nextInt(6) + 1;
          final hop = math.sin(roll * math.pi) * g.r * 1.4;
          final spin = (1 - roll) * (i == 0 ? 5 : -4);
          _die(canvas, o - Offset((1 - roll) * (mine ? 1 : -1) * g.pw * 2.5, hop), g.r * 1.7, face, spin, used: false, scale: 1 + math.sin(roll * math.pi) * .25);
        } else {
          _die(canvas, o, g.r * 1.7, dice[i], (i == 0 ? -.18 : .14), used: used);
        }
      }
      // a double: how many of its four steps are left
      if (roll >= 1 && dice.length == 2 && dice[0] == dice[1] && left.isNotEmpty) {
        _label(canvas, '×${left.length}', g.dice(mine, 1) + Offset(g.r * 1.9, -g.r * 1.1), size: g.r * .9, color: _frameDark);
      }
    }
  }

  /// whether the die at [i] of [dice] is among the ones still to play (a double keeps both bright while any is left)
  bool _stillLeft(int i) {
    if (dice.length == 2 && dice[0] == dice[1]) return left.isNotEmpty;
    final d = dice[i];
    final before = dice.take(i).where((x) => x == d).length;
    return left.where((x) => x == d).length > before;
  }

  void _checker(Canvas canvas, Offset o, bool mine, {bool lifted = false, double scale = 1}) {
    final r = geo.r * scale;
    canvas.drawCircle(o + Offset(r * .12, r * (lifted ? .45 : .2)), r * (lifted ? 1.05 : 1), Paint()..color = Colors.black.withValues(alpha: lifted ? .3 : .22));
    final base = mine ? _mine : _theirs;
    canvas.drawCircle(o, r, Paint()..shader = RadialGradient(center: const Alignment(-.35, -.4), radius: .95, colors: [Color.lerp(base, Colors.white, mine ? .4 : .35)!, base, Color.lerp(base, Colors.black, mine ? .22 : .5)!], stops: const [0, .55, 1]).createShader(Rect.fromCircle(center: o, radius: r)));
    canvas.drawCircle(
        o,
        r * .62,
        Paint()
          ..color = (mine ? const Color(0xFFC9B48C) : const Color(0xFF6E6B7A)).withValues(alpha: .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .1);
    canvas.drawCircle(o + Offset(-r * .3, -r * .35), r * .18, Paint()..color = Colors.white.withValues(alpha: mine ? .9 : .5));
    if (lifted) {
      canvas.drawCircle(
          o,
          r * 1.08,
          Paint()
            ..color = const Color(0xFFFFB020)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * .16);
    }
  }

  void _die(Canvas canvas, Offset o, double s, int n, double angle, {required bool used, double scale = 1}) {
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.rotate(angle);
    canvas.scale(scale);
    final rr = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: s, height: s), Radius.circular(s * .22));
    canvas.drawRRect(rr.shift(Offset(s * .08, s * .14)), Paint()..color = Colors.black.withValues(alpha: .3));
    canvas.drawRRect(rr, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFFFFFFFF), const Color(0xFFF3EEE2), const Color(0xFFD9D1BF)]).createShader(rr.outerRect));
    const pips = {
      1: [(0.0, 0.0)],
      2: [(-.28, -.28), (.28, .28)],
      3: [(-.28, -.28), (0.0, 0.0), (.28, .28)],
      4: [(-.28, -.28), (.28, -.28), (-.28, .28), (.28, .28)],
      5: [(-.28, -.28), (.28, -.28), (0.0, 0.0), (-.28, .28), (.28, .28)],
      6: [(-.28, -.3), (.28, -.3), (-.28, 0.0), (.28, 0.0), (-.28, .3), (.28, .3)],
    };
    final pip = Paint()..color = n == 1 ? _red : const Color(0xFF1F1612);
    for (final (x, y) in pips[n] ?? const <(double, double)>[]) {
      canvas.drawCircle(Offset(x * s, y * s), s * .09, pip);
    }
    if (used) canvas.drawRRect(rr, Paint()..color = _felt.withValues(alpha: .55));
    canvas.restore();
  }

  void _label(Canvas canvas, String text, Offset at, {required double size, required Color color}) {
    final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_BoardPainter o) => true;
}
