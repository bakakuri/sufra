// The site's bar at the top of every page: the logo and name, search, notifications, who looked at me, all the
// services, making something. On the tabs it stands over them all and opens its pages inside the open tab; on a page
// opened over the whole app it stands over that page.
import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../home/services.dart';
import '../notes/notes_screen.dart';
import '../people/person_screen.dart';
import '../people/profile_parts.dart';
import '../people/search_screen.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class PeeraTopBar extends StatelessWidget {
  const PeeraTopBar({super.key, this.inShell = false});

  /// over the tabs (its pages open inside the open tab), not over one page
  final bool inShell;

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app;
    BuildContext at() => inShell ? (app.tabContext?.call() ?? context) : context;
    Future<void> write({bool photos = false, bool poll = false}) async {
      final w = app.write;
      // the feed writes it, so the new post stands at its top
      if (w != null) return w(photos: photos, poll: poll);
      await openPage(at(), ComposeScreen(startWithPhotos: photos, startWithPoll: poll), full: true);
    }

    return Material(
      color: c.surface,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line.withValues(alpha: .6)))),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 60,
            child: Row(children: [
              const SizedBox(width: 14),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    key: const ValueKey('top-logo'),
                    // on the tabs the logo leads to the feed
                    onTap: inShell ? () => app.goTab?.call('home') : null,
                    child: const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: PeeraLogo()),
                  ),
                ),
              ),
              IconBtn('search', key: const ValueKey('top-search'), label: 'ძებნა', onTap: () => openPage(at(), const SearchScreen())),
              ValueListenableBuilder<int>(
                valueListenable: app.unreadNotes,
                builder: (_, n, __) => IconBtn('bell', key: const ValueKey('bell'), label: 'შეტყობინებები', badge: n, onTap: () => openNotes(at())),
              ),
              ValueListenableBuilder<int>(
                valueListenable: app.newGuests,
                builder: (_, n, __) => IconBtn(
                  'eye',
                  key: const ValueKey('guests'),
                  label: 'სტუმრები',
                  badge: n,
                  onTap: () {
                    app.newGuests.value = 0;
                    final ctx = at();
                    guestsSheet(ctx, open: (uid) => openPage(ctx, PersonScreen(uid: uid)), invisible: context.me.guest);
                  },
                ),
              ),
              IconBtn('grid', key: const ValueKey('services'), label: 'სერვისები', onTap: () => servicesMenu(at())),
              IconBtn('plus', key: const ValueKey('create'), label: 'შექმნა', onTap: () => createMenu(at(), write: write)),
              const SizedBox(width: 4),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A page opened over the whole app, with the bar over it (the page keeps its own bar with its back arrow below).
class WithTopBar extends StatelessWidget {
  const WithTopBar({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
        color: context.pc.bg,
        child: Column(children: [
          const PeeraTopBar(),
          Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
        ]),
      );
}
