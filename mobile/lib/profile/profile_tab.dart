import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'profile.dart';

String coinsText(int n) {
  final s = n.abs().toString(), b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '${n < 0 ? '−' : ''}$b';
}

/// The person's own page: picture, name, @username, city, coins; the full profile is on the site for now.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.me, required this.onSignOut, this.onRefresh});
  final Profile me;
  final Future<void> Function() onSignOut;
  final Future<void> Function()? onRefresh;

  Future<void> _out(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('გასვლა'),
        content: const Text('ანგარიშიდან გახვალ ამ ტელეფონზე.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('არა')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('გასვლა')),
        ],
      ),
    );
    if (yes == true) await onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final list = ListView(padding: const EdgeInsets.fromLTRB(16, 22, 16, 32), children: [
      Center(child: Avatar(p: me, size: 96)),
      const SizedBox(height: 14),
      Text(me.fullName.isEmpty ? 'უსახელო' : me.fullName,
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
      if ((me.username ?? '').isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('@${me.username}', textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 15)),
        ),
      if ((me.city ?? '').isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            PIcon('pin', size: 17, color: c.muted),
            const SizedBox(width: 4),
            Text(me.city!, style: TextStyle(color: c.muted, fontSize: 14.5)),
          ]),
        ),
      const SizedBox(height: 18),
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(colors: [c.gold.withValues(alpha: .2), c.gold.withValues(alpha: .08)]),
            border: Border.all(color: c.gold.withValues(alpha: .45)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            PIcon('coin', size: 22, color: c.gold),
            const SizedBox(width: 8),
            Text('${coinsText(me.coins)} ქოინი', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: c.ink)),
          ]),
        ),
      ),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: () => launchUrl(Uri.parse('$siteUrl/#me'), mode: LaunchMode.externalApplication),
        icon: PIcon('globe', size: 20, color: c.ink),
        label: const Text('სრული პროფილი საიტზე'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => _out(context),
        style: OutlinedButton.styleFrom(foregroundColor: c.nope),
        icon: PIcon('out', size: 20, color: c.nope),
        label: const Text('გასვლა'),
      ),
    ]);
    return Scaffold(
      appBar: peeraBar(context, title: 'პროფილი'),
      body: onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list),
    );
  }
}
