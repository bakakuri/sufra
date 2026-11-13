import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../clips/clip_feed.dart';
import '../config.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../people/person_screen.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/rich_body.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'photo_viewer.dart';
import 'post_screen.dart';

/// One post as the site draws it: who wrote it, the words, photos (swipe, double tap for ❤️), a poll,
/// a shared post, then reactions, comments, the link and saving.
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.onDeleted, this.inPostScreen = false, this.sponsored = false});
  final Post post;
  final VoidCallback? onDeleted;

  /// a paid post (ads): "რეკლამა" beside the name
  final bool sponsored;

  /// on the post's own screen: the words unfolded, the comment button goes to the field below
  final bool inPostScreen;

  @override
  Widget build(BuildContext context) {
    if (post.plainRepost && post.original != null) {
      final c = context.pc, who = post.ap, mine = post.author == context.me.id;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
          child: Row(children: [
            PIcon('repost', size: 17, color: c.muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: mine ? 'შენ' : (who?.name ?? ''), style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
                  TextSpan(text: ' ${mine ? 'გააზიარე' : 'გააზიარა'} · ${ago(post.createdAt)}'),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.muted, fontSize: 13.5),
              ),
            ),
          ]),
        ),
        _PostView(post: post.original!, onDeleted: onDeleted, inPostScreen: inPostScreen),
      ]);
    }
    return _PostView(post: post, onDeleted: onDeleted, inPostScreen: inPostScreen, sponsored: sponsored);
  }
}

Future<void> openPerson(BuildContext context, Profile p) async {
  if (p.id.startsWith('page:')) return;
  await openPage(context, PersonScreen(uid: p.id, initial: p));
}

class _PostView extends StatelessWidget {
  const _PostView({required this.post, this.onDeleted, this.inPostScreen = false, this.sponsored = false});
  final Post post;
  final VoidCallback? onDeleted;
  final bool sponsored;
  final bool inPostScreen;

  Future<void> _open(BuildContext context, {bool focus = false}) async {
    if (inPostScreen) return;
    final gone = await openPage<bool>(context, PostScreen(post: post, focus: focus), full: true);
    if (gone == true) onDeleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final hasMedia = post.media.isNotEmpty;
    final quote = post.repostOf != null && !post.plainRepost;
    return Container(
      margin: EdgeInsets.fromLTRB(inPostScreen ? 0 : 12, 0, inPostScreen ? 0 : 12, inPostScreen ? 0 : 12),
      clipBehavior: Clip.antiAlias,
      decoration: inPostScreen
          ? BoxDecoration(color: c.surface)
          : BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Head(post: post, onDeleted: onDeleted, inPostScreen: inPostScreen, sponsored: sponsored),
        if (post.body.trim().isNotEmpty && post.body.trim() != post.poll?.q.trim())
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: RichBody(post.body.trim(), maxLines: inPostScreen ? null : (hasMedia ? 3 : 6)),
            ),
          ),
        if (hasMedia) _Gallery(post: post),
        if (post.media.any((m) => !m.isVideo)) _Grades(post: post),
        if (post.poll != null) Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 4), child: _PollView(post: post)),
        if (quote)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
            child: _Quote(original: post.original),
          ),
        _Actions(post: post, onComments: () => _open(context, focus: true), inPostScreen: inPostScreen),
      ]),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.post, this.onDeleted, this.inPostScreen = false, this.sponsored = false});
  final Post post;
  final VoidCallback? onDeleted;
  final bool inPostScreen, sponsored;

  Future<void> _more(BuildContext context) async {
    final mine = post.author == context.me.id;
    final link = '$siteUrl/#post-${post.id}';
    await showChoices(context, [
      SheetItem('copy', 'ბმულის კოპირება', () {
        Clipboard.setData(ClipboardData(text: link));
        toast(context, 'ბმული დაკოპირდა');
      }),
      SheetItem('globe', 'საიტზე გახსნა', () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication)),
      if (mine)
        SheetItem('trash', 'პოსტის წაშლა', () async {
          final yes = await confirm(context, title: 'წაიშალოს პოსტი?', text: 'აღარ გამოჩნდება არც შენთან, არც სხვებთან.', yes: 'წაშლა', danger: true);
          if (!yes || !context.mounted) return;
          final ok = await attempt(context, () => context.app.api.deletePost(post.id));
          if (ok && context.mounted) {
            toast(context, 'პოსტი წაიშალა');
            onDeleted?.call();
          }
        }, danger: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final who = post.ap ?? Profile(id: post.author, name: '');
    final tags = <Widget>[
      if (sponsored) const _Tag('რეკლამა', warn: true),
      if (post.byPage) const _Tag('არხი'),
      if (post.groupName != null) _Tag(post.groupName!),
      if (post.placeName != null) _Tag('📍 ${post.placeName}'),
      if (post.hidden) _Tag('დამალულია', warn: true),
      if (post.pending) _Tag('ელოდება დამტკიცებას', warn: true),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 10),
      child: Row(children: [
        GestureDetector(onTap: () => openPerson(context, who), child: Avatar(p: who, size: 40)),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openPerson(context, who),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: NameLine(who, size: 15)),
                for (final t in tags) Padding(padding: const EdgeInsets.only(left: 6), child: t),
              ]),
              const SizedBox(height: 2),
              Text('${ago(post.createdAt)}${post.edited ? ' · რედაქტირებული' : ''}', style: TextStyle(color: c.muted, fontSize: 12.5)),
            ]),
          ),
        ),
        IconBtn('more', label: 'მეტი მოქმედება', size: 22, color: c.muted, onTap: () => _more(context)),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.warn = false});
  final String text;
  final bool warn;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, col = warn ? c.gold : c.muted;
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: col.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: col, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}

/// The photos and videos: one frame the shape of the first, swiped sideways; a double tap leaves a ❤️.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.post});
  final Post post;
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> with SingleTickerProviderStateMixin {
  int at = 0;
  late final burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void dispose() {
    burst.dispose();
    super.dispose();
  }

  void _like() {
    burst.forward(from: 0);
    final store = context.app.posts;
    if (store.of(widget.post.id).mine == null) {
      attempt(context, () => store.react(widget.post.id, '❤️'));
    }
  }

  void _tap(Media m, int i) {
    if (m.isVideo) {
      openPage(context, ClipViewer(posts: [widget.post]), full: true);
      return;
    }
    final photos = widget.post.media.where((x) => !x.isVideo).toList();
    final at = photos.indexOf(m);
    openPhotos(context, photos, start: at > 0 ? at : 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, media = widget.post.media, n = media.length;
    return Column(children: [
      AspectRatio(
        aspectRatio: media.first.box,
        child: Stack(fit: StackFit.expand, children: [
          PageView.builder(
            itemCount: n,
            onPageChanged: (i) => setState(() => at = i),
            itemBuilder: (_, i) {
              final m = media[i];
              return GestureDetector(
                onTap: () => _tap(m, i),
                onDoubleTap: _like,
                child: m.isVideo ? _VideoTile(m) : PImage(m.mid),
              );
            },
          ),
          if (n > 1)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(20)),
                child: Text('${at + 1}/$n', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
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
                    opacity: t < .7 ? 1 : (1 - (t - .7) / .3),
                    child: Transform.scale(scale: s, child: const Text('❤️', style: TextStyle(fontSize: 88))),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
      if (n > 1)
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < n; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: i == at ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(color: i == at ? c.accent : c.line, borderRadius: BorderRadius.circular(3)),
              ),
          ]),
        ),
    ]);
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile(this.m);
  final Media m;
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        if (m.poster != null)
          PImage(m.poster!)
        else
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1E2230), Color(0xFF0C0E14)]))),
        Center(
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .45), shape: BoxShape.circle),
            child: const Padding(padding: EdgeInsets.only(left: 4), child: PIcon('play', size: 30, color: Colors.white)),
          ),
        ),
      ]);
}

class _PollView extends StatelessWidget {
  const _PollView({required this.post});
  final Post post;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, store = context.app.posts, poll = post.poll!;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.of(post.id), tot = s.voteTotal, voted = s.myVote != null;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(poll.q, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
          const SizedBox(height: 8),
          for (var i = 0; i < poll.opts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Semantics(
                button: true,
                selected: s.myVote == i,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => attempt(context, () => store.vote(post.id, i)),
                  child: Container(
                    height: 44,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: s.myVote == i ? c.accent : c.line, width: s.myVote == i ? 1.6 : 1),
                    ),
                    child: Stack(children: [
                      if (voted)
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: tot == 0 ? 0 : (s.votes[i] ?? 0) / tot,
                            child: ColoredBox(color: s.myVote == i ? c.accentSoft : c.sunk),
                          ),
                        ),
                      Positioned.fill(
                        child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(children: [
                          Expanded(child: Text(poll.opts[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: s.myVote == i ? FontWeight.w700 : FontWeight.w500))),
                          if (voted) Text('${tot == 0 ? 0 : ((s.votes[i] ?? 0) * 100 / tot).round()}%', style: TextStyle(fontWeight: FontWeight.w700, color: c.muted)),
                        ]),
                      ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          Text('$tot ხმა${voted ? '' : ' · აირჩიე პასუხი'}', style: TextStyle(color: c.muted, fontSize: 13)),
        ]);
      },
    );
  }
}

/// A shared post inside a post: a small card that opens the original.
class _Quote extends StatelessWidget {
  const _Quote({required this.original});
  final Post? original;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, o = original;
    if (o == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
        child: Row(children: [
          PIcon('repost', size: 18, color: c.muted),
          const SizedBox(width: 8),
          Expanded(child: Text('ეს პოსტი აღარ არის ხელმისაწვდომი', style: TextStyle(color: c.muted))),
        ]),
      );
    }
    final who = o.ap ?? Profile(id: o.author, name: ''), m = o.media.firstOrNull;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => openPage(context, PostScreen(post: o), full: true),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (m != null) ...[
            SizedBox.square(dimension: 64, child: m.isVideo && m.poster == null ? Container(color: c.sunk, child: Center(child: PIcon('play', color: c.muted))) : PImage(m.isVideo ? m.poster! : m.small, radius: 10)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Avatar(p: who, size: 22),
                const SizedBox(width: 6),
                Flexible(child: NameLine(who, size: 13.5)),
                Text(' · ${ago(o.createdAt)}', style: TextStyle(color: c.muted, fontSize: 12.5)),
              ]),
              if (o.body.trim().isNotEmpty || o.poll != null) ...[
                const SizedBox(height: 5),
                Text(o.body.trim().isNotEmpty ? o.body.trim() : '📊 ${o.poll!.q}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.35)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.post, required this.onComments, this.inPostScreen = false});
  final Post post;
  final VoidCallback onComments;
  final bool inPostScreen;

  Future<void> _pick(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final at = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final e = await pickReaction(context, at);
    if (e != null && context.mounted) await attempt(context, () => context.app.posts.react(post.id, e));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, store = context.app.posts;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.of(post.id), top = s.top;
        return Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 8, 6),
          child: Row(children: [
            Builder(
              builder: (bctx) => _Act(
                key: ValueKey('react-${post.id}'),
                label: s.mine == null ? 'რეაქცია' : 'რეაქციის მოხსნა',
                on: s.mine != null,
                icon: s.mine == null ? PIcon('heart', size: 23, color: c.ink) : Text(reactionGlyph(s.mine!), style: const TextStyle(fontSize: 20, height: 1.1)),
                count: s.total,
                onTap: () => s.mine == null ? _pick(bctx) : attempt(context, () => store.react(post.id, null)),
                onLong: () => _pick(bctx),
              ),
            ),
            _Act(key: ValueKey('comments-${post.id}'), label: 'კომენტარები', icon: PIcon('comment', size: 23, color: c.ink), count: s.comments, onTap: onComments),
            _Act(
              label: 'ბმულის გაზიარება',
              icon: PIcon('send', size: 22, color: c.ink),
              onTap: () {
                Clipboard.setData(ClipboardData(text: '$siteUrl/#post-${post.id}'));
                toast(context, 'ბმული დაკოპირდა — ჩასვი სადაც გინდა');
              },
            ),
            _Act(
              key: ValueKey('save-${post.id}'),
              label: s.saved ? 'შენახულია' : 'შენახვა',
              on: s.saved,
              icon: PIcon(s.saved ? 'bookmarked' : 'bookmark', size: 22, color: s.saved ? c.accent : c.ink),
              onTap: () async {
                final ok = await attempt(context, () => store.save(post.id));
                if (ok && context.mounted) toast(context, store.of(post.id).saved ? 'შენახულია' : 'შენახულიდან ამოიშალა');
              },
            ),
            const Spacer(),
            if (top.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(top.map(reactionGlyph).join(), style: const TextStyle(fontSize: 15, letterSpacing: -2)),
              ),
          ]),
        );
      },
    );
  }
}

class _Act extends StatelessWidget {
  const _Act({super.key, required this.label, required this.icon, required this.onTap, this.count = 0, this.on = false, this.onLong});
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final VoidCallback? onLong;
  final int count;
  final bool on;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLong,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(height: 24, child: Center(child: icon)),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text(grouped(count), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: on ? c.accent : c.ink)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// The seven reactions in a pill above the button; null when closed without a choice (back closes it too).
Future<String?> pickReaction(BuildContext context, Rect? anchor) {
  final c = context.pc;
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'დახურვა',
    barrierColor: Colors.black.withValues(alpha: .08),
    transitionDuration: const Duration(milliseconds: 170),
    pageBuilder: (ctx, _, __) {
      final size = MediaQuery.sizeOf(ctx);
      const w = 7 * 44.0 + 14;
      final a = anchor ?? Rect.fromLTWH(size.width / 2, size.height / 2, 0, 0);
      final left = (a.left - 4).clamp(8.0, size.width - w - 8).toDouble();
      final top = (a.top - 60).clamp(MediaQuery.paddingOf(ctx).top + 8, size.height - 70).toDouble();
      return Stack(children: [
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: c.surface,
            elevation: 8,
            shadowColor: Colors.black38,
            shape: StadiumBorder(side: BorderSide(color: c.line)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final e in reactions)
                  Semantics(
                    button: true,
                    label: e == '🍷' ? 'კარგი იდეა' : e,
                    excludeSemantics: true,
                    child: InkResponse(
                      key: ValueKey('react-$e'),
                      radius: 24,
                      onTap: () => Navigator.pop(ctx, e),
                      child: SizedBox(width: 44, height: 44, child: Center(child: Text(reactionGlyph(e), style: const TextStyle(fontSize: 27)))),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ]);
    },
    transitionBuilder: (_, a, __, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: .85, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: child),
    ),
  );
}

/// The 5+ price (the admin sets it; half goes to the photo's author), asked once a session.
Future<int>? _plusCost;
Future<int> plusCost(AppState app) => _plusCost ??= app.api.myCoins().then((m) => m['plus_cost'] == null ? 50 : asInt(m['plus_cost'])).catchError((_) {
      _plusCost = null;
      return 50;
    });

/// A photo's grade, as on the site: 1 to 5 free, 5+ for coins (the first time it says so first); the average under it.
/// The author sees only the average.
class _Grades extends StatelessWidget {
  const _Grades({required this.post});
  final Post post;

  Future<void> _grade(BuildContext context, String g) async {
    final app = context.app, s = app.posts.of(post.id);
    if (s.myGrade == g) return;
    if (g == '5+') {
      final cost = await plusCost(app);
      if (!context.mounted) return;
      var told = false;
      try {
        told = (await SharedPreferences.getInstance()).getBool('plus5') == true;
      } catch (_) {}
      if (cost > 0 && !told) {
        if (!context.mounted) return;
        final coins = context.me.coins;
        final ok = await showModalBottomSheet<bool>(
          context: context,
          useRootNavigator: true,
          showDragHandle: true,
          backgroundColor: context.pc.surface,
          builder: (sh) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('„5+“ მონეტებით', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text.rich(TextSpan(children: [
                  const TextSpan(text: '„5+“-ის დაწერა '),
                  TextSpan(text: '${grouped(cost)} მონეტა', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const TextSpan(text: ' ღირს. ნახევარი ფოტოს ავტორს მიდის საჩუქრად.'),
                ])),
                const SizedBox(height: 8),
                Text('ერთ პოსტზე ერთხელ იხდი: შეფასებას თუ შეცვლი და ისევ „5+“-ს დაწერ, აღარ ჩამოგეჭრება. 1-დან 5-მდე შეფასება ისევ უფასოა.',
                    style: TextStyle(color: sh.pc.muted, fontSize: 13.5, height: 1.4)),
                const SizedBox(height: 8),
                Text('ბალანსი: ${grouped(coins)} მონეტა', style: TextStyle(color: sh.pc.muted, fontSize: 13.5)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.of(sh).pop(false), child: const Text('გაუქმება'))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('plus-go'),
                      onPressed: coins < cost ? null : () => Navigator.of(sh).pop(true),
                      child: FittedBox(child: Text(coins < cost ? 'მონეტები არ გყოფნის' : '„5+“ · ${grouped(cost)} მონეტა')),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        );
        if (ok != true) return;
        try {
          await (await SharedPreferences.getInstance()).setBool('plus5', true);
        } catch (_) {}
      }
    }
    if (!context.mounted) return;
    final prev = s.myGrade;
    try {
      final paid = await app.posts.grade(post.id, g);
      if (g == '5+') app.refreshMe?.call();
      if (context.mounted) {
        toast(context, (prev != null ? 'შეფასება შეიცვალა' : (g == '5+' ? '„5+“ გაიგზავნა' : 'შეფასება გაიგზავნა')) + (paid > 0 ? ' · ავტორს +$paid მონეტა' : ''));
      }
    } catch (e) {
      if (!context.mounted) return;
      final cost = await plusCost(app);
      if (context.mounted) toast(context, '$e'.contains('not_enough_coins') ? '„5+“ ${grouped(cost)} მონეტა ღირს: მონეტები არ გყოფნის' : errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, store = context.app.posts, mine = post.author == context.me.id;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.of(post.id);
        final sum = s.gradeN > 0 && s.gradeAvg != null ? 'საშ. ${s.gradeAvg} · ${s.gradeN}' : null;
        if (mine && sum == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          // as on the site, it wraps when the line is too narrow
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 4, children: [
            Padding(padding: const EdgeInsets.only(right: 6), child: Text('შეფასება', style: TextStyle(color: c.muted, fontSize: 12))),
            if (!mine)
              for (final g in const ['1', '2', '3', '4', '5', '5+'])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Material(
                    color: s.myGrade == g ? c.gold : Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7), side: BorderSide(color: s.myGrade == g || g == '5+' ? c.gold : c.line)),
                    child: InkWell(
                      key: ValueKey('grade-${post.id}-$g'),
                      borderRadius: BorderRadius.circular(7),
                      onTap: () => _grade(context, g),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 30),
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        // sized by its number (an alignment would stretch it across the line)
                        child: Center(
                          widthFactor: 1,
                          child: Text(g,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: s.myGrade == g ? const Color(0xFF1A1205) : (g == '5+' ? c.gold : c.ink),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            )),
                        ),
                      ),
                    ),
                  ),
                ),
            if (sum != null) Padding(padding: const EdgeInsets.only(left: 4), child: Text(sum, style: TextStyle(color: c.muted, fontSize: 12))),
          ]),
        );
      },
    );
  }
}
