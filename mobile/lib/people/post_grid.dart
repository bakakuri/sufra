// A profile's posts as a grid of squares, as on the site (people.js gridHTML): the first photo (or a video's still,
// or the words on a colour), a corner mark for several photos, a video or a poll, and a photo's grade at the bottom.
// A tap opens the post.
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../feed/post_screen.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';

class PostGrid extends StatelessWidget {
  const PostGrid({super.key, required this.posts, this.onGone});
  final List<Post> posts;

  /// a post deleted from its own page
  final void Function(Post p)? onGone;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: app.posts,
      builder: (context, _) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
        itemCount: posts.length,
        itemBuilder: (context, i) => _Tile(post: posts[i], stats: app.posts.of(posts[i].id), mine: posts[i].author == app.api.myId, onGone: onGone),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.post, required this.stats, required this.mine, this.onGone});
  final Post post;
  final PostStats stats;
  final bool mine;
  final void Function(Post p)? onGone;

  @override
  Widget build(BuildContext context) {
    final c = context.pc, p = post.original != null && post.plainRepost ? post.original! : post, ms = p.media;
    final m = ms.where((x) => !x.isVideo).firstOrNull ?? ms.firstOrNull;
    final h = ((p.ap?.hue ?? 200) % 360).toDouble();
    Widget inner;
    if (m != null && !m.isVideo) {
      inner = PImage(m.small, fit: BoxFit.cover);
    } else if (m != null && (m.poster ?? '').isNotEmpty) {
      inner = PImage(m.poster!, fit: BoxFit.cover);
    } else {
      inner = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-.6, -1),
            end: const Alignment(.6, 1),
            colors: [HSLColor.fromAHSL(1, h, .45, .36).toColor(), HSLColor.fromAHSL(1, (h + 40) % 360, .5, .22).toColor()],
          ),
        ),
        child: m != null
            ? const Center(child: PIcon('clips', size: 28, color: Colors.white))
            : Padding(
                padding: const EdgeInsets.all(10),
                child: Text(p.body.length > 140 ? p.body.substring(0, 140) : p.body,
                    maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.35)),
              ),
      );
    }
    final hasPhoto = ms.any((x) => !x.isVideo);
    Widget? badge;
    if (ms.length > 1) {
      badge = Row(mainAxisSize: MainAxisSize.min, children: [
        const PIcon('image', size: 16, color: Colors.white),
        const SizedBox(width: 2),
        Text('${ms.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ]);
    } else if (m != null && m.isVideo) {
      badge = const PIcon('clips', size: 16, color: Colors.white);
    } else if (p.poll != null) {
      badge = const PIcon('poll', size: 16, color: Colors.white);
    }
    Widget? grade;
    if (hasPhoto) {
      final s = stats;
      if (s.myGrade != null) {
        grade = _Grade(text: s.myGrade!, small: s.gradeN > 1 && s.gradeAvg != null ? '${s.gradeAvg}' : null, gold: true);
      } else if (s.gradeN > 0 && s.gradeAvg != null) {
        grade = _Grade(text: '${s.gradeAvg}', small: '${s.gradeN}');
      } else if (!mine) {
        grade = const _Grade(text: 'შეაფასე', soft: true);
      }
    }
    return Semantics(
      button: true,
      label: 'პოსტის გახსნა',
      child: GestureDetector(
        key: ValueKey('grid-${post.id}'),
        onTap: () async {
          final gone = await openPage<bool>(context, PostScreen(post: post), full: true);
          if (gone == true) onGone?.call(post);
        },
        child: Opacity(
          opacity: post.hidden ? .5 : 1,
          child: ColoredBox(
            color: c.sunk,
            child: Stack(fit: StackFit.expand, children: [
              inner,
              if (badge != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 4)]),
                    child: badge,
                  ),
                ),
              if (grade != null) Positioned(left: 6, bottom: 6, child: grade),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Grade extends StatelessWidget {
  const _Grade({required this.text, this.small, this.gold = false, this.soft = false});
  final String text;
  final String? small;
  final bool gold, soft;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, fg = gold ? const Color(0xFF1A1205) : Colors.white;
    return Container(
      height: 22,
      padding: const EdgeInsets.fromLTRB(5, 0, 7, 0),
      decoration: BoxDecoration(color: gold ? c.gold : Color.fromRGBO(14, 10, 18, soft ? .5 : .62), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        PIcon('star', size: 13, color: gold ? fg : (soft ? Colors.white : const Color(0xFFFFD166))),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: soft ? FontWeight.w600 : FontWeight.w700)),
        if (small != null) ...[
          const SizedBox(width: 2),
          Text(small!, style: TextStyle(color: fg.withValues(alpha: .75), fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }
}
