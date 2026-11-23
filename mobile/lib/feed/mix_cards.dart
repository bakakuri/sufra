// What "for you" brings among the posts besides them (home.js mixMatch, mixAlbum): a coming or live match with its
// score and a free prediction a tap away, and a shared album with its newest photos.
import 'package:flutter/material.dart';

import '../community/sport.dart';
import '../data/stores.dart';
import '../people/albums.dart';
import '../profile/profile.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// the frame both cards stand in, like a post's
class _MixFrame extends StatelessWidget {
  const _MixFrame({required this.child, this.tint});
  final Widget child;
  final Color? tint;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      decoration: BoxDecoration(
        color: c.surface,
        gradient: tint == null ? null : RadialGradient(center: Alignment.topLeft, radius: 1.6, colors: [Color.alphaBlend(tint!.withValues(alpha: .14), c.surface), c.surface]),
        border: Border.symmetric(horizontal: BorderSide(color: c.line)),
      ),
      child: child,
    );
  }
}

/// a coming or live match: league, teams, score or time; a tap opens it
class MixMatchCard extends StatefulWidget {
  const MixMatchCard({super.key, required this.id});
  final int id;
  @override
  State<MixMatchCard> createState() => _MixMatchCardState();
}

class _MixMatchCardState extends State<MixMatchCard> {
  Map<String, dynamic>? f;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    context.app.api.fixture(widget.id).then((x) {
      if (mounted && x != null) setState(() => f = x.f);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = f;
    if (x == null) return const SizedBox.shrink();
    final live = fixtureLive(x);
    final league = '${x['league'] ?? ''}'.isEmpty ? 'მატჩი' : '${x['league']}';
    return _MixFrame(
      tint: c.accent,
      child: InkWell(
        key: ValueKey('mixm-${widget.id}'),
        onTap: () => openPage(context, FixtureScreen(id: widget.id), full: true),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(children: [
            Row(children: [
              PIcon('trophy', size: 15, color: c.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(league.toUpperCase(), style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .4))),
              fixtureBadge(context, x),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('${x['home']}', textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(fixtureScore(x), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: live ? c.nope : c.accent)),
              ),
              Expanded(child: Text('${x['away']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(999)),
              child: Text(live ? 'ცოცხალი ჩატი' : 'გააკეთე პროგნოზი · უფასოა', style: TextStyle(color: c.accent, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// a shared album: whose, how many photos, the newest four; a tap opens it
class MixAlbumCard extends StatefulWidget {
  const MixAlbumCard({super.key, required this.id});
  final int id;
  @override
  State<MixAlbumCard> createState() => _MixAlbumCardState();
}

class _MixAlbumCardState extends State<MixAlbumCard> {
  Map<String, dynamic>? a;
  List<String> pics = const [];
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
      final x = await app.api.album(widget.id);
      if (x == null) return;
      final ph = await app.api.albumPhotos(widget.id);
      await app.people.ensure(['${x['owner']}']);
      if (!mounted) return;
      final urls = [for (final p in ph.reversed) '${p['sm'] ?? p['md'] ?? p['url'] ?? ''}'].where((u) => u.startsWith('http')).take(4).toList();
      setState(() {
        a = x;
        pics = urls;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = a;
    if (x == null || pics.isEmpty) return const SizedBox.shrink();
    final uid = '${x['owner']}', p = context.app.people[uid] ?? Profile(id: uid, name: '…');
    void open() => openPage(context, AlbumScreen(id: widget.id), full: true);
    Widget img(String u) => SizedBox.expand(child: PImage(u, fit: BoxFit.cover));
    final grid = switch (pics.length) {
      1 => img(pics[0]),
      2 => Row(children: [Expanded(child: img(pics[0])), const SizedBox(width: 3), Expanded(child: img(pics[1]))]),
      3 => Row(children: [
          Expanded(flex: 2, child: img(pics[0])),
          const SizedBox(width: 3),
          Expanded(child: Column(children: [Expanded(child: img(pics[1])), const SizedBox(height: 3), Expanded(child: img(pics[2]))])),
        ]),
      _ => Column(children: [
          Expanded(child: Row(children: [Expanded(child: img(pics[0])), const SizedBox(width: 3), Expanded(child: img(pics[1]))])),
          const SizedBox(height: 3),
          Expanded(child: Row(children: [Expanded(child: img(pics[2])), const SizedBox(width: 3), Expanded(child: img(pics[3]))])),
        ]),
    };
    return _MixFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(p: p, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('საერთო ალბომი · ${x['photos'] ?? pics.length} ფოტო', style: TextStyle(color: c.muted, fontSize: 12.5)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          GestureDetector(
            key: ValueKey('mixa-${widget.id}'),
            // the whole picture takes the tap, also where a photo is still loading
            behavior: HitTestBehavior.opaque,
            onTap: open,
            child: ClipRRect(borderRadius: BorderRadius.circular(14), child: AspectRatio(aspectRatio: 16 / 10, child: grid)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text('${x['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
            OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)), onPressed: open, child: const Text('ალბომის ნახვა')),
          ]),
        ]),
      ),
    );
  }
}

