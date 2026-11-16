import 'package:flutter/material.dart';

import '../ui/icons.dart';
import '../ui/theme.dart';

/// The app's tabs. The feed and my profile have no button on the bar: the logo leads to the feed from every page and
/// my picture on the feed opens my profile; the bar keeps the other five, messages raised in the middle.
class PTab {
  const PTab(this.id, this.label, this.icon);
  final String id, label, icon;
}

const tabs = [
  PTab('home', 'მთავარი', 'home'),
  PTab('friends', 'მეგობრები', 'users'),
  PTab('date', 'გაცნობა', 'heart'),
  PTab('chats', 'მიმოწერა', 'msg'),
  PTab('clips', 'კლიპები', 'clips'),
  PTab('joker', 'ჯოკერი', 'cards'),
  PTab('me', 'პროფილი', 'user'),
];
const tabMid = 3;

/// the tabs with a button on the bar, in its order
const barTabs = ['friends', 'date', 'chats', 'clips', 'joker'];

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
        height: 62,
        child: Row(children: [
          for (final id in barTabs)
            Expanded(
              child: Builder(builder: (context) {
                final i = tabs.indexWhere((t) => t.id == id);
                return KeyedSubtree(key: ValueKey('tab-$id'), child: i == tabMid ? _mid(context, i) : _tab(context, i));
              }),
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

  Widget _tab(BuildContext context, int i) {
    final c = context.pc, on = i == index, t = tabs[i], col = on ? c.accent : c.muted;
    return Semantics(
      button: true,
      selected: on,
      label: t.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => onTap(i),
        radius: 34,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: on ? c.accentSoft : Colors.transparent, borderRadius: BorderRadius.circular(14)),
            child: Stack(clipBehavior: Clip.none, children: [PIcon(t.icon, size: 24, color: col, stroke: on ? 2.1 : 1.8), _badge(context, i)]),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(t.label, maxLines: 1, style: TextStyle(fontFamily: fontLogo, fontFamilyFallback: fontFallback, fontSize: 11.5, fontWeight: on ? FontWeight.w700 : FontWeight.w400, color: col, height: 1.1)),
          ),
        ]),
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(i),
        // the round button stands out above the bar; the bar keeps its height
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
          Positioned(
            top: -26,
            child: AnimatedScale(
              scale: on ? 1 : .92,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Container(
                width: 60,
                height: 60,
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
                child: PIcon(t.icon, size: 25, color: Colors.white, stroke: 2.1),
              ),
            ),
          ),
          // the number sits on the round button's rim, top right, clear of the icon
          Positioned(
            top: -26,
            child: SizedBox(width: 60, height: 60, child: Stack(clipBehavior: Clip.none, children: [_badge(context, i, right: -1, top: -1, size: 20)])),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 7,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(t.label, maxLines: 1, style: TextStyle(fontFamily: fontLogo, fontFamilyFallback: fontFallback, fontSize: 11.5, fontWeight: FontWeight.w700, color: c.accent, height: 1.1)),
            ),
          ),
        ]),
      ),
    );
  }
}
