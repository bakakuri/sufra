// The notifications (the bell): the latest sixty, the new ones marked, each opening what it is about — in the app
// where the app has it, otherwise on the site. Seen as soon as the list is opened, as on the site.
import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../data/models.dart';
import '../dating/dating_tab.dart';
import '../data/stores.dart';
import '../feed/comments_sheet.dart';
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
  bool _started = false, more = false, older = false;
  late final AppState app;

  /// the last look before this one: what came after it is "new"
  DateTime? prev;

  /// read or unread as changed here (a line stays unread until it is opened, as on Facebook)
  final marks = <int, bool>{};

  /// all of them or only the unread, and the lines of one person's many things that are open
  String filter = 'all';
  final expanded = <int>{};

  bool isRead(Notif n) => marks[n.id] ?? n.read;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    app = context.app;
    app.notesOpen = true;
    // the bell's number goes (after this frame: the bell is being built right now)
    WidgetsBinding.instance.addPostFrameCallback((_) => app.unreadNotes.value = 0);
    final uid = app.api.myId, now = DateTime.now();
    NotesSeen.get(uid).then((t) {
      if (mounted) setState(() => prev = t ?? now.subtract(const Duration(days: 1)));
      NotesSeen.set(uid, now);
    });
    _load();
  }

  @override
  void dispose() {
    app.notesOpen = false;
    NotesSeen.set(app.api.myId, DateTime.now());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await app.api.notes();
      await app.people.ensure([for (final n in r) if (n.actor != null) n.actor!]);
      if (!mounted) return;
      setState(() {
        list = r;
        error = null;
        more = r.length >= 40;
        marks.clear();
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  /// "ძველი შეტყობინებების ნახვა": the forty before the last one shown
  Future<void> _older() async {
    final l = list;
    if (l == null || l.isEmpty || older) return;
    setState(() => older = true);
    try {
      final r = await app.api.notes(before: l.last.createdAt);
      await app.people.ensure([for (final n in r) if (n.actor != null) n.actor!]);
      if (!mounted) return;
      setState(() {
        final have = {for (final n in l) n.id};
        l.addAll(r.where((n) => have.add(n.id)));
        more = r.length >= 40;
      });
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
    if (mounted) setState(() => older = false);
  }

  Future<void> _mark(List<Notif> items, bool read) async {
    final ids = [for (final n in items) if (isRead(n) != read) n.id];
    if (ids.isEmpty) return;
    setState(() {
      for (final id in ids) {
        marks[id] = read;
      }
    });
    try {
      await app.api.notesRead(ids, read: read);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  Future<void> _allRead() async {
    final l = list ?? const <Notif>[];
    setState(() {
      for (final n in l) {
        marks[n.id] = true;
      }
    });
    await attempt(context, app.api.allNotesRead);
  }

  Future<void> _remove(NoteGroup g) async {
    final ids = [for (final n in g.items) n.id];
    setState(() => list?.removeWhere((n) => ids.contains(n.id)));
    try {
      await app.api.deleteNotes(ids);
      if (mounted) toast(context, 'შეტყობინება წაიშალა');
    } catch (e) {
      if (mounted) toast(context, errText(e));
      _load();
    }
  }

  /// "turn these off": the same switch as in the settings, for this kind's group
  Future<void> _turnOff(String cat, String title) async {
    try {
      final m = await app.api.mySettings();
      final n = m['notif'] is Map ? Map<String, dynamic>.from(m['notif'] as Map) : <String, dynamic>{};
      final off = n['off'] is Map ? Map<String, dynamic>.from(n['off'] as Map) : <String, dynamic>{};
      off[cat] = true;
      await app.api.updateMe({'notif': {...n, 'off': off}});
      if (mounted) toast(context, 'გამოირთო: $title · ჩართვა პარამეტრებიდან შეიძლება');
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  void _settings() => openPage(context, const NotifSettingsScreen(), full: true);

  /// the "…" on a line, as Facebook's: read or unread, remove, turn these off, the settings
  Future<void> _menu(NoteGroup g) {
    final c = context.pc, unread = g.items.any((n) => !isRead(n)), cat = noteCategory(g.kind);
    final kind = [for (final k in notifKinds) if (k.$1 == cat) k];
    final names = [for (final a in g.actors) app.people[a]?.fullName ?? '…'];
    late BuildContext sheet;
    Widget opt(String key, String icon, String title, VoidCallback onTap, {String? sub}) => ListTile(
          key: ValueKey(key),
          leading: PIcon(icon, size: 22, color: c.ink),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: sub == null ? null : Text(sub, style: TextStyle(color: c.muted, fontSize: 12.5)),
          onTap: () {
            Navigator.pop(sheet);
            onTap();
          },
        );
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: c.surface,
      builder: (s) {
        sheet = s;
        return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              _Faces(g: g, size: 44, people: app.people),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    if (names.isNotEmpty) TextSpan(text: '${namesLine(names)} ', style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: groupText(g)),
                  ]),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, height: 1.35),
                ),
              ),
            ]),
          ),
          Divider(height: 1, color: c.line),
          const SizedBox(height: 4),
          opt('nm-read', unread ? 'check' : 'eye', unread ? 'წაკითხულად მონიშვნა' : 'წაუკითხავად მონიშვნა', () => _mark(g.items, unread)),
          opt('nm-del', 'x', 'ამ შეტყობინების წაშლა', () => _remove(g)),
          if (kind.isNotEmpty) opt('nm-off', 'mute', 'ასეთი შეტყობინებების გამორთვა', () => _turnOff(cat, kind.first.$3), sub: kind.first.$3),
          opt('nm-set', 'gear', 'შეტყობინებების პარამეტრები', _settings),
          const SizedBox(height: 8),
        ]),
      );
      },
    );
  }

  /// the "…" at the top
  Future<void> _top() => showChoices(context, [
        SheetItem('check', 'ყველას წაკითხულად მონიშვნა', _allRead),
        SheetItem('gear', 'შეტყობინებების პარამეტრები', _settings),
      ]);

  /// what a notification opens: a post, a conversation, a person, a tab, a Joker table; the rest on the site
  Future<void> _open(Notif n, [List<Notif>? line]) async {
    _mark(line ?? [n], true);
    final r = n.ref, k = n.kind;
    int id(String key) => asInt(r[key]);
    Future<void> post(int p) async {
      try {
        final x = await app.api.post(p);
        if (x == null || !mounted) return;
        await app.posts.load([x]);
        // the post comes up over the notifications with its comments, the answered one open
        final cm = int.tryParse('${n.ref['comment'] ?? ''}');
        if (mounted) await openPost(context, x, thread: cm);
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
    if (k == 'weekly') return weekSheet(context, r);
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
    final c = context.pc, l = list;
    return Scaffold(
      appBar: peeraBar(context, title: 'შეტყობინებები', actions: [
        IconBtn('more', key: const ValueKey('notes-more'), label: 'მეტი', onTap: _top),
      ]),
      body: l == null
          ? (error != null
              ? Center(child: Empty(icon: 'bell', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'თავიდან', onAction: _load))
              : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListenableBuilder(
                listenable: Listenable.merge([app.people, app.friends]),
                builder: (context, _) {
                  final p = prev ?? DateTime.now();
                  final shown = [for (final n in l) if (filter == 'all' || !isRead(n)) n];
                  final parts = groupNotes(shown, {for (final n in shown) if (n.createdAt.isAfter(p)) n.id});
                  var order = 0;
                  return ListView(padding: const EdgeInsets.only(bottom: 28), children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(children: [
                        for (final (k, t) in noteFilters)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Material(
                              color: filter == k ? Color.alphaBlend(c.accent.withValues(alpha: .14), c.surface) : Colors.transparent,
                              shape: const StadiumBorder(),
                              child: InkWell(
                                key: ValueKey('nf-$k'),
                                customBorder: const StadiumBorder(),
                                onTap: () => setState(() => filter = k),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  child: Text(t, style: TextStyle(color: filter == k ? c.accent : c.ink, fontWeight: FontWeight.w700, fontSize: 14.5)),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    if (parts.isEmpty)
                      filter == 'un'
                          ? const Empty(icon: 'check', title: 'წაუკითხავი არაფერია', text: 'ყველაფერი ნანახი გაქვს.')
                          : const Empty(icon: 'bell', title: 'შეტყობინებები ჯერ არ არის', text: 'მოწონებები, კომენტარები და მოთხოვნები აქ გამოჩნდება.'),
                    for (final (sec, groups) in parts) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Text(sec, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                      for (final g in groups) Rise(key: ValueKey('ng-${g.latest.id}'), order: order++, dy: 10, child: _line(g)),
                    ],
                    if (more && l.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: FilledButton(
                          key: const ValueKey('notes-older'),
                          style: FilledButton.styleFrom(
                            backgroundColor: c.sunk,
                            foregroundColor: c.ink,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: older ? null : _older,
                          child: Text(older ? 'იტვირთება…' : 'ძველი შეტყობინებების ნახვა', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ]);
                },
              ),
            ),
    );
  }

  /// One line, as Facebook's: the face with the kind's sign, the names and what they did, when; tinted with a dot
  /// until opened; "…" for the rest; a request answered right here; a person on many things opens to show them.
  Widget _line(NoteGroup g) {
    final c = context.pc, people = app.people, n = g.latest;
    final unread = g.items.any((x) => !isRead(x));
    final names = [for (final a in g.actors) people[a]?.fullName ?? '…'];
    final open = expanded.contains(n.id);
    final req = n.kind == 'friend_req' && n.actor != null ? app.friends.stateWith(n.actor!) : null;
    Widget btn(String key, String t, bool main, VoidCallback onTap) => Expanded(
          child: FilledButton(
            key: ValueKey(key),
            style: FilledButton.styleFrom(
              backgroundColor: main ? c.accent : c.sunk,
              foregroundColor: main ? c.onAccent : c.ink,
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onTap,
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700))),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Material(
        color: unread ? Color.alphaBlend(c.accent.withValues(alpha: .08), c.bg) : Colors.transparent,
        child: InkWell(
          key: ValueKey('note-${n.id}'),
          onTap: () {
            if (g.manyThings) {
              _mark(g.items, true);
              setState(() => open ? expanded.remove(n.id) : expanded.add(n.id));
            } else {
              _open(n, g.items);
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
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
                      style: TextStyle(fontSize: 15, height: 1.34, color: c.ink),
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      Text(ago(n.createdAt), style: TextStyle(color: unread ? c.accent : c.muted, fontSize: 13, fontWeight: unread ? FontWeight.w800 : FontWeight.w500)),
                      if (g.manyThings) ...[
                        const SizedBox(width: 6),
                        AnimatedRotation(turns: open ? .75 : .25, duration: const Duration(milliseconds: 260), child: PIcon('chev', size: 14, color: c.muted)),
                      ],
                    ]),
                  ]),
                ),
                IconBtn('more', key: ValueKey('note-more-${n.id}'), label: 'მეტი', size: 20, color: c.muted, onTap: () => _menu(g)),
                SizedBox(
                  width: 18,
                  child: unread ? Center(child: Container(key: ValueKey('note-dot-${n.id}'), width: 12, height: 12, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle))) : null,
                ),
              ]),
              if (req == Friendship.received)
                Padding(
                  padding: const EdgeInsets.fromLTRB(68, 6, 12, 2),
                  child: Row(children: [
                    btn('nreq-ok-${n.id}', 'დადასტურება', true, () => attempt(context, () => app.friends.accept(n.actor!))),
                    const SizedBox(width: 8),
                    btn('nreq-no-${n.id}', 'წაშლა', false, () => attempt(context, () => app.friends.remove(n.actor!))),
                  ]),
                )
              else if (n.kind == 'friend_req' && req == Friendship.friends)
                Padding(
                  padding: const EdgeInsets.fromLTRB(68, 4, 12, 0),
                  child: Text('ახლა მეგობრები ხართ', style: TextStyle(color: c.vine, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
            ]),
          ),
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
                padding: const EdgeInsets.fromLTRB(78, 0, 12, 8),
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
  const _Faces({required this.g, this.size = 56, this.people});
  final NoteGroup g;
  final double size;

  /// given where the app's scope is not above (a sheet over everything)
  final People? people;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, people = this.people ?? context.app.people, a = g.actors, n = g.latest;
    final (icon, c1, c2) = noteSign(g.kind);
    // a reaction shows itself (as Facebook's ❤️ and 😂 on the face)
    final emo = const {'react', 'story_react', 'msg_react'}.contains(g.kind) ? g.emojis.characters.take(1).toString() : '';
    final k = size / 56, f = size - 4 * k;
    Profile who(String id) => people[id] ?? Profile(id: id, name: '…');
    Widget ring(Widget w) => Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle), child: w);
    final Widget faces = n.actor == null
        ? Container(
            width: f,
            height: f,
            decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: PeeraMark(size: 30 * k),
          )
        : a.length < 2
            ? Avatar(p: who(a.first), size: f)
            : SizedBox.square(
                dimension: f,
                child: Stack(children: [
                  Positioned(left: 0, top: 0, child: Avatar(p: who(a[1]), size: 38 * k)),
                  Positioned(right: -2, bottom: -2, child: ring(Avatar(p: who(a[0]), size: 38 * k))),
                ]),
              );
    final sign = 26 * k;
    return SizedBox.square(
      dimension: size,
      child: Stack(clipBehavior: Clip.none, children: [
        faces,
        Positioned(
          right: -2,
          bottom: -2,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: .3, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.elasticOut,
            builder: (_, v, ch) => Transform.scale(scale: v, child: ch),
            child: Container(
              width: sign,
              height: sign,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: emo.isEmpty ? null : c.surface,
                gradient: emo.isEmpty ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(c1), Color(c2)]) : null,
                shape: BoxShape.circle,
                border: Border.all(color: c.surface, width: 2),
                boxShadow: emo.isEmpty ? null : const [BoxShadow(color: Color(0x2E000000), blurRadius: 4, offset: Offset(0, 1))],
              ),
              child: emo.isEmpty ? PIcon(icon, size: 13 * k, color: Colors.white) : Text(emo, style: TextStyle(fontSize: 13 * k, height: 1)),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The week in numbers: what others gave, who came, who watched.
Future<void> weekSheet(BuildContext context, Map r) {
  final c = context.pc;
  int n(String k) => int.tryParse('${r[k] ?? 0}') ?? 0;
  Widget box(String icon, String k, String label, int color) => Container(
        key: ValueKey('wk-$k'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(Color(color).withValues(alpha: .09), c.surface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Color(color).withValues(alpha: .22)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Color(color), shape: BoxShape.circle),
            child: PIcon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(compact(n(k)), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
          Text(label, maxLines: 2, style: TextStyle(color: c.muted, fontSize: 12, height: 1.25)),
        ]),
      );
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: c.surface,
    builder: (s) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('შენი კვირა', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text('ბოლო 7 დღე', style: TextStyle(color: c.muted)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: .92,
            children: [
              box('heart', 'likes', 'მოწონება', 0xFFF43F5E),
              box('comment', 'comments', 'კომენტარი', 0xFF10B981),
              box('users', 'friends', 'ახალი მეგობარი', 0xFF3B82F6),
              box('eye', 'visits', 'პროფილის ნახვა', 0xFF8B5CF6),
              box('play', 'views', 'კლიპის ნახვა', 0xFFF97316),
              box('edit', 'posts', 'შენი პოსტი', 0xFF0EA5E9),
            ],
          ),
        ]),
      ),
    ),
  );
}
