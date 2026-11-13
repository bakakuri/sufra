import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../home/calendar.dart';
import '../home/home_cards.dart';
import '../home/promos.dart';
import '../home/services.dart';
import '../notes/notes_screen.dart';
import '../people/person_screen.dart';
import '../people/profile_parts.dart';
import '../people/search_screen.dart';
import '../stories/stories.dart';
import '../ui/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'compose_screen.dart';
import 'post_actions.dart';
import 'post_card.dart';

/// how the feed starts: 'for' (you), 'friends' or 'new' (the tests start with the newest first)
String feedStartMode = 'for';

/// one thing in the feed: a post, a paid post, a sponsored post of the admin's, or people you may know
class FeedItem {
  const FeedItem.post(Post this.post, {this.ad})
      : promo = null,
        suggest = false;
  const FeedItem.promo(Promo this.promo)
      : post = null,
        ad = null,
        suggest = false;
  const FeedItem.suggest()
      : post = null,
        promo = null,
        ad = null,
        suggest = true;
  final Post? post;
  final Promo? promo;
  final int? ad;
  final bool suggest;
}

/// The main tab, as the site's home page (home.js): the admin's banner, the stories (with friends' days coming up and
/// sponsored stories), the services, the first steps, "on this day", writing something, and the feed (for you,
/// friends, the newest), with people you may know and sponsored posts among the posts. More as you scroll.
class FeedTab extends StatefulWidget {
  const FeedTab({super.key, this.pageSize = 10});
  final int pageSize;
  @override
  State<FeedTab> createState() => FeedTabState();
}

class FeedTabState extends State<FeedTab> {
  final items = <FeedItem>[];
  List<Post> get posts => [for (final i in items) if (i.post != null && i.ad == null) i.post!];
  bool loading = true, more = false, done = false;
  late String mode = feedStartMode;
  Object? error;
  int _gen = 0, _count = 0, _nextPromo = 3;
  String? _cursor;
  bool _started = false;
  final scroll = ScrollController();
  final _seen = <int>{};
  Set<String> _tags = {};
  bool _tagsRead = false;
  List<Promo> _promoQ = [];
  List<(int, Post)> _adQ = [];

  /// friends' days in the next two weeks, sponsored stories (and which were seen), new guests
  List<FriendDay> remind = const [];
  List<Promo> promoStories = const [];
  Set<int> seenPromos = {};
  int newGuests = 0;
  final _steps = GlobalKey<FirstStepsCardState>();

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (scroll.position.extentAfter < 900) load(false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      postOverrides.load();
      _extras();
      load(true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) welcomeGift(context);
      });
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  /// back to the top (the tab tapped again)
  void top() {
    if (scroll.hasClients) scroll.animateTo(0, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  /// what stands above the feed: the settings and numbers, friends' days, sponsored stories, new guests
  Future<void> _extras({bool force = false}) async {
    final app = context.app;
    app.home.load(force: force);
    final off = app.home.off, admin = context.me.role == 'admin';
    upcomingDays(context, 14).then((d) {
      if (mounted && (admin || !app.home.off.contains('calendar'))) setState(() => remind = d);
    }, onError: (_) {});
    loadPromos(context).then((r) {
      if (mounted && (admin || !off.contains('stories'))) {
        setState(() {
          promoStories = r.$2;
          seenPromos = r.$3;
        });
      }
    });
    try {
      final n = await app.api.guestsSince(await guestsSeenAt());
      if (mounted) setState(() => newGuests = n);
    } catch (_) {}
  }

  /// a post and its plain reposts show once
  int _key(Post p) => p.plainRepost && p.repostOf != null ? p.repostOf! : p.id;

  double _score(Post p) {
    final app = context.app, s = app.posts.of(p.id);
    final h = DateTime.now().difference(p.createdAt).inMinutes / 60;
    final topic = _tags.isNotEmpty && p.tags.any((t) => _tags.contains(t.toLowerCase())) ? 4 : 0;
    final friend = app.friends.friends.contains(p.author) ? 3 : 0, mine = p.author == app.api.myId ? 1 : 0;
    return (1 + s.total + s.comments * 2 + s.gradeN + topic + friend + mine) / math.pow(h + 2, 1.3);
  }

  Future<void> load(bool reset) async {
    if (!reset && (more || done || loading)) return;
    final app = context.app, me = context.me, m = mode;
    final g = reset ? ++_gen : _gen;
    setState(() {
      if (reset) {
        loading = items.isEmpty;
        error = null;
      } else {
        more = true;
      }
    });
    try {
      if (m == 'for' && !_tagsRead) {
        _tagsRead = true;
        try {
          _tags = await app.api.tagFollows();
        } catch (_) {}
      }
      List<String>? authors;
      if (m == 'friends') {
        if (!app.friends.loaded) await app.friends.load();
        authors = [me.id, ...app.friends.friends];
      }
      if (reset) app.stories.load();
      var rows = await app.api.feed(authors: authors, before: reset ? null : _cursor, limit: widget.pageSize);
      final last = rows.lastOrNull?.cursor;
      final end = rows.length < widget.pageSize;
      // posts on the topics I follow come in even when they are older than the newest ones
      if (m == 'for' && reset && _tags.isNotEmpty) {
        try {
          final have = rows.map((p) => p.id).toSet();
          rows = [...rows, ...(await app.api.feedTagged(_tags.toList())).where((p) => !have.contains(p.id))];
        } catch (_) {}
      }
      var promoQ = _promoQ, adQ = _adQ;
      if (reset) {
        adQ = m == 'friends' ? [] : await app.api.adPosts().catchError((_) => <(int, Post)>[]);
        promoQ = m == 'friends' || !mounted ? [] : (await loadPromos(context)).$1;
      }
      await app.posts.load([...rows, for (final a in adQ) a.$2]);
      if (!mounted || g != _gen) return;
      final seen = reset ? <int>{} : _seen;
      rows = rows.where((p) => seen.add(_key(p))).toList();
      if (m == 'for') rows.sort((a, b) => _score(b).compareTo(_score(a)));
      setState(() {
        if (reset) {
          items.clear();
          _seen
            ..clear()
            ..addAll(seen);
          _count = 0;
          _nextPromo = 3;
          _promoQ = [...promoQ];
          _adQ = [...adQ];
        }
        for (final p in rows) {
          _count++;
          items.add(FeedItem.post(p));
          if (_promoQ.isNotEmpty && _count >= _nextPromo) {
            final pr = _promoQ.removeAt(0);
            items.add(FeedItem.promo(pr));
            _nextPromo = _count + pr.every;
            promoSeen(context, pr.id);
          }
          if (_count % 6 == 0 && _adQ.isNotEmpty) {
            final ad = _adQ.removeAt(0);
            items.add(FeedItem.post(ad.$2, ad: ad.$1));
            adSeen(context, ad.$1);
          }
          if (reset && _count == 2) items.add(const FeedItem.suggest());
        }
        _cursor = last ?? _cursor;
        done = end;
        loading = false;
        more = false;
        error = null;
      });
    } catch (e) {
      if (!mounted || g != _gen) return;
      setState(() {
        error = e;
        loading = false;
        more = false;
      });
    }
  }

  void _mode(String m) {
    if (m == mode) return;
    setState(() {
      mode = m;
      items.clear();
      done = false;
    });
    load(true);
  }

  Future<void> _refresh() async {
    _extras(force: true);
    _steps.currentState?.reload();
    await load(true);
  }

  Future<void> _write({bool photos = false, bool poll = false, String text = ''}) async {
    final p = await openPage<Post>(context, ComposeScreen(startWithPhotos: photos, startWithPoll: poll, text: text), full: true);
    if (p == null || !mounted) return;
    setState(() => items.insert(0, FeedItem.post(p)));
    context.app.posts.load([p]);
    toast(context, 'გამოქვეყნდა');
    _steps.currentState?.reload();
  }

  Future<void> _topics() async {
    if (await topicsSheet(context) && mounted) {
      _tagsRead = false;
      if (mode == 'for') {
        setState(() => items.clear());
        load(true);
      }
    }
  }

  Future<void> _guests() async {
    setState(() => newGuests = 0);
    await guestsSheet(context, open: (uid) => openPage(context, PersonScreen(uid: uid)), invisible: context.me.guest);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final empty = !loading && items.isEmpty;
    return Scaffold(
      appBar: peeraBar(context, actions: [
        IconBtn('search', label: 'ძებნა', onTap: () => openPage(context, const SearchScreen())),
        ValueListenableBuilder<int>(
          valueListenable: context.app.unreadNotes,
          builder: (context, n, _) => IconBtn('bell', key: const ValueKey('bell'), label: 'შეტყობინებები', badge: n, onTap: () => openNotes(context)),
        ),
        IconBtn('eye', key: const ValueKey('guests'), label: 'სტუმრები', badge: newGuests, onTap: _guests),
        IconBtn('grid', key: const ValueKey('services'), label: 'სერვისები', onTap: () => servicesMenu(context)),
        IconBtn('plus', key: const ValueKey('create'), label: 'შექმნა', onTap: () => createMenu(context, write: ({photos = false, poll = false}) => _write(photos: photos, poll: poll))),
      ]),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(controller: scroll, physics: const AlwaysScrollableScrollPhysics(), slivers: [
          const SliverToBoxAdapter(child: HomeBanner()),
          SliverToBoxAdapter(
            child: StoriesBar(extra: [
              if (remind.isNotEmpty) ReminderRing(days: remind, onTap: () => remindersSheet(context, remind)),
              for (final p in promoStories)
                PromoRing(
                  p: p,
                  seen: seenPromos.contains(p.id),
                  onTap: () async {
                    await openPromoStory(context, p);
                    if (mounted) setState(() => seenPromos = {...seenPromos, p.id});
                  },
                ),
            ]),
          ),
          const SliverToBoxAdapter(child: ServicesStrip()),
          SliverToBoxAdapter(child: FirstStepsCard(key: _steps, onWrite: (t) => _write(text: t))),
          SliverToBoxAdapter(child: MemoriesCard(onShare: (t) => _write(text: t))),
          SliverToBoxAdapter(child: _Prompt(onWrite: () => _write(), onPhoto: () => _write(photos: true), onPoll: () => _write(poll: true))),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 4, 10),
              child: Row(children: [
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(21)),
                    child: Row(children: [
                      for (final (k, l) in const [('for', 'შენთვის'), ('friends', 'მეგობრები'), ('new', 'ახალი')])
                        Expanded(child: _Chip(l, key: ValueKey('feed-$k'), on: mode == k, onTap: () => _mode(k))),
                    ]),
                  ),
                ),
                IconBtn('star', key: const ValueKey('topics'), label: 'ჩემი თემები', size: 22, color: c.gold, onTap: _topics),
              ]),
            ),
          ),
          if (loading)
            SliverList.list(children: const [SkeletonPost(), SkeletonPost(photo: false)])
          else if (error != null && items.isEmpty)
            SliverToBoxAdapter(child: Empty(icon: 'globe', title: 'ფიდი ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: () => load(true)))
          else if (empty)
            SliverToBoxAdapter(
              child: Column(children: [
                Empty(
                  icon: mode == 'friends' ? 'users' : 'home',
                  title: mode == 'friends' ? 'მეგობრების პოსტები ჯერ არ არის' : 'აქ ჯერ ცარიელია',
                  text: mode == 'friends' ? 'დაამატე მეგობრები და მათი პოსტები აქ გამოჩნდება.' : 'დაწერე პირველი პოსტი ან მოიწვიე მეგობრები.',
                ),
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                  FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => _write(), child: const Text('პოსტის დაწერა')),
                  OutlinedButton(
                    key: const ValueKey('empty-invite'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => inviteSheet(context),
                    child: const Text('მეგობრის მოწვევა'),
                  ),
                ]),
                const SizedBox(height: 24),
              ]),
            )
          else
            SliverList.builder(
              itemCount: items.length + 1,
              itemBuilder: (_, i) {
                if (i == items.length) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    child: Center(
                      child: more
                          ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
                          : error != null
                              ? TextButton(onPressed: () => load(false), child: const Text('ვერ ჩაიტვირთა — ხელახლა'))
                              : done && _count > 0
                                  ? Text('ყველაფერი ნახე', style: TextStyle(color: c.muted))
                                  : const SizedBox(height: 24),
                    ),
                  );
                }
                final it = items[i];
                if (it.suggest) return const SuggestRow();
                if (it.promo != null) {
                  final pr = it.promo!;
                  return PromoCard(p: pr, onHidden: () => setState(() => items.removeWhere((x) => x.promo?.id == pr.id)));
                }
                final p = it.post!;
                return PostCard(
                  key: ValueKey(it.ad != null ? 'ad-${it.ad}' : 'post-${p.id}'),
                  post: p,
                  sponsored: it.ad != null,
                  onDeleted: () => setState(() => items.removeWhere((x) => x.post?.id == p.id)),
                );
              },
            ),
        ]),
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.onWrite, required this.onPhoto, required this.onPoll});
  final VoidCallback onWrite, onPhoto, onPoll;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, me = context.me;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
      child: Row(children: [
        Avatar(p: me, size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            button: true,
            label: 'პოსტის დაწერა',
            child: GestureDetector(
              key: const ValueKey('compose'),
              behavior: HitTestBehavior.opaque,
              onTap: onWrite,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(21)),
                child: Text('რა ხდება, ${me.name.split(' ').first}?', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 15)),
              ),
            ),
          ),
        ),
        IconBtn('image', key: const ValueKey('compose-photo'), label: 'ფოტოს დამატება', color: c.vine, onTap: onPhoto),
        IconBtn('poll', key: const ValueKey('compose-poll'), label: 'გამოკითხვა', color: c.gold, onTap: onPoll),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {super.key, required this.on, required this.onTap});
  final String text;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: on ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: on ? const [BoxShadow(color: Color(0x1A141830), blurRadius: 6, offset: Offset(0, 1))] : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text, style: TextStyle(color: on ? c.ink : c.muted, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ),
      ),
    );
  }
}

/// Posts of one person, for their page.
class PostsColumn extends StatelessWidget {
  const PostsColumn({super.key, required this.posts, required this.onDeleted});
  final List<Post> posts;
  final void Function(Post) onDeleted;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final p in posts) PostCard(key: ValueKey('post-${p.id}'), post: p, onDeleted: () => onDeleted(p)),
      ]);
}
