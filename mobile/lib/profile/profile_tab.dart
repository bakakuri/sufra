import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../people/person_screen.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'profile.dart';

String coinsText(int n) => grouped(n);

/// Your own page: the same as anyone's (picture, name, posts), with your coins under it and "გასვლა" in the bar.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.me, required this.onSignOut, this.onRefresh});
  final Profile me;
  final Future<void> Function() onSignOut;
  final Future<void> Function()? onRefresh;

  Future<void> _out(BuildContext context) async {
    if (await confirm(context, title: 'გასვლა', text: 'ანგარიშიდან გახვალ ამ ტელეფონზე.', yes: 'გასვლა', danger: true)) await onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    // the newest sign-in profile (it changes on refresh); [me] is the first one
    final c = context.pc, me = context.me;
    return PersonScreen(
      uid: me.id,
      initial: me,
      ownTab: true,
      onRefresh: onRefresh,
      actions: [IconBtn('out', label: 'გასვლა', onTap: () => _out(context))],
      extra: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [c.gold.withValues(alpha: .2), c.gold.withValues(alpha: .07)]),
            border: Border.all(color: c.gold.withValues(alpha: .45)),
          ),
          child: Row(children: [
            PIcon('coin', size: 24, color: c.gold),
            const SizedBox(width: 10),
            Text('${coinsText(me.coins)} ქოინი', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: c.ink)),
            const Spacer(),
            Text('ბალანსი', style: TextStyle(color: c.muted, fontSize: 13.5)),
          ]),
        ),
      ),
    );
  }
}
