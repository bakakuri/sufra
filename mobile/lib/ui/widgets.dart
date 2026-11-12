import 'package:flutter/material.dart';

import '../profile/profile.dart';
import 'icons.dart';
import 'theme.dart';

/// A round picture: the photo when there is one, otherwise the first letter on the person's own colour (as on the site).
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.p, this.size = 40});
  final Profile p;
  final double size;

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
    if (url == null || url.isEmpty) return initials;
    return ClipOval(
      child: Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => initials),
    );
  }
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
PreferredSizeWidget peeraBar(BuildContext context, {String? title, List<Widget> actions = const []}) => AppBar(
      toolbarHeight: 60,
      titleSpacing: 16,
      title: title == null ? const PeeraLogo() : Text(title),
      actions: [...actions, const SizedBox(width: 8)],
    );

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
