// The notifications (the bell): the latest sixty, the new ones marked, each opening what it is about — in the app
// where the app has it, otherwise on the site. Seen as soon as the list is opened, as on the site.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../chat/chat_screen.dart';
import '../config.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/post_screen.dart';
import '../joker/online_screen.dart';
import '../people/albums.dart';
import '../people/coins.dart';
import '../people/family.dart';
import '../people/my_space.dart';
import '../people/verify.dart';
import '../people/person_screen.dart';
import '../profile/profile.dart';
import '../settings/settings_screens.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
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
    if (const {'react', 'comment', 'comment_reply', 'comment_like', 'mention', 'grade_plus', 'group_post_ok'}.contains(k) && id('post') > 0) return post(id('post'));
    if (k == 'gift' && id('post') > 0) return post(id('post'));
    if (k == 'msg_react' && id('conv') > 0) return openChat(context, id('conv'));
    if (k == 'jk_invite' && id('table') > 0) return openJokerTable(context, id('table'));
    if (k == 'friend_req' || k == 'friend_ok') {
      Navigator.of(context).pop();
      app.goTab?.call('friends');
      return;
    }
    if (k == 'super') {
      Navigator.of(context).pop();
      app.goTab?.call('date');
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
      await launchUrl(Uri.parse('$siteUrl/$path'), mode: LaunchMode.externalApplication);
      return;
    }
    if (n.actor != null && mounted) await openPage(context, PersonScreen(uid: n.actor!), full: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, people = context.app.people, l = list;
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
                      listenable: people,
                      builder: (context, _) => ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: l.length,
                        itemBuilder: (context, i) {
                          final n = l[i], who = n.actor == null ? null : people[n.actor!];
                          final isNew = fresh.contains(n.id);
                          return InkWell(
                            key: ValueKey('note-${n.id}'),
                            onTap: () => _open(n),
                            child: Container(
                              color: isNew ? c.accentSoft.withValues(alpha: .55) : null,
                              padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                n.actor == null
                                    ? Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
                                        alignment: Alignment.center,
                                        child: const PeeraMark(size: 26),
                                      )
                                    : Avatar(p: who ?? Profile(id: n.actor!, name: '…'), size: 44),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text.rich(
                                      TextSpan(children: [
                                        if (n.actor != null) TextSpan(text: '${who?.fullName ?? '…'} ', style: const TextStyle(fontWeight: FontWeight.w800)),
                                        TextSpan(text: noteText(n.kind, n.ref)),
                                      ]),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 14.5, height: 1.35, color: c.ink),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(ago(n.createdAt), style: TextStyle(color: isNew ? c.accent : c.muted, fontSize: 12.5, fontWeight: isNew ? FontWeight.w700 : FontWeight.w500)),
                                  ]),
                                ),
                                if (isNew) Padding(padding: const EdgeInsets.only(top: 6, left: 8), child: Container(width: 9, height: 9, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle))),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
            ),
    );
  }
}
