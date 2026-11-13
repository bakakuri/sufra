// "My space" on my own profile, as on the site: the stories archive (stories, photos, clips, videos, highlights),
// close friends, drafts and scheduled posts, angel's days; and opening a highlight.
import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../feed/post_card.dart';
import '../feed/post_screen.dart';
import '../profile/profile.dart';
import '../stories/stories.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'namedays.dart';

/// A highlight's stories, one after another (an empty one just says so).
Future<void> openHighlight(BuildContext context, Highlight h, String owner) async {
  try {
    final items = await context.app.api.highlightItems(h.id);
    if (!context.mounted) return;
    if (items.isEmpty) {
      toast(context, 'ეს რჩეული ცარიელია');
      return;
    }
    await openStories(context, [StoryGroup(owner, items)], 0, title: h.title, highlight: h.id);
  } catch (e) {
    if (context.mounted) toast(context, errText(e));
  }
}

// ---------- the archive ----------

const _archTabs = [('stories', 'story', 'ისტორიები'), ('photos', 'image', 'ფოტოები'), ('clips', 'clips', 'კლიპები'), ('videos', 'play', 'ვიდეოები'), ('hl', 'star', 'რჩეულები')];

/// Everything of mine that has a picture, by kind (extras.js storyarch): stories (only I see them), the photos and
/// videos of my posts, my clips, and my highlights. A kind is a tab inside the page, not a step back.
class StoryArchiveScreen extends StatefulWidget {
  const StoryArchiveScreen({super.key});
  @override
  State<StoryArchiveScreen> createState() => _StoryArchiveScreenState();
}

class _StoryArchiveScreenState extends State<StoryArchiveScreen> {
  String tab = 'stories';
  List<Story>? stories;
  List<Highlight> hl = const [];
  List<(Post, Media)> photos = const [], videos = const [];
  List<Post> clips = const [];
  Object? error;
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
      final st = await app.api.myStories();
      final h = await app.api.highlights(app.api.myId);
      final posts = await app.api.postsBy(app.api.myId, limit: 200);
      final ph = <(Post, Media)>[], vi = <(Post, Media)>[], cl = <Post>[];
      for (final p in posts) {
        if (p.repostOf != null) continue;
        if (p.isClip && p.media.any((m) => m.isVideo)) {
          cl.add(p);
          continue;
        }
        for (final m in p.media) {
          (m.isVideo ? vi : ph).add((p, m));
        }
      }
      if (!mounted) return;
      setState(() {
        stories = st;
        hl = h;
        photos = ph;
        videos = vi;
        clips = cl;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  int _count(String k) => switch (k) {
        'stories' => stories?.length ?? 0,
        'photos' => photos.length,
        'clips' => clips.length,
        'videos' => videos.length,
        _ => hl.length,
      };

  /// a story from the archive: see it, keep it in a highlight, or post it again
  void _story(Story s) {
    final app = context.app;
    showChoices(context, [
      SheetItem('eye', 'ნახვა', () => openStories(context, [StoryGroup(app.api.myId, [s])], 0, title: 'ისტორია')),
      SheetItem('star', 'რჩეულებში დამატება', () async {
        await pickHighlight(context, s.id);
        _load();
      }),
      SheetItem('repost', 'ხელახლა გაზიარება ისტორიად', () async {
        if (await attempt(context, () => app.api.addStory(s.url, video: s.video)) && mounted) {
          app.stories.load().catchError((_) {});
          toast(context, 'ისტორია ხელახლა გაზიარდა');
          _load();
        }
      }),
    ]);
  }

  Future<void> _rename(Highlight h) async {
    final t = TextEditingController(text: h.title);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('რჩეულის სახელი'),
        content: TextField(key: const ValueKey('hl-name'), controller: t, maxLength: 24, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('გაუქმება')),
          FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('შენახვა')),
        ],
      ),
    );
    final v = t.text.trim();
    if (ok != true || v.isEmpty || !mounted) return;
    if (await attempt(context, () => context.app.api.renameHighlight(h.id, v))) _load();
  }

  Future<void> _delete(Highlight h) async {
    if (!await confirm(context, title: 'რჩეულის წაშლა', text: 'წაიშლება მხოლოდ რჩეული. ისტორიები არქივში დარჩება.', yes: 'წაშლა', danger: true) || !mounted) return;
    if (await attempt(context, () => context.app.api.deleteHighlight(h.id))) _load();
  }

  /// tiles under a month's name
  List<Widget> _months<T>(List<T> rows, DateTime Function(T) at, Widget Function(T, DateTime) tile, {double ratio = 9 / 16}) {
    final out = <Widget>[];
    var last = '';
    var group = <Widget>[];
    void flush() {
      if (group.isEmpty) return;
      out.add(GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        childAspectRatio: ratio,
        children: group,
      ));
      group = [];
    }

    for (final r in rows) {
      final d = at(r), mk = '${monthNames[d.month - 1]} ${d.year}';
      if (mk != last) {
        flush();
        out.add(Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 6), child: Text(mk, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))));
        last = mk;
      }
      group.add(tile(r, d));
    }
    flush();
    return out;
  }

  Widget _note(String icon, String text) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PIcon(icon, size: 16, color: c.muted),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(color: c.muted, fontSize: 13, height: 1.4))),
      ]),
    );
  }

  Widget _thumb({String? image, bool video = false, String? corner, bool live = false, required VoidCallback onTap, Key? key}) {
    final c = context.pc;
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: ColoredBox(
        color: c.sunk,
        child: Stack(fit: StackFit.expand, children: [
          if (image != null && image.isNotEmpty) PImage(image) else Center(child: PIcon(video ? 'clips' : 'image', size: 26, color: c.muted)),
          if (video) const Center(child: PIcon('play', size: 26, color: Colors.white)),
          if (corner != null)
            Positioned(
              left: 6,
              top: 6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 26),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(8)),
                child: Text(corner, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF1D1320), fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          if (live)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(999)),
                child: const Text('ახლა ჩანს', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _openPost(Post p) => openPage(context, PostScreen(post: p), full: true);

  List<Widget> _body() {
    final c = context.pc, app = context.app, st = stories!;
    switch (tab) {
      case 'stories':
        if (st.isEmpty) {
          return [
            Empty(
              icon: 'story',
              title: 'ისტორიები ჯერ არ არის',
              text: 'გამოაქვეყნე ისტორია: 24 საათის შემდეგაც აქ შეინახება და მხოლოდ შენ დაინახავ.',
              action: 'ისტორიის დამატება',
              onAction: () async {
                await addStory(context);
                _load();
              },
            ),
          ];
        }
        return [
          _note('lock', 'აქ ინახება შენი ყველა ისტორია, 24 საათის შემდეგაც. მხოლოდ შენ ხედავ. შეეხე და დაამატე რჩეულებში.'),
          ..._months<Story>(
            st,
            (s) => s.createdAt,
            (s, d) => _thumb(
              key: ValueKey('arch-${s.id}'),
              image: s.video ? null : s.url,
              video: s.video,
              corner: '${d.day}',
              live: s.expiresAt != null && s.expiresAt!.isAfter(DateTime.now()),
              onTap: () => _story(s),
            ),
          ),
        ];
      case 'photos':
        if (photos.isEmpty) {
          return [
            Empty(
              icon: 'image',
              title: 'ფოტოები ჯერ არ არის',
              text: 'პოსტებში დამატებული ფოტოები აქ შეგროვდება.',
              action: 'პოსტის დაწერა',
              onAction: () => openPage(context, const ComposeScreen(), full: true),
            ),
          ];
        }
        return _months<(Post, Media)>(photos, (x) => x.$1.createdAt, (x, _) => _thumb(image: x.$2.small, onTap: () => _openPost(x.$1)), ratio: 1);
      case 'clips':
        if (clips.isEmpty) return [const Empty(icon: 'clips', title: 'კლიპები ჯერ არ არის', text: 'ატვირთე მოკლე ვიდეო და კლიპებში გამოჩნდება.')];
        return _months<Post>(clips, (p) => p.createdAt, (p, _) {
          final m = p.media.firstWhere((x) => x.isVideo);
          final d = m.dur;
          return _thumb(
            image: m.poster,
            video: true,
            corner: d == null ? null : '${d ~/ 60}:${(d.round() % 60).toString().padLeft(2, '0')}',
            onTap: () => _openPost(p),
          );
        });
      case 'videos':
        if (videos.isEmpty) return [const Empty(icon: 'play', title: 'ვიდეოები ჯერ არ არის', text: 'პოსტებში დამატებული ვიდეოები აქ შეგროვდება.')];
        return _months<(Post, Media)>(videos, (x) => x.$1.createdAt, (x, _) => _thumb(image: x.$2.poster, video: true, onTap: () => _openPost(x.$1)), ratio: 1);
      default:
        return [
          _note('star', 'რჩეულები პროფილზე ჩანს, ყველასთვის. ახლის შესაქმნელად „ისტორიებში“ შეეხე ისტორიას და აირჩიე „რჩეულებში დამატება“.'),
          if (hl.isEmpty)
            Empty(icon: 'star', title: 'რჩეულები ჯერ არ გაქვს', action: 'ისტორიების ნახვა', onAction: () => setState(() => tab = 'stories'))
          else
            for (final h in hl)
              ListTile(
                key: ValueKey('archhl-${h.id}'),
                leading: GestureDetector(
                  onTap: () => openHighlight(context, h, app.api.myId),
                  child: ClipOval(
                    child: SizedBox.square(
                      dimension: 42,
                      child: (h.cover ?? '').isNotEmpty ? PImage(h.cover!) : ColoredBox(color: c.sunk, child: Center(child: PIcon('star', size: 18, color: c.muted))),
                    ),
                  ),
                ),
                title: Text(h.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconBtn('edit', label: 'სახელის შეცვლა', onTap: () => _rename(h)),
                  IconBtn('trash', label: 'წაშლა', onTap: () => _delete(h)),
                ]),
              ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      appBar: peeraBar(context, title: 'ისტორიები', actions: [
        IconBtn('plus', label: 'ისტორია', onTap: () async {
          await addStory(context);
          _load();
        }),
      ]),
      body: stories == null
          ? (error != null
              ? Center(child: Empty(icon: 'story', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'თავიდან', onAction: _load))
              : const Center(child: CircularProgressIndicator()))
          : ListView(padding: const EdgeInsets.only(bottom: 28), children: [
              Container(
                decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.line))),
                child: Row(children: [
                  for (final t in _archTabs)
                    Expanded(
                      child: InkWell(
                        key: ValueKey('archtab-${t.$1}'),
                        onTap: () => setState(() => tab = t.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tab == t.$1 ? c.accent : Colors.transparent, width: 2))),
                          child: Column(children: [
                            PIcon(t.$2, size: 19, color: tab == t.$1 ? c.ink : c.muted),
                            const SizedBox(height: 3),
                            FittedBox(
                              child: Text(t.$3, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tab == t.$1 ? c.ink : c.muted)),
                            ),
                            Text(_count(t.$1) > 0 ? '${_count(t.$1)}' : ' ', style: TextStyle(fontSize: 10.5, color: c.muted, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
              ..._body(),
            ]),
    );
  }
}

// ---------- close friends ----------

/// Who sees my "close friends" stories (they are not told they are on the list).
class CloseFriendsScreen extends StatefulWidget {
  const CloseFriendsScreen({super.key});
  @override
  State<CloseFriendsScreen> createState() => _CloseFriendsScreenState();
}

class _CloseFriendsScreenState extends State<CloseFriendsScreen> {
  Set<String>? on;
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
      if (!app.friends.loaded) await app.friends.load();
      await app.people.ensure(app.friends.friends);
      final c = await app.api.closeFriends();
      if (mounted) setState(() => on = c.toSet());
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  Future<void> _set(String uid, bool v) async {
    setState(() => v ? on!.add(uid) : on!.remove(uid));
    final ok = await attempt(context, () => context.app.api.setClose(uid, v));
    if (!mounted) return;
    if (!ok) {
      setState(() => v ? on!.remove(uid) : on!.add(uid));
    } else {
      toast(context, v ? 'დაემატა ახლო მეგობრებში' : 'ამოიშალა');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, friends = app.friends.friends;
    return Scaffold(
      appBar: peeraBar(context, title: 'ახლო მეგობრები'),
      body: on == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text('„ახლო მეგობრებისთვის“ გამოქვეყნებულ ისტორიას მხოლოდ ესენი ნახავენ. მათ არ ეცნობებათ, რომ სიაში არიან.',
                    style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.4)),
              ),
              if (friends.isEmpty)
                Empty(icon: 'users', title: 'მეგობრები ჯერ არ გყავს', action: 'მეგობრების პოვნა', onAction: () {
                  Navigator.of(context).pop();
                  app.goTab?.call('friends');
                })
              else
                for (final id in friends)
                  CheckboxListTile(
                    key: ValueKey('close-$id'),
                    value: on!.contains(id),
                    onChanged: (v) => _set(id, v == true),
                    secondary: Avatar(p: app.people[id] ?? Profile(id: id, name: '…'), size: 44),
                    title: NameLine(app.people[id] ?? Profile(id: id, name: '…'), size: 15),
                  ),
            ]),
    );
  }
}

// ---------- drafts ----------

/// My drafts (only I see them) and the posts waiting for their time: publish now, or delete.
class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});
  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  List<Post>? list;
  Object? error;
  bool _started = false;
  final _busy = <int>{};

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
      final l = await app.api.drafts();
      await app.posts.load(l);
      if (mounted) setState(() => list = l);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _publish(Post p) async {
    setState(() => _busy.add(p.id));
    final ok = await attempt(context, () => context.app.api.publishNow(p.id));
    if (!mounted) return;
    setState(() => _busy.remove(p.id));
    if (ok) {
      toast(context, 'გამოქვეყნდა');
      _load();
    }
  }

  Future<void> _delete(Post p) async {
    if (!await confirm(context, title: 'წაშლა', text: 'დრაფტი წაიშლება.', yes: 'წაშლა', danger: true) || !mounted) return;
    if (await attempt(context, () => context.app.api.deletePost(p.id))) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, l = list;
    return Scaffold(
      appBar: peeraBar(context, title: 'დრაფტები და დაგეგმილი'),
      body: l == null
          ? (error != null ? Center(child: Empty(icon: 'clock', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'თავიდან', onAction: _load)) : const Center(child: CircularProgressIndicator()))
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text('დრაფტებს მხოლოდ შენ ხედავ. დაგეგმილი პოსტი თავისით გამოქვეყნდება მითითებულ დროს.', style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.4)),
              ),
              if (l.isEmpty)
                Empty(
                  icon: 'clock',
                  title: 'დრაფტები არ გაქვს',
                  text: 'პოსტის წერისას დააჭირე საათის ღილაკს და შეინახე დრაფტად ან დაგეგმე.',
                  action: 'პოსტის დაწერა',
                  onAction: () => openPage(context, const ComposeScreen(), full: true),
                )
              else
                for (final p in l) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: p.createdAt.isAfter(DateTime.now()) ? c.accentSoft : c.sunk, borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          p.createdAt.isAfter(DateTime.now()) ? 'დაგეგმილია · ${dayLabel(p.createdAt)} ${hhmm(p.createdAt)}' : 'დრაფტი',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.ink),
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        key: ValueKey('dpub-${p.id}'),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
                        onPressed: _busy.contains(p.id) ? null : () => _publish(p),
                        icon: PIcon('send', size: 16, color: c.onAccent),
                        label: const Text('ახლავე'),
                      ),
                      IconBtn('trash', label: 'წაშლა', onTap: () => _delete(p)),
                    ]),
                  ),
                  PostCard(key: ValueKey('draft-${p.id}'), post: p),
                ],
            ]),
    );
  }
}

// ---------- angel's days ----------

/// Angel's days (namedays.js): mine (from the calendar, or chosen by hand), today's feasts and friends celebrating,
/// a name search, the days ahead.
class NamedaysScreen extends StatefulWidget {
  const NamedaysScreen({super.key});
  @override
  State<NamedaysScreen> createState() => _NamedaysScreenState();
}

class _NamedaysScreenState extends State<NamedaysScreen> {
  String? own, ownLabel;
  String q = '';
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final me = context.me;
    own = me.nameday;
    ownLabel = me.namedayLabel;
    final app = context.app;
    _friends(app);
    // the row as the server has it (the sign-in copy may be older)
    app.api.mySettings().then((m) {
      if (!mounted) return;
      setState(() {
        own = (m['nameday'] as String?)?.isEmpty == true ? null : m['nameday'] as String?;
        ownLabel = m['nameday_label'] as String?;
      });
    }).catchError((_) {});
  }

  Future<void> _friends(AppState app) async {
    try {
      if (!app.friends.loaded) await app.friends.load();
      await app.people.ensure(app.friends.friends);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _save(String? md, String label) async {
    if (md != null) {
      final p = md.split('-').map(int.parse).toList();
      if (p[1] > DateTime(2024, p[0] + 1, 0).day) {
        toast(context, 'ასეთი თარიღი არ არსებობს');
        return;
      }
    }
    final app = context.app;
    if (!await attempt(context, () => app.api.updateMe({'nameday': md, 'nameday_label': label}))) return;
    if (!mounted) return;
    setState(() {
      own = md;
      ownLabel = label;
    });
    app.refreshMe?.call();
    toast(context, 'შენახულია. მეგობრებს ამ დღეს შევახსენებთ');
  }

  Future<void> _pick() async {
    final me = context.me, opts = daysOfName(me.name);
    var m = 1, d = 1;
    if (own != null) {
      final p = own!.split('-');
      m = int.tryParse(p[0]) ?? 1;
      d = int.tryParse(p[1]) ?? 1;
    }
    final label = TextEditingController(text: own != null ? (ownLabel ?? '') : '');
    String two(int n) => n.toString().padLeft(2, '0');
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => StatefulBuilder(
        builder: (s, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(s).bottom),
          child: SafeArea(
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), children: [
              const Text('ჩემი ანგელოზის დღე', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              if (opts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('შენი სახელის დღეები კალენდარში:', style: TextStyle(color: s.pc.muted, fontSize: 13.5)),
                for (final o in opts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${mdText(o.$1)} · ${o.$2}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.of(s).pop();
                      _save(o.$1, o.$2);
                    },
                  ),
                Text('ან აირჩიე სხვა დღე:', style: TextStyle(color: s.pc.muted, fontSize: 13.5)),
              ],
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: m,
                    decoration: const InputDecoration(labelText: 'თვე'),
                    items: [for (var i = 1; i <= 12; i++) DropdownMenuItem(value: i, child: Text(monthNames[i - 1]))],
                    onChanged: (v) => set(() => m = v ?? m),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: d,
                    decoration: const InputDecoration(labelText: 'დღე'),
                    items: [for (var i = 1; i <= 31; i++) DropdownMenuItem(value: i, child: Text('$i'))],
                    onChanged: (v) => set(() => d = v ?? d),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(controller: label, maxLength: 80, decoration: const InputDecoration(labelText: 'წმინდანი ან დღესასწაული', hintText: 'მაგ. წმ. გიორგის ხსენება', counterText: '')),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () {
                  Navigator.of(s).pop();
                  _save('${two(m)}-${two(d)}', label.text.trim());
                },
                child: const Text('შენახვა'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, me = context.me, app = context.app;
    final today = mdOf(DateTime.now());
    final mine = nameDaysOf(me.name, own, ownLabel).map((x) => (x.$1, x.$2, daysUntil(x.$1))).toList()..sort((a, b) => a.$3.compareTo(b.$3));
    final tf = feastsOn(today);
    final fr = [
      for (final id in app.friends.friends)
        if (app.people[id] != null && nameDaysOf(app.people[id]!.name, app.people[id]!.nameday, app.people[id]!.namedayLabel).any((x) => x.$1 == today)) app.people[id]!,
    ];
    final up = <(DateTime, List<(String, List<String>)>)>[];
    final seen = <String>{};
    for (var i = 1; i <= 45; i++) {
      final d = DateTime.now().add(Duration(days: i));
      final fs = feastsOn(mdOf(d)).where((f) => f.$1 != 'ყოველთა წმინდათა ხსენება' || !seen.contains(f.$1)).toList();
      if (fs.isEmpty) continue;
      for (final f in fs) {
        seen.add(f.$1);
      }
      up.add((d, fs));
    }
    final v = firstName(q);
    final hits = v.isEmpty ? const <(List<String>, List<(String, String)>)>[] : nameDays.where((x) => x.$1.any((n) => n.startsWith(v) || latn(n).startsWith(v))).take(8).toList();
    Widget sec(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 22, 16, 8), child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)));
    Widget row(Widget lead, String title, String sub) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            lead,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                Text(sub, style: TextStyle(color: c.muted, fontSize: 13, height: 1.35)),
              ]),
            ),
          ]),
        );
    return Scaffold(
      appBar: peeraBar(context, title: 'სახელის დღეები'),
      body: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Color.alphaBlend(c.vine.withValues(alpha: .12), c.surface), borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ჩემი ანგელოზის დღე', style: TextStyle(color: c.vine, fontWeight: FontWeight.w800, fontSize: 12.5, letterSpacing: .3)),
            const SizedBox(height: 6),
            if (mine.isEmpty)
              Text('შენი სახელი (${firstName(me.name).isEmpty ? '—' : firstName(me.name)}) კალენდარში ვერ ვიპოვე. მიუთითე დღე თავად, მეგობრებს შევახსენებთ.', style: const TextStyle(fontSize: 14.5, height: 1.4))
            else
              for (final x in mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: mdText(x.$1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    TextSpan(text: '  ${x.$2} · ${whenText(x.$3)}', style: TextStyle(color: c.muted, fontSize: 13.5)),
                  ])),
                ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              FilledButton.icon(
                key: const ValueKey('nd-set'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                onPressed: _pick,
                icon: PIcon('edit', size: 16, color: c.onAccent),
                label: Text(own != null ? 'შეცვლა' : 'მითითება'),
              ),
              if (own != null)
                OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)), onPressed: () => _save(null, ''), child: const Text('კალენდრით განსაზღვრა')),
            ]),
          ]),
        ),
        sec('დღეს, ${mdText(today)}'),
        if (tf.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('დღეს კალენდარში სახელობის დღე არ არის.', style: TextStyle(color: c.muted)))
        else
          for (final f in tf) row(const Text('🕯', style: TextStyle(fontSize: 22)), f.$1, f.$2.take(10).join(', ')),
        for (final p in fr)
          ListTile(
            leading: Avatar(p: p, size: 40),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('ანგელოზის დღე დღეს', style: TextStyle(color: c.vine, fontSize: 13)),
            trailing: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 12)),
              onPressed: () async {
                final conv = await context.app.api.startDm(p.id);
                if (context.mounted) await openChat(context, conv);
              },
              child: const Text('მილოცვა'),
            ),
          ),
        sec('სახელის მოძებნა'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            key: const ValueKey('nd-search'),
            onChanged: (x) => setState(() => q = x),
            decoration: const InputDecoration(hintText: 'მაგ. ნინო, გიორგი, Tamar', prefixIcon: Padding(padding: EdgeInsets.all(12), child: PIcon('search', size: 18))),
          ),
        ),
        if (v.isNotEmpty && hits.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text('ამ სახელს კალენდარში ვერ ვპოულობ. შეიძლება მას ანგელოზის დღედ ყოველთა წმინდათა ხსენება (24 დეკემბერი) ჰქონდეს.', style: TextStyle(color: c.muted, fontSize: 13.5)),
          ),
        for (final h in hits) row(PIcon('cal', size: 20, color: c.accent), h.$1.take(4).join(', '), h.$2.map((x) => '${mdText(x.$1)} · ${x.$2}').join('\n')),
        sec('მომავალი დღეები'),
        if (up.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('მომდევნო დღეებში ჩანაწერი არ არის.', style: TextStyle(color: c.muted)))
        else
          for (final (d, fs) in up)
            row(
              SizedBox(
                width: 40,
                child: Column(children: [
                  Text('${d.day}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(monthNames[d.month - 1].substring(0, 3), style: TextStyle(color: c.muted, fontSize: 11.5)),
                ]),
              ),
              fs.map((f) => f.$1).join(' · '),
              fs.map((f) => f.$2.take(8).join(', ')).join('\n'),
            ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Text('თარიღები ახალი სტილითაა. ერთ სახელს ხშირად რამდენიმე წმინდანი ჰყავს: თუ შენ სხვა დღეს აღნიშნავ, მიუთითე ის „ჩემს ანგელოზის დღეში“.',
              style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4)),
        ),
      ]),
    );
  }
}
