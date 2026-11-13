// Shared albums (albums.js): a wedding or a supra where every invited guest adds their photos. The list (mine, where
// I was invited, friends'), an album with its people and photos, adding photos, the viewer (who added it, when),
// inviting, members, editing and deleting.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'person_screen.dart';

const albumAudience = {'friends': 'მეგობრები ხედავენ', 'members': 'მხოლოდ მონაწილეები', 'all': 'ყველა ხედავს'};

/// An album's card: the cover with its number of photos, the name, whose and when.
class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.album, this.onChanged});
  final Album album;
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, mine = album.owner == app.api.myId;
    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.line)),
      child: InkWell(
        key: ValueKey('album-${album.id}'),
        onTap: () async {
          await openPage(context, AlbumScreen(id: album.id));
          onChanged?.call();
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              (album.cover ?? '').isNotEmpty ? PImage(album.cover!) : ColoredBox(color: c.sunk, child: Center(child: PIcon('image', size: 30, color: c.muted))),
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0x9E0E0A12), borderRadius: BorderRadius.circular(999)),
                  child: Text('${album.photos}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('${mine ? 'შენი' : (app.people[album.owner]?.name ?? '…')} · ${ago(album.updatedAt)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }
}

Widget albumGrid(List<Album> list, {VoidCallback? onChanged}) => GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: .86,
      children: [for (final a in list) AlbumCard(album: a, onChanged: onChanged)],
    );

/// Making an album, or changing one: name, about, who sees it. The new one opens.
Future<void> albumForm(BuildContext context, {Map<String, dynamic>? album, VoidCallback? done}) async {
  final app = context.app;
  final title = TextEditingController(text: '${album?['title'] ?? ''}'), about = TextEditingController(text: '${album?['about'] ?? ''}');
  var aud = '${album?['audience'] ?? 'friends'}';
  final id = await showModalBottomSheet<int>(
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
            Text(album == null ? 'ახალი ალბომი' : 'ალბომის რედაქტირება', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(key: const ValueKey('al-title'), controller: title, maxLength: 80, decoration: const InputDecoration(labelText: 'სახელი', hintText: 'მაგ. ნინოს და გიორგის ქორწილი', counterText: '')),
            const SizedBox(height: 10),
            TextField(controller: about, maxLength: 500, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'აღწერა', counterText: '')),
            const SizedBox(height: 12),
            Text('ვინ ნახავს', style: TextStyle(color: s.pc.muted, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in albumAudience.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: aud == e.key,
                  showCheckmark: false,
                  selectedColor: s.pc.ink,
                  labelStyle: TextStyle(color: aud == e.key ? s.pc.bg : s.pc.ink, fontWeight: FontWeight.w600),
                  onSelected: (_) => set(() => aud = e.key),
                ),
            ]),
            const SizedBox(height: 10),
            Text('ფოტოების დამატება შეუძლიათ შენ მიერ მოწვეულ ადამიანებს.', style: TextStyle(color: s.pc.muted, fontSize: 12.5)),
            const SizedBox(height: 14),
            FilledButton(
              key: const ValueKey('al-ok'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () async {
                final t = title.text.trim();
                if (t.isEmpty) {
                  toast(s, 'ჩაწერე ალბომის სახელი');
                  return;
                }
                final ab = about.text.trim().isEmpty ? null : about.text.trim();
                try {
                  if (album != null) {
                    await app.api.updateAlbum(asInt(album['id']), t, ab, aud);
                    if (s.mounted) Navigator.of(s).pop(asInt(album['id']));
                  } else {
                    final n = await app.api.createAlbum(t, ab, aud);
                    if (s.mounted) Navigator.of(s).pop(n);
                  }
                } catch (e) {
                  if (s.mounted) toast(s, errText(e));
                }
              },
              child: Text(album == null ? 'შექმნა' : 'შენახვა'),
            ),
          ]),
        ),
      ),
    ),
  );
  if (id == null || !context.mounted) return;
  done?.call();
  if (album == null) await openPage(context, AlbumScreen(id: id));
}

/// The albums page: mine, the ones I add photos to, my friends'.
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});
  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  (List<Album>, List<Album>, List<Album>)? data;
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
      final d = await app.api.albumsPage();
      await app.people.ensure([...d.$2, ...d.$3].map((a) => a.owner));
      if (mounted) setState(() => data = d);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, d = data;
    Widget sec(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 10), child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)));
    return Scaffold(
      appBar: peeraBar(context, title: 'ალბომები', actions: [IconBtn('plus', key: const ValueKey('albums-new'), label: 'ახალი', onTap: () => albumForm(context, done: _load))]),
      body: d == null
          ? (error != null ? Center(child: Empty(icon: 'image', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'თავიდან', onAction: _load)) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text('საერთო ალბომში ყველა მონაწილე ამატებს თავის ფოტოებს: ქორწილი, დაბადების დღე, ლაშქრობა.', style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.4)),
                ),
                if (d.$1.isEmpty && d.$2.isEmpty && d.$3.isEmpty)
                  Empty(
                    icon: 'image',
                    title: 'ალბომები ჯერ არ არის',
                    text: 'შექმენი ალბომი და მოიწვიე მეგობრები, რომ თავიანთი ფოტოები დაამატონ.',
                    action: 'ალბომის შექმნა',
                    onAction: () => albumForm(context, done: _load),
                  ),
                if (d.$1.isNotEmpty) ...[sec('ჩემი ალბომები'), albumGrid(d.$1, onChanged: _load)],
                if (d.$2.isNotEmpty) ...[sec('სადაც მონაწილე ვარ'), albumGrid(d.$2, onChanged: _load)],
                if (d.$3.isNotEmpty) ...[sec('მეგობრების ალბომები'), albumGrid(d.$3, onChanged: _load)],
              ]),
            ),
    );
  }
}

/// One album: its name, about, who sees it, the people in it, and the photos; adding photos for whoever may.
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key, required this.id});
  final int id;
  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  Map<String, dynamic>? a;
  List<Map<String, dynamic>> photos = [];
  List<String> members = [];
  bool canAdd = false, loaded = false, gone = false, _started = false;
  (int, int)? uploading;
  Object? error;

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
      final x = await app.api.album(widget.id);
      if (x == null) {
        if (mounted) {
          setState(() {
            gone = true;
            loaded = true;
          });
        }
        return;
      }
      final p = await app.api.albumPhotos(widget.id);
      final m = await app.api.albumMembers(widget.id);
      final can = await app.api.albumCanAdd(widget.id);
      await app.people.ensure(['${x['owner']}', ...m, ...p.map((r) => '${r['added_by']}')]);
      if (!mounted) return;
      setState(() {
        a = x;
        photos = p;
        members = m;
        canAdd = can;
        loaded = true;
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loaded = true;
        });
      }
    }
  }

  bool get own => a != null && '${a!['owner']}' == context.app.api.myId;

  Future<void> _add() async {
    final app = context.app;
    List<Uint8List> got;
    try {
      got = await photoSource(false);
    } catch (_) {
      return;
    }
    final list = got.take(50).toList();
    if (list.isEmpty || !mounted) return;
    var done = 0, fail = 0;
    setState(() => uploading = (0, list.length));
    for (final b in list) {
      try {
        final m = await app.api.uploadPhoto(await photoPrep(b));
        final row = await app.api.addAlbumPhoto(widget.id, m);
        if (!mounted) return;
        setState(() => photos.insert(0, row));
        done++;
      } catch (e) {
        fail++;
        if (fail == 1 && mounted) toast(context, errText(e));
      }
      if (mounted) setState(() => uploading = (done + fail, list.length));
    }
    if (!mounted) return;
    setState(() => uploading = null);
    toast(context, fail > 0 ? 'დაემატა $done, ვერ აიტვირთა $fail' : 'დაემატა $done ფოტო');
  }

  Future<void> _invite() async {
    final picked = await pickFriends(context, title: 'ვინ დაამატოს ფოტოები', action: 'მოწვევა', skip: members.toSet());
    if (picked == null || picked.isEmpty || !mounted) return;
    if (await attempt(context, () => context.app.api.inviteToAlbum(widget.id, picked)) && mounted) {
      toast(context, 'მოწვეულია ${picked.length}');
      _load();
    }
  }

  void _more() => showChoices(context, [
        SheetItem('edit', 'რედაქტირება', () => albumForm(context, album: a, done: _load)),
        SheetItem('users', 'მონაწილეები', _members),
        SheetItem('trash', 'ალბომის წაშლა', () async {
          if (!await confirm(context, title: 'ალბომის წაშლა', text: 'წაიშლება ალბომი და მისი ყველა ფოტო.', yes: 'წაშლა', danger: true) || !mounted) return;
          if (await attempt(context, () => context.app.api.deleteAlbum(widget.id)) && mounted) Navigator.of(context).pop();
        }, danger: true),
      ]);

  Future<void> _members() async {
    final app = context.app;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => StatefulBuilder(
        builder: (s, set) => SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: [
            const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('მონაწილეები', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            if (members.isEmpty)
              Padding(padding: const EdgeInsets.all(20), child: Text('ჯერ არავინ. მოიწვიე მეგობრები.', style: TextStyle(color: s.pc.muted)))
            else
              for (final u in [...members])
                ListTile(
                  leading: Avatar(p: app.people[u] ?? Profile(id: u, name: '…'), size: 40),
                  title: Text(app.people[u]?.name ?? '…', style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: TextButton(
                    onPressed: () async {
                      try {
                        await app.api.removeFromAlbum(widget.id, u);
                        set(() => members.remove(u));
                        if (s.mounted) toast(s, 'მოშორდა');
                      } catch (e) {
                        if (s.mounted) toast(s, errText(e));
                      }
                    },
                    child: const Text('მოშორება'),
                  ),
                ),
          ]),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _leave() async {
    if (!await confirm(context, title: 'ალბომის დატოვება', text: 'ფოტოებს ვეღარ დაამატებ. შენ მიერ დამატებული ფოტოები დარჩება.', yes: 'დატოვება') || !mounted) return;
    final app = context.app;
    if (await attempt(context, () => app.api.removeFromAlbum(widget.id, app.api.myId))) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, x = a;
    Widget body;
    if (!loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (gone) {
      body = const Center(child: Empty(icon: 'image', title: 'ალბომი ვერ მოიძებნა', text: 'შეიძლება წაშლილია ან შენთვის დახურულია.'));
    } else if (x == null) {
      body = Center(child: Empty(icon: 'image', title: 'ვერ ჩაიტვირთა', text: error == null ? null : errText(error!), action: 'თავიდან', onAction: _load));
    } else {
      final people = {'${x['owner']}', ...members, ...photos.map((p) => '${p['added_by']}')}.toList();
      final me = app.api.myId;
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${x['title'] ?? ''}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              if ('${x['about'] ?? ''}'.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${x['about']}', style: const TextStyle(fontSize: 15, height: 1.4))),
              const SizedBox(height: 4),
              Text('${asInt(x['photos']) > 0 ? asInt(x['photos']) : photos.length} ფოტო · ${albumAudience['${x['audience']}'] ?? ''}', style: TextStyle(color: c.muted, fontSize: 13)),
              const SizedBox(height: 10),
              Row(children: [
                for (final u in people.take(8))
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(onTap: () => openPage(context, PersonScreen(uid: u)), child: Avatar(p: app.people[u] ?? Profile(id: u, name: '…'), size: 30)),
                  ),
                if (people.length > 8) Text('+${people.length - 8}', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (canAdd)
                  FilledButton.icon(
                    key: const ValueKey('alb-add'),
                    onPressed: uploading != null ? null : _add,
                    icon: PIcon('image', size: 18, color: c.onAccent),
                    label: Text(uploading == null ? 'ფოტოების დამატება' : 'იტვირთება ${uploading!.$1}/${uploading!.$2}'),
                  ),
                if (own) ...[
                  OutlinedButton.icon(key: const ValueKey('alb-invite'), onPressed: _invite, icon: PIcon('users', size: 18, color: c.ink), label: const Text('მოწვევა')),
                  IconBtn('more', key: const ValueKey('alb-more'), label: 'მეტი', onTap: _more),
                ],
                if (!own && members.contains(me)) OutlinedButton(onPressed: _leave, child: const Text('დატოვება')),
              ]),
            ]),
          ),
          const SizedBox(height: 8),
          if (photos.isEmpty)
            Empty(
              icon: 'image',
              title: 'ალბომი ცარიელია',
              text: canAdd ? 'დაამატე პირველი ფოტოები.' : 'ფოტოები ჯერ არ დაუმატებიათ.',
              action: canAdd ? 'ფოტოების დამატება' : null,
              onAction: canAdd ? _add : null,
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
              itemCount: photos.length,
              itemBuilder: (context, i) {
                final p = photos[i];
                return GestureDetector(
                  key: ValueKey('albp-${p['id']}'),
                  onTap: () async {
                    final removed = await Navigator.of(context, rootNavigator: true).push<int>(PageRouteBuilder(
                      opaque: false,
                      barrierColor: Colors.black,
                      pageBuilder: (_, __, ___) => AppScope(app: app, me: context.me, child: AlbumViewer(title: '${x['title'] ?? ''}', photos: photos, start: i, own: own)),
                      transitionsBuilder: (_, an, __, child) => FadeTransition(opacity: an, child: child),
                    ));
                    if (removed != null && mounted) setState(() => photos.removeWhere((r) => asInt(r['id']) == removed));
                  },
                  child: ColoredBox(color: c.sunk, child: PImage('${p['sm'] ?? p['md'] ?? p['url']}')),
                );
              },
            ),
        ]),
      );
    }
    return Scaffold(appBar: peeraBar(context, title: x == null ? 'ალბომი' : '${x['title'] ?? 'ალბომი'}'), body: body);
  }
}

/// The album's photos one by one: swipe between them, who added each and when, delete (theirs, or any for the owner).
class AlbumViewer extends StatefulWidget {
  const AlbumViewer({super.key, required this.title, required this.photos, required this.start, required this.own});
  final String title;
  final List<Map<String, dynamic>> photos;
  final int start;
  final bool own;
  @override
  State<AlbumViewer> createState() => _AlbumViewerState();
}

class _AlbumViewerState extends State<AlbumViewer> {
  late int i = widget.start;
  late final pages = PageController(initialPage: widget.start);

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    if (!await confirm(context, title: 'ფოტოს წაშლა', text: 'ფოტო ალბომიდან წაიშლება ყველასთვის.', yes: 'წაშლა', danger: true) || !mounted) return;
    if (await attempt(context, () => context.app.api.deleteAlbumPhoto(asInt(p['id']))) && mounted) {
      toast(context, 'ფოტო წაიშალა');
      Navigator.of(context).pop(asInt(p['id']));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app, p = widget.photos[i], by = '${p['added_by']}';
    final who = app.people[by] ?? Profile(id: by, name: '…');
    final at = DateTime.tryParse('${p['created_at']}')?.toLocal();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          Row(children: [
            const SizedBox(width: 16),
            Expanded(child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
            if (widget.photos.length > 1) Text('${i + 1}/${widget.photos.length}', style: const TextStyle(color: Colors.white70)),
            IconBtn('x', label: 'დახურვა', color: Colors.white, onTap: () => Navigator.of(context).maybePop()),
          ]),
          Expanded(
            child: PageView.builder(
              controller: pages,
              itemCount: widget.photos.length,
              onPageChanged: (k) => setState(() => i = k),
              itemBuilder: (context, k) => InteractiveViewer(
                child: PImage('${widget.photos[k]['md'] ?? widget.photos[k]['url']}', fit: BoxFit.contain, background: Colors.black),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: Row(children: [
              Avatar(p: who, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(who.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  if (at != null) Text('${dayLabel(at)} ${hhmm(at)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              if (by == app.api.myId || widget.own || context.me.role == 'admin' || context.me.role == 'moderator')
                IconBtn('trash', key: const ValueKey('albp-del'), label: 'ფოტოს წაშლა', color: Colors.white, onTap: () => _delete(p)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Choosing friends (many): a list with ticks and the action's button; null when closed.
Future<List<String>?> pickFriends(BuildContext context, {required String title, required String action, Set<String> skip = const {}}) async {
  final app = context.app;
  if (!app.friends.loaded) await app.friends.load().catchError((_) {});
  await app.people.ensure(app.friends.friends);
  if (!context.mounted) return null;
  final ids = app.friends.friends.where((x) => !skip.contains(x)).toList();
  final sel = <String>{};
  return showModalBottomSheet<List<String>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => StatefulBuilder(
      builder: (s, set) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(s).height * .75),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            Flexible(
              child: ids.isEmpty
                  ? Padding(padding: const EdgeInsets.all(24), child: Text('მოსაწვევი მეგობრები აღარ დარჩა.', style: TextStyle(color: s.pc.muted)))
                  : ListView(shrinkWrap: true, children: [
                      for (final id in ids)
                        CheckboxListTile(
                          key: ValueKey('pick-$id'),
                          value: sel.contains(id),
                          onChanged: (v) => set(() => v == true ? sel.add(id) : sel.remove(id)),
                          secondary: Avatar(p: app.people[id] ?? Profile(id: id, name: '…'), size: 40),
                          title: Text(app.people[id]?.name ?? '…', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                    ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilledButton(
                key: const ValueKey('pick-ok'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: sel.isEmpty ? null : () => Navigator.of(s).pop(sel.toList()),
                child: Text(sel.isEmpty ? action : '$action (${sel.length})'),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}
