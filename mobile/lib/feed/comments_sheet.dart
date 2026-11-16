// All of a post's comments in a window that comes up from below, as Facebook shows them: the comments the newest first
// (fifteen at the start and ten more each time the reader comes near the end); an answer one step in, an answer to an
// answer one step further, and further answers on that step naming whom they answer; each folded under what it
// answers behind "N პასუხის ნახვა"; "პასუხი" under every one; liking and deleting as on the post's page.
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/mentions.dart';
import '../ui/stickers.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'comment_tree.dart';
import 'compose_screen.dart';
import 'post_actions.dart';
import 'post_card.dart';
import 'post_screen.dart';

/// how many come first, and how many more each time
const commentsFirst = 15, commentsMore = 10;

/// The window; [replyTo] opens it answering that comment, [thread] with that comment's answers open.
Future<void> showCommentsSheet(BuildContext context, Post post, {Comment? replyTo, int? thread}) =>
    _commentsWindow<void>(context, post, replyTo: replyTo, thread: thread, withPost: false);

/// A post seen by itself (from a notification, a link, a grid, a chat): never a page of its own, but the window over
/// where one is, the post on top and its comments under it. True when the post was deleted from there.
Future<bool?> openPost(BuildContext context, Post post, {Comment? replyTo, int? thread, bool focus = false}) =>
    _commentsWindow<bool>(context, post, replyTo: replyTo, thread: thread, withPost: true, focus: focus);

Future<T?> _commentsWindow<T>(BuildContext context, Post post, {Comment? replyTo, int? thread, required bool withPost, bool focus = false}) {
  // the window stands over the whole app, outside the tab: it takes the app with it
  final scope = AppScope.of(context);
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => AppScope(
      app: scope.app,
      me: scope.me,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(s).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(s).height * (withPost ? .93 : .86),
          child: CommentsPanel(post: post, replyTo: replyTo, thread: thread, withPost: withPost, focus: focus),
        ),
      ),
    ),
  );
}

class CommentsPanel extends StatefulWidget {
  const CommentsPanel({super.key, required this.post, this.replyTo, this.thread, this.withPost = false, this.focus = false});
  final Post post;
  final Comment? replyTo;
  final int? thread;

  /// the post itself on top of its comments (a post opened by itself)
  final bool withPost;

  /// the field ready to type in
  final bool focus;
  @override
  State<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends State<CommentsPanel> {
  /// the comments (not the answers), newest first
  final tops = <Comment>[];

  /// the answers (to the comments and to answers)
  final replies = <Comment>[];

  /// the comments and answers whose answers are open
  final open = <int>{};
  bool loading = false, done = false, sending = false, _started = false;
  Object? error;
  Comment? replyTo;
  Set<int> liked = {};
  final likes = <int, int>{};
  final field = TextEditingController();
  final focus = FocusNode();
  final scroll = ScrollController();

  /// the answer I just wrote, brought into view
  int? _just;
  final _justKey = GlobalKey();

  int get _id => widget.post.id;
  int get _loaded => tops.length + replies.length;
  CommentForest get _forest => CommentForest(tops, replies);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.thread != null) open.add(widget.thread!);
    if (widget.focus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focus.requestFocus();
      });
    }
    final r = widget.replyTo;
    if (r != null) {
      open.add(r.id);
      if (r.parentId != null) open.add(r.parentId!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reply(r);
      });
    }
    _more();
  }

  @override
  void dispose() {
    field.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  /// the next page: fifteen at first, then ten more, each with its answers
  Future<void> _more() async {
    if (loading || done) return;
    final app = context.app, first = tops.isEmpty, n = first ? commentsFirst : commentsMore;
    setState(() => loading = true);
    try {
      final r = await app.api.commentsPage(_id, from: tops.length, count: n);
      final have = {for (final c in tops) c.id};
      final fresh = [for (final c in r) if (!have.contains(c.id)) c];
      final rs = await app.api.commentReplies(_id, [for (final c in fresh) c.id]);
      if (!mounted) return;
      setState(() {
        tops.addAll(fresh);
        final had = {for (final y in replies) y.id};
        replies.addAll([for (final x in rs) if (!had.contains(x.id)) x]);
        for (final c in [...fresh, ...rs]) {
          likes[c.id] ??= c.likes;
        }
        done = r.length < n;
        loading = false;
        error = null;
      });
      // with everything here, the count under the post is put right
      final s = app.posts.of(_id);
      if (done && s.comments != _loaded) app.posts.commented(_id, _loaded - s.comments);
      app.api.commentLikes([for (final c in [...fresh, ...rs]) c.id]).then((l) {
        if (mounted) setState(() => liked = {...liked, ...l});
      }).catchError((_) {});
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e;
        });
      }
    }
  }

  Future<bool> _post(String body, {Map<String, dynamic>? media}) async {
    if (sending) return false;
    final app = context.app, par = replyTo;
    setState(() => sending = true);
    try {
      // the comment answered goes as its parent; the server hangs it where it belongs (two steps in at most)
      final c = await app.api.addComment(_id, body, parentId: par?.id, media: media);
      if (!mounted) return true;
      setState(() {
        if (c.parentId == null) {
          tops.insert(0, c);
        } else {
          replies.add(c);
          final f = _forest;
          for (Comment? x = f.byId[c.parentId]; x != null; x = f.byId[x.parentId]) {
            open.add(x.id);
          }
        }
        likes[c.id] = 0;
        replyTo = null;
        sending = false;
      });
      app.posts.commented(_id);
      if (c.parentId == null) {
        if (scroll.hasClients) scroll.animateTo(0, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
      } else {
        _show(c.id);
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => sending = false);
      toast(context, errText(e));
      return false;
    }
  }

  /// an answer just written: the list goes to it (built or not yet)
  void _show(int id) {
    _just = id;
    var tries = 0;
    void look() {
      if (!mounted || tries++ > 12) return;
      final ctx = _justKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx, alignment: .5, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
        return;
      }
      if (scroll.hasClients) {
        final pos = scroll.position;
        scroll.jumpTo((pos.pixels + pos.viewportDimension * .8).clamp(0.0, pos.maxScrollExtent));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => look());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => look());
  }

  Future<void> _send() async {
    final t = field.text.trim();
    if (t.isEmpty) return;
    field.clear();
    if (!await _post(t)) field.text = t;
  }

  Future<void> _sticker() async {
    final r = await pickSticker(context);
    if (r == null || !mounted) return;
    if (r.emoji != null) {
      final v = field.value, at = v.selection.isValid ? v.selection.baseOffset : v.text.length;
      final text = v.text.substring(0, at) + r.emoji! + v.text.substring(at);
      field.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: at + r.emoji!.length));
      focus.requestFocus();
      return;
    }
    final k = r.sticker!;
    await _post(stickerLabel(k) ?? '✨', media: {'sticker': k});
  }

  Future<void> _photo() async {
    final app = context.app;
    try {
      final got = await photoSource(false);
      if (got.isEmpty || !mounted) return;
      final pic = await editPicked(context, got.first);
      if (!mounted) return;
      toast(context, 'იტვირთება…');
      final m = await app.api.uploadPhoto(await photoPrep(pic));
      final t = field.text.trim();
      field.clear();
      if (!await _post(t.isEmpty ? '📷' : t, media: {'url': m.url, if (m.sm != null) 'sm': m.sm, 'w': m.w, 'h': m.h})) field.text = t;
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  /// answering a comment or an answer; an answer to one already two steps in stays beside it and names its author
  void _reply(Comment c) {
    final f = _forest;
    setState(() {
      replyTo = c;
      for (Comment? x = c; x != null; x = f.byId[x.parentId]) {
        open.add(x.id);
      }
    });
    final u = c.ap?.username ?? '';
    if (f.depth(c) >= 2 && u.isNotEmpty && c.author != context.me.id && !field.text.contains('@$u')) {
      field.text = '@$u ${field.text}';
      field.selection = TextSelection.collapsed(offset: field.text.length);
    }
    focus.requestFocus();
  }

  Future<void> _like(Comment c) async {
    final on = !liked.contains(c.id);
    setState(() {
      on ? liked.add(c.id) : liked.remove(c.id);
      likes[c.id] = ((likes[c.id] ?? c.likes) + (on ? 1 : -1)).clamp(0, 1 << 30).toInt();
    });
    try {
      await context.app.api.likeComment(c.id, on);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        on ? liked.remove(c.id) : liked.add(c.id);
        likes[c.id] = ((likes[c.id] ?? 0) + (on ? -1 : 1)).clamp(0, 1 << 30).toInt();
      });
      toast(context, errText(e));
    }
  }

  Future<void> _delete(Comment c) async {
    final yes = await confirm(context, title: 'კომენტარის წაშლა', text: 'წაიშლება კომენტარი და მისი პასუხებიც.', yes: 'წაშლა', danger: true);
    if (!yes || !mounted) return;
    final app = context.app;
    if (!await attempt(context, () => app.api.deleteComment(c.id)) || !mounted) return;
    final ids = {c.id, for (final x in _forest.under(c.id)) x.id};
    setState(() {
      tops.removeWhere((x) => ids.contains(x.id));
      replies.removeWhere((x) => ids.contains(x.id));
    });
    app.posts.commented(_id, -ids.length);
  }

  Widget _tile(Comment cm, int depth, Comment? to) {
    final me = context.me.id, staff = isStaff(context), author = widget.post.author;
    return _Arrive(
      key: ValueKey('cm-${cm.id}'),
      child: KeyedSubtree(
        key: cm.id == _just ? _justKey : null,
        child: CommentTile(
          c: cm,
          depth: depth,
          answered: to,
          liked: liked.contains(cm.id),
          likes: likes[cm.id] ?? cm.likes,
          canDelete: cm.author == me || author == me || staff,
          onReply: () => _reply(cm),
          onLike: () => _like(cm),
          onDelete: () => _delete(cm),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    // a flat list: each comment, then what hangs under it (or the line that opens it)
    final rows = commentRows(context, _forest, open: open, tile: _tile, toggle: (id) => setState(() => open.contains(id) ? open.remove(id) : open.add(id)));
    return ListenableBuilder(
      listenable: context.app.posts,
      builder: (context, _) {
        final total = context.app.posts.of(_id).comments;
        final head = Padding(
          padding: EdgeInsets.fromLTRB(20, widget.withPost ? 10 : 0, 20, 6),
          child: Row(children: [
            Expanded(
              child: Text(total > 0 ? 'კომენტარები · $total' : 'კომენტარები', key: const ValueKey('cs-title'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ),
            Text('ჯერ ახლები', style: TextStyle(color: c.muted, fontSize: 12.5)),
          ]),
        );
        // a post by itself: the post, then its comments, in one list
        final post = !widget.withPost
            ? null
            : PostCard(
                key: ValueKey('cs-post-$_id'),
                post: widget.post,
                inPostScreen: true,
                onDeleted: () => Navigator.of(context).pop(true),
              );
        final lead = post == null ? 0 : 2, none = post != null && done && tops.isEmpty;
        return Column(children: [
          if (post == null) ...[head, Divider(height: 1, color: c.line)],
          Expanded(
            child: tops.isEmpty && post == null
                ? (error != null
                    ? Empty(icon: 'comment', title: 'კომენტარები ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _more)
                    : loading || !done
                        ? const Center(child: SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 2.4)))
                        : Center(child: Text('ჯერ არავის დაუწერია. იყავი პირველი!', style: TextStyle(color: c.muted, fontSize: 14.5))))
                : ListView.builder(
                    key: const ValueKey('cs-list'),
                    controller: scroll,
                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                    itemCount: lead + rows.length + (done ? 0 : 1) + (none ? 1 : 0),
                    itemBuilder: (context, j) {
                      if (post != null && j == 0) return post;
                      if (post != null && j == 1) return Column(children: [Divider(height: 1, color: c.line), head]);
                      final i = j - lead;
                      if (none) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                          child: Text(error != null ? errText(error!) : 'ჯერ არავის დაუწერია. იყავი პირველი!', style: TextStyle(color: c.muted, fontSize: 14.5)),
                        );
                      }
                      // near the end of what is here (five comments before it), the next ten are asked for
                      if (!done && error == null && (i >= rows.length || rows[i].$1 >= tops.length - 5)) WidgetsBinding.instance.addPostFrameCallback((_) => _more());
                      if (i >= rows.length && error != null) {
                        return Center(child: TextButton(onPressed: _more, child: const Text('ვერ ჩაიტვირთა. ხელახლა ცდა')));
                      }
                      if (i >= rows.length) {
                        return const Padding(padding: EdgeInsets.all(18), child: Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.2))));
                      }
                      return rows[i].$2();
                    },
                  ),
          ),
          MentionSuggest(field: field),
          CommentInputBar(
            fieldKey: const ValueKey('cs-field'),
            field: field,
            focus: focus,
            sending: sending,
            replyTo: replyTo,
            onCancelReply: () => setState(() => replyTo = null),
            onSend: _send,
            onSticker: _sticker,
            onPhoto: _photo,
          ),
        ]);
      },
    );
  }
}

/// a comment coming into the list: up a little and in
class _Arrive extends StatelessWidget {
  const _Arrive({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 14), child: c)),
        child: child,
      );
}

/// The newest comments under a post in the feed, opened like an accordion: the last five (oldest of them first), each
/// with "პასუხი" and how many answers it has (both open the window), all of them in the window, and a line to write one
/// straight away — what is written shows at once.
class InlineComments extends StatefulWidget {
  const InlineComments({super.key, required this.post});
  final Post post;
  @override
  State<InlineComments> createState() => _InlineCommentsState();
}

/// Under the post, as Facebook keeps it: the last comments, each with "ყველა N პასუხის ნახვა" right under it that
/// opens its answers there (one step in, and one more), "პასუხი" under every one answering it here; "ყველას ნახვა"
/// opens every comment in the window.
class _InlineCommentsState extends State<InlineComments> {
  List<Comment>? tops;
  final replies = <Comment>[];
  final open = <int>{};
  Set<int> liked = {};
  final likes = <int, int>{};
  Comment? replyTo;
  Object? error;
  bool sending = false, _started = false;
  final field = TextEditingController();
  final focus = FocusNode();
  final _endKey = GlobalKey();

  int get _id => widget.post.id;
  CommentForest get _forest => CommentForest(tops ?? const [], replies);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    field.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.app.api;
    try {
      final r = await api.commentsPage(_id, from: 0, count: 5);
      final rs = await api.commentReplies(_id, [for (final c in r) c.id]).catchError((_) => const <Comment>[]);
      if (!mounted) return;
      setState(() {
        tops = r.reversed.toList();
        replies
          ..clear()
          ..addAll(rs);
        for (final c in [...r, ...rs]) {
          likes[c.id] = c.likes;
        }
        error = null;
      });
      api.commentLikes([for (final c in [...r, ...rs]) c.id]).then((l) {
        if (mounted) setState(() => liked = {...l});
      }).catchError((_) {});
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  /// answering here: the field says whom; an answer to one already two steps in names its author
  void _reply(Comment c) {
    final f = _forest;
    setState(() {
      replyTo = c;
      for (Comment? x = c; x != null; x = f.byId[x.parentId]) {
        open.add(x.id);
      }
    });
    final u = c.ap?.username ?? '';
    if (f.depth(c) >= 2 && u.isNotEmpty && c.author != context.me.id && !field.text.contains('@$u')) {
      field.text = '@$u ${field.text}';
      field.selection = TextSelection.collapsed(offset: field.text.length);
    }
    focus.requestFocus();
  }

  Future<void> _send() async {
    final t = field.text.trim();
    if (t.isEmpty || sending) return;
    final app = context.app, par = replyTo;
    setState(() => sending = true);
    try {
      final c = await app.api.addComment(_id, t, parentId: par?.id);
      if (!mounted) return;
      field.clear();
      setState(() {
        if (c.parentId == null) {
          final l = [...?tops, c];
          tops = l.length > 5 ? l.sublist(l.length - 5) : l;
        } else {
          replies.add(c);
          final f = _forest;
          for (Comment? x = f.byId[c.parentId]; x != null; x = f.byId[x.parentId]) {
            open.add(x.id);
          }
        }
        likes[c.id] = 0;
        replyTo = null;
        sending = false;
      });
      app.posts.commented(_id);
      // the new comment is shown where the writing line is, not under the keyboard
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _endKey.currentContext;
        if (mounted && ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd, duration: const Duration(milliseconds: 220));
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => sending = false);
      toast(context, errText(e));
    }
  }

  Future<void> _like(Comment c) async {
    final on = !liked.contains(c.id);
    setState(() {
      on ? liked.add(c.id) : liked.remove(c.id);
      likes[c.id] = ((likes[c.id] ?? c.likes) + (on ? 1 : -1)).clamp(0, 1 << 30).toInt();
    });
    try {
      await context.app.api.likeComment(c.id, on);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        on ? liked.remove(c.id) : liked.add(c.id);
        likes[c.id] = ((likes[c.id] ?? 0) + (on ? -1 : 1)).clamp(0, 1 << 30).toInt();
      });
      toast(context, errText(e));
    }
  }

  Future<void> _delete(Comment c) async {
    final yes = await confirm(context, title: 'კომენტარის წაშლა', text: 'წაიშლება კომენტარი და მისი პასუხებიც.', yes: 'წაშლა', danger: true);
    if (!yes || !mounted) return;
    final app = context.app;
    if (!await attempt(context, () => app.api.deleteComment(c.id)) || !mounted) return;
    final ids = {c.id, for (final x in _forest.under(c.id)) x.id};
    setState(() {
      tops?.removeWhere((x) => ids.contains(x.id));
      replies.removeWhere((x) => ids.contains(x.id));
      if (replyTo != null && ids.contains(replyTo!.id)) replyTo = null;
    });
    app.posts.commented(_id, -ids.length);
  }

  Future<void> _sheet() async {
    await showCommentsSheet(context, widget.post);
    // what was written or deleted in the window shows here too
    if (mounted) _load();
  }

  Widget _tile(Comment cm, int depth, Comment? to) {
    final me = context.me.id, staff = isStaff(context), author = widget.post.author;
    return KeyedSubtree(
      key: ValueKey('icm-${cm.id}'),
      child: CommentTile(
        c: cm,
        depth: depth,
        answered: to,
        liked: liked.contains(cm.id),
        likes: likes[cm.id] ?? cm.likes,
        canDelete: cm.author == me || author == me || staff,
        onReply: () => _reply(cm),
        onLike: () => _like(cm),
        onDelete: () => _delete(cm),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, l = tops;
    final total = context.app.posts.of(_id).comments;
    final rows = l == null || l.isEmpty
        ? const <(int, Widget Function())>[]
        : commentRows(context, _forest, open: open, tile: _tile, toggle: (id) => setState(() => open.contains(id) ? open.remove(id) : open.add(id)));
    final to = replyTo;
    return Container(
      key: ValueKey('inline-cm-$_id'),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (l == null)
          error != null
              ? TextButton(onPressed: _load, child: const Text('ვერ ჩაიტვირთა. ხელახლა ცდა'))
              : const Padding(padding: EdgeInsets.all(14), child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2))))
        else if (l.isEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 4), child: Text('ჯერ არავის დაუწერია. იყავი პირველი!', style: TextStyle(color: c.muted, fontSize: 14)))
        else
          for (final (i, r) in rows.indexed) _Unfold(order: i < 8 ? i : 8, child: r.$2()),
        if (l != null && l.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('all-cm-$_id'),
                onPressed: _sheet,
                icon: PIcon('comment', size: 17, color: c.accent),
                label: Text(total > _forest.byId.length ? 'სხვა კომენტარების ნახვა · $total' : 'ყველა კომენტარი ცალკე ფანჯარაში'),
              ),
            ),
          ),
        if (to != null)
          Padding(
            key: ValueKey('icm-to-$_id'),
            padding: const EdgeInsets.fromLTRB(54, 4, 8, 0),
            child: Row(children: [
              PIcon('reply', size: 13, color: c.muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text('პასუხი: ${(to.ap?.name ?? '').split(' ').first}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              InkWell(
                key: ValueKey('icm-to-x-$_id'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => replyTo = null),
                child: Padding(padding: const EdgeInsets.all(4), child: PIcon('x', size: 15, color: c.muted)),
              ),
            ]),
          ),
        Padding(
          key: _endKey,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Row(children: [
            Avatar(p: context.me, size: 30),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: ValueKey('icm-field-$_id'),
                controller: field,
                focusNode: focus,
                minLines: 1,
                maxLines: 3,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: to != null ? 'დაწერე პასუხი…' : 'დაწერე კომენტარი…',
                  isDense: true,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: c.accent, width: 1.5)),
                ),
              ),
            ),
            ListenableBuilder(
              listenable: field,
              builder: (_, __) {
                final can = field.text.trim().isNotEmpty && !sending;
                return IconButton(
                  key: ValueKey('icm-send-$_id'),
                  tooltip: 'კომენტარის გაგზავნა',
                  onPressed: can ? _send : null,
                  icon: sending ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : PIcon('send', size: 22, color: can ? c.accent : c.muted),
                );
              },
            ),
          ]),
        ),
      ]),
    );
  }
}

/// one comment coming out as the accordion opens, a moment after the one above it
class _Unfold extends StatelessWidget {
  const _Unfold({required this.order, required this.child});
  final int order;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final ms = 240 + order * 60;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Interval(order * 60 / ms, 1, curve: Curves.easeOutCubic),
      builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (v - 1) * 12), child: c)),
      child: child,
    );
  }
}
