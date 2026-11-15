// The Joker table's stage: a picture of the room and the table drawn for a 1080×1920 frame (9:16), laid over the
// screen as a film frame is (filling it, cut at the sides on a narrow phone), with its own light. Everything the game
// shows — the cards on the table, who said and took how much, my hand — is a separate layer over it, placed by the
// stage's own coordinates, so the room, the table and the camera never move during play.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// the room's slow life (the lamp's light, people breathing); off in the tests so a screen can settle
bool jokerAmbient = true;

/// A picture on the stage: where it lies in stage pixels.
class SceneLayer {
  const SceneLayer(this.asset, this.rect, {this.seat, this.front = false});
  final String asset;
  final Rect rect;

  /// the seat whose person this is (it breathes and leans with them)
  final int? seat;

  /// over the table (their hands and cards), not behind it
  final bool front;
}

/// Where a seat's things are, in stage pixels.
class SeatSpot {
  const SeatSpot({required this.hand, required this.plate, required this.pile, required this.slot, required this.turn, required this.pivot});

  /// where the cards are held: a card played leaves from here, a dealt one arrives here
  final Offset hand;

  /// the middle of the name plate
  final Offset plate;

  /// the tricks taken, face down
  final Offset pile;

  /// the card in the trick, and how it lies turned
  final Offset slot;
  final double turn;

  /// what a person turns about when breathing and leaning (the middle of where they sit)
  final Offset pivot;
}

class SceneSpec {
  const SceneSpec({
    required this.size,
    required this.layers,
    required this.seats,
    required this.trump,
    required this.trumpTurn,
    required this.felt,
    required this.feltR,
    required this.cardW,
    required this.focus,
  });
  final Size size;
  final List<SceneLayer> layers;

  /// 0 is me (at the bottom), 1 left, 2 across, 3 right
  final List<SeatSpot> seats;
  final Offset trump;
  final double trumpTurn;

  /// the felt's middle and half-sizes (the lamp's pool of light)
  final Offset felt;
  final Size feltR;

  /// a card on the table, in stage pixels
  final double cardW;

  /// the stage point kept on screen when a wide screen cuts the top and the bottom
  final double focus;
}

const _s = 'assets/joker/scene';

/// The table seen from above and behind my seat.
const jokerScene = SceneSpec(
  size: Size(1080, 1920),
  layers: [
    SceneLayer('$_s/room.jpg', Rect.fromLTWH(0, 0, 1080, 1920)),
    SceneLayer('$_s/table.webp', Rect.fromLTWH(16, 517, 1049, 847)),
  ],
  seats: [
    SeatSpot(hand: Offset(540, 1790), plate: Offset(540, 1560), pile: Offset(700, 1215), slot: Offset(540, 1036), turn: -.03, pivot: Offset(540, 1700)),
    SeatSpot(hand: Offset(60, 860), plate: Offset(206, 905), pile: Offset(230, 1120), slot: Offset(392, 905), turn: .13, pivot: Offset(80, 1000)),
    SeatSpot(hand: Offset(540, 470), plate: Offset(540, 405), pile: Offset(745, 640), slot: Offset(540, 770), turn: .04, pivot: Offset(540, 520)),
    SeatSpot(hand: Offset(1020, 860), plate: Offset(874, 905), pile: Offset(850, 1120), slot: Offset(688, 905), turn: -.12, pivot: Offset(1000, 1000)),
  ],
  // up on the felt, where neither my choices nor the plates ever cover it
  trump: Offset(330, 640),
  trumpTurn: -.18,
  felt: Offset(540, 905),
  feltR: Size(468, 352),
  cardW: 150,
  focus: 905,
);

/// The stage laid over a box: filling it, its middle kept in the middle, cut at the sides (a narrow phone) or at the top
/// and the bottom around [SceneSpec.focus] (a wide one).
class StageMap {
  StageMap(this.spec, Size box)
      : scale = math.max(box.width / spec.size.width, box.height / spec.size.height),
        box = box {
    dx = (box.width - spec.size.width * scale) / 2;
    final h = spec.size.height * scale;
    if (h <= box.height + .5) {
      dy = (box.height - h) / 2;
    } else {
      // keep the felt a little above the middle, never showing past the picture
      dy = (box.height * .48 - spec.focus * scale).clamp(box.height - h, 0.0);
    }
  }
  final SceneSpec spec;
  final Size box;
  final double scale;
  late final double dx, dy;

  Offset at(Offset p) => Offset(dx + p.dx * scale, dy + p.dy * scale);
  Rect rect(Rect r) => Rect.fromLTWH(dx + r.left * scale, dy + r.top * scale, r.width * scale, r.height * scale);
  double len(double v) => v * scale;

  /// a card on the table, in screen points
  double get cardW => spec.cardW * scale;
  Offset seatHand(int p) => at(spec.seats[p].hand);
  Offset slot(int p) => at(spec.seats[p].slot);
  Offset pile(int p) => at(spec.seats[p].pile);
  Offset plate(int p) => at(spec.seats[p].plate);
}

/// The stage: its pictures, its light; [active] is the seat whose turn it is (its person is lit and leans in);
/// [overlay] is everything the game puts over it.
class JokerStage extends StatefulWidget {
  const JokerStage({super.key, this.spec = jokerScene, this.active, required this.overlay});
  final SceneSpec spec;
  final int? active;
  final Widget Function(BuildContext context, StageMap map) overlay;
  @override
  State<JokerStage> createState() => _JokerStageState();
}

class _JokerStageState extends State<JokerStage> with SingleTickerProviderStateMixin {
  AnimationController? _life;

  @override
  void initState() {
    super.initState();
    if (jokerAmbient) _life = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }

  @override
  void dispose() {
    _life?.dispose();
    super.dispose();
  }

  /// a person breathing and, on their turn, leaning in to the table a little
  Widget _person(SceneLayer l, StageMap m, Widget img) {
    final seat = l.seat!, pivot = widget.spec.seats[seat].pivot, on = widget.active == seat;
    final r = m.rect(l.rect), pv = m.at(pivot) - r.topLeft;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: on ? 1 : 0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, lean, child) {
        final life = _life;
        Widget at(double t) {
          final ph = seat * 1.7;
          final breathe = math.sin((t * 6 + ph) * 2 * math.pi) * .006;
          final sway = math.sin((t * 2 + ph * .6) * 2 * math.pi) * .004;
          final mtx = Matrix4.translationValues(pv.dx, pv.dy, 0)
            ..multiply(Matrix4.rotationZ(sway))
            ..multiply(Matrix4.diagonal3Values(1 + lean * .018, 1 + breathe + lean * .018, 1))
            ..multiply(Matrix4.translationValues(-pv.dx, -pv.dy + lean * m.len(6), 0));
          return Transform(transform: mtx, child: child);
        }

        return life == null ? at(0) : AnimatedBuilder(animation: life, builder: (_, __) => at(life.value));
      },
      child: img,
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    return LayoutBuilder(builder: (context, box) {
      final m = StageMap(spec, box.biggest);
      Widget pic(SceneLayer l) {
        final r = m.rect(l.rect);
        Widget img = Image.asset(l.asset, width: r.width, height: r.height, fit: BoxFit.fill, filterQuality: FilterQuality.medium, gaplessPlayback: true);
        if (l.seat != null) img = _person(l, m, img);
        return Positioned.fromRect(rect: r, child: img);
      }

      final behind = [for (final l in spec.layers) if (!l.front) l], front = [for (final l in spec.layers) if (l.front) l];
      final felt = m.at(spec.felt), fr = Size(m.len(spec.feltR.width), m.len(spec.feltR.height));
      return Stack(clipBehavior: Clip.hardEdge, children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFF07090D))),
        for (final l in behind) pic(l),
        // the lamp's pool of light on the felt, breathing very slightly like a real bulb
        Positioned.fromRect(
          rect: Rect.fromCenter(center: felt, width: fr.width * 2.3, height: fr.height * 2.3),
          child: IgnorePointer(
            child: _life == null
                ? const _Pool(1)
                : AnimatedBuilder(
                    animation: _life!,
                    builder: (_, __) {
                      final t = _life!.value * 2 * math.pi;
                      return _Pool(1 + .035 * math.sin(t * 7) + .02 * math.sin(t * 17 + 1));
                    },
                  ),
          ),
        ),
        for (final l in front) pic(l),
        // the film: the corners darker, a breath of warm light from the lamp up on the right
        const Positioned.fill(child: IgnorePointer(child: _Vignette())),
        Positioned.fill(child: widget.overlay(context, m)),
      ]);
    });
  }
}

class _Pool extends StatelessWidget {
  const _Pool(this.k);
  final double k;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [Color.fromRGBO(255, 214, 150, .16 * k), Color.fromRGBO(255, 190, 120, .06 * k), const Color(0x00FFB070)],
            stops: const [0, .45, 1],
          ),
        ),
      );
}

class _Vignette extends StatelessWidget {
  const _Vignette();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.05),
            radius: 1.05,
            colors: [Color(0x00000000), Color(0x00000000), Color(0x8C000000)],
            stops: [0, .62, 1],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(1.1, -1.1),
              radius: 1.2,
              colors: [Color(0x26FFC27A), Color(0x00FFC27A)],
            ),
          ),
        ),
      );
}
