import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../home/calendar.dart';
import '../home/home_cards.dart';
import '../home/promos.dart';
import '../home/services.dart';
import '../people/profile_parts.dart';
import '../stories/stories.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'compose_screen.dart';
import 'mix_cards.dart';
import 'post_actions.dart';
import 'post_card.dart';
import 'reels_row.dart';

/// how the feed starts: 'for' (you), 'friends' or 'new' (the tests start with the newest first)
String feedStartMode = 'for';

/// one thing in the feed: a post, a paid post, a sponsored post of the admin's, people you may know, or the clips
class FeedItem {
  const FeedItem.post(Post this.post, {this.ad})
      : promo = null,
        suggest = false,
        album = null,
        match = null,
        reels = false;
  const FeedItem.promo(Promo this.promo)
      : post = null,
        ad = null,
        suggest = false,
        album = null,
        match = null,
        reels = false;
  const FeedItem.suggest()
      : post = null,
        promo = null,
        ad = null,
        suggest = true,
        album = null,
        match = null,
        reels = false;

  /// the clips, sideways, as Facebook's reels
  const FeedItem.reels()
      : post = null,
        promo = null,
        ad = null,
        suggest = false,
        album = null,
        match = null,
        reels = true;

  /// "for you" brings a shared album and a coming or live match among the posts
  const FeedItem.album(int this.album)
      : post = null,
        promo = null,
        ad = null,
        suggest = false,
        match = null,
        reels = false;
  const FeedItem.match(int this.match)
      : post = null,
        promo = null,
        ad = null,
        suggest = false,
        album = null,
        reels = false;
  final Post? post;
  final Promo? promo;
  final int? ad;
  final bool suggest, reels;
  final int? album, match;
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

class FeedTabState extends State<FeedTab> with WidgetsBindingObserver {
  /// the keyboard is up (the round "+" steps aside while something is typed)
  bool keyboard = false;
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

  /// what "for you" already showed in this scroll ('p:12', 'a:3', 'm:9'), sent back for the next part
  final _mixSeen = <String>[];
  List<Promo> _promoQ = [];
  List<(int, Post)> _adQ = [];

  /// friends' days in the next two weeks, sponsored stories (and which were seen), new guests
  List<FriendDay> remind = const [];
  List<Promo> promoStories = const [];
  Set<int> seenPromos = {};
  final _steps = GlobalKey<FirstStepsCardState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scroll.addListener(() {
      if (scroll.position.extentAfter < 900) load(false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      // the top bar's + writes through the feed, so the new post lands at its top
      context.app.write = ({bool photos = false, bool poll = false}) => _write(photos: photos, poll: poll);
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
    WidgetsBinding.instance.removeObserver(this);
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
    // friends' days stand in the stories on the day itself, not before it (the days coming up are in the calendar)
    upcomingDays(context, 0).then((d) {
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
      if (mounted) app.newGuests.value = n;
    } catch (_) {}
  }

  /// a post and its plain reposts show once
  int _key(Post p) => p.plainRepost && p.repostOf != null ? p.repostOf! : p.id;

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
      List<String>? authors;
      if (m == 'friends') {
        if (!app.friends.loaded) await app.friends.load();
        authors = [me.id, ...app.friends.friends];
      }
      if (reset) app.stories.load();
      List<Post> rows;
      String? last;
      bool end;
      int? album, match;
      if (m == 'for') {
        // "for you": a random mix from everywhere (friends, groups, pages, everyone), a shared album, a match
        final seenNow = reset ? <String>[] : [..._mixSeen];
        final mix = await app.api.feedMix(seenNow, limit: widget.pageSize);
        if (reset) _mixSeen.clear();
        _mixSeen.addAll([for (final id in mix.posts) 'p:$id', for (final id in mix.albums) 'a:$id', for (final id in mix.matches) 'm:$id']);
        final got = await app.api.postsByIds(mix.posts);
        final at = {for (var i = 0; i < mix.posts.length; i++) mix.posts[i]: i};
        rows = [...got]..sort((a, b) => (at[a.id] ?? 0).compareTo(at[b.id] ?? 0));
        end = mix.posts.isEmpty;
        album = mix.albums.firstOrNull;
        match = mix.matches.firstOrNull;
      } else {
        rows = await app.api.feed(authors: authors, before: reset ? null : _cursor, limit: widget.pageSize);
        last = rows.lastOrNull?.cursor;
        end = rows.length < widget.pageSize;
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
        var n = 0;
        int? mt = match, al = album;
        for (final p in rows) {
          _count++;
          items.add(FeedItem.post(p));
          // the match after the third post of this part, the album after the sixth
          n++;
          if (n == 3 && mt != null) {
            items.add(FeedItem.match(mt));
            mt = null;
          }
          if (n == 6 && al != null) {
            items.add(FeedItem.album(al));
            al = null;
          }
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
          if (reset && _count == 4) items.add(const FeedItem.reels());
        }
        if (mt != null) items.add(FeedItem.match(mt));
        if (al != null) items.add(FeedItem.album(al));
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
      if (mode == 'for') {
        setState(() => items.clear());
        load(true);
      }
    }
  }

  @override
  void didChangeMetrics() {
    // the tabs do not see the keyboard (the shell makes room for it), so the phone's own view tells
    if (!mounted) return;
    final k = View.of(context).viewInsets.bottom > 0;
    if (k != keyboard) setState(() => keyboard = k);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final empty = !loading && items.isEmpty;
    // the bar with the logo, search, notifications and the rest stands over every tab (the shell's top bar)
    return Scaffold(
      // making anything starts here: the round "+" stays in its place over the feed while it scrolls (only on the feed),
      // and steps aside while something is being typed
      floatingActionButton: AnimatedScale(
        scale: keyboard ? 0 : 1,
        duration: const Duration(milliseconds: 180),
        child: _CreateButton(onTap: () => createMenu(context, write: ({bool photos = false, bool poll = false}) => _write(photos: photos, poll: poll))),
      ),
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
          SliverToBoxAdapter(
            child: _Prompt(
              // my picture is the way to my profile (it has no button on the bar)
              onMe: () => context.app.goTab?.call('me'),
              onWrite: () => _write(),
              onPhoto: () => _write(photos: true),
              onPoll: () => _write(poll: true),
            ),
          ),
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
                if (it.reels) return const ReelsRow();
                if (it.match != null) return MixMatchCard(key: ValueKey('mix-m-${it.match}'), id: it.match!);
                if (it.album != null) return MixAlbumCard(key: ValueKey('mix-a-${it.album}'), id: it.album!);
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
  const _Prompt({required this.onMe, required this.onWrite, required this.onPhoto, required this.onPoll});
  final VoidCallback onMe, onWrite, onPhoto, onPoll;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, me = context.me;
    Widget icon(String name, String key, String label, Color color, VoidCallback onTap) => IconButton(
          key: ValueKey(key),
          tooltip: label,
          onPressed: onTap,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 50),
          icon: PIcon(name, size: 29, color: color),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.line)),
      child: Row(children: [
        Semantics(
          button: true,
          label: 'ჩემი პროფილი',
          excludeSemantics: true,
          child: GestureDetector(key: const ValueKey('compose-me'), behavior: HitTestBehavior.opaque, onTap: onMe, child: Avatar(p: me, size: 48)),
        ),
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
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(25)),
                // the words stay whole inside the field: a long name makes them smaller, never cut
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('რა ხდება, ${me.name.split(' ').first}?', maxLines: 1, style: TextStyle(color: c.muted, fontSize: 18)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        icon('image', 'compose-photo', 'ფოტოს დამატება', c.vine, onPhoto),
        icon('poll', 'compose-poll', 'გამოკითხვა', c.gold, onPoll),
      ]),
    );
  }
}

/// The round "+" over the feed: everything that can be made (a post, a photo, a clip, a poll, a story…)
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Semantics(
      button: true,
      label: 'შექმნა',
      excludeSemantics: true,
      child: Material(
        key: const ValueKey('create'),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(c.accent, Colors.white, .15)!, c.accent],
              ),
              boxShadow: [BoxShadow(color: c.accent.withValues(alpha: .35), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: const Center(child: PIcon('plus', size: 30, color: Colors.white, stroke: 2.6)),
          ),
        ),
      ),
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
