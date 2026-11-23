// The games tab: a big card for backgammon and Joker together, a card for each, and a table with friends. Each game
// opens its own page (against the computer, with people, the rules); more games will join them here.
import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../joker/cards.dart';
import '../joker/engine.dart';
import '../joker/joker_tab.dart';
import '../nardi/nardi_tab.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';

class GamesTab extends StatelessWidget {
  const GamesTab({super.key});

  Future<void> _joker(BuildContext context, {bool friends = false}) => openPage(context, JokerTab(friends: friends));
  Future<void> _nardi(BuildContext context) => openPage(context, const NardiTab());

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 28), children: [
        Row(children: [
          BarIcon('games', on: true, color: c.accent, detailColor: c.surface, size: 28),
          const SizedBox(width: 10),
          const Text('თამაშები', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 14),
        _Hero(onPlay: () => _nardi(context)),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: _GameCard(
                key: const ValueKey('games-nardi'),
                title: 'ითამაშე\nნარდი',
                art: const _NardiArt(),
                onTap: () => _nardi(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GameCard(
                key: const ValueKey('games-joker'),
                title: 'გამოსცადე\nჯოკერი',
                art: const _CardsArt(),
                onTap: () => _joker(context),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        _FriendsBanner(onTap: () => _joker(context, friends: true)),
      ]),
    );
  }
}

const _deep = Color(0xFF2A1A6E), _mid = Color(0xFF4B32C8), _bright = Color(0xFF6D4AE8);

/// The wide card at the top: the table and its players, a backgammon board on it, and the button to play.
class _Hero extends StatelessWidget {
  const _Hero({required this.onPlay});
  final VoidCallback onPlay;
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('games-hero'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_deep, _mid, _bright]),
        boxShadow: [BoxShadow(color: _mid.withValues(alpha: .3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(children: [
        SizedBox(
          height: 196,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/joker/table.jpg', fit: BoxFit.cover, alignment: const Alignment(0, -.85)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, .5, 1],
                  colors: [Color(0x332A1A6E), Color(0x002A1A6E), _mid],
                ),
              ),
            ),
            const Positioned(left: 0, right: 0, bottom: 4, child: Center(child: SizedBox(width: 210, height: 96, child: _Tilted(child: _Board())))),
            const Positioned(right: 34, bottom: 20, child: _Dice(a: 6, b: 3, size: 24)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(children: [
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('ონლაინ ნარდი და ჯოკერი',
                  maxLines: 1, style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, height: 1.15, letterSpacing: .2)),
            ),
            const SizedBox(height: 6),
            Text('ითამაშე  •  გაერთე  •  დაუკავშირდი', style: TextStyle(color: Colors.white.withValues(alpha: .82), fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _Pill(key: const ValueKey('games-play'), label: 'თამაშის დაწყება', arrow: true, big: true, onTap: onPlay),
          ]),
        ),
      ]),
    );
  }
}

/// A game's card: its picture, its name, "დაწყება".
class _GameCard extends StatelessWidget {
  const _GameCard({super.key, required this.title, required this.art, required this.onTap});
  final String title;
  final Widget art;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_mid, _bright]),
          boxShadow: [BoxShadow(color: _mid.withValues(alpha: .25), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 112,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(center: Alignment(0, -.2), radius: 1, colors: [Color(0xFF7C5CF0), _deep]),
                  ),
                  child: art,
                ),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, height: 1.2)),
              const Spacer(),
              const SizedBox(height: 12),
              _Pill(label: 'დაწყება', onTap: onTap),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "With friends it is more fun": a Joker table for friends.
class _FriendsBanner extends StatelessWidget {
  const _FriendsBanner({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors: [_mid, _bright, Color(0xFF9B5CF0)]),
        ),
        child: InkWell(
          key: const ValueKey('games-friends'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .18)),
                child: const BarIcon('friends', on: true, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('დაუკავშირდი მეგობრებს', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('ერთად უფრო სახალისოა!', style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 13.5)),
                ]),
              ),
              const PIcon('chev', size: 22, color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A rounded light button on the purple cards.
class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label, required this.onTap, this.arrow = false, this.big = false});
  final String label;
  final VoidCallback onTap;
  final bool arrow, big;
  @override
  Widget build(BuildContext context) {
    final h = big ? 52.0 : 40.0;
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(h / 2),
          gradient: const LinearGradient(colors: [Color(0xFF8B6CFF), Color(0xFF6A4BEA)]),
          border: Border.all(color: Colors.white.withValues(alpha: .22)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(h / 2),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: big ? 26 : 14),
            child: Row(mainAxisSize: big ? MainAxisSize.min : MainAxisSize.max, mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label,
                      style: TextStyle(color: Colors.white, fontSize: big ? 17 : 14.5, fontWeight: FontWeight.w800)),
                ),
              ),
              if (arrow) ...[const SizedBox(width: 10), const PIcon('arrow', size: 22, color: Colors.white, stroke: 2.2)],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Backgammon's picture: the board leaning back, two dice before it.
class _NardiArt extends StatelessWidget {
  const _NardiArt();
  @override
  Widget build(BuildContext context) => const Stack(children: [
        Positioned(left: 8, right: 8, bottom: 6, top: 30, child: _Tilted(child: _Board())),
        Positioned(right: 12, bottom: 10, child: _Dice(a: 5, b: 2, size: 20)),
      ]);
}

/// Joker's picture: a fan of cards, the joker last.
class _CardsArt extends StatelessWidget {
  const _CardsArt();
  @override
  Widget build(BuildContext context) {
    final cards = [JCard.parse('s14'), JCard.parse('h13'), JCard.parse('d12'), const JCard.joker(1)];
    const w = 48.0;
    return Stack(alignment: Alignment.bottomCenter, clipBehavior: Clip.none, children: [
      for (var i = 0; i < cards.length; i++)
        Positioned(
          bottom: -w * .35,
          child: Transform.rotate(
            angle: (i - 1.5) * .3,
            alignment: const Alignment(0, 1.6),
            child: DecoratedBox(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3))]),
              child: CardFace(cards[i], w: w),
            ),
          ),
        ),
    ]);
  }
}

/// A board leaning back, as if lying on a table.
class _Tilted extends StatelessWidget {
  const _Tilted({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0022)
          ..rotateX(-.78),
        child: child,
      );
}

class _Board extends StatelessWidget {
  const _Board();
  @override
  Widget build(BuildContext context) => const CustomPaint(painter: _BoardPainter(), size: Size.infinite);
}

/// A backgammon board seen from above: the wooden frame, the two halves with their points, the bar, a few checkers.
class _BoardPainter extends CustomPainter {
  const _BoardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(h * .08));
    canvas.drawRRect(outer.shift(Offset(0, h * .05)), Paint()..color = const Color(0x55000000));
    canvas.drawRRect(
      outer,
      Paint()..shader = const LinearGradient(colors: [Color(0xFFA0582A), Color(0xFF6B3413), Color(0xFF8C4A20)]).createShader(Offset.zero & size),
    );
    final m = h * .08, bar = w * .06;
    final fieldW = (w - 2 * m - bar) / 2, fieldH = h - 2 * m;
    final felt = Paint()..color = const Color(0xFFF2E3C2);
    final reds = Paint()..color = const Color(0xFFB3261E), darks = Paint()..color = const Color(0xFF203A2C);
    final tw = fieldW / 6, th = fieldH * .42;
    for (var side = 0; side < 2; side++) {
      final left = m + side * (fieldW + bar);
      final field = Rect.fromLTWH(left, m, fieldW, fieldH);
      canvas.drawRRect(RRect.fromRectAndRadius(field, Radius.circular(h * .03)), felt);
      for (var i = 0; i < 6; i++) {
        final x = left + i * tw;
        final top = Path()
          ..moveTo(x, m)
          ..lineTo(x + tw, m)
          ..lineTo(x + tw / 2, m + th)
          ..close();
        final bottom = Path()
          ..moveTo(x, m + fieldH)
          ..lineTo(x + tw, m + fieldH)
          ..lineTo(x + tw / 2, m + fieldH - th)
          ..close();
        canvas.drawPath(top, i.isEven ? reds : darks);
        canvas.drawPath(bottom, i.isEven ? darks : reds);
      }
    }
    // checkers: (half, point, from the top?, how many, white?)
    final r = tw * .42;
    void stack(int side, int point, bool top, int n, bool white) {
      final cx = m + side * (fieldW + bar) + point * tw + tw / 2;
      for (var k = 0; k < n; k++) {
        final cy = top ? m + r + k * r * 1.9 : m + fieldH - r - k * r * 1.9;
        final o = Offset(cx, cy);
        canvas.drawCircle(o.translate(0, r * .18), r, Paint()..color = const Color(0x44000000));
        canvas.drawCircle(o, r, Paint()..color = white ? const Color(0xFFFDFBF6) : const Color(0xFF2A2A2E));
        canvas.drawCircle(
          o,
          r * .62,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * .14
            ..color = white ? const Color(0xFFD9CFBF) : const Color(0xFF55555C),
        );
      }
    }

    stack(0, 0, true, 3, true);
    stack(0, 4, false, 2, false);
    stack(1, 1, true, 2, false);
    stack(1, 5, false, 3, true);
    stack(1, 3, false, 1, false);
  }

  @override
  bool shouldRepaint(_BoardPainter o) => false;
}

/// Two dice, a little turned.
class _Dice extends StatelessWidget {
  const _Dice({required this.a, required this.b, this.size = 22});
  final int a, b;
  final double size;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Transform.rotate(angle: -.25, child: _Die(a, size)),
        SizedBox(width: size * .25),
        Transform.rotate(angle: .2, child: _Die(b, size)),
      ]);
}

class _Die extends StatelessWidget {
  const _Die(this.n, this.size);
  final int n;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF8),
          borderRadius: BorderRadius.circular(size * .22),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 5, offset: Offset(0, 3))],
        ),
        child: CustomPaint(painter: _PipsPainter(n)),
      );
}

class _PipsPainter extends CustomPainter {
  const _PipsPainter(this.n);
  final int n;
  static const _at = {
    1: [(.5, .5)],
    2: [(.27, .27), (.73, .73)],
    3: [(.27, .27), (.5, .5), (.73, .73)],
    4: [(.27, .27), (.73, .27), (.27, .73), (.73, .73)],
    5: [(.27, .27), (.73, .27), (.5, .5), (.27, .73), (.73, .73)],
    6: [(.27, .25), (.73, .25), (.27, .5), (.73, .5), (.27, .75), (.73, .75)],
  };
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = n == 1 ? const Color(0xFFB3261E) : const Color(0xFF1F1612);
    for (final (x, y) in _at[n] ?? const <(double, double)>[]) {
      canvas.drawCircle(Offset(size.width * x, size.height * y), size.width * .09, p);
    }
  }

  @override
  bool shouldRepaint(_PipsPainter o) => o.n != n;
}
