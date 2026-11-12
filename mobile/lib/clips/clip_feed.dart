import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/post_card.dart';
import '../feed/post_screen.dart';
import '../media/player.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/widgets.dart';

/// Clips sound on or off, the same for every clip (off at first, as on the site).
final clipSound = ValueNotifier<bool>(false);

/// Videos one to a screen, swiped up and down. Only the one on screen plays (and only while [visible]);
/// the next one starts loading so a swipe lands on a ready clip. A tap pauses, two taps leave a ❤️.
class ClipFeed extends StatefulWidget {
  const ClipFeed({super.key, required this.posts, this.start = 0, this.visible, this.onMore, this.top});
  final List<Post> posts;
  final int start;

  /// whether the clips are on screen at all (their tab is open, nothing is over them)
  final ValueListenable<bool>? visible;

  /// asks for more clips near the end of the list
  final Future<void> Function()? onMore;

  /// laid over the top of every clip: the title and the upload button, or a back arrow
  final Widget? top;

  @override
  State<ClipFeed> createState() => ClipFeedState();
}

class ClipFeedState extends State<ClipFeed> with WidgetsBindingObserver {
  late final pages = PageController(initialPage: widget.start);
  late int at = widget.start;
  final _players = <int, Player>{};
  bool _covered = false, _away = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.visible?.addListener(_sync);
    clipSound.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(ClipFeed old) {
    super.didUpdateWidget(old);
    if (old.visible != widget.visible) {
      old.visible?.removeListener(_sync);
      widget.visible?.addListener(_sync);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.visible?.removeListener(_sync);
    clipSound.removeListener(_sync);
    for (final p in _players.values) {
      p.dispose();
    }
    pages.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _away = s != AppLifecycleState.resumed;
    _sync();
  }

  bool get _live => !_covered && !_away && (widget.visible?.value ?? true);

  Media? _video(Post p) => (p.original ?? p).media.where((m) => m.isVideo).firstOrNull;

  Player? player(int i) {
    if (i < 0 || i >= widget.posts.length) return null;
    final m = _video(widget.posts[i]);
    if (m == null) return null;
    return _players[widget.posts[i].id] ??= makePlayer(m.url);
  }

  /// the one on screen plays; its neighbours wait ready; the rest let go of their memory
  void _sync() {
    if (!mounted) return;
    final keep = {for (var i = at - 1; i <= at + 1; i++) if (i >= 0 && i < widget.posts.length) widget.posts[i].id};
    for (final id in _players.keys.where((k) => !keep.contains(k)).toList()) {
      _players.remove(id)!.dispose();
    }
    for (var i = at - 1; i <= at + 1; i++) {
      final p = player(i);
      if (p == null) continue;
      if (i == at && _live && !_held.contains(widget.posts[i].id)) {
        p.mute(!clipSound.value);
        p.play();
      } else if (i == at) {
        p.pause();
      } else if (p.playing) {
        p.rewind();
      } else {
        p.prepare();
      }
    }
    setState(() {});
  }

  final _held = <int>{};

  void _toggle(Post p) {
    final pl = _players[p.id];
    if (pl == null) return;
    if (pl.playing) {
      _held.add(p.id);
      pl.pause();
    } else {
      _held.remove(p.id);
      _sync();
    }
    setState(() {});
  }

  /// another screen over the clips (comments, a profile): they wait
  Future<T?> cover<T>(Future<T?> Function() open) async {
    _covered = true;
    _sync();
    try {
      return await open();
    } finally {
      _covered = false;
      if (mounted) _sync();
    }
  }

  void _changed(int i) {
    final old = at;
    at = i;
    _held.remove(widget.posts[old].id);
    _sync();
    if (widget.onMore != null && i >= widget.posts.length - 3) widget.onMore!();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      PageView.builder(
        controller: pages,
        scrollDirection: Axis.vertical,
        itemCount: widget.posts.length,
        onPageChanged: _changed,
        itemBuilder: (_, i) => ClipPage(
          key: ValueKey('clip-${widget.posts[i].id}'),
          post: widget.posts[i],
          player: player(i),
          active: i == at && _live,
          held: _held.contains(widget.posts[i].id),
          onTap: () => _toggle(widget.posts[i]),
          cover: cover,
        ),
      ),
      if (widget.top != null) Positioned(left: 0, right: 0, top: 0, child: widget.top!),
    ]);
  }
}

/// One clip: the video, who made it and what they wrote, and on the right ❤️, comments, sharing.
class ClipPage extends StatefulWidget {
  const ClipPage({super.key, required this.post, required this.player, required this.active, required this.held, required this.onTap, required this.cover});
  final Post post;
  final Player? player;
  final bool active, held;
  final VoidCallback onTap;
  final Future<T?> Function<T>(Future<T?> Function() open) cover;

  @override
  State<ClipPage> createState() => _ClipPageState();
}

class _ClipPageState extends State<ClipPage> with SingleTickerProviderStateMixin {
  late final burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool open = false;

  @override
  void dispose() {
    burst.dispose();
    super.dispose();
  }

  Post get p => widget.post.original ?? widget.post;

  void _like() {
    burst.forward(from: 0);
    HapticFeedback.lightImpact();
    final store = context.app.posts;
    if (store.of(p.id).mine != '❤️') attempt(context, () => store.react(p.id, '❤️'));
  }

  void _heart() {
    final store = context.app.posts, on = store.of(p.id).mine == '❤️';
    if (!on) {
      burst.forward(from: 0);
      HapticFeedback.lightImpact();
    }
    attempt(context, () => store.react(p.id, on ? null : '❤️'));
  }

  Future<void> _comments() async {
    await widget.cover(() => openPage<bool>(context, PostScreen(post: p, focus: false), full: true));
  }

  Future<void> _person(Profile who) async {
    if (who.id.startsWith('page:')) return;
    await widget.cover(() => openPerson(context, who).then((_) => null));
  }

  Future<void> _more() async {
    final mine = p.author == context.me.id, link = '$siteUrl/#post-${p.id}';
    await showChoices(context, [
      SheetItem('copy', 'ბმულის კოპირება', () {
        Clipboard.setData(ClipboardData(text: link));
        toast(context, 'ბმული დაკოპირდა');
      }),
      if (mine)
        SheetItem('trash', 'კლიპის წაშლა', () async {
          if (!await confirm(context, title: 'წაიშალოს კლიპი?', yes: 'წაშლა', danger: true) || !mounted) return;
          if (await attempt(context, () => context.app.api.deletePost(p.id)) && mounted) toast(context, 'კლიპი წაიშალა');
        }, danger: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final m = p.media.where((x) => x.isVideo).firstOrNull;
    final who = p.ap ?? Profile(id: p.author, name: '');
    final portrait = m != null && m.h > m.w * 1.05;
    final pl = widget.player;
    return ColoredBox(
      color: Colors.black,
      child: Stack(fit: StackFit.expand, children: [
        if (pl != null)
          VideoBox(player: pl, poster: m?.poster, fit: portrait || m == null || m.w == 0 ? BoxFit.cover : BoxFit.contain, waiting: widget.active)
        else
          const Center(child: Text('ვიდეო არ არის', style: TextStyle(color: Colors.white70))),
        // tap: pause or go on; two taps: ❤️
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, onDoubleTap: _like),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0xAA000000)], stops: [0, .18, .55, 1]),
            ),
          ),
        ),
        if (widget.held)
          IgnorePointer(
            child: Center(
              child: Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
                child: const Padding(padding: EdgeInsets.only(left: 5), child: PIcon('play', size: 36, color: Colors.white)),
              ),
            ),
          ),
        IgnorePointer(
          child: AnimatedBuilder(
            animation: burst,
            builder: (_, __) {
              final t = burst.value;
              if (t == 0 || t == 1) return const SizedBox.shrink();
              final s = t < .3 ? .4 + t / .3 * .8 : 1.2 - (t - .3) * .3;
              return Center(
                child: Opacity(
                  opacity: t < .7 ? 1 : 1 - (t - .7) / .3,
                  child: Transform.scale(scale: s, child: const PIcon('heartfill', size: 110, color: Color(0xFFFF4D67))),
                ),
              );
            },
          ),
        ),
        // the buttons on the right
        Positioned(
          right: 8,
          bottom: 22,
          child: ListenableBuilder(
            listenable: context.app.posts,
            builder: (context, _) {
              final s = context.app.posts.of(p.id), liked = s.mine == '❤️';
              return Column(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: () => _person(who),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Avatar(p: who, size: 44),
                  ),
                ),
                const SizedBox(height: 14),
                _SideBtn(
                  key: ValueKey('clip-like-${p.id}'),
                  icon: liked ? 'heartfill' : 'heart',
                  color: liked ? const Color(0xFFFF4D67) : Colors.white,
                  label: liked ? 'მოწონების მოხსნა' : 'მოწონება',
                  text: grouped(s.total),
                  onTap: _heart,
                ),
                _SideBtn(key: ValueKey('clip-comments-${p.id}'), icon: 'comment', label: 'კომენტარები', text: grouped(s.comments), onTap: _comments),
                _SideBtn(
                  icon: 'send',
                  label: 'გაზიარება',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: '$siteUrl/#post-${p.id}'));
                    toast(context, 'ბმული დაკოპირდა — ჩასვი სადაც გინდა');
                  },
                ),
                _SideBtn(icon: 'more', label: 'მეტი', onTap: _more),
              ]);
            },
          ),
        ),
        // who and what, bottom left
        Positioned(
          left: 14,
          right: 86,
          bottom: 22,
          child: GestureDetector(
            onTap: () => setState(() => open = !open),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(onTap: () => _person(who), child: NameLine(who, size: 15.5, color: Colors.white)),
              if (p.body.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    p.body.trim(),
                    maxLines: open ? 12 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4, shadows: [Shadow(blurRadius: 6, color: Colors.black54)]),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(ago(p.createdAt), style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ),
            ]),
          ),
        ),
        // sound
        Positioned(
          right: 10,
          top: MediaQuery.paddingOf(context).top + 56,
          child: ValueListenableBuilder<bool>(
            valueListenable: clipSound,
            builder: (_, on, __) => Semantics(
              button: true,
              label: on ? 'ხმის გამორთვა' : 'ხმის ჩართვა',
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('clip-sound'),
                onTap: () => clipSound.value = !on,
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Color(0x55000000), shape: BoxShape.circle),
                  child: PIcon(on ? 'vol' : 'voloff', size: 21, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        // how far along
        if (pl != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 2.5,
            child: ListenableBuilder(
              listenable: pl,
              builder: (_, __) {
                final d = pl.duration.inMilliseconds;
                final f = d <= 0 ? 0.0 : (pl.position.inMilliseconds / d).clamp(0.0, 1.0).toDouble();
                return Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: f, child: const ColoredBox(color: Colors.white)));
              },
            ),
          ),
      ]),
    );
  }
}

class _SideBtn extends StatelessWidget {
  const _SideBtn({super.key, required this.icon, required this.label, required this.onTap, this.text, this.color = Colors.white});
  final String icon, label;
  final String? text;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                PIcon(icon, size: 30, color: color, stroke: 2),
                if (text != null) ...[
                  const SizedBox(height: 3),
                  Text(text!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
                ],
              ]),
            ),
          ),
        ),
      );
}

/// A video over the whole app, swiped like the clips (from the feed: a video post; it may bring others along).
class ClipViewer extends StatelessWidget {
  const ClipViewer({super.key, required this.posts, this.start = 0});
  final List<Post> posts;
  final int start;
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: ClipFeed(
            posts: posts,
            start: start,
            top: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Row(children: [IconBtn('back', label: 'უკან', color: Colors.white, onTap: () => Navigator.of(context).maybePop())]),
              ),
            ),
          ),
        ),
      );
}
