import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat/chats_tab.dart';
import '../data/api.dart';
import '../data/stores.dart';
import '../feed/feed_tab.dart';
import '../people/friends_tab.dart';
import '../profile/profile.dart';
import '../profile/profile_tab.dart';
import 'soon_screen.dart';
import 'tab_bar.dart';

/// The app after sign-in: seven tabs, each keeping its own stack of screens.
/// The back button undoes exactly one step and never drops out of the app by surprise (the site's rule):
/// first the open screen inside the tab, then back to the main tab, and on the main tab it asks for a second press.
/// Screens opened over the whole app (a conversation, a post) are closed first, by the app's own navigator.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.me, required this.api, required this.onSignOut, this.onRefresh, this.exit});
  final Profile me;
  final PeeraApi api;
  final Future<void> Function() onSignOut;
  final Future<void> Function()? onRefresh;

  /// how the app leaves on the second back press (the tests watch it)
  final VoidCallback? exit;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int index = 0;
  final _navs = List.generate(tabs.length, (_) => GlobalKey<NavigatorState>());
  final _feed = GlobalKey<FeedTabState>();
  DateTime? _armed;
  late final AppState app;

  static const exitHint = 'გასასვლელად კიდევ ერთხელ დააჭირე „უკან“';

  @override
  void initState() {
    super.initState();
    app = AppState(widget.api)..start();
  }

  @override
  void dispose() {
    app.dispose();
    super.dispose();
  }

  void select(int i) {
    if (i == index) {
      // tapping the open tab again goes to its first screen, and the feed to its top
      final nav = _navs[i].currentState;
      if (nav != null && nav.canPop()) {
        nav.popUntil((r) => r.isFirst);
      } else if (tabs[i].id == 'home') {
        _feed.currentState?.top();
      }
      return;
    }
    setState(() => index = i);
  }

  /// one back step; true when the app should close
  bool back() {
    final nav = _navs[index].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }
    if (index != 0) {
      setState(() => index = 0);
      return false;
    }
    final now = DateTime.now();
    if (_armed != null && now.difference(_armed!) < const Duration(seconds: 2)) return true;
    _armed = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(exitHint), duration: Duration(seconds: 2)));
    return false;
  }

  Widget _root(int i) {
    final t = tabs[i];
    switch (t.id) {
      case 'home':
        return FeedTab(key: _feed);
      case 'friends':
        return const FriendsTab();
      case 'chats':
        return const ChatsTab();
      case 'me':
        return ProfileTab(me: widget.me, onSignOut: widget.onSignOut, onRefresh: widget.onRefresh);
    }
    return SoonScreen(tab: t, me: widget.me);
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      app: app,
      me: widget.me,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (back()) (widget.exit ?? SystemNavigator.pop)();
        },
        child: Scaffold(
          body: IndexedStack(
            index: index,
            children: [
              for (var i = 0; i < tabs.length; i++)
                Navigator(
                  key: _navs[i],
                  onGenerateRoute: (s) => MaterialPageRoute(settings: s, builder: (_) => _root(i)),
                ),
            ],
          ),
          bottomNavigationBar: ListenableBuilder(
            listenable: Listenable.merge([app.chats, app.friends]),
            builder: (_, __) => PeeraTabBar(
              index: index,
              onTap: select,
              badges: {tabMid: app.chats.unread, 1: app.friends.incoming.length},
            ),
          ),
        ),
      ),
    );
  }
}
