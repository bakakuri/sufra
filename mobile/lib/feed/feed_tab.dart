import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../people/search_screen.dart';
import '../stories/stories.dart';
import '../ui/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'compose_screen.dart';
import 'post_card.dart';

/// The main tab: write something, then everyone's posts (or only friends'), newest first, more as you scroll.
class FeedTab extends StatefulWidget {
  const FeedTab({super.key, this.pageSize = 15});
  final int pageSize;
  @override
  State<FeedTab> createState() => FeedTabState();
}

class FeedTabState extends State<FeedTab> {
  final posts = <Post>[];
  bool loading = true, more = false, done = false, friendsOnly = false;
  Object? error;
  int _gen = 0;
  bool _started = false;
  final scroll = ScrollController();

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
      load(true);
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

  Future<void> load(bool reset) async {
    if (!reset && (more || done || loading)) return;
    final app = context.app, me = context.me;
    final g = reset ? ++_gen : _gen;
    setState(() {
      if (reset) {
        loading = posts.isEmpty;
        error = null;
      } else {
        more = true;
      }
    });
    try {
      List<String>? authors;
      if (friendsOnly) {
        if (!app.friends.loaded) await app.friends.load();
        authors = [me.id, ...app.friends.friends];
      }
      if (reset) app.stories.load();
      final rows = await app.api.feed(authors: authors, before: reset ? null : posts.lastOrNull?.cursor, limit: widget.pageSize);
      await app.posts.load(rows);
      if (!mounted || g != _gen) return;
      setState(() {
        if (reset) posts.clear();
        final have = posts.map((p) => p.id).toSet();
        posts.addAll(rows.where((p) => have.add(p.id)));
        done = rows.length < widget.pageSize;
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

  void _mode(bool friends) {
    if (friends == friendsOnly) return;
    setState(() {
      friendsOnly = friends;
      posts.clear();
      done = false;
    });
    load(true);
  }

  Future<void> _write({bool photos = false}) async {
    final p = await openPage<Post>(context, ComposeScreen(startWithPhotos: photos), full: true);
    if (p == null || !mounted) return;
    setState(() => posts.insert(0, p));
    context.app.posts.load([p]);
    toast(context, 'გამოქვეყნდა');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      appBar: peeraBar(context, actions: [
        IconBtn('search', label: 'ძებნა', onTap: () => openPage(context, const SearchScreen())),
        IconBtn('plus', label: 'ახალი პოსტი', onTap: _write),
      ]),
      body: RefreshIndicator(
        onRefresh: () => load(true),
        child: CustomScrollView(controller: scroll, physics: const AlwaysScrollableScrollPhysics(), slivers: [
          const SliverToBoxAdapter(child: StoriesBar()),
          SliverToBoxAdapter(child: _Prompt(onWrite: _write, onPhoto: () => _write(photos: true))),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
              child: Row(children: [
                _Chip('ყველა', on: !friendsOnly, onTap: () => _mode(false)),
                const SizedBox(width: 8),
                _Chip('მეგობრები', on: friendsOnly, onTap: () => _mode(true)),
              ]),
            ),
          ),
          if (loading)
            SliverList.list(children: const [SkeletonPost(), SkeletonPost(photo: false)])
          else if (error != null && posts.isEmpty)
            SliverToBoxAdapter(child: Empty(icon: 'globe', title: 'ფიდი ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: () => load(true)))
          else if (posts.isEmpty)
            SliverToBoxAdapter(
              child: Empty(
                icon: friendsOnly ? 'users' : 'home',
                title: friendsOnly ? 'მეგობრებს ჯერ არაფერი დაუწერიათ' : 'ჯერ პოსტები არ არის',
                text: friendsOnly ? 'დაამატე მეგობრები ან ნახე ყველას პოსტები.' : 'დაწერე პირველი!',
                action: 'პოსტის დაწერა',
                onAction: _write,
              ),
            )
          else
            SliverList.builder(
              itemCount: posts.length + 1,
              itemBuilder: (_, i) {
                if (i == posts.length) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    child: Center(
                      child: more
                          ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
                          : error != null
                              ? TextButton(onPressed: () => load(false), child: const Text('ვერ ჩაიტვირთა — ხელახლა'))
                              : done
                                  ? Text('სულ ესაა', style: TextStyle(color: c.muted))
                                  : const SizedBox(height: 24),
                    ),
                  );
                }
                final p = posts[i];
                return PostCard(key: ValueKey('post-${p.id}'), post: p, onDeleted: () => setState(() => posts.removeWhere((x) => x.id == p.id)));
              },
            ),
        ]),
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.onWrite, required this.onPhoto});
  final VoidCallback onWrite, onPhoto;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, me = context.me;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
      child: Row(children: [
        Avatar(p: me, size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            button: true,
            label: 'პოსტის დაწერა',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onWrite,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(21)),
                child: Text('რას ფიქრობ, ${me.name}?', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 15)),
              ),
            ),
          ),
        ),
        IconBtn('image', label: 'ფოტოს დამატება', color: c.vine, onTap: onPhoto),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {required this.on, required this.onTap});
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
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: on ? c.ink : c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? c.ink : c.line),
          ),
          child: Text(text, style: TextStyle(color: on ? c.bg : c.ink, fontWeight: FontWeight.w700, fontSize: 14)),
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
