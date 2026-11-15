// What moves over the Joker table: a card thrown from a hand to its place in the trick (an arc, a turn, a flip from its
// back, a shadow that shrinks as it lands), the trick swept to whoever took it, the piles of taken tricks, the trump
// lying on the felt, the deal, a word said over a player's head, and the little score notebook that opens up.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/icons.dart';
import 'cards.dart';
import 'engine.dart';
import 'sheets.dart';

/// A card moving once from [from] to [to] (its middle, in the box's points), turning from [turn0] to [turn1], growing from
/// [scale0] to [scale1]; [flip] shows its back first and turns it over in the air; [back] keeps it face down.
class CardFlight extends StatelessWidget {
  const CardFlight({
    super.key,
    required this.card,
    required this.from,
    required this.to,
    required this.w,
    this.turn0 = 0,
    this.turn1 = 0,
    this.scale0 = 1,
    this.scale1 = 1,
    this.lift = .22,
    this.flip = false,
    this.back = false,
    this.toBack = false,
    this.duration = const Duration(milliseconds: 480),
    this.delay = Duration.zero,
    this.glow = false,
    this.c4 = false,
    this.below,
    this.fadeOut = false,
  });
  final JCard? card;
  final Offset from, to;
  final double w, turn0, turn1, scale0, scale1, lift;
  final bool flip, back, toBack, glow, c4, fadeOut;
  final Duration duration, delay;

  /// a line under the card once it lies (a joker's call)
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final total = delay + duration, d0 = delay.inMicroseconds / math.max(1, total.inMicroseconds);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, v, _) {
        final t = d0 >= 1 ? 1.0 : ((v - d0) / (1 - d0)).clamp(0.0, 1.0);
        if (v < d0 && delay > Duration.zero) return const SizedBox.shrink();
        final e = Curves.easeOutCubic.transform(t);
        // a thrown card: up off the hand, over in an arc, down onto the felt
        final dist = (to - from).distance;
        final mid = Offset.lerp(from, to, .5)! - Offset(0, dist * lift);
        final p = _bez(from, mid, to, e);
        final air = math.sin(math.pi * t);
        final land = t < .86 ? 0.0 : math.sin((t - .86) / .14 * math.pi) * .035;
        final sc = (scale0 + (scale1 - scale0) * e) * (1 + air * .1 - land);
        final turn = turn0 + (turn1 - turn0) * e + air * .25 * (to.dx >= from.dx ? 1 : -1);
        final showBack = back || (flip && t < .5) || (toBack && t >= .5);
        final sx = flip || toBack ? (math.cos(math.pi * t)).abs().clamp(.04, 1.0) : 1.0;
        final h = w * cardRatio;
        final face = card == null || showBack ? CardBack(w: w) : CardFace(card!, w: w, glow: glow && t >= 1, c4: c4);
        return Stack(clipBehavior: Clip.none, children: [
          // the shadow on the felt: wide and faint in the air, close and sharp when it lies
          Positioned(
            left: p.dx - w * sc / 2 + 3 + air * 10,
            top: p.dy - h * sc / 2 + 5 + air * 22,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: turn,
                child: Container(
                  width: w * sc,
                  height: h * sc,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8 * w / 56),
                    boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, .42 - air * .22), blurRadius: 4 + air * 16)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: p.dx - w / 2,
            top: p.dy - h / 2,
            child: Opacity(
              opacity: fadeOut ? (1 - Curves.easeIn.transform((math.max(0.0, t - .7) / .3).clamp(0.0, 1.0))).clamp(0.0, 1.0) : 1,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationZ(turn)..multiply(Matrix4.diagonal3Values(sc * sx, sc, 1)),
                child: face,
              ),
            ),
          ),
          if (below != null && t >= 1)
            Positioned(left: p.dx - 70, width: 140, top: p.dy + h * sc / 2 + 2, child: Center(child: below!)),
        ]);
      },
    );
  }

  static Offset _bez(Offset a, Offset b, Offset c, double t) => a * ((1 - t) * (1 - t)) + b * (2 * (1 - t) * t) + c * (t * t);
}

/// the same small turn for a card every time it is drawn (its key), as a hand never lays two cards alike
double cardJitter(JCard c, [double amount = .07]) => ((c.key.hashCode % 1000) / 1000 - .5) * 2 * amount;

/// The tricks a player has taken this hand: face down, squared a little carelessly, the number beside them.
class PileView extends StatelessWidget {
  const PileView({super.key, required this.count, required this.w, this.label});
  final int count;
  final double w;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final h = w * cardRatio;
    return SizedBox(
      width: w + 34,
      height: h + 16,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        if (count == 0)
          Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8 * w / 56),
              border: Border.all(color: Colors.white.withValues(alpha: .14), width: 1.2),
            ),
          ),
        for (var i = 0; i < math.min(count, 6); i++)
          Transform.translate(
            offset: Offset(i * 1.2, -i * 1.6),
            child: Transform.rotate(angle: (i.isEven ? 1 : -1) * (.05 + i * .012), child: CardBack(w: w)),
          ),
        Positioned(
          right: 0,
          top: 0,
          child: TweenAnimationBuilder<double>(
            key: ValueKey(count),
            tween: Tween(begin: count == 0 ? 1 : 1.5, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              constraints: const BoxConstraints(minWidth: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: count > 0 ? goldTable : const Color(0xCC0B1424),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xCC0B1424), width: 1.5),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 4)],
              ),
              child: Text('$count',
                  textAlign: TextAlign.center,
                  style: numFont.copyWith(color: count > 0 ? const Color(0xFF1A1205) : lightMuted, fontSize: 13, fontWeight: FontWeight.w800, height: 1.15)),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The trump lying on the felt: the card turned up (or the suit chosen, or no trump), lit, its name beside it.
class TrumpOnTable extends StatelessWidget {
  const TrumpOnTable({super.key, required this.g, required this.w, required this.turn, this.c4 = false});
  final JokerGame g;
  final double w, turn;
  final bool c4;

  @override
  Widget build(BuildContext context) {
    final choosing = g.phase == 'trump';
    final Widget thing;
    if (choosing) {
      thing = CardBack(w: w);
    } else if (g.trumpCard != null) {
      thing = CardFace(g.trumpCard!, w: w, c4: c4);
    } else {
      // a suit chosen from the first three (no card turned), or no trump at all: a little brass plaque
      thing = Container(
        width: w,
        height: w * cardRatio,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8 * w / 56),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF6E0), Color(0xFFE9D7AE)]),
          border: Border.all(color: const Color(0xFFC9A24A), width: 2),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (g.trump != null) SuitMark(g.trump!, size: w * .55, color: suitInk(g.trump!, c4: c4)) else CustomPaint(size: Size.square(w * .5), painter: _NoTrump()),
          SizedBox(height: w * .06),
          Text(g.trump == null ? 'უკოზირო' : suitName[g.trump]!, style: TextStyle(color: cardInk, fontSize: w * .17, fontWeight: FontWeight.w800)),
        ]),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      TweenAnimationBuilder<double>(
        key: ValueKey('trump-${g.h}-${g.phase == 'trump'}'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) {
          // turned over where it lies, then a short glow
          final sx = math.cos((1 - v) * math.pi / 2);
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: goldTable.withValues(alpha: .55 * math.sin(v * math.pi)), blurRadius: 22, spreadRadius: 2)],
            ),
            child: Transform(alignment: Alignment.center, transform: Matrix4.rotationZ(turn)..multiply(Matrix4.diagonal3Values(sx.clamp(.05, 1.0), 1, 1)), child: child),
          );
        },
        child: thing,
      ),
      const SizedBox(height: 6),
      Container(
        key: const ValueKey('joker-trump'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xCC0B1424), borderRadius: BorderRadius.circular(8), border: Border.all(color: goldTable.withValues(alpha: .6))),
        child: Text(
          choosing ? 'კოზირი ირჩევა…' : (g.trump == null ? 'უკოზირო' : 'კოზირი: ${suitName[g.trump]}'),
          style: const TextStyle(color: goldTable, fontSize: 11.5, fontWeight: FontWeight.w800, height: 1.25),
        ),
      ),
    ]);
  }
}

class _NoTrump extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF8A93AE)
      ..strokeWidth = size.width * .12
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * .2, size.height * .2), Offset(size.width * .8, size.height * .8), p);
    canvas.drawLine(Offset(size.width * .8, size.height * .2), Offset(size.width * .2, size.height * .8), p);
  }

  @override
  bool shouldRepaint(_NoTrump o) => false;
}

/// The deal: backs flying from the dealer's hands to each seat, one round after another.
class DealFx extends StatelessWidget {
  const DealFx({super.key, required this.from, required this.to, required this.w, required this.rounds, required this.first});
  final Offset from;
  final List<Offset> to;
  final double w;
  final int rounds;

  /// the seat that gets the first card (the one after the dealer)
  final int first;

  @override
  Widget build(BuildContext context) {
    const each = Duration(milliseconds: 70);
    return IgnorePointer(
      child: Stack(clipBehavior: Clip.none, children: [
        for (var k = 0; k < rounds * 4; k++)
          CardFlight(
            key: ValueKey('deal-$k'),
            card: null,
            back: true,
            from: from,
            to: to[(first + k) % 4],
            w: w,
            scale0: .8,
            scale1: .9,
            lift: .12,
            turn0: -.4,
            turn1: (k.isEven ? .2 : -.2),
            delay: each * k,
            duration: const Duration(milliseconds: 340),
            fadeOut: true,
          ),
      ]),
    );
  }
}

/// A word said over a player's head ("2", "პასი"): it pops up, stays, and fades.
class SaidBubble extends StatelessWidget {
  const SaidBubble({super.key, required this.text, this.tail = 'down'});
  final String text;

  /// which way the little tail points: down, left, right
  final String tail;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 2600),
        builder: (_, v, child) {
          final pop = Curves.easeOutBack.transform((v / .12).clamp(0.0, 1.0));
          final out = v < .8 ? 1.0 : 1 - (v - .8) / .2;
          return Opacity(opacity: out.clamp(0.0, 1.0), child: Transform.scale(scale: .4 + .6 * pop, child: child));
        },
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cardPaper,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: Text(text, style: numFont.copyWith(color: cardInk, fontSize: 20, fontWeight: FontWeight.w900, height: 1.1)),
          ),
        ),
      );
}

/// The score notebook as it lies on the table: a little page with everyone's points, to be opened.
class MiniNotebook extends StatelessWidget {
  const MiniNotebook({super.key, required this.g, required this.names, required this.onTap});
  final JokerGame g;
  final List<String> names;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1B3A8C), red = Color(0xFFC62828);
    final best = g.score.reduce(math.max);
    return Tooltip(
      message: 'ქულების ფურცელი',
      child: GestureDetector(
        key: const ValueKey('joker-notebook'),
        onTap: onTap,
        child: Transform.rotate(
          angle: .045,
          child: Container(
            width: 84,
            padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF8EF),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(2, 4))],
            ),
            foregroundDecoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0x55C62828), width: 1))),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('რვეული', style: TextStyle(color: ink, fontSize: 9.5, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, height: 1.2)),
              Container(height: .8, color: const Color(0x551B3A8C), margin: const EdgeInsets.symmetric(vertical: 2)),
              for (var p = 0; p < 4; p++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: .5),
                  child: Row(children: [
                    Expanded(
                      child: Text(names[p], maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(color: ink, fontSize: 9.5, fontWeight: p == 0 ? FontWeight.w800 : FontWeight.w600, height: 1.25)),
                    ),
                    if (g.score[p] == best && best > 0) const Padding(padding: EdgeInsets.only(right: 2), child: Star(size: 8, color: Color(0xFFE0A21B))),
                    Text('${g.score[p]}', style: numFont.copyWith(color: g.score[p] < 0 ? red : ink, fontSize: 10, fontWeight: FontWeight.w800, height: 1.25)),
                  ]),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The notebook opened over the table: it grows out of where it lay, the whole sheet inside.
class NotebookOpen extends StatelessWidget {
  const NotebookOpen({super.key, required this.from, required this.g, required this.names, required this.onClose});
  final Rect from;
  final JokerGame g;
  final List<String> names;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final pad = MediaQuery.paddingOf(context);
        final to = Rect.fromLTRB(12, pad.top + 12, box.maxWidth - 12, box.maxHeight - pad.bottom - 12);
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) {
            // laid out at its full size all along and only drawn smaller, so nothing inside is ever squeezed
            final r = Rect.lerp(from, to, v)!;
            final mtx = Matrix4.translationValues(r.left - to.left, r.top - to.top, 0)
              ..multiply(Matrix4.diagonal3Values(r.width / to.width, r.height / to.height, 1))
              ..multiply(Matrix4.rotationZ(.045 * (1 - v)));
            return Stack(children: [
              Positioned.fill(
                child: GestureDetector(onTap: onClose, child: ColoredBox(color: Color.fromRGBO(3, 6, 12, .62 * v))),
              ),
              Positioned.fromRect(
                rect: to,
                child: Transform(transform: mtx, child: Opacity(opacity: (.3 + v).clamp(0.0, 1.0), child: child)),
              ),
            ]);
          },
          child: Material(
            color: const Color(0xFF121D33),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 12),
              child: Column(children: [
                Row(children: [
                  const Expanded(child: Text('ქულების ფურცელი', style: TextStyle(color: light, fontSize: 17, fontWeight: FontWeight.w800))),
                  IconButton(key: const ValueKey('joker-notebook-close'), tooltip: 'დახურვა', onPressed: onClose, icon: const PIcon('x', color: light)),
                ]),
                const SizedBox(height: 4),
                Expanded(child: Padding(padding: const EdgeInsets.only(right: 6), child: ScorePaper(g: g, names: names))),
              ]),
            ),
          ),
        );
      });
}
