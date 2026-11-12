import 'package:flutter/material.dart';

import '../profile/profile.dart';
import 'format.dart';
import 'icons.dart';
import 'net_image.dart';
import 'theme.dart';

/// A round picture: the photo when there is one, otherwise the first letter on the person's own colour (as on the site).
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.p, this.size = 40, this.online = false});
  final Profile p;
  final double size;

  /// a green dot at the corner
  final bool online;

  @override
  Widget build(BuildContext context) {
    final h = (p.hue % 360).toDouble();
    final letter = p.name.trim().isEmpty ? '?' : p.name.trim().characters.first.toUpperCase();
    final initials = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: const Alignment(-.6, -1),
          end: const Alignment(.6, 1),
          colors: [
            HSLColor.fromAHSL(1, h, .72, .58).toColor(),
            HSLColor.fromAHSL(1, (h + 38) % 360, .66, .38).toColor(),
          ],
        ),
      ),
      child: Text(letter, style: TextStyle(color: Colors.white, fontSize: size * .42, fontWeight: FontWeight.w700, height: 1)),
    );
    final url = p.avatarUrl;
    Widget pic = url == null || url.isEmpty
        ? initials
        : ClipOval(
            child: Image(
              image: netImage(url),
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => initials,
              frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : initials,
            ),
          );
    if (!online) return pic;
    final d = (size * .28).clamp(10.0, 16.0).toDouble();
    return SizedBox.square(
      dimension: size,
      child: Stack(clipBehavior: Clip.none, children: [
        pic,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: d,
            height: d,
            decoration: BoxDecoration(color: context.pc.vine, shape: BoxShape.circle, border: Border.all(color: context.pc.surface, width: 2)),
          ),
        ),
      ]),
    );
  }
}

/// The blue tick after a verified name.
class Verified extends StatelessWidget {
  const Verified({super.key, this.size = 15});
  final double size;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: context.pc.accent, shape: BoxShape.circle),
          child: PIcon('check', size: size * .78, color: Colors.white, stroke: 3),
        ),
      );
}

/// A name in bold with the tick when verified; one line.
class NameLine extends StatelessWidget {
  const NameLine(this.p, {super.key, this.size = 15, this.weight = FontWeight.w700, this.color});
  final Profile p;
  final double size;
  final FontWeight weight;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: Text(p.fullName.isEmpty ? 'უსახელო' : p.fullName,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: size, fontWeight: weight, color: color ?? context.pc.ink)),
        ),
        if (p.verified) Verified(size: size * .95),
      ]);
}

/// "Peera" beside the mark, in the site's condensed extra-bold.
class PeeraLogo extends StatelessWidget {
  const PeeraLogo({super.key, this.size = 30});
  final double size;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        PeeraMark(size: size * 1.24),
        SizedBox(width: size * .22),
        Text('Peera',
            style: TextStyle(
                fontFamily: fontLogo,
                fontFamilyFallback: fontFallback,
                fontWeight: FontWeight.w800,
                fontSize: size,
                height: 1,
                color: context.pc.accent,
                letterSpacing: -.3)),
      ]);
}

/// The top bar of a tab: the logo on the main tab, a title elsewhere.
PreferredSizeWidget peeraBar(BuildContext context, {String? title, Widget? titleWidget, List<Widget> actions = const []}) => AppBar(
      toolbarHeight: 60,
      titleSpacing: Navigator.of(context).canPop() ? 0 : 16,
      title: titleWidget ?? (title == null ? const PeeraLogo() : Text(title)),
      actions: [...actions, const SizedBox(width: 6)],
    );

/// A round button with one of the site's icons.
class IconBtn extends StatelessWidget {
  const IconBtn(this.icon, {super.key, required this.label, required this.onTap, this.color, this.size = 24, this.badge = 0});
  final String icon, label;
  final VoidCallback? onTap;
  final Color? color;
  final double size;
  final int badge;
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: label,
        onPressed: onTap,
        icon: Badge(
          isLabelVisible: badge > 0,
          label: Text(badge > 99 ? '99+' : '$badge'),
          backgroundColor: context.pc.nope,
          child: PIcon(icon, size: size, color: color ?? context.pc.ink),
        ),
      );
}

/// A plain card with room inside.
class PCard extends StatelessWidget {
  const PCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: padding, child: child));
}

/// Shown under a field or a form when something went wrong (or, in green, went right).
class Note extends StatelessWidget {
  const Note(this.text, {super.key, this.ok = false});
  final String text;
  final bool ok;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final col = ok ? c.vine : c.nope;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: col.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: col, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}

/// An empty list or a failed load: an icon, a line, and what to do.
class Empty extends StatelessWidget {
  const Empty({super.key, required this.icon, required this.title, this.text, this.action, this.onAction});
  final String icon, title;
  final String? text, action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
          child: PIcon(icon, size: 30, color: c.accent),
        ),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        if (text != null) ...[
          const SizedBox(height: 6),
          Text(text!, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 14.5, height: 1.4)),
        ],
        if (action != null) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20)),
            child: Text(action!),
          ),
        ],
      ]),
    );
  }
}

/// Grey shapes where a post will be while it loads.
class SkeletonPost extends StatelessWidget {
  const SkeletonPost({super.key, this.photo = true});
  final bool photo;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    Widget bar(double w, [double h = 12]) => Container(width: w, height: h, decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(6)));
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: c.sunk, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(120), const SizedBox(height: 6), bar(60, 10)]),
        ]),
        const SizedBox(height: 14),
        bar(double.infinity),
        const SizedBox(height: 8),
        bar(200),
        if (photo) ...[
          const SizedBox(height: 14),
          AspectRatio(aspectRatio: 1.3, child: Container(decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(12)))),
        ],
      ]),
    );
  }
}

/// Runs something that talks to the server; a failure is told in a line at the bottom.
Future<bool> attempt(BuildContext context, Future<void> Function() f) async {
  try {
    await f();
    return true;
  } catch (e) {
    if (context.mounted) toast(context, errText(e));
    return false;
  }
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
}

/// Asks yes or no; true when the person agrees.
Future<bool> confirm(BuildContext context, {required String title, String? text, required String yes, bool danger = false}) async {
  final c = context.pc;
  final r = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: text == null ? null : Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('არა')),
        TextButton(
          onPressed: () => Navigator.pop(d, true),
          style: danger ? TextButton.styleFrom(foregroundColor: c.nope) : null,
          child: Text(yes),
        ),
      ],
    ),
  );
  return r == true;
}

/// A choice sheet from the bottom: rows with an icon and words.
class SheetItem {
  const SheetItem(this.icon, this.label, this.onTap, {this.danger = false});
  final String icon, label;
  final VoidCallback onTap;
  final bool danger;
}

Future<void> showChoices(BuildContext context, List<SheetItem> items) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final it in items)
            ListTile(
              leading: PIcon(it.icon, size: 22, color: it.danger ? context.pc.nope : context.pc.ink),
              title: Text(it.label, style: TextStyle(fontWeight: FontWeight.w600, color: it.danger ? context.pc.nope : context.pc.ink)),
              onTap: () {
                Navigator.pop(s);
                it.onTap();
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
