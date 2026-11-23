// Saved things as Facebook keeps them (home.js svPage): the collections as cards with a picture and how many are in
// each (the first card makes a new one), then everything saved, each on a line with its picture, what it is and whose,
// a button to put it into a collection and "…" for the rest. A collection opens on its own page.
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../feed/comments_sheet.dart';
import '../feed/post_actions.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/motion.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// a post's picture for a card or a line: its first photo, or a video's poster
String? _pic(Post? p) {
  if (p == null) return null;
  for (final m in p.media) {
    final u = m.isVideo ? m.poster : m.small;
    if (u != null && u.startsWith('http')) return u;
  }
  return null;
}

String _kind(Post p) => p.isClip
    ? 'კლიპი'
    : p.media.any((m) => m.isVideo)
        ? 'ვიდეო'
        : p.media.isNotEmpty
            ? 'ფოტო'
            : 'პოსტი';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key, this.folder});

  /// one collection (id and name), or everything
  final (int, String)? folder;
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<(int, String)> folders = const [];

  /// what is saved, newest first: the post and its collection
  List<(int, int?)> items = const [];
  final posts = <int, Post>{};
  bool loaded = false;
  Object? error;
  bool _started = false;
  late String title = widget.folder?.$2 ?? 'შენახული';

  int? get folder => widget.folder?.$1;

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
      final f = await app.api.saveFolders();
      final all = await app.api.savedItems();
      final mine = [for (final x in all) if (folder == null || x.$2 == folder) x];
      // the lines, and each collection's newest for its card
      final want = <int>{
        for (final x in mine.take(90)) x.$1,
        if (folder == null)
          for (final (id, _) in f) ...[for (final x in all) if (x.$2 == id) x.$1].take(1),
      };
      final ps = want.isEmpty ? const <Post>[] : await app.api.postsByIds(want.toList());
      await app.posts.load(ps);
      await app.people.ensure({for (final p in ps) if (p.ap == null) p.author});
      if (!mounted) return;
      setState(() {
        folders = f;
        items = all;
        posts
          ..clear()
          ..addAll({for (final p in ps) p.id: p});
        loaded = true;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _newFolder() async {
    final name = await _askName(context, 'ახალი კოლექცია', '');
    if (name == null || !mounted) return;
    if (await attempt(context, () => context.app.api.newFolder(name)) && mounted) {
      toast(context, 'კოლექცია „$name“ შეიქმნა');
      _load();
    }
  }

  Future<void> _move(int postId) async {
    await folderPick(context, postId);
    if (mounted) _load();
  }

  Future<void> _open(Post p) async {
    await openPost(context, p);
  }

  Future<void> _menu(Post p) => showChoices(context, [
        SheetItem('eye', 'გახსნა', () => _open(p)),
        SheetItem('folder', 'კოლექციაში გადატანა', () => _move(p.id)),
        SheetItem('x', 'შენახულიდან ამოშლა', () async {
          if (!await attempt(context, () => context.app.api.save(p.id, false)) || !mounted) return;
          context.app.posts.of(p.id).saved = false;
          toast(context, 'შენახულიდან ამოიშალა');
          setState(() => items = [for (final x in items) if (x.$1 != p.id) x]);
        }),
      ]);

  /// a collection's own "…": a new name, or away (what is in it stays saved)
  Future<void> _folderMenu() async {
    final f = widget.folder;
    if (f == null) return;
    await showChoices(context, [
      SheetItem('edit', 'სახელის შეცვლა', () async {
        final name = await _askName(context, 'კოლექციის სახელი', title);
        if (name == null || !mounted) return;
        if (await attempt(context, () => context.app.api.renameFolder(f.$1, name)) && mounted) setState(() => title = name);
      }),
      SheetItem('trash', 'კოლექციის წაშლა', () async {
        if (!await confirm(context, title: 'წაიშალოს კოლექცია?', text: 'რაც შიგ არის, შენახულში დარჩება.', yes: 'წაშლა', danger: true) || !mounted) return;
        if (await attempt(context, () => context.app.api.deleteFolder(f.$1)) && mounted) Navigator.of(context).maybePop();
      }, danger: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final mine = [for (final x in items) if ((folder == null || x.$2 == folder) && posts.containsKey(x.$1)) x];
    Widget head(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        );
    return Scaffold(
      appBar: peeraBar(context, title: title, actions: [
        if (widget.folder != null) IconBtn('more', key: const ValueKey('svf-more'), label: 'კოლექციის მართვა', onTap: _folderMenu),
      ]),
      body: !loaded
          ? (error != null
              ? Center(child: Empty(icon: 'bookmark', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'თავიდან', onAction: _load))
              : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
                if (folder == null) ...[
                  head('კოლექციები'),
                  SizedBox(
                    height: 206,
                    child: ListView.separated(
                      key: const ValueKey('sv-row'),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      itemCount: folders.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return Rise(order: 0, dy: 0, child: _FolderCard(key: const ValueKey('svc-new'), name: 'ახალი კოლექცია', onTap: _newFolder));
                        }
                        final (id, name) = folders[i - 1];
                        final its = [for (final x in items) if (x.$2 == id) x.$1];
                        return Rise(
                          order: i,
                          dy: 0,
                          child: _FolderCard(
                            key: ValueKey('svc-$id'),
                            name: name,
                            count: its.length,
                            pic: its.isEmpty ? null : _pic(posts[its.first]),
                            onTap: () async {
                              await openPage(context, SavedScreen(folder: (id, name)), full: true);
                              if (mounted) _load();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
                head(folder == null ? 'ყველა' : '${mine.length} ელემენტი'),
                if (mine.isEmpty)
                  Empty(
                    icon: 'bookmark',
                    title: folder != null ? 'ეს კოლექცია ცარიელია' : 'შენახული ჯერ არაფერია',
                    text: folder != null ? 'შენახულ პოსტთან „კოლექციაში“ დააჭირე და აქ გადმოვა.' : 'პოსტის 🔖 ღილაკით შეინახე, რაც მოგეწონა.',
                  )
                else
                  for (final (i, (pid, fid)) in mine.take(90).indexed)
                    Rise(
                      key: ValueKey('svi-$pid'),
                      order: i,
                      dy: 10,
                      child: _line(posts[pid]!, folder == null && fid != null ? [for (final f in folders) if (f.$1 == fid) f.$2].firstOrNull : null, c),
                    ),
              ]),
            ),
    );
  }

  Widget _line(Post p, String? inFolder, PeeraColors c) {
    final who = p.ap ?? context.app.people[p.author] ?? Profile(id: p.author, name: '…');
    final pic = _pic(p);
    final words = p.body.trim().split('\n').first;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          key: ValueKey('svo-${p.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(p),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox.square(
                dimension: 84,
                child: pic != null ? PImage(pic, fit: BoxFit.cover) : ColoredBox(color: c.sunk, child: Center(child: Avatar(p: who, size: 52))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(words.isEmpty ? _kind(p) : words, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.3)),
                const SizedBox(height: 3),
                Text('${_kind(p)} · ${who.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 13)),
                if (inFolder != null) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    PIcon('bookmark', size: 13, color: c.accent),
                    const SizedBox(width: 4),
                    Flexible(child: Text(inFolder, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: 12.5))),
                  ]),
                ],
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 96, top: 8),
          child: Row(children: [
            FilledButton.icon(
              key: ValueKey('svmove-${p.id}'),
              style: FilledButton.styleFrom(
                backgroundColor: c.sunk,
                foregroundColor: c.ink,
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _move(p.id),
              icon: PIcon('folder', size: 16, color: c.ink),
              label: const Text('კოლექციაში', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 4),
            IconBtn('more', key: ValueKey('svmenu-${p.id}'), label: 'მეტი', size: 20, color: c.muted, onTap: () => _menu(p)),
          ]),
        ),
      ]),
    );
  }
}

/// A collection: its newest picture, its name, how many; or the dashed one that makes a new collection.
class _FolderCard extends StatelessWidget {
  const _FolderCard({super.key, required this.name, required this.onTap, this.count, this.pic});
  final String name;
  final int? count;
  final String? pic;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, isNew = count == null;
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 140,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 140,
            height: 140,
            clipBehavior: Clip.antiAlias,
            decoration: isNew
                ? BoxDecoration(
                    color: Color.alphaBlend(c.accent.withValues(alpha: .1), c.surface),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.accent.withValues(alpha: .45), width: 1.5),
                  )
                : cardLook(context, radius: 14, color: c.sunk, raised: true),
            alignment: Alignment.center,
            child: isNew
                ? PIcon('plus', size: 34, color: c.accent)
                : pic != null
                    ? SizedBox.expand(child: PImage(pic!, fit: BoxFit.cover))
                    : PIcon('bookmark', size: 34, color: c.muted),
          ),
          const SizedBox(height: 7),
          Text(name, maxLines: isNew ? 2 : 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
          if (!isNew) Text('$count ელემენტი', style: TextStyle(color: c.muted, fontSize: 12.5)),
        ]),
      ),
    );
  }
}

/// a name asked for in a small window (a new collection, or a new name for one)
Future<String?> _askName(BuildContext context, String title, String now) async {
  final t = TextEditingController(text: now);
  final r = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const ValueKey('sv-name'),
        controller: t,
        autofocus: true,
        maxLength: 40,
        decoration: const InputDecoration(hintText: 'მაგ. რეცეპტები, მოგზაურობა', counterText: ''),
        onSubmitted: (v) => Navigator.pop(d, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('გაუქმება')),
        FilledButton(key: const ValueKey('sv-ok'), onPressed: () => Navigator.pop(d, t.text), child: const Text('შენახვა')),
      ],
    ),
  );
  final v = r?.trim() ?? '';
  return v.isEmpty ? null : v;
}
