import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat/chat_screen.dart';
import '../clips/clips_tab.dart';
import '../chat/chats_tab.dart';
import '../data/api.dart';
import '../data/stores.dart';
import '../feed/feed_tab.dart';
import '../feed/post_screen.dart';
import '../dating/dating_tab.dart';
import '../joker/joker_tab.dart';
import '../joker/online_screen.dart';
import '../people/friends_tab.dart';
import '../profile/profile.dart';
import '../profile/profile_tab.dart';
import '../push/push.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'soon_screen.dart';
import 'tab_bar.dart';

/// The app after sign-in: seven tabs, each keeping its own stack of screens.
/// The back button undoes exactly one step and never drops out of the app by surprise (the site's rule):
/// first the open screen inside the tab, then back to the main tab, and on the main tab it asks for a second press.
/// Screens opened over the whole app (a conversation, a post) are closed first, by the app's own navigator.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.me, required this.api, required this.onSignOut, this.onRefresh, this.exit, this.push});
  final Profile me;
  final PeeraApi api;

  /// notifications to the phone (none in the tests)
  final PushService? push;
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
  final _scaffold = GlobalKey<ScaffoldState>();
  DateTime? _armed;
  late final AppState app;

  /// the one made with this shell (the sign-in may rebuild the widget with a fresh one; that one is not used)
  late final PushService? _push = widget.push;
  OverlayEntry? _banner;
  Timer? _bannerTimer;

  static const exitHint = 'გასასვლელად კიდევ ერთხელ დააჭირე „უკან“';

  @override
  void initState() {
    super.initState();
    app = AppState(widget.api)
      ..push = _push
      ..start();
    app.banner.addListener(_showBanner);
    _push?.start(app.api, onOpen: _openFromPush, onForeground: _pushWhileOpen);
  }

  /// a tapped notification: its conversation or post opens over the app, a friend request opens the friends tab
  void _openFromPush(PushTarget to) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = _scaffold.currentContext;
      if (ctx == null || !mounted) return;
      if (to.conv != null) {
        await openChat(ctx, to.conv!);
      } else if (to.post != null) {
        final p = await app.api.post(to.post!).catchError((_) => null);
        if (p == null || !ctx.mounted) return;
        await app.posts.load([p]);
        if (ctx.mounted) await openPage(ctx, PostScreen(post: p), full: true);
      } else if (to.jk != null) {
        final i = tabs.indexWhere((t) => t.id == 'joker');
        if (i >= 0 && i != index) {
          setState(() => index = i);
          app.tab.value = i;
        }
        await openJokerTable(ctx, to.jk!);
      } else if (to.tab != null) {
        final i = tabs.indexWhere((t) => t.id == to.tab);
        if (i >= 0 && i != index) {
          setState(() => index = i);
          app.tab.value = i;
        }
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// with the app open the phone shows nothing itself: messages already have their card at the top,
  /// the rest comes as a line at the bottom that opens what it is about
  void _pushWhileOpen(String title, String body, PushTarget? to) {
    if (!mounted || to?.conv != null || body.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 4),
        action: to == null ? null : SnackBarAction(label: 'ნახვა', onPressed: () => _openFromPush(to)),
      ));
  }

  Future<void> _signOut() async {
    await _push?.stop(app.api);
    await widget.onSignOut();
  }

  @override
  void dispose() {
    _hideBanner();
    _push?.dispose();
    app.banner.removeListener(_showBanner);
    app.dispose();
    super.dispose();
  }

  /// a message from a conversation that is not open: a card slides in at the top for a few seconds;
  /// a tap opens the conversation. It is not a screen, so the back button never has to close it.
  void _showBanner() {
    final b = app.banner.value, ctx = _scaffold.currentContext;
    if (b == null || ctx == null || !mounted) return;
    _hideBanner();
    final who = app.people[b.actor];
    if (who == null) return;
    _banner = OverlayEntry(
      builder: (_) => MessageBanner(
        who: who,
        text: b.text,
        onTap: () {
          _hideBanner();
          if (ctx.mounted) openChat(ctx, b.conv);
        },
        onClose: _hideBanner,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_banner!);
    _bannerTimer = Timer(const Duration(seconds: 4), _hideBanner);
  }

  void _hideBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    _banner?.remove();
    _banner = null;
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
    app.tab.value = i;
  }

  /// one back step; true when the app should close
  bool back() {
    final nav = _navs[index].currentState;
    if (nav != null && nav.canPop()) {
      // maybePop: a screen that asks before closing (a form with changes) is asked
      nav.maybePop();
      return false;
    }
    if (index != 0) {
      setState(() => index = 0);
      app.tab.value = 0;
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
      case 'clips':
        return const ClipsTab();
      case 'joker':
        return const JokerTab();
      case 'date':
        return const DatingTab();
      case 'me':
        return ProfileTab(me: widget.me, onSignOut: _signOut, onRefresh: widget.onRefresh);
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
          key: _scaffold,
          body: IndexedStack(
            index: index,
            children: [
              for (var i = 0; i < tabs.length; i++)
                // the tabs not on screen keep their place but do not animate
                TickerMode(
                  enabled: i == index,
                  child: Navigator(
                    key: _navs[i],
                    onGenerateRoute: (s) => MaterialPageRoute(settings: s, builder: (_) => _root(i)),
                  ),
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

/// The card at the top for a new message: who, what, tap to open; swipe it up to put it away.
class MessageBanner extends StatelessWidget {
  const MessageBanner({super.key, required this.who, required this.text, required this.onTap, required this.onClose});
  final Profile who;
  final String text;
  final VoidCallback onTap, onClose;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Positioned(
      left: 10,
      right: 10,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: -1, end: 0),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => FractionalTranslation(translation: Offset(0, v), child: child),
          child: Dismissible(
            key: const ValueKey('message-banner'),
            direction: DismissDirection.up,
            onDismissed: (_) => onClose(),
            child: Material(
              color: c.surface,
              elevation: 10,
              shadowColor: Colors.black45,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                  child: Row(children: [
                    Avatar(p: who, size: 42),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        NameLine(who, size: 14.5),
                        Text(text.isEmpty ? 'ახალი შეტყობინება' : text,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 14, height: 1.3)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
