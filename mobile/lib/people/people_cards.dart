// People shown as cards, as Facebook shows them: someone you may know with their picture large, their name, what
// you have in common and one button; the picture stands for the person when it is there, their letter on their colour
// when it is not.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../profile/profile.dart';
import '../ui/icons.dart';
import '../ui/motion.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// A person's picture filling a box (cut to fit), or their letter large on their colour.
class BigPhoto extends StatelessWidget {
  const BigPhoto({super.key, required this.p});
  final Profile p;
  @override
  Widget build(BuildContext context) {
    final h = (p.hue % 360).toDouble();
    final letter = p.name.trim().isEmpty ? '?' : p.name.trim().characters.first.toUpperCase();
    final plain = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-.8, -1),
          end: const Alignment(.8, 1),
          colors: [HSLColor.fromAHSL(1, h, .72, .6).toColor(), HSLColor.fromAHSL(1, (h + 40) % 360, .66, .36).toColor()],
        ),
      ),
      child: LayoutBuilder(
        builder: (_, box) => Center(
          child: Text(letter, style: TextStyle(color: Colors.white.withValues(alpha: .95), fontSize: box.maxHeight * .42, fontWeight: FontWeight.w800, height: 1)),
        ),
      ),
    );
    final url = p.avatarUrl;
    if (url == null || url.isEmpty) return plain;
    return Image(
      image: netImage(url),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => plain,
      frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : plain,
    );
  }
}

/// The people I said I do not want suggested (kept on the phone).
class HiddenSuggestions {
  static Set<String>? _ids;
  static const _key = 'sug_hidden';
  static Future<Set<String>> load() async {
    if (_ids != null) return _ids!;
    try {
      _ids = {...?(await SharedPreferences.getInstance()).getStringList(_key)};
    } catch (_) {
      _ids = {};
    }
    return _ids!;
  }

  static Future<void> hide(String id) async {
    final s = await load();
    s.add(id);
    try {
      await (await SharedPreferences.getInstance()).setStringList(_key, s.toList());
    } catch (_) {}
  }
}

/// Someone you may know: the picture large (a tap opens them), a cross to take them away, the name, friends in
/// common or their town, and the button (add; sent; friends; or confirm when they asked me).
class SuggestCard extends StatelessWidget {
  const SuggestCard({super.key, required this.s, required this.state, required this.onOpen, required this.onAdd, this.onHide});
  final Suggestion s;
  final Friendship state;
  final VoidCallback onOpen, onAdd;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    final c = context.pc, p = s.p;
    final sub = s.mutual > 0 ? '${s.mutual} საერთო მეგობარი' : ((p.city ?? '').isEmpty ? 'Peera-ზეა' : p.city!);
    final Widget button = switch (state) {
      Friendship.none => FilledButton.icon(
          key: ValueKey('sug-add-${p.id}'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: onAdd,
          icon: PIcon('uadd', size: 17, color: c.onAccent),
          label: const FittedBox(fit: BoxFit.scaleDown, child: Text('დამატება')),
        ),
      Friendship.received => FilledButton(
          key: ValueKey('sug-add-${p.id}'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: onAdd,
          child: const FittedBox(fit: BoxFit.scaleDown, child: Text('დადასტურება')),
        ),
      _ => Container(
          key: ValueKey('sug-done-${p.id}'),
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.accent.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              PIcon('check', size: 16, color: c.accent),
              const SizedBox(width: 5),
              Text(state == Friendship.friends ? 'მეგობარია' : 'გაგზავნილია', style: TextStyle(color: c.accent, fontWeight: FontWeight.w800, fontSize: 14)),
            ]),
          ),
        ),
    };
    return Container(
      key: ValueKey('sug-${p.id}'),
      clipBehavior: Clip.antiAlias,
      decoration: cardLook(context, radius: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            GestureDetector(onTap: onOpen, child: BigPhoto(p: p)),
            // a breath of shade at the bottom so the picture meets the white softly
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment(0, .35), end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x33000000)])),
              ),
            ),
            if (p.online)
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(color: const Color(0xCC0B1020), borderRadius: BorderRadius.circular(99)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF22C55E)),
                    SizedBox(width: 4),
                    Text('ონლაინ', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            if (onHide != null)
              Positioned(
                right: 6,
                top: 6,
                child: Material(
                  color: const Color(0x8C0B1020),
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: ValueKey('sug-hide-${p.id}'),
                    customBorder: const CircleBorder(),
                    onTap: onHide,
                    child: Padding(padding: const EdgeInsets.all(6), child: Semantics(label: 'დამალვა', child: const PIcon('x', size: 15, color: Colors.white))),
                  ),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GestureDetector(onTap: onOpen, child: NameLine(p, size: 15)),
            const SizedBox(height: 2),
            Row(children: [
              PIcon(s.mutual > 0 ? 'users' : 'pin', size: 13, color: c.muted),
              const SizedBox(width: 4),
              Expanded(child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5))),
            ]),
            const SizedBox(height: 9),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (ch, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .9, end: 1.0).animate(a), child: ch)),
              child: SizedBox(key: ValueKey(state), width: double.infinity, child: button),
            ),
          ]),
        ),
      ]),
    );
  }
}
