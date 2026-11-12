import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../profile/profile.dart';
import '../profile/profile_tab.dart';
import 'soon_screen.dart';
import 'tab_bar.dart';

/// The app after sign-in: seven tabs, each keeping its own stack of screens.
/// The back button undoes exactly one step and never drops out of the app by surprise (the site's rule):
/// first the open screen inside the tab, then back to the main tab, and on the main tab it asks for a second press.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.me, required this.onSignOut, this.onRefresh, this.exit});
  final Profile me;
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
  DateTime? _armed;

  static const exitHint = 'გასასვლელად კიდევ ერთხელ დააჭირე „უკან“';

  void select(int i) {
    if (i == index) {
      // tapping the open tab again goes to its first screen
      _navs[i].currentState?.popUntil((r) => r.isFirst);
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
    if (t.id == 'me') return ProfileTab(me: widget.me, onSignOut: widget.onSignOut, onRefresh: widget.onRefresh);
    return SoonScreen(tab: t, me: widget.me);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
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
        bottomNavigationBar: PeeraTabBar(index: index, onTap: select),
      ),
    );
  }
}
