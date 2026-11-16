// The small movements the pages share: things coming in one after another, a card giving a little under the finger,
// and the card's look (a soft shadow that lifts it off the page).
import 'package:flutter/material.dart';

import 'theme.dart';

/// Coming in: up a little and into view, a moment after the one before it ([order]: its place in the row).
class Rise extends StatelessWidget {
  const Rise({super.key, required this.order, required this.child, this.dy = 18, this.step = 50, this.ms = 380});
  final int order;
  final Widget child;
  final double dy;
  final int step, ms;
  @override
  Widget build(BuildContext context) {
    final wait = (order.clamp(0, 8)) * step, all = ms + wait;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: all),
      curve: Interval(wait / all, 1, curve: Curves.easeOutCubic),
      builder: (_, v, ch) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * dy), child: ch)),
      child: child,
    );
  }
}

/// A card that gives a little under the finger and springs back.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = .97});
  final Widget child;
  final VoidCallback? onTap, onLongPress;
  final double scale;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool down = false;
  void _set(bool v) {
    if (down != v && mounted) setState(() => down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(scale: down ? widget.scale : 1, duration: const Duration(milliseconds: 130), curve: Curves.easeOut, child: widget.child),
      );
}

/// A card lifted off the page: its colour, round corners, a hairline and a soft shadow (deeper in the dark).
BoxDecoration cardLook(BuildContext context, {double radius = 18, Color? color, bool raised = false}) {
  final c = context.pc, dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: color ?? c.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: c.line.withValues(alpha: dark ? .5 : .7)),
    boxShadow: [
      BoxShadow(color: const Color(0xFF141830).withValues(alpha: dark ? .38 : (raised ? .12 : .06)), blurRadius: raised ? 24 : 16, offset: Offset(0, raised ? 10 : 5)),
      BoxShadow(color: const Color(0xFF141830).withValues(alpha: dark ? .2 : .03), blurRadius: 3, offset: const Offset(0, 1)),
    ],
  );
}

/// A heading over a part of a page: a coloured mark, the words, and what stands at its end.
class SectionHead extends StatelessWidget {
  const SectionHead(this.text, {super.key, this.trailing, this.count, this.padding = const EdgeInsets.fromLTRB(16, 14, 12, 8)});
  final String text;
  final Widget? trailing;
  final int? count;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: padding,
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.accent, c.accent.withValues(alpha: .45)]), borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 9),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800))),
        if (count != null) ...[
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
            decoration: BoxDecoration(color: c.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
            child: Text('$count', style: TextStyle(color: c.accent, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
