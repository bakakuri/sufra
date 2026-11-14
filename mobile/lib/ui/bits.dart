// Small pieces the board pages share (places, help, rides, the match room, jobs, the kitchen, the toast book): a row of
// chips that scrolls sideways, a little label, stars, a link opened outside, the map's tiles.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../map/live_map.dart';
import 'theme.dart';

/// a link opened in its own app (the browser, the phone, the map); the tests note it instead
Future<bool> Function(Uri) openExternal = (u) async {
  try {
    return await launchUrl(u, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
};

const osmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// the map's pictures, cached (and none in the tests)
class MapTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => mapTile(getTileUrl(coordinates, options));
}

TileLayer osmLayer() => TileLayer(urlTemplate: osmTiles, tileProvider: MapTiles(), userAgentPackageName: 'my.peera.app', maxNativeZoom: 19);

/// ★★★★☆
String starsText(num r) {
  final n = r.round().clamp(0, 5);
  return '${'★' * n}${'☆' * (5 - n)}';
}

/// "1.2 კმ", "400 მ"
String kmText(num? k) {
  if (k == null) return '';
  if (k < 1) return '${(k * 1000).round()} მ';
  return '${k < 10 ? k.toStringAsFixed(1) : k.round()} კმ';
}

/// 1,200
String thousands(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// A small label (the site's ptag): plain, accent ('ad'), warning, good.
class PTag extends StatelessWidget {
  const PTag(this.text, {super.key, this.kind = ''});
  final String text, kind;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final (bg, fg) = switch (kind) {
      'ad' => (c.accentSoft, c.accent),
      'warn' => (c.nope.withValues(alpha: .12), c.nope),
      'ok' => (c.vine.withValues(alpha: .14), c.vine),
      'blood' => (const Color(0xFFE11D48).withValues(alpha: .12), const Color(0xFFE11D48)),
      _ => (c.sunk, c.ink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// A row of choices that scrolls sideways; each is keyed '[prefix]-[value]'.
class ChipsBar extends StatelessWidget {
  const ChipsBar({super.key, required this.prefix, required this.items, required this.value, required this.onPick});
  final String prefix;
  final List<(String, String)> items;
  final String value;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return SizedBox(
      height: 48,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 6, 12, 4), children: [
        for (final (k, label) in items)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: ValueKey('$prefix-$k'),
              label: Text(label),
              selected: value == k,
              showCheckmark: false,
              selectedColor: c.accentSoft,
              side: BorderSide(color: value == k ? c.accent : c.line),
              onSelected: (_) => onPick(k),
            ),
          ),
      ]),
    );
  }
}

/// A heading between parts of a page.
class SecHead extends StatelessWidget {
  const SecHead(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 12, 6),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}
