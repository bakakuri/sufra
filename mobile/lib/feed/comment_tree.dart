// A post's comments as Facebook threads them: a comment, the answers to it one step in, the answers to those one step
// further; an answer to one of those stays on that second step and names whom it answers. Each answer is folded under
// what it answers behind "N პასუხის ნახვა", and thin lines lead from a comment's face to its answers.
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// where a comment of each step starts, and its face's size
const commentIndent = [14.0, 56.0, 92.0], commentAvatar = [36.0, 30.0, 24.0];

/// the line under a face runs down its middle
double _railX(int depth) => commentIndent[depth] + commentAvatar[depth] / 2;

/// The comments: the first ones in their order, the answers under what they hang on (oldest first).
class CommentForest {
  CommentForest(List<Comment> tops, Iterable<Comment> replies) : tops = List.of(tops) {
    for (final c in [...tops, ...replies]) {
      byId[c.id] = c;
    }
    for (final r in replies) {
      if (r.parentId != null && byId.containsKey(r.parentId)) {
        (kids[r.parentId!] ??= []).add(r);
      } else if (!this.tops.any((t) => t.id == r.id)) {
        // its comment is gone: it stands on its own
        this.tops.add(r);
      }
    }
    for (final l in kids.values) {
      l.sort((a, b) => a.createdAt != b.createdAt ? a.createdAt.compareTo(b.createdAt) : a.id.compareTo(b.id));
    }
  }

  /// all of a post's comments at once (the oldest first)
  factory CommentForest.of(List<Comment> all) {
    final ids = {for (final c in all) c.id};
    return CommentForest([for (final c in all) if (c.parentId == null || !ids.contains(c.parentId)) c], [for (final c in all) if (c.parentId != null && ids.contains(c.parentId)) c]);
  }

  final List<Comment> tops;
  final byId = <int, Comment>{};
  final kids = <int, List<Comment>>{};

  /// 0 a comment, 1 an answer to it, 2 an answer to an answer (and everything further down)
  int depth(Comment c) {
    var d = 0;
    var x = c;
    while (x.parentId != null && byId[x.parentId] != null && d < 4) {
      x = byId[x.parentId]!;
      d++;
    }
    return d > 2 ? 2 : d;
  }

  /// the comment an answer answers: the one it names, or the one it hangs under
  Comment? answered(Comment c) => byId[c.replyTo] ?? byId[c.parentId];

  /// the first comment a comment belongs to
  Comment root(Comment c) {
    var x = c;
    for (var i = 0; i < 4 && x.parentId != null && byId[x.parentId] != null; i++) {
      x = byId[x.parentId]!;
    }
    return x;
  }

  /// everything under a comment
  List<Comment> under(int id) => [for (final k in kids[id] ?? const <Comment>[]) ...[k, ...under(k.id)]];
}

/// The rows of the list: each comment with what hangs under it (open or behind its line), and the first comment each
/// row belongs to (for reading more as the end comes near).
List<(int, Widget Function())> commentRows(
  BuildContext context,
  CommentForest f, {
  required Set<int> open,
  required Widget Function(Comment c, int depth, Comment? answered) tile,
  required void Function(int id) toggle,
}) {
  final rows = <(int, Widget Function())>[];
  for (var i = 0; i < f.tops.length; i++) {
    final t = f.tops[i], l1 = f.kids[t.id] ?? const <Comment>[];
    rows.add((i, () => ThreadRail(down: l1.isEmpty ? null : 0, child: tile(t, 0, null))));
    if (l1.isEmpty) continue;
    if (open.contains(t.id)) {
      for (final a in l1) {
        final l2 = f.kids[a.id] ?? const <Comment>[];
        rows.add((i, () => ThreadRail(through: const [0], elbow: 1, down: l2.isEmpty ? null : 1, child: tile(a, 1, f.answered(a)))));
        if (l2.isEmpty) continue;
        if (open.contains(a.id)) {
          for (final b in l2) {
            rows.add((i, () => ThreadRail(through: const [0, 1], elbow: 2, child: tile(b, 2, f.answered(b)))));
          }
        }
        rows.add((i, () => ThreadRail(through: const [0], elbow: 2, last: true, child: ThreadToggle(of: a, depth: 2, count: l2.length, first: l2.first, open: open.contains(a.id), onTap: () => toggle(a.id)))));
      }
    }
    final all = f.under(t.id);
    rows.add((i, () => ThreadRail(elbow: 1, last: true, child: ThreadToggle(of: t, depth: 1, count: all.length, first: l1.first, open: open.contains(t.id), onTap: () => toggle(t.id)))));
  }
  return rows;
}

/// "N პასუხის ნახვა" with the first answerer's face, or "პასუხების დამალვა"
class ThreadToggle extends StatelessWidget {
  const ThreadToggle({super.key, required this.of, required this.depth, required this.count, required this.first, required this.open, required this.onTap});
  final Comment of, first;
  final int depth, count;
  final bool open;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: EdgeInsets.fromLTRB(commentIndent[depth] - 4, 0, 14, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          key: ValueKey('cthread-${of.id}'),
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (!open && first.ap != null) ...[Avatar(p: first.ap!, size: 20), const SizedBox(width: 6)],
              Flexible(
                child: Text(open ? 'პასუხების დამალვა' : (count == 1 ? '1 პასუხის ნახვა' : 'ყველა $count პასუხის ნახვა'),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The thin lines beside a row: going on past it ([through]), turning into its face ([elbow], the row's step), and
/// starting under its own face toward its answers ([down]); [last] ends the turning line there.
class ThreadRail extends StatelessWidget {
  const ThreadRail({super.key, required this.child, this.through = const [], this.elbow, this.down, this.last = false});
  final Widget child;
  final List<int> through;
  final int? elbow, down;
  final bool last;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _Rail(context.pc.line, through, elbow, down, last), child: child);
}

class _Rail extends CustomPainter {
  _Rail(this.color, this.through, this.elbow, this.down, this.last);
  final Color color;
  final List<int> through;
  final int? elbow, down;
  final bool last;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final d in through) {
      canvas.drawLine(Offset(_railX(d), 0), Offset(_railX(d), size.height), p);
    }
    final e = elbow;
    if (e != null) {
      // from the line of the step above, round into this row's face (or its "N პასუხი" line)
      final x = _railX(e - 1), y = last ? size.height / 2 - 2 : 6 + commentAvatar[e] / 2, to = commentIndent[e] - (last ? 6 : 3);
      const r = 10.0;
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x, y - r)
        ..quadraticBezierTo(x, y, x + r, y)
        ..lineTo(to, y);
      canvas.drawPath(path, p);
    }
    final dn = down;
    if (dn != null) {
      canvas.drawLine(Offset(_railX(dn), 6 + commentAvatar[dn] + 3), Offset(_railX(dn), size.height), p);
    }
  }

  @override
  bool shouldRepaint(_Rail o) => o.color != color || o.elbow != elbow || o.down != down || o.last != last || o.through.length != through.length;
}
