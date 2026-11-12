import 'package:flutter/material.dart';

import '../ui/icons.dart';
import '../ui/theme.dart';

/// The site's seven tabs, the same order and words; messages sit raised in the middle.
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
  PTab('games', 'თამაშები', 'dice'),
  PTab('me', 'პროფილი', 'user'),
];
const tabMid = 3;

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
          for (var i = 0; i < tabs.length; i++) Expanded(child: KeyedSubtree(key: ValueKey('tab-${tabs[i].id}'), child: i == tabMid ? _mid(context, i) : _tab(context, i))),
        ]),
      ),
    );
  }

  Widget _badge(BuildContext context, int i) {
    final n = badges[i] ?? 0;
    if (n <= 0) return const SizedBox.shrink();
    final c = context.pc;
    return Positioned(
      right: -8,
      top: -6,
      child: Container(
        constraints: const BoxConstraints(minWidth: 18),
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.nope, borderRadius: BorderRadius.circular(9), border: Border.all(color: c.surface, width: 2)),
        child: Text(n > 99 ? '99+' : '$n', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, height: 1)),
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
                child: Stack(clipBehavior: Clip.none, children: [PIcon(t.icon, size: 25, color: Colors.white, stroke: 2.1), _badge(context, i)]),
              ),
            ),
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
