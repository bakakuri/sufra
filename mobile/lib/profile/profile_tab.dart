import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../people/person_screen.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import 'profile.dart';

/// Your own page: the same as anyone's, with my coins, "my space" and the settings button, as on the site. When the
/// phone keeps notifications off, a note under the coins says so.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.me, required this.onSignOut, this.onRefresh});
  final Profile me;
  final Future<void> Function() onSignOut;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    // the newest sign-in profile (it changes on refresh); [me] is the first one
    final me = context.me, push = context.app.push;
    return PersonScreen(
      uid: me.id,
      initial: me,
      ownTab: true,
      onRefresh: onRefresh,
      extra: push == null
          ? null
          : ValueListenableBuilder<bool?>(
              valueListenable: push.enabled,
              builder: (context, on, _) => on == false ? _NotificationsOff(onTap: push.openSettings) : const SizedBox.shrink(),
            ),
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
      padding: const EdgeInsets.only(top: 10),
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
