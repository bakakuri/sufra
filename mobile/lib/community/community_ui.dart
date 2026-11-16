// What a group's and a page's screens share: the cover over the head with the square picture on its edge, the tabs
// with a sliding mark, the number tiles and the month's bars, the stars, and a cover photo chosen and uploaded.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/photos.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../settings/frame_photo.dart';
import '../ui/icons.dart';
import '../ui/motion.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'groups.dart';

/// A wide cover chosen, cut and uploaded: its address, or null.
Future<String?> pickCover(BuildContext context, String title) async {
  final app = context.app;
  final got = await photoSource(false);
  if (got.isEmpty || !context.mounted) return null;
  final f = await photoFrame(context, got.first, aspect: 16 / 9, max: 1400, title: title);
  if (f == null || !context.mounted) return null;
  toast(context, 'იტვირთება…');
  final m = await app.api.uploadPhoto(PreparedPhoto(f.bytes, f.w, f.h));
  return m.url;
}

/// The head of a group or a page: the cover (its photo, or the colour's soft waves), the square picture on its lower
/// edge, then the name and what is under it. Who keeps it changes the cover and the picture right here.
class CoverHead extends StatelessWidget {
  const CoverHead({
    super.key,
    required this.name,
    required this.hue,
    required this.title,
    required this.sub,
    this.cover,
    this.avatar,
    this.onCover,
    this.onAvatar,
    this.coverKey = 'cover-edit',
    this.picKey = 'cover-pic',
  });
  final String name;
  final int hue;
  final String? cover, avatar;

  /// the name's line (with its marks) and the line under it
  final Widget title, sub;

  /// changing the cover, the picture (for who keeps it); a tap on the picture otherwise opens it
  final VoidCallback? onCover, onAvatar;
  final String coverKey, picKey;

  @override
  Widget build(BuildContext context) {
    final c = context.pc, w = MediaQuery.sizeOf(context).width, h = (w / 2.5).clamp(128.0, 220.0);
    final base = HSLColor.fromAHSL(1, (hue % 360).toDouble(), .55, .5).toColor();
    final deep = HSLColor.fromAHSL(1, ((hue + 40) % 360).toDouble(), .6, .32).toColor();
    const pic = 92.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: h + pic / 2 + 4,
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: h,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.08, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, s, ch) => ClipRect(child: Transform.scale(scale: s, child: ch)),
              child: cover != null && cover!.startsWith('http')
                  ? PImage(cover!)
                  : DecoratedBox(
                      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [base, deep])),
                      child: CustomPaint(painter: _Waves(Colors.white.withValues(alpha: .12))),
                    ),
            ),
          ),
          // a soft shade at the bottom, so the picture sits well on any photo
          Positioned(
            left: 0,
            right: 0,
            top: h - 60,
            height: 60,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: .22)])),
              ),
            ),
          ),
          if (onCover != null)
            Positioned(
              right: 12,
              top: h - 48,
              child: Material(
                color: Colors.black.withValues(alpha: .45),
                shape: const StadiumBorder(),
                child: InkWell(
                  key: ValueKey(coverKey),
                  customBorder: const StadiumBorder(),
                  onTap: onCover,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      PIcon('camera', size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text('ქავერი', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    ]),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            top: h - pic / 2,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: .6, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.elasticOut,
              builder: (_, s, ch) => Transform.scale(scale: s, child: ch),
              child: GestureDetector(
                key: ValueKey(picKey),
                onTap: onAvatar,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(pic * .3),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: BoxPic(name: name, hue: hue, url: avatar, size: pic - 8),
                ),
              ),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Rise(order: 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 3), sub])),
      ),
    ]);
  }
}

class _Waves extends CustomPainter {
  _Waves(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    for (var i = 0; i < 4; i++) {
      final y = size.height * (.25 + i * .22);
      final path = Path()..moveTo(-20, y);
      for (double x = -20; x <= size.width + 40; x += 40) {
        path.quadraticBezierTo(x + 20, y + (i.isEven ? -14 : 14), x + 40, y);
      }
      canvas.drawPath(path, p);
    }
    canvas.drawCircle(Offset(size.width * .86, size.height * .22), size.height * .32, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Waves old) => old.color != color;
}

/// The tabs of a group's or a page's screen, with a mark that slides to the chosen one.
class SlideTabs extends StatelessWidget {
  const SlideTabs({super.key, required this.tabs, required this.value, required this.onChanged, this.prefix = 'tab'});

  /// id, icon, label
  final List<(String, String, String)> tabs;
  final String value;
  final ValueChanged<String> onChanged;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final c = context.pc, i = math.max(0, tabs.indexWhere((t) => t.$1 == value));
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      height: 44,
      decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(14)),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / tabs.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            left: i * w + 3,
            top: 3,
            width: w - 6,
            height: 38,
            child: Container(decoration: cardLook(context, radius: 11, raised: true)),
          ),
          Row(children: [
            for (final (id, icon, label) in tabs)
              Expanded(
                child: InkWell(
                  key: ValueKey('$prefix-$id'),
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => onChanged(id),
                  child: Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      PIcon(icon, size: 16, color: id == value ? c.accent : c.muted),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13.5, fontWeight: id == value ? FontWeight.w800 : FontWeight.w600, color: id == value ? c.ink : c.muted)),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

/// A number with what it counts, coming up from zero.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.label, required this.value, this.plus, this.order = 0});
  final String icon, label;
  final int value;

  /// how much it grew (shown green when above zero)
  final int? plus;
  final int order;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Rise(
      order: order,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: cardLook(context, radius: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(9)),
              child: PIcon(icon, size: 15, color: c.accent),
            ),
            const Spacer(),
            if ((plus ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: c.vine.withValues(alpha: .14), borderRadius: BorderRadius.circular(8)),
                child: Text('+$plus', style: TextStyle(color: c.vine, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
          ]),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text('${v.round()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.1)),
          ),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// Tiles two in a row.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles});
  final List<Widget> tiles;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          for (var i = 0; i < tiles.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: 10),
                Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink()),
              ]),
            ),
        ]),
      );
}

/// The month day by day ({d, n} each), as bars that grow in.
class DayBars extends StatelessWidget {
  const DayBars({super.key, required this.days, required this.title});
  final List<Map<String, dynamic>> days;
  final String title;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, top = days.fold<int>(1, (m, d) => math.max(m, asInt(d['n'])));
    final sum = days.fold<int>(0, (s, d) => s + asInt(d['n']));
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: cardLook(context, radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
          Text('$sum · 30 დღე', style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 84,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, t, __) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final d in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.2),
                    child: Container(
                      height: math.max(3, 84 * t * asInt(d['n']) / top),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: asInt(d['n']) > 0 ? LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [c.accent, c.accent.withValues(alpha: .55)]) : null,
                        color: asInt(d['n']) > 0 ? null : c.line,
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Stars, filled as far as [value] (out of five).
class Stars extends StatelessWidget {
  const Stars(this.value, {super.key, this.size = 16});
  final double value;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Padding(
          padding: const EdgeInsets.only(right: 1),
          child: Text(value >= i - .5 ? '★' : '☆', style: TextStyle(fontSize: size, height: 1, color: value >= i - .5 ? c.gold : c.muted.withValues(alpha: .6))),
        ),
    ]);
  }
}

/// Five stars to tap (1–5).
class StarPick extends StatelessWidget {
  const StarPick({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (var i = 1; i <= 5; i++)
        GestureDetector(
          key: ValueKey('star-$i'),
          onTap: () => onChanged(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedScale(
              scale: i <= value ? 1.12 : 1,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Text(i <= value ? '★' : '☆', style: TextStyle(fontSize: 40, height: 1, color: i <= value ? c.gold : c.muted)),
            ),
          ),
        ),
    ]);
  }
}

/// A pinned post's card on top of the posts: "📌 მიმაგრებული" and the post, or a line to open it.
class PinnedBox extends StatelessWidget {
  const PinnedBox({super.key, required this.child, this.onUnpin});
  final Widget child;
  final VoidCallback? onUnpin;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Rise(
      order: 2,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.gold.withValues(alpha: .55), width: 1.4),
          boxShadow: [BoxShadow(color: c.gold.withValues(alpha: .14), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            color: c.gold.withValues(alpha: .12),
            child: Row(children: [
              PIcon('pin', size: 16, color: c.gold),
              const SizedBox(width: 6),
              Expanded(child: Text('მიმაგრებული', style: TextStyle(color: c.gold, fontWeight: FontWeight.w800, fontSize: 13.5))),
              if (onUnpin != null)
                TextButton(key: const ValueKey('pin-off'), onPressed: onUnpin, style: TextButton.styleFrom(minimumSize: const Size(0, 30)), child: const Text('მოხსნა')),
            ]),
          ),
          child,
        ]),
      ),
    );
  }
}
