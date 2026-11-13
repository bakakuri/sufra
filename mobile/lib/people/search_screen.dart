import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../feed/post_card.dart';
import '../feed/tag_screen.dart';
import '../home/services.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'person_screen.dart';

/// Searching (home.js PG.search): people, posts, pages and channels, groups, as you type; "#…" opens a topic. Before
/// anything is typed: the topics in fashion and people I may know.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.tab = 'all'});

  /// all, people, posts, pages or groups
  final String tab;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

typedef _Found = ({List<Profile> people, List<Post> posts, List<Map<String, dynamic>> pages, List<Map<String, dynamic>> groups});

class _SearchScreenState extends State<SearchScreen> {
  final field = TextEditingController();
  Timer? _wait;
  late String tab = widget.tab;
  _Found? found;
  List<(String, int)>? trends;
  List<Suggestion>? maybe;
  bool busy = false;
  Object? error;
  int _gen = 0;
  bool _started = false;

  static const tabs = [('all', 'ყველა'), ('people', 'ადამიანები'), ('posts', 'პოსტები'), ('pages', 'გვერდები'), ('groups', 'ჯგუფები')];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final api = context.app.api;
    api.trendingTags().then((t) {
      if (mounted) setState(() => trends = t);
    }).catchError((_) {
      if (mounted) setState(() => trends = const []);
    });
    api.suggestions().then((s) {
      if (mounted) setState(() => maybe = s.take(8).toList());
    }).catchError((_) {
      if (mounted) setState(() => maybe = const []);
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    field.dispose();
    super.dispose();
  }

  void _changed(String q) {
    _wait?.cancel();
    final v = q.trim();
    if (v.length < 2 || v.startsWith('#')) {
      _gen++;
      setState(() {
        found = null;
        busy = false;
        error = null;
      });
      return;
    }
    _wait = Timer(const Duration(milliseconds: 320), () => _run(v));
  }

  Future<void> _run(String q) async {
    final g = ++_gen, api = context.app.api, app = context.app;
    setState(() => busy = true);
    final k = tab, s = q.startsWith('@') ? q.substring(1) : q;
    try {
      final people = k == 'all' || k == 'people' ? api.search(s) : Future.value(<Profile>[]);
      final posts = k == 'all' || k == 'posts' ? api.searchPosts(q) : Future.value(<Post>[]);
      final pages = k == 'all' || k == 'pages' ? api.searchPages(q) : Future.value(<Map<String, dynamic>>[]);
      final groups = k == 'all' || k == 'groups' ? api.searchGroups(q) : Future.value(<Map<String, dynamic>>[]);
      final r = (people: await people, posts: await posts, pages: await pages, groups: await groups);
      await app.posts.load(r.posts);
      if (!mounted || g != _gen) return;
      setState(() {
        found = (
          people: k == 'all' ? r.people.take(5).toList() : r.people,
          posts: r.posts,
          pages: k == 'all' ? r.pages.take(4).toList() : r.pages,
          groups: k == 'all' ? r.groups.take(4).toList() : r.groups,
        );
        busy = false;
        error = null;
      });
    } catch (e) {
      if (!mounted || g != _gen) return;
      setState(() {
        busy = false;
        error = e;
      });
    }
  }

  void _tab(String k) {
    setState(() => tab = k);
    final v = field.text.trim();
    if (v.length >= 2 && !v.startsWith('#')) _run(v);
  }

  Widget _sec(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)));

  Widget _box(Map<String, dynamic> g, {required bool group}) {
    final c = context.pc, name = '${g['name'] ?? ''}', hue = asInt(g['hue'], 200), url = g['avatar_url'] as String?;
    final sub = group
        ? [g['is_private'] == true ? '🔒 დახურული ჯგუფი' : 'ღია ჯგუფი', if ('${g['description'] ?? ''}'.isNotEmpty) '${g['description']}']
        : [g['kind'] == 'business' ? 'ბიზნესი' : 'არხი', if ('${g['category'] ?? ''}'.isNotEmpty) '${g['category']}'];
    return ListTile(
      key: ValueKey('${group ? 'sg' : 'spg'}-${g['id']}'),
      leading: Container(
        width: 44,
        height: 44,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: HSLColor.fromAHSL(1, (hue % 360).toDouble(), .5, .45).toColor(), borderRadius: BorderRadius.circular(12)),
        child: url != null && url.startsWith('http')
            ? PImage(url)
            : Center(child: Text(name.isEmpty ? '?' : name.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
      ),
      title: Row(children: [
        Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
        if (g['verified'] == true) const Padding(padding: EdgeInsets.only(left: 4), child: Verified(size: 15)),
      ]),
      subtitle: Text(sub.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted)),
      onTap: () => openService(context, group ? 'group' : 'pagev', arg: '${g['id']}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, q = field.text.trim(), f = found;
    final body = <Widget>[];
    if (q.startsWith('#') && q.length > 1) {
      final tag = q.substring(1).toLowerCase();
      body.add(ListTile(
        key: const ValueKey('s-tag'),
        leading: CircleAvatar(radius: 22, backgroundColor: c.accentSoft, child: Text('#', style: TextStyle(color: c.accent, fontSize: 20, fontWeight: FontWeight.w800))),
        title: Text('#$tag', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('ნახე ყველა პოსტი ამ ჰეშთეგით', style: TextStyle(color: c.muted)),
        onTap: () => openPage(context, TagScreen(tag: tag)),
      ));
    } else if (error != null) {
      body.add(Empty(icon: 'search', title: 'ძიება ვერ მოხერხდა', text: errText(error!)));
    } else if (f == null) {
      if ((trends ?? const []).isNotEmpty) {
        body.add(_sec('ტრენდები'));
        body.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (t, n) in trends!)
              ActionChip(
                key: ValueKey('trend-$t'),
                label: Text('#$t  $n'),
                onPressed: () => openPage(context, TagScreen(tag: t)),
              ),
          ]),
        ));
      }
      if ((maybe ?? const []).isNotEmpty) {
        body.add(_sec('შეიძლება იცნობდე'));
        for (final s in maybe!) {
          body.add(PersonRow(p: s.p, sub: s.mutual > 0 ? '${s.mutual} საერთო მეგობარი' : null, onTap: () => openPage(context, PersonScreen(uid: s.p.id, initial: s.p))));
        }
      }
      if (body.isEmpty && trends != null && maybe != null) body.add(const Empty(icon: 'search', title: 'დაიწყე წერა', text: 'მოძებნე ადამიანები, პოსტები ან #ჰეშთეგები.'));
    } else if (f.people.isEmpty && f.posts.isEmpty && f.pages.isEmpty && f.groups.isEmpty) {
      body.add(Empty(icon: 'search', title: 'ვერაფერი მოიძებნა', text: '„$q“ — სცადე სხვა სიტყვით.'));
    } else {
      if (f.people.isNotEmpty) {
        body.add(_sec('ადამიანები'));
        for (final p in f.people) {
          body.add(PersonRow(key: ValueKey('sp-${p.id}'), p: p, onTap: () => openPage(context, PersonScreen(uid: p.id, initial: p))));
        }
      }
      if (f.pages.isNotEmpty) {
        body.add(_sec('გვერდები და არხები'));
        for (final g in f.pages) {
          body.add(_box(g, group: false));
        }
      }
      if (f.groups.isNotEmpty) {
        body.add(_sec('ჯგუფები'));
        for (final g in f.groups) {
          body.add(_box(g, group: true));
        }
      }
      if (f.posts.isNotEmpty) {
        body.add(_sec('პოსტები'));
        body.add(const SizedBox(height: 6));
        for (final p in f.posts) {
          body.add(PostCard(key: ValueKey('spost-${p.id}'), post: p));
        }
      }
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        leading: backButton(context),
        titleSpacing: 0,
        title: TextField(
          key: const ValueKey('s-q'),
          controller: field,
          autofocus: true,
          onChanged: _changed,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'ადამიანები, პოსტები, #ჰეშთეგები',
            isDense: true,
            prefixIcon: Padding(padding: const EdgeInsets.all(11), child: PIcon('search', size: 20, color: c.muted)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: c.accent, width: 1.5)),
          ),
        ),
        actions: const [SizedBox(width: 14)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 48,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 4, 12, 8), children: [
              for (final (k, l) in tabs)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: ValueKey('stab-$k'),
                    label: Text(l),
                    selected: tab == k,
                    showCheckmark: false,
                    selectedColor: c.accentSoft,
                    side: BorderSide(color: tab == k ? c.accent : c.line),
                    onSelected: (_) => _tab(k),
                  ),
                ),
            ]),
          ),
        ),
      ),
      body: Column(children: [
        if (busy) LinearProgressIndicator(minHeight: 2, color: c.accent, backgroundColor: Colors.transparent),
        Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 24), children: body)),
      ]),
    );
  }
}

/// A person in a list: picture, name, a line under it and something on the right.
class PersonRow extends StatelessWidget {
  const PersonRow({super.key, required this.p, required this.onTap, this.sub, this.trailing, this.size = 50});
  final Profile p;
  final VoidCallback onTap;
  final String? sub;
  final Widget? trailing;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final line = sub ?? [if ((p.username ?? '').isNotEmpty) '@${p.username}', if ((p.city ?? '').isNotEmpty) p.city!].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Avatar(p: p, size: size, online: p.online),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              NameLine(p, size: 15.5),
              if (line.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 13.5)),
                ),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      ),
    );
  }
}
