// Clips inside the feed, as Facebook shows its reels (home.js loadReels): a sideways row of tall cards — the first
// makes a new clip, each other one the clip's picture with who made it, its words and its likes. The first card fully in
// view plays itself without sound, three seconds over and over; the watched ones are marked and come after the rest.
// A tap opens the clips from that one; "ყველა" goes to the clips tab.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../clips/clip_composer.dart';
import '../clips/clip_feed.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../media/player.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../shell/tab_bar.dart';
import '../ui/icons.dart';
import '../ui/look.dart';
import '../ui/motion.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const _w = 118.0, _h = _w * 16 / 9;

class ReelsRow extends StatefulWidget {
  const ReelsRow({super.key});
  @override
  State<ReelsRow> createState() => _ReelsRowState();
}

class _ReelsRowState extends State<ReelsRow> {
  List<Post>? clips;
  Set<int> seen = {};
  bool _started = false;
  final scroll = ScrollController();
  Timer? _tick;

  /// the clip playing on its card, and its player
  int? _on;
  Player? _player;
  bool _looping = false;

  static final _home = tabs.indexWhere((t) => t.id == 'home');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _stop();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.app;
    try {
      final r = [for (final p in await app.api.clips(limit: 12)) if (p.media.any((m) => m.isVideo)) p];
      await app.posts.load(r);
      await app.people.ensure({for (final p in r) if (p.ap == null) p.author});
      loadClipViews(app.api, [for (final p in r) p.id]);
      final s = await ClipsSeen.load();
      // the ones not watched yet first, each part in its own order
      final l = [...r.where((p) => !s.contains(p.id)), ...r.where((p) => s.contains(p.id))];
      if (!mounted) return;
      setState(() {
        clips = l;
        seen = s;
      });
      _tick = Timer.periodic(const Duration(milliseconds: 700), (_) => _check());
      scroll.addListener(_check);
    } catch (_) {
      if (mounted) setState(() => clips = const []);
    }
  }

  void _stop() {
    final p = _player;
    _player = null;
    _on = null;
    p?.dispose();
  }

  /// which card should play now: the first one fully in view, while the row is on the screen, the feed's tab open
  /// and nothing over it; none in the economy mode or with less motion asked
  int? _wanted() {
    final l = clips;
    if (l == null || l.isEmpty || ecoMode.value || MediaQuery.of(context).disableAnimations) return null;
    if (!(ModalRoute.of(context)?.isCurrent ?? true) || context.app.tab.value != _home) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final top = box.localToGlobal(Offset.zero).dy, h = box.size.height, sh = MediaQuery.sizeOf(context).height;
    if ((math.min(top + h, sh) - math.max(top, 0.0)) / h < .55) return null;
    final off = scroll.hasClients ? scroll.offset : 0.0, vw = scroll.hasClients ? scroll.position.viewportDimension : MediaQuery.sizeOf(context).width;
    for (var i = 1; i <= l.length; i++) {
      final left = 12 + i * (_w + 8);
      if (left >= off - 1 && left + _w <= off + vw + 1) return l[i - 1].id;
    }
    return null;
  }

  void _check() {
    if (!mounted) return;
    final want = _wanted();
    if (want == _on) return;
    _stop();
    if (want != null) {
      final m = clips!.firstWhere((p) => p.id == want).media.firstWhere((x) => x.isVideo);
      final pl = makePlayer(m.url, loop: true)..mute(true);
      pl.addListener(() {
        // three seconds, over and over
        if (_looping || !pl.started || pl.position < const Duration(milliseconds: 3200)) return;
        _looping = true;
        pl.rewind().then((_) => pl.play()).whenComplete(() => _looping = false);
      });
      pl.play();
      _player = pl;
      _on = want;
    }
    setState(() {});
  }

  Future<void> _open(List<Post> l, int i) async {
    _stop();
    setState(() {});
    await openPage(context, ClipViewer(posts: l, start: i), full: true);
    final s = await ClipsSeen.load();
    if (mounted) setState(() => seen = s);
  }

  Future<void> _create() async {
    final app = context.app;
    _stop();
    final p = await openPage<Post>(context, const ClipComposer(), full: true, bare: true);
    if (p == null || !mounted) return;
    await app.posts.load([p]);
    if (!mounted) return;
    setState(() => clips = [p, ...?clips]);
    toast(context, 'კლიპი გამოქვეყნდა');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, l = clips;
    if (l == null || l.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('reels'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: cardLook(context, radius: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 6, 10),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFDB2777)]), borderRadius: BorderRadius.circular(11)),
              child: const PIcon('clips', size: 19, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('კლიპები', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            TextButton(
              key: const ValueKey('reels-all'),
              onPressed: () => app.goTab?.call('clips'),
              child: Text('ყველა', style: TextStyle(fontWeight: FontWeight.w800, color: c.accent)),
            ),
          ]),
        ),
        SizedBox(
          height: _h + 10,
          child: ListenableBuilder(
            listenable: app.posts,
            builder: (context, _) => ListView.separated(
              key: const ValueKey('reels-row'),
              controller: scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              itemCount: l.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Rise(
                order: i,
                dy: 0,
                child: i == 0
                    ? Pressable(key: const ValueKey('reel-new'), onTap: _create, child: const _NewCard())
                    : Pressable(
                        key: ValueKey('reel-${l[i - 1].id}'),
                        onTap: () => _open(l, i - 1),
                        child: _ReelCard(
                          p: l[i - 1],
                          likes: app.posts.of(l[i - 1].id).total,
                          seen: seen.contains(l[i - 1].id),
                          player: _on == l[i - 1].id ? _player : null,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

BoxDecoration _frame(BuildContext context, Color color) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [BoxShadow(color: const Color(0xFF141830).withValues(alpha: dark ? .45 : .16), blurRadius: 14, offset: const Offset(0, 6))],
  );
}

/// the first card: my picture, a round "+" and "კლიპის შექმნა"
class _NewCard extends StatelessWidget {
  const _NewCard();
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Container(
      width: _w,
      height: _h,
      clipBehavior: Clip.antiAlias,
      decoration: _frame(context, c.sunk),
      child: Stack(children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: _h * .62,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.alphaBlend(c.accent.withValues(alpha: .22), c.sunk), c.sunk]),
            ),
            child: Avatar(p: context.me, size: 60, ring: false),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: _h * .62 - 17,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle, border: Border.all(color: c.sunk, width: 3)),
              child: const PIcon('plus', size: 18, color: Colors.white, stroke: 2.4),
            ),
          ),
        ),
        const Positioned(
          left: 6,
          right: 6,
          bottom: 14,
          child: Text('კლიპის შექმნა', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ]),
    );
  }
}

/// a clip: its picture, who made it at the top, the words and the likes at the bottom, a play mark in the middle
class _ReelCard extends StatelessWidget {
  const _ReelCard({required this.p, required this.likes, this.seen = false, this.player});
  final Post p;
  final int likes;

  /// watched already: a little darker, marked
  final bool seen;

  /// playing on the card, without sound
  final Player? player;
  @override
  Widget build(BuildContext context) {
    final app = context.app, m = p.media.firstWhere((x) => x.isVideo);
    final who = p.ap ?? app.people[p.author] ?? Profile(id: p.author, name: '…');
    final pic = m.poster ?? '';
    const shadow = [Shadow(blurRadius: 6, color: Colors.black54)];
    return Container(
      width: _w,
      height: _h,
      clipBehavior: Clip.antiAlias,
      decoration: _frame(context, const Color(0xFF14141A)),
      child: Stack(children: [
        if (pic.startsWith('http'))
          Positioned.fill(child: PImage(pic, fit: BoxFit.cover, background: const Color(0xFF14141A)))
        else
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3B3B52), Color(0xFF14141A)]))),
          ),
        if (player != null)
          Positioned.fill(
            child: ListenableBuilder(
              listenable: player!,
              builder: (_, __) => AnimatedOpacity(
                opacity: player!.started && !player!.failed ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                child: player!.ready && !player!.failed ? VideoBox(key: ValueKey('reel-play-${p.id}'), player: player!, fit: BoxFit.cover, waiting: false) : const SizedBox(),
              ),
            ),
          ),
        if (seen) const Positioned.fill(child: ColoredBox(color: Color(0x40000000))),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .28, .55, 1],
                colors: [Color(0x59000000), Color(0x00000000), Color(0x00000000), Color(0xC0000000)],
              ),
            ),
          ),
        ),
        Positioned(left: 7, top: 7, child: Avatar(p: who, size: 32, ring: !seen)),
        if (seen)
          Positioned(
            right: 7,
            top: 10,
            child: Container(
              key: ValueKey('reel-seen-${p.id}'),
              padding: const EdgeInsets.fromLTRB(5, 3, 7, 3),
              decoration: BoxDecoration(color: const Color(0x80000000), borderRadius: BorderRadius.circular(99)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                PIcon('eye', size: 12, color: Colors.white),
                SizedBox(width: 3),
                Text('ნანახი', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        // the play mark, gone once the card plays by itself
        Center(
          child: player == null
              ? const _PlayMark()
              : ListenableBuilder(
                  listenable: player!,
                  builder: (_, __) => AnimatedOpacity(opacity: player!.started ? 0 : 1, duration: const Duration(milliseconds: 300), child: const _PlayMark()),
                ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(who.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5, shadows: shadow)),
            if (p.body.trim().isNotEmpty)
              Text(p.body.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 11.5, height: 1.25, shadows: shadow)),
            const SizedBox(height: 4),
            Row(children: [
              const PIcon('heart', size: 13, color: Colors.white, stroke: 2.2),
              const SizedBox(width: 4),
              Text(compact(likes), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, shadows: shadow)),
              // how many watched
              ValueListenableBuilder<Map<int, int>>(
                valueListenable: clipViews,
                builder: (_, v, __) => v[p.id] == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(left: 9),
                        child: Row(key: ValueKey('reel-views-${p.id}'), mainAxisSize: MainAxisSize.min, children: [
                          const PIcon('play', size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(compact(v[p.id]!), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, shadows: shadow)),
                        ]),
                      ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _PlayMark extends StatelessWidget {
  const _PlayMark();
  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Color(0x59000000), shape: BoxShape.circle),
        child: const Padding(padding: EdgeInsets.only(left: 2), child: PIcon('play', size: 17, color: Colors.white)),
      );
}
