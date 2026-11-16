import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// The app's seven tabs. The bar shows them as pictures only (the words are their tooltips): the feed is the Peera
/// mark, my profile is my picture in a ring, the rest are the bar's own icons; messages sit raised in the middle.
class PTab {
  const PTab(this.id, this.label, this.icon);
  final String id, label, icon;
}

const tabs = [
  PTab('home', 'მთავარი', 'home'),
  PTab('friends', 'მეგობრები', 'friends'),
  PTab('date', 'გაცნობა', 'heart'),
  PTab('chats', 'მიმოწერა', 'chat'),
  PTab('clips', 'კლიპები', 'clips'),
  // Joker for now; more games will join it
  PTab('joker', 'თამაშები', 'games'),
  PTab('me', 'პროფილი', 'me'),
];
const tabMid = 3;

/// the little stars and Peera marks that scatter from my picture now and then (the tests turn them off: they wait
/// for a still screen)
bool barSparkles = true;

class PeeraTabBar extends StatelessWidget {
  const PeeraTabBar({super.key, required this.index, required this.onTap, this.badges = const {}});
  final int index;
  final ValueChanged<int> onTap;
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: 60,
        child: Row(children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: KeyedSubtree(
                key: ValueKey('tab-${tabs[i].id}'),
                child: i == tabMid
                    ? _mid(context, i)
                    : tabs[i].id == 'me'
                        ? _cell(context, i, _MeCell(on: i == index))
                        : _cell(context, i, _icon(context, i)),
              ),
            ),
        ]),
      ),
    );
  }

  /// the red number: on a tab's icon, or on the round button's rim (not over its icon)
  Widget _badge(BuildContext context, int i, {double right = -8, double top = -6, double size = 18}) {
    final n = badges[i] ?? 0;
    if (n <= 0) return const SizedBox.shrink();
    final c = context.pc;
    return Positioned(
      right: right,
      top: top,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(n),
        tween: Tween(begin: .5, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          key: ValueKey('badge-${tabs[i].id}'),
          constraints: BoxConstraints(minWidth: size),
          height: size,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.nope, borderRadius: BorderRadius.circular(size / 2), border: Border.all(color: c.surface, width: 2)),
          child: Text(n > 99 ? '99+' : '$n', style: TextStyle(color: Colors.white, fontSize: size * .58, fontWeight: FontWeight.w800, height: 1)),
        ),
      ),
    );
  }

  /// the picture of a tab: the Peera mark for the feed, the bar's icon for the rest
  Widget _icon(BuildContext context, int i) {
    final c = context.pc, on = i == index, t = tabs[i];
    final pic = t.id == 'home'
        ? AnimatedOpacity(opacity: on ? 1 : .62, duration: const Duration(milliseconds: 200), child: const PeeraMark(size: 30))
        : BarIcon(t.icon, on: on, color: on ? c.accent : c.muted, detailColor: c.surface, size: 27);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: on ? c.accentSoft : Colors.transparent, borderRadius: BorderRadius.circular(16)),
      child: Stack(clipBehavior: Clip.none, children: [pic, _badge(context, i)]),
    );
  }

  Widget _cell(BuildContext context, int i, Widget pic) {
    final on = i == index, t = tabs[i];
    return Semantics(
      button: true,
      selected: on,
      label: t.label,
      excludeSemantics: true,
      child: Tooltip(
        message: t.label,
        child: InkResponse(
          onTap: () => onTap(i),
          radius: 30,
          child: Center(
            child: AnimatedScale(scale: on ? 1.06 : 1, duration: const Duration(milliseconds: 220), curve: Curves.easeOutBack, child: pic),
          ),
        ),
      ),
    );
  }

  Widget _mid(BuildContext context, int i) {
    final c = context.pc, on = i == index, t = tabs[i];
    return Semantics(
      button: true,
      selected: on,
      label: t.label,
      excludeSemantics: true,
      child: Tooltip(
        message: t.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(i),
          // the round button stands out above the bar; the bar keeps its height
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            Positioned(
              top: -22,
              child: AnimatedScale(
                scale: on ? 1.04 : .96,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.lerp(c.accent, Colors.white, .18)!, c.accent, Color.lerp(c.accent, const Color(0xFFC026D3), .4)!],
                      stops: const [0, .45, 1],
                    ),
                    border: Border.all(color: c.bg, width: 5),
                    boxShadow: [BoxShadow(color: c.accent.withValues(alpha: .28), blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: BarIcon('chat', on: true, color: Colors.white, detailColor: c.accent, size: 28),
                ),
              ),
            ),
            // the number sits on the round button's rim, top right, clear of the icon
            Positioned(
              top: -22,
              child: SizedBox(width: 62, height: 62, child: Stack(clipBehavior: Clip.none, children: [_badge(context, i, right: -1, top: -1, size: 20)])),
            ),
          ]),
        ),
      ),
    );
  }
}

/// My picture in a ring, and now and then a little burst of stars and Peera marks scattering from it.
class _MeCell extends StatefulWidget {
  const _MeCell({required this.on});
  final bool on;
  @override
  State<_MeCell> createState() => _MeCellState();
}

class _MeCellState extends State<_MeCell> with SingleTickerProviderStateMixin {
  late final burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _later(const Duration(seconds: 4));
    });
  Timer? _next;

  @override
  void initState() {
    super.initState();
    if (barSparkles) _later(const Duration(milliseconds: 900));
  }

  @override
  void didUpdateWidget(_MeCell old) {
    super.didUpdateWidget(old);
    // opening my profile sets one off at once
    if (widget.on && !old.on) _go();
  }

  void _later(Duration d) {
    _next?.cancel();
    _next = Timer(d, _go);
  }

  void _go() {
    if (!mounted || !barSparkles || burst.isAnimating) return;
    _next?.cancel();
    // a phone asked for less movement gets none
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    burst.forward(from: 0);
  }

  @override
  void dispose() {
    _next?.cancel();
    burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, on = widget.on;
    const ring = 40.0;
    return SizedBox.square(
      dimension: ring,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(child: CustomPaint(key: const ValueKey('me-sparkles'), painter: _Sparkles(burst, c.accent))),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: ring,
          height: ring,
          padding: EdgeInsets.all(on ? 2.6 : 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(colors: [c.accent, const Color(0xFFC026D3), const Color(0xFFFFB020), const Color(0xFF22C3A6), c.accent]),
            boxShadow: on ? [BoxShadow(color: c.accent.withValues(alpha: .35), blurRadius: 10)] : const [],
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.surface),
            child: FittedBox(child: Avatar(p: context.me, size: 32)),
          ),
        ),
      ]),
    );
  }
}

/// The burst: each piece leaves the ring at its own moment, flies out, turns a little and fades.
class _Sparkles extends CustomPainter {
  _Sparkles(this.t, this.accent) : super(repaint: t);
  final Animation<double> t;
  final Color accent;

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
    final tints = [const Color(0xFFFFB020), const Color(0xFFC026D3), accent];
    for (final p in _pieces) {
      final u = ((v - p.delay) / .55).clamp(0.0, 1.0);
      if (u <= 0 || u >= 1) continue;
      final fade = math.sin(math.pi * u), d = r0 + p.far * Curves.easeOutCubic.transform(u);
      final at = center + Offset(math.cos(p.angle), math.sin(p.angle)) * d;
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(p.spin * u);
      if (p.mark) {
        final s = p.size * 2.3 * (.7 + .3 * fade);
        canvas.translate(-s / 2, -s / 2);
        drawPeeraMark(canvas, s, opacity: fade);
      } else {
        final s = p.size * (.6 + .5 * fade);
        canvas.drawPath(_star(s), Paint()..color = tints[p.tint].withValues(alpha: fade));
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Sparkles o) => o.accent != accent;
}
