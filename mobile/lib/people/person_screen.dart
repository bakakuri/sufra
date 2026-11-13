import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/feed_tab.dart';
import '../profile/profile.dart';
import '../settings/edit_profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Someone's page: cover, picture, name, city, about, friends and posts, and what you can do — add, accept,
/// write. Your own page is the same, with [extra] under it (coins) and [actions] in the bar.
class PersonScreen extends StatefulWidget {
  const PersonScreen({super.key, required this.uid, this.initial, this.ownTab = false, this.extra, this.actions = const [], this.onRefresh});
  final String uid;

  /// also run on pull-to-refresh (your own page: the coins)
  final Future<void> Function()? onRefresh;
  final Profile? initial;
  final bool ownTab;
  final Widget? extra;
  final List<Widget> actions;

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  Profile? p;
  Counts? counts;
  List<Post>? posts;
  Object? error;
  bool _started = false, opening = false;

  @override
  void initState() {
    super.initState();
    p = widget.initial;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.uid == context.me.id) p = widget.ownTab ? context.me : (p ?? context.me);
    final f = context.app.friends;
    if (!f.loaded) f.load().catchError((_) {});
    _load();
  }

  @override
  void didUpdateWidget(PersonScreen old) {
    super.didUpdateWidget(old);
    if (widget.ownTab && p != null) p = _mergeMine(p!);
  }

  Future<void> _load() async {
    final app = context.app;
    try {
      final r = await Future.wait<Object?>([
        app.api.person(widget.uid),
        app.api.counts(widget.uid).then<Object?>((x) => x, onError: (_) => null),
        app.api.postsBy(widget.uid),
      ]);
      final list = r[2] as List<Post>;
      await app.posts.load(list);
      if (!mounted) return;
      setState(() {
        final got = r[0] as Profile?;
        if (got != null) {
          p = widget.ownTab ? _mergeMine(got) : got;
          app.people.put(got);
        }
        counts = r[1] as Counts?;
        posts = list;
        error = got == null && p == null ? 'not found' : null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  /// my own profile from the server, with the coins the sign-in already knows
  Profile _mergeMine(Profile x) {
    final m = context.me;
    return Profile(
      id: x.id,
      name: x.name,
      surname: x.surname,
      username: x.username,
      avatarUrl: x.avatarUrl,
      coverUrl: x.coverUrl,
      city: x.city,
      bio: x.bio,
      hue: x.hue,
      verified: x.verified,
      lastSeen: x.lastSeen,
      coins: m.coins,
      onboarded: true,
    );
  }

  Future<void> _edit() async {
    final saved = await openPage<bool>(context, const EditProfileScreen(), full: true);
    if (saved == true && mounted) _load();
  }

  Future<void> _message() async {
    if (opening) return;
    setState(() => opening = true);
    try {
      final conv = await context.app.api.startDm(widget.uid);
      if (!mounted) return;
      setState(() => opening = false);
      await openChat(context, conv);
    } catch (e) {
      if (!mounted) return;
      setState(() => opening = false);
      toast(context, errText(e));
    }
  }

  Widget _friendButton(BuildContext context) {
    final f = context.app.friends, c = context.pc, uid = widget.uid;
    final small = FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 14));
    final smallO = OutlinedButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 14));
    return switch (f.stateWith(uid)) {
      Friendship.none => FilledButton.icon(
          style: small,
          onPressed: () => attempt(context, () => f.add(uid)),
          icon: PIcon('uadd', size: 20, color: c.onAccent),
          label: const Text('დამატება'),
        ),
      Friendship.sent => OutlinedButton.icon(
          style: smallO,
          onPressed: () => showChoices(context, [SheetItem('x', 'მოთხოვნის გაუქმება', () => attempt(context, () => f.remove(uid)))]),
          icon: PIcon('check', size: 20, color: c.ink),
          label: const Text('გაგზავნილია'),
        ),
      Friendship.received => FilledButton.icon(
          style: small,
          onPressed: () => attempt(context, () => f.accept(uid)),
          icon: PIcon('ucheck', size: 20, color: c.onAccent),
          label: const Text('დადასტურება'),
        ),
      Friendship.friends => OutlinedButton.icon(
          style: smallO,
          onPressed: () => showChoices(context, [
            SheetItem('x', 'მეგობრობის გაუქმება', () async {
              if (await confirm(context, title: 'გავაუქმო მეგობრობა?', yes: 'გაუქმება', danger: true) && context.mounted) {
                await attempt(context, () => f.remove(uid));
              }
            }, danger: true),
          ]),
          icon: PIcon('ucheck', size: 20, color: c.vine),
          label: const Text('მეგობრები'),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, mine = widget.uid == context.me.id, who = p;
    final header = who == null
        ? const SizedBox(height: 240, child: Center(child: SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 2.4))))
        : _Header(p: who, counts: counts, mine: mine);
    return Scaffold(
      appBar: peeraBar(context, title: widget.ownTab ? 'პროფილი' : (who?.name ?? ''), actions: widget.actions),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([_load(), if (widget.onRefresh != null) widget.onRefresh!()]),
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          header,
          if (who != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: mine
                  ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                      key: const ValueKey('edit-profile'),
                      onPressed: _edit,
                      icon: PIcon('edit', size: 19, color: c.ink),
                      label: const Text('პროფილის რედაქტირება'),
                    )
                  : ListenableBuilder(
                      listenable: context.app.friends,
                      builder: (context, _) => Row(children: [
                        Expanded(child: _friendButton(context)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 14)),
                            onPressed: _message,
                            icon: opening
                                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : PIcon('msg', size: 20, color: c.ink),
                            label: const Text('მიწერა'),
                          ),
                        ),
                      ]),
                    ),
            ),
            if (widget.extra != null) widget.extra!,
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: Text('პოსტები', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: c.ink)),
            ),
          ],
          if (error != null && posts == null)
            Empty(icon: 'user', title: 'გვერდი ვერ ჩაიტვირთა', text: error is String ? 'ასეთი ადამიანი ვერ ვიპოვე' : errText(error!), action: 'ხელახლა ცდა', onAction: _load)
          else if (posts == null && who != null)
            const SkeletonPost()
          else if (posts != null && posts!.isEmpty)
            Empty(
              icon: 'edit',
              title: mine ? 'ჯერ არაფერი დაგიწერია' : 'ჯერ პოსტები არ არის',
              text: mine ? 'შენი პოსტები აქ გამოჩნდება.' : null,
            )
          else if (posts != null)
            PostsColumn(posts: posts!, onDeleted: (x) => setState(() => posts!.removeWhere((y) => y.id == x.id))),
        ]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.p, required this.counts, required this.mine});
  final Profile p;
  final Counts? counts;
  final bool mine;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, h = (p.hue % 360).toDouble();
    final seen = mine ? '' : lastSeenText(p.lastSeen);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 196,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 146,
            child: (p.coverUrl ?? '').isNotEmpty
                ? PImage(p.coverUrl!)
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [HSLColor.fromAHSL(1, h, .7, .62).toColor(), HSLColor.fromAHSL(1, (h + 50) % 360, .62, .42).toColor()],
                      ),
                    ),
                  ),
          ),
          Positioned(
            left: 16,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
              child: Avatar(p: p, size: 100, online: !mine && p.online),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NameLine(p, size: 23, weight: FontWeight.w800),
          if ((p.username ?? '').isNotEmpty || seen.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [if ((p.username ?? '').isNotEmpty) '@${p.username}', if (seen.isNotEmpty) seen].join(' · '),
                style: TextStyle(color: seen == 'ონლაინ' ? c.vine : c.muted, fontSize: 14.5),
              ),
            ),
          if ((p.city ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                PIcon('pin', size: 17, color: c.muted),
                const SizedBox(width: 4),
                Text(p.city!, style: TextStyle(color: c.muted, fontSize: 14.5)),
              ]),
            ),
          if ((p.bio ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(p.bio!.trim(), style: TextStyle(fontSize: 15, height: 1.45, color: c.ink)),
            ),
          if (counts != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(children: [
                _Count(counts!.friends, 'მეგობარი'),
                const SizedBox(width: 22),
                _Count(counts!.posts, 'პოსტი'),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

class _Count extends StatelessWidget {
  const _Count(this.n, this.label);
  final int n;
  final String label;
  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(children: [
        TextSpan(text: grouped(n), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        TextSpan(text: ' $label', style: TextStyle(color: context.pc.muted, fontSize: 14.5)),
      ]));
}
