// A person's own photos on their profile ("ფოტოები"), apart from their posts and from the shared albums: uploaded
// straight or into albums of their own. Who sees them is their choice (everyone, friends or nobody, in the privacy
// settings); a visitor who may not see them is told so, and the photos do not open.
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../feed/photo_viewer.dart';
import '../feed/post_actions.dart';
import '../settings/settings_screens.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/motion.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// who sees my photos, in words (privacy 'photos')
String photosAudience(String? v) => switch (v) {
      'all' => 'ყველა',
      'none' => 'მხოლოდ შენ',
      _ => 'მეგობრები',
    };

/// Photos chosen on the phone go up one by one, into [album] (or among all of them); what was added comes back.
Future<List<Photo>> uploadMyPhotos(BuildContext context, {int? album}) async {
  final app = context.app, out = <Photo>[];
  try {
    final got = await photoSource(false);
    if (got.isEmpty || !context.mounted) return out;
    // one photo can be cropped and turned first
    final pics = got.length == 1 ? [await editPicked(context, got.first)] : got.take(20).toList();
    for (var i = 0; i < pics.length; i++) {
      if (!context.mounted) break;
      toast(context, pics.length == 1 ? 'იტვირთება…' : 'იტვირთება ${i + 1}/${pics.length}…');
      final m = await app.api.uploadPhoto(await photoPrep(pics[i]));
      out.add(await app.api.addPhoto(m, album: album));
    }
    if (context.mounted) toast(context, out.length == 1 ? 'ფოტო დაემატა' : '${out.length} ფოტო დაემატა');
  } catch (e) {
    if (context.mounted) toast(context, '$e'.contains('too_many') ? 'დღეში მაქსიმუმ 100 ფოტო შეიძლება' : errText(e));
  }
  return out;
}

Future<String?> _askTitle(BuildContext context, {String title = 'ახალი ალბომი', String initial = ''}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const ValueKey('phalb-title'),
        controller: ctl,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'მაგ.: ზაფხული 2026'),
        onSubmitted: (v) => Navigator.of(d).pop(v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('გაუქმება')),
        FilledButton(key: const ValueKey('phalb-ok'), onPressed: () => Navigator.of(d).pop(ctl.text.trim()), child: const Text('შენახვა')),
      ],
    ),
  ).then((v) => (v ?? '').trim().isEmpty ? null : v!.trim());
}

/// The profile's photos tab: for me, upload and a new album, and who sees them; then my albums in a row, and all the
/// photos three to a row. For a visitor who may not see them, a closed card saying why.
class PhotosTab extends StatefulWidget {
  const PhotosTab({super.key, required this.uid, required this.mine});
  final String uid;
  final bool mine;
  @override
  State<PhotosTab> createState() => _PhotosTabState();
}

class _PhotosTabState extends State<PhotosTab> {
  String? access;
  List<PhotoAlbum>? albums;
  List<Photo>? photos;
  Object? error;
  String? audience;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final api = context.app.api;
    try {
      final a = widget.mine ? 'ok' : await api.photoAccess(widget.uid);
      if (a != 'ok') {
        if (mounted) setState(() => access = a);
        return;
      }
      final r = await Future.wait<Object>([api.photoAlbums(widget.uid), api.photos(widget.uid)]);
      if (widget.mine) {
        api.mySettings().then((m) {
          final p = m['privacy'];
          if (mounted) setState(() => audience = p is Map ? '${p['photos'] ?? 'friends'}' : 'friends');
        }).catchError((_) {});
      }
      if (!mounted) return;
      setState(() {
        access = a;
        albums = r[0] as List<PhotoAlbum>;
        photos = r[1] as List<Photo>;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _upload() async {
    final got = await uploadMyPhotos(context);
    if (got.isNotEmpty && mounted) setState(() => photos = [...got.reversed, ...?photos]);
  }

  Future<void> _newAlbum() async {
    final t = await _askTitle(context);
    if (t == null || !mounted) return;
    try {
      final a = await context.app.api.makePhotoAlbum(t);
      if (!mounted) return;
      setState(() => albums = [a, ...?albums]);
      await _openAlbum(a);
    } catch (e) {
      if (mounted) toast(context, '$e'.contains('too_many') ? 'მაქსიმუმ 50 ალბომი შეიძლება' : errText(e));
    }
  }

  Future<void> _openAlbum(PhotoAlbum a) async {
    await openPage(context, PhotoAlbumScreen(album: a, uid: widget.uid, mine: widget.mine), full: true);
    if (mounted) _load();
  }

  Future<void> _who() async {
    await openPage(context, const PrivacyScreen(), full: true);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    const wait = Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)));
    if (error != null) {
      return Empty(icon: 'image', title: 'ფოტოები ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load);
    }
    if (access == null) return wait;
    if (access != 'ok') {
      final friendsOnly = access == 'friends';
      return Rise(
        order: 0,
        child: Container(
          key: const ValueKey('ph-locked'),
          margin: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
          decoration: cardLook(context, radius: 22),
          child: Column(children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)])),
              child: const PIcon('lock', size: 28, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(friendsOnly ? 'ფოტოებს მხოლოდ მეგობრები ხედავენ' : 'ფოტოები დახურულია',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(friendsOnly ? 'დაემეგობრე და მის ფოტოებს ნახავ.' : 'მან თავისი ფოტოები არავის აჩვენა.',
                textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 14, height: 1.4)),
          ]),
        ),
      );
    }
    final al = albums, ph = photos;
    if (al == null || ph == null) return wait;
    final w = MediaQuery.sizeOf(context).width;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.mine)
        Rise(
          order: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Row(children: [
              Expanded(
                child: _Gradient(
                  key: const ValueKey('ph-up'),
                  icon: 'camera',
                  text: 'ფოტოს ატვირთვა',
                  onTap: _upload,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('ph-newalb'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: _newAlbum,
                  icon: PIcon('folder', size: 18, color: c.accent),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('ახალი ალბომი')),
                ),
              ),
            ]),
          ),
        ),
      if (widget.mine)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: GestureDetector(
            key: const ValueKey('ph-who'),
            onTap: _who,
            child: Row(children: [
              PIcon('eye', size: 15, color: c.muted),
              const SizedBox(width: 5),
              Flexible(
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'ფოტოებს ხედავენ: '),
                    TextSpan(text: photosAudience(audience), style: TextStyle(color: c.accent, fontWeight: FontWeight.w800)),
                  ]),
                  style: TextStyle(color: c.muted, fontSize: 13),
                ),
              ),
              const SizedBox(width: 4),
              PIcon('chev', size: 14, color: c.accent),
            ]),
          ),
        ),
      if (al.isNotEmpty) ...[
        SectionHead('ალბომები', count: al.length),
        SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            itemCount: al.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final a = al[i];
              return Rise(
                order: i,
                dy: 10,
                child: Pressable(
                  key: ValueKey('pal-${a.id}'),
                  onTap: () => _openAlbum(a),
                  child: Container(
                    width: 136,
                    clipBehavior: Clip.antiAlias,
                    decoration: cardLook(context, radius: 18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(
                        child: a.cover == null
                            ? DecoratedBox(
                                decoration: BoxDecoration(gradient: LinearGradient(colors: [c.accent.withValues(alpha: .25), c.accent.withValues(alpha: .08)])),
                                child: Center(child: PIcon('image', size: 30, color: c.accent)),
                              )
                            : PImage(a.cover!),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          Text('${a.n} ფოტო', style: TextStyle(color: c.muted, fontSize: 12)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
      SectionHead('ყველა ფოტო', count: ph.length),
      if (ph.isEmpty)
        Empty(
          icon: 'image',
          title: widget.mine ? 'ჯერ ფოტო არ აგიტვირთავს' : 'ფოტოები ჯერ არ არის',
          text: widget.mine ? 'ატვირთე ფოტოები პირდაპირ ან ალბომებად.' : null,
        )
      else
        PhotoGrid(
          photos: ph,
          width: w,
          mine: widget.mine,
          albums: al,
          onChanged: _load,
        ),
    ]);
  }
}

class _Gradient extends StatelessWidget {
  const _Gradient({super.key, required this.icon, required this.text, required this.onTap});
  final String icon, text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color.lerp(c.accent, const Color(0xFF8B5CF6), .35)!, c.accent]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: c.accent.withValues(alpha: .32), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            PIcon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 7),
            Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5)),
          ]),
        ),
      ),
    );
  }
}

/// Photos three to a row, square; a tap opens them over the screen, a long press (mine) moves one to an album or
/// deletes it.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key, required this.photos, required this.width, required this.mine, this.albums = const [], this.onChanged});
  final List<Photo> photos;
  final double width;
  final bool mine;
  final List<PhotoAlbum> albums;
  final VoidCallback? onChanged;

  Future<void> _menu(BuildContext context, Photo p) async {
    final c = context.pc, api = context.app.api;
    final pick = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (albums.isNotEmpty)
            ListTile(key: const ValueKey('ph-move'), leading: PIcon('folder', color: c.ink), title: const Text('ალბომში გადატანა'), onTap: () => Navigator.of(s).pop('move')),
          if (p.albumId != null)
            ListTile(key: const ValueKey('ph-out'), leading: PIcon('image', color: c.ink), title: const Text('ალბომიდან ამოღება'), onTap: () => Navigator.of(s).pop('out')),
          ListTile(key: const ValueKey('ph-del'), leading: PIcon('trash', color: c.nope), title: Text('წაშლა', style: TextStyle(color: c.nope)), onTap: () => Navigator.of(s).pop('del')),
        ]),
      ),
    );
    if (pick == null || !context.mounted) return;
    if (pick == 'del') {
      final yes = await confirm(context, title: 'ფოტოს წაშლა', text: 'ფოტო სამუდამოდ წაიშლება.', yes: 'წაშლა', danger: true);
      if (yes && context.mounted && await attempt(context, () => api.deletePhoto(p.id))) onChanged?.call();
      return;
    }
    if (pick == 'out') {
      if (await attempt(context, () => api.movePhoto(p.id, null))) onChanged?.call();
      return;
    }
    final to = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (s) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final a in albums)
            if (a.id != p.albumId) ListTile(key: ValueKey('ph-to-${a.id}'), leading: PIcon('folder', color: c.accent), title: Text(a.title), subtitle: Text('${a.n} ფოტო'), onTap: () => Navigator.of(s).pop(a.id)),
        ]),
      ),
    );
    if (to != null && context.mounted && await attempt(context, () => api.movePhoto(p.id, to))) onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final side = (width - 4) / 3;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(spacing: 2, runSpacing: 2, children: [
        for (final (i, p) in photos.indexed)
          Rise(
            order: i,
            dy: 0,
            ms: 300,
            step: 30,
            child: GestureDetector(
              key: ValueKey('ph-${p.id}'),
              onTap: () => openPhotos(context, [for (final x in photos) x.media], start: i),
              onLongPress: mine ? () => _menu(context, p) : null,
              child: SizedBox.square(dimension: side, child: PImage(p.sm ?? p.url)),
            ),
          ),
      ]),
    );
  }
}

/// One of my (or their) albums: its photos, three to a row; for me, adding photos to it, renaming it, deleting it
/// (its photos stay among all of them).
class PhotoAlbumScreen extends StatefulWidget {
  const PhotoAlbumScreen({super.key, required this.album, required this.uid, required this.mine});
  final PhotoAlbum album;
  final String uid;
  final bool mine;
  @override
  State<PhotoAlbumScreen> createState() => _PhotoAlbumScreenState();
}

class _PhotoAlbumScreenState extends State<PhotoAlbumScreen> {
  late String title = widget.album.title;
  List<Photo>? photos;
  List<PhotoAlbum> albums = const [];
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
    final api = context.app.api;
    try {
      final r = await Future.wait<Object>([api.photos(widget.uid, album: widget.album.id), if (widget.mine) api.photoAlbums(widget.uid)]);
      if (!mounted) return;
      setState(() {
        photos = r[0] as List<Photo>;
        if (r.length > 1) albums = r[1] as List<PhotoAlbum>;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _add() async {
    final got = await uploadMyPhotos(context, album: widget.album.id);
    if (got.isNotEmpty && mounted) setState(() => photos = [...got.reversed, ...?photos]);
  }

  Future<void> _more() async {
    final c = context.pc, api = context.app.api;
    final pick = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(key: const ValueKey('phalb-ren'), leading: PIcon('edit', color: c.ink), title: const Text('სახელის შეცვლა'), onTap: () => Navigator.of(s).pop('ren')),
          ListTile(key: const ValueKey('phalb-del'), leading: PIcon('trash', color: c.nope), title: Text('ალბომის წაშლა', style: TextStyle(color: c.nope)), onTap: () => Navigator.of(s).pop('del')),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    if (pick == 'ren') {
      final t = await _askTitle(context, title: 'ალბომის სახელი', initial: title);
      if (t != null && mounted && await attempt(context, () => api.renamePhotoAlbum(widget.album.id, t)) && mounted) setState(() => title = t);
      return;
    }
    final yes = await confirm(context, title: 'ალბომის წაშლა', text: 'ალბომი წაიშლება, მისი ფოტოები კი „ყველა ფოტოში“ დარჩება.', yes: 'წაშლა', danger: true);
    if (yes && mounted && await attempt(context, () => api.deletePhotoAlbum(widget.album.id)) && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = photos;
    return Scaffold(
      appBar: peeraBar(context, title: title, actions: [
        if (widget.mine) IconBtn('plus', key: const ValueKey('phalb-add'), label: 'ფოტოს დამატება', onTap: _add),
        if (widget.mine) IconBtn('more', key: const ValueKey('phalb-more'), label: 'მეტი', onTap: _more),
      ]),
      body: error != null
          ? Empty(icon: 'image', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
          : l == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(children: [
                    if (l.isEmpty)
                      Empty(
                        icon: 'image',
                        title: 'ალბომი ცარიელია',
                        text: widget.mine ? 'დაამატე პირველი ფოტოები.' : null,
                        action: widget.mine ? 'ფოტოს დამატება' : null,
                        onAction: widget.mine ? _add : null,
                      )
                    else
                      PhotoGrid(photos: l, width: MediaQuery.sizeOf(context).width, mine: widget.mine, albums: albums, onChanged: _load),
                  ]),
                ),
    );
  }
}
