// The notifications (the bell): the latest sixty, the new ones marked, each opening what it is about — in the app
// where the app has it, otherwise on the site. Seen as soon as the list is opened, as on the site.
import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../data/models.dart';
import '../dating/dating_tab.dart';
import '../data/stores.dart';
import '../feed/post_screen.dart';
import '../home/services.dart';
import '../joker/online_screen.dart';
import '../people/albums.dart';
import '../people/coins.dart';
import '../people/family.dart';
import '../people/friends_tab.dart';
import '../people/my_space.dart';
import '../people/verify.dart';
import '../people/person_screen.dart';
import '../profile/profile.dart';
import '../settings/settings_screens.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'note_groups.dart';
import 'note_text.dart';

Future<void> openNotes(BuildContext context) => openPage(context, const NotesScreen(), full: true);

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Notif>? list;
  Object? error;
  Set<int> fresh = {};
  bool _started = false;

  /// the filter on top, and the lines of one person's many things that are open
  String filter = 'all';
  final expanded = <int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final app = context.app;
    try {
      final r = await app.api.notes();
      await app.people.ensure([for (final n in r) if (n.actor != null) n.actor!]);
      if (!mounted) return;
      final unread = [for (final n in r) if (!n.read) n.id];
      setState(() {
        list = r;
        error = null;
        fresh = {...fresh, ...unread};
      });
      if (unread.isNotEmpty) {
        await app.api.notesRead(unread);
        app.unreadNotes.value = 0;
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _allRead() async {
    final app = context.app;
    await attempt(context, app.api.allNotesRead);
    app.unreadNotes.value = 0;
    if (mounted) setState(() => fresh = {});
  }

  /// what a notification opens: a post, a conversation, a person, a tab, a Joker table; the rest on the site
  Future<void> _open(Notif n) async {
    final app = context.app, r = n.ref, k = n.kind;
    int id(String key) => asInt(r[key]);
    Future<void> post(int p) async {
      try {
        final x = await app.api.post(p);
        if (x == null || !mounted) return;
        await app.posts.load([x]);
        if (mounted) await openPage(context, PostScreen(post: x), full: true);
      } catch (e) {
        if (mounted) toast(context, errText(e));
      }
    }

    if (k == 'repost' && id('post') > 0) return post(r['quote'] == true && id('by') > 0 ? id('by') : id('post'));
    if (const {'react', 'comment', 'comment_reply', 'comment_like', 'mention', 'grade_plus', 'group_post_ok', 'page_post', 'page_pin'}.contains(k) && id('post') > 0) return post(id('post'));
    if (k == 'gift' && id('post') > 0) return post(id('post'));
    if (k == 'msg_react' && id('conv') > 0) return openChat(context, id('conv'));
    if (k == 'jk_invite' && id('table') > 0) return openJokerTable(context, id('table'));
    // the friends' and dating pages open over the notifications, so back comes to them again (one step)
    if (k == 'friend_req' || k == 'friend_ok') {
      if (k == 'friend_req') app.friendsSeg.value = 1;
      await openPage(context, const FriendsTab(), full: true);
      return;
    }
    if (k == 'super') {
      await openPage(context, const DatingTab(), full: true);
      return;
    }
    if (k == 'match' && n.actor != null) {
      try {
        final conv = await app.api.startDm(n.actor!);
        if (mounted) await openChat(context, conv);
      } catch (e) {
        if (mounted) toast(context, errText(e));
      }
      return;
    }
    if (k == 'admin_msg' || k == 'verified') return;
    // the parts the app has itself; the rest still opens on the site
    final Widget? here = k.startsWith('album_') && id('album') > 0
        ? AlbumScreen(id: id('album'))
        : (k == 'kin_req' || k == 'kin_ok')
            ? TreeScreen(uid: app.api.myId)
            : k == 'verify_rejected'
                ? const VerifyScreen()
                : k == 'admin_coins'
                    ? const CoinsScreen()
                    : (k == 'nameday_me' || k == 'birthday_me')
                        ? const NamedaysScreen()
                        : null;
    if (here != null) {
      await openPage<void>(context, here, full: true);
      return;
    }
    final path = noteSitePath(k, r);
    if (path != null) {
      // here when the app has it (an event, a group, a room, a ride…), otherwise on the site
      await openPath(context, path);
      return;
    }
    if (n.actor != null && mounted) await openPage(context, PersonScreen(uid: n.actor!), full: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, l = list;
    return Scaffold(
      appBar: peeraBar(context, title: 'შეტყობინებები', actions: [
        IconBtn('check', label: 'ყველა წაკითხულია', onTap: _allRead),
        IconBtn('gear', label: 'შეტყობინებების პარამეტრები', onTap: () => openPage(context, const NotifSettingsScreen(), full: true)),
      ]),
      body: l == null
          ? (error != null
              ? Center(child: Empty(icon: 'bell', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'თავიდან', onAction: _load))
              : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: l.isEmpty
                  ? ListView(children: const [Empty(icon: 'bell', title: 'შეტყობინებები ჯერ არ არის', text: 'მოწონებები, კომენტარები და მოთხოვნები აქ გამოჩნდება.')])
                  : ListenableBuilder(
                      listenable: Listenable.merge([app.people, app.friends]),
                      builder: (context, _) {
                        final shown = [for (final n in l) if (noteInFilter(n, filter, fresh)) n];
                        final parts = groupNotes(shown, fresh);
                        var order = 0;
                        return ListView(padding: const EdgeInsets.only(bottom: 28), children: [
                          SizedBox(
                            height: 52,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                              itemCount: noteFilters.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 7),
                              itemBuilder: (_, i) {
                                final (k, t) = noteFilters[i];
                                final on = filter == k;
                                final cnt = k == 'new' ? fresh.length : 0;
                                return GestureDetector(
                                  key: ValueKey('nf-$k'),
                                  onTap: () => setState(() => filter = k),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: on ? c.accent : c.surface,
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(color: on ? c.accent : c.line),
                                      boxShadow: on ? [BoxShadow(color: c.accent.withValues(alpha: .3), blurRadius: 10, offset: const Offset(0, 3))] : null,
                                    ),
                                    child: Text(cnt > 0 ? '$t · $cnt' : t, style: TextStyle(color: on ? c.onAccent : c.ink, fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (parts.isEmpty)
                            Padding(padding: const EdgeInsets.all(36), child: Center(child: Text('აქ ჯერ არაფერია', style: TextStyle(color: c.muted)))),
                          for (final (sec, groups) in parts) ...[
                            SectionHead(sec, count: sec == noteSections[0] ? groups.length : null, padding: const EdgeInsets.fromLTRB(16, 14, 12, 6)),
                            for (final g in groups) Rise(key: ValueKey('ng-${g.latest.id}'), order: order++, child: _line(g)),
                          ],
                        ]);
                      },
                    ),
            ),
    );
  }

  /// One line: the faces with the kind's sign, the names and what they did, when; a request answered right here; a
  /// person on many things opens to show them one by one.
  Widget _line(NoteGroup g) {
    final c = context.pc, app = context.app, people = app.people, n = g.latest;
    final isNew = g.items.any((x) => fresh.contains(x.id));
    final names = [for (final a in g.actors) people[a]?.fullName ?? '…'];
    final open = expanded.contains(n.id);
    final req = n.kind == 'friend_req' && n.actor != null ? app.friends.stateWith(n.actor!) : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Pressable(
        key: ValueKey('note-${n.id}'),
        scale: .985,
        onTap: () {
          if (g.manyThings) {
            setState(() => open ? expanded.remove(n.id) : expanded.add(n.id));
          } else {
            _open(n);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: isNew
              ? cardLook(context, radius: 16, raised: true, color: Color.alphaBlend(c.accent.withValues(alpha: .08), c.surface))
              : BoxDecoration(borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Faces(g: g),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(
                  TextSpan(children: [
                    if (names.isNotEmpty) TextSpan(text: '${namesLine(names)} ', style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: groupText(g)),
                  ]),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, height: 1.35, color: c.ink),
                ),
                const SizedBox(height: 3),
                Row(children: [
                  Text(ago(n.createdAt), style: TextStyle(color: isNew ? c.accent : c.muted, fontSize: 12.5, fontWeight: isNew ? FontWeight.w700 : FontWeight.w500)),
                  if (g.manyThings) ...[
                    const SizedBox(width: 6),
                    AnimatedRotation(turns: open ? .75 : .25, duration: const Duration(milliseconds: 260), child: PIcon('chev', size: 14, color: c.muted)),
                  ],
                ]),
                if (req == Friendship.received)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      Expanded(
                        child: FilledButton(
                          key: ValueKey('nreq-ok-${n.id}'),
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                          onPressed: () => attempt(context, () => app.friends.accept(n.actor!)),
                          child: const FittedBox(fit: BoxFit.scaleDown, child: Text('დადასტურება')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          key: ValueKey('nreq-no-${n.id}'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                          onPressed: () => attempt(context, () => app.friends.remove(n.actor!)),
                          child: const FittedBox(fit: BoxFit.scaleDown, child: Text('წაშლა')),
                        ),
                      ),
                    ]),
                  )
                else if (n.kind == 'friend_req' && req == Friendship.friends)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('ახლა მეგობრები ხართ', style: TextStyle(color: c.vine, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
              ]),
            ),
            if (isNew) Padding(padding: const EdgeInsets.only(top: 6, left: 8), child: Container(width: 9, height: 9, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle))),
          ]),
        ),
      ),
      // one person's many things, one under another
      AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: !open
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.fromLTRB(62, 0, 12, 8),
                child: Column(children: [
                  for (final (i, x) in g.items.indexed)
                    Rise(
                      order: i,
                      dy: 8,
                      child: InkWell(
                        key: ValueKey('note-${x.id}-one'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _open(x),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                          child: Row(children: [
                            Expanded(child: Text(noteText(x.kind, x.ref), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5))),
                            const SizedBox(width: 8),
                            Text(ago(x.createdAt), style: TextStyle(color: c.muted, fontSize: 12)),
                            PIcon('chev', size: 15, color: c.muted),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
      ),
    ]);
  }
}

/// The faces on a line: one large, or two overlapping (the newest in front); the kind's small sign at the corner.
class _Faces extends StatelessWidget {
  const _Faces({required this.g});
  final NoteGroup g;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, people = context.app.people, a = g.actors, n = g.latest;
    final (icon, c1, c2) = noteSign(g.kind);
    Profile who(String id) => people[id] ?? Profile(id: id, name: '…');
    Widget ring(Widget w) => Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle), child: w);
    final Widget faces = n.actor == null
        ? Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const PeeraMark(size: 30),
          )
        : a.length < 2
            ? Avatar(p: who(a.first), size: 52)
            : SizedBox.square(
                dimension: 52,
                child: Stack(children: [
                  Positioned(left: 0, top: 0, child: Avatar(p: who(a[1]), size: 36)),
                  Positioned(right: -2, bottom: -2, child: ring(Avatar(p: who(a[0]), size: 36))),
                ]),
              );
    return SizedBox.square(
      dimension: 56,
      child: Stack(clipBehavior: Clip.none, children: [
        faces,
        Positioned(
          right: 0,
          bottom: 0,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: .3, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.elasticOut,
            builder: (_, v, ch) => Transform.scale(scale: v, child: ch),
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(c1), Color(c2)]),
                shape: BoxShape.circle,
                border: Border.all(color: c.surface, width: 2),
              ),
              child: PIcon(icon, size: 12, color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }
}
