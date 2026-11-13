import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../people/person_screen.dart';
import '../settings/settings_screens.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'profile.dart';

String coinsText(int n) => grouped(n);

/// Your own page: the same as anyone's (picture, name, posts), with your coins under it and the settings in the bar
/// (signing out is there, as on the site).
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.me, required this.onSignOut, this.onRefresh});
  final Profile me;
  final Future<void> Function() onSignOut;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    // the newest sign-in profile (it changes on refresh); [me] is the first one
    final c = context.pc, me = context.me;
    return PersonScreen(
      uid: me.id,
      initial: me,
      ownTab: true,
      onRefresh: onRefresh,
      actions: [IconBtn('gear', label: 'პარამეტრები', onTap: () => openSettings(context))],
      extra: Column(children: [
        Padding(
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
              Expanded(
                child: Text('${coinsText(me.coins)} ქოინი',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: c.ink)),
              ),
              Text('ბალანსი', style: TextStyle(color: c.muted, fontSize: 13.5)),
            ]),
          ),
        ),
        if (context.app.push != null)
          ValueListenableBuilder<bool?>(
            valueListenable: context.app.push!.enabled,
            builder: (context, on, _) => on == false ? _NotificationsOff(onTap: context.app.push!.openSettings) : const SizedBox.shrink(),
          ),
      ]),
    );
  }
}

/// The phone does not let the app show notifications: say so, and open the setting.
class _NotificationsOff extends StatelessWidget {
  const _NotificationsOff({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          PIcon('bell', size: 24, color: c.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('შეტყობინებები გამორთულია', style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
              const SizedBox(height: 2),
              Text('ჩართე, რომ მიმოწერა და მოთხოვნები აპი დახურულზეც მოგივიდეს.', style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.35)),
            ]),
          ),
          TextButton(onPressed: onTap, child: const Text('ჩართვა')),
        ]),
      ),
    );
  }
}
