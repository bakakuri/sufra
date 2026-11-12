import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../profile/profile.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'tab_bar.dart';

/// What each tab will hold in the app, in the words of the site; until it is built here, the site opens it.
const _what = <String, (String, String)>{
  'home': ('ფიდი', 'მეგობრებისა და კლასელების პოსტები, ისტორიები, სერვისები.'),
  'friends': ('მეგობრები', 'მეგობრები, მოთხოვნები, ხალხის ძებნა, ცოცხალი რუკა.'),
  'date': ('გაცნობა', 'ახალი ხალხი, მოწონებები და დამთხვევები.'),
  'chats': ('მიმოწერა', 'მესიჯები, ხმოვანი შეტყობინებები, ფოტოები და ზარები.'),
  'clips': ('კლიპები', 'მოკლე ვიდეოები ვერტიკალურად.'),
  'games': ('თამაშები', 'ჯოკერი, ნარდი, დომინო, შაში, ჭადრაკი და სხვა.'),
};

/// The first version of the app has its frame; the tab's own screens come in the next phases.
class SoonScreen extends StatelessWidget {
  const SoonScreen({super.key, required this.tab, required this.me});
  final PTab tab;
  final Profile me;

  Future<void> _open(BuildContext context) async {
    final ok = await launchUrl(Uri.parse('$siteUrl/#${tab.id}'), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('საიტი ვერ გაიხსნა')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final w = _what[tab.id] ?? (tab.label, '');
    final first = tab.id == 'home';
    return Scaffold(
      appBar: peeraBar(context, title: first ? null : tab.label),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 32), children: [
        if (first) ...[
          Text('გამარჯობა, ${me.name}!', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('ეს Peera-ს აპის პირველი ვერსიაა.', style: TextStyle(color: c.muted, fontSize: 15)),
          const SizedBox(height: 18),
        ],
        PCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(16)),
              child: PIcon(tab.icon, size: 28, color: c.accent),
            ),
            const SizedBox(height: 14),
            Text(w.$1, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(w.$2, style: TextStyle(color: c.muted, fontSize: 14.5, height: 1.45)),
            const SizedBox(height: 14),
            Text('აპში ეს ნაწილი მალე გამოჩნდება. მანამდე საიტზე გახსენი, იგივე ანგარიშით.',
                style: TextStyle(fontSize: 14.5, height: 1.45, color: c.ink)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _open(context),
              icon: PIcon('globe', size: 20, color: c.ink),
              label: const Text('საიტზე გახსნა'),
            ),
          ]),
        ),
      ]),
    );
  }
}
