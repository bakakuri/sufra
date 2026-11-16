// All of a post's comments in a window that comes up from below: the newest first, fifteen at the start and ten more each
// time the reader comes near the end of what is there; writing, answering, liking and deleting, as on the post's page.
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/mentions.dart';
import '../ui/stickers.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'compose_screen.dart';
import 'post_actions.dart';
import 'post_screen.dart';

/// how many come first, and how many more each time
const commentsFirst = 15, commentsMore = 10;

Future<void> showCommentsSheet(BuildContext context, Post post) {
  // the window stands over the whole app, outside the tab: it takes the app with it
  final scope = AppScope.of(context);
  return showModalBottomSheet<void>(
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
        child: SizedBox(height: MediaQuery.sizeOf(s).height * .86, child: CommentsPanel(post: post)),
      ),
    ),
  );
}

class CommentsPanel extends StatefulWidget {
  const CommentsPanel({super.key, required this.post});
  final Post post;
  @override
  State<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends State<CommentsPanel> {
  final list = <Comment>[];
  bool loading = false, done = false, sending = false, _started = false;
  Object? error;
  Comment? replyTo;
  Set<int> liked = {};
  final likes = <int, int>{};
  final field = TextEditingController();
  final focus = FocusNode();
  final scroll = ScrollController();

  int get _id => widget.post.id;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _more();
  }

  @override
  void dispose() {
    field.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  /// the next page: fifteen at first, then ten more
  Future<void> _more() async {
    if (loading || done) return;
    final app = context.app, first = list.isEmpty, n = first ? commentsFirst : commentsMore;
    setState(() => loading = true);
    try {
      final r = await app.api.commentsPage(_id, from: list.length, count: n);
      if (!mounted) return;
      setState(() {
        final have = {for (final c in list) c.id};
        list.addAll([for (final c in r) if (!have.contains(c.id)) c]);
        for (final c in r) {
          likes[c.id] ??= c.likes;
        }
        done = r.length < n;
        loading = false;
        error = null;
      });
      // the first page tells how many there are when it is the only one
      final s = app.posts.of(_id);
      if (first && done && s.comments != list.length) app.posts.commented(_id, list.length - s.comments);
      app.api.commentLikes([for (final c in r) c.id]).then((l) {
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
      final c = await app.api.addComment(_id, body, parentId: par == null ? null : (par.parentId ?? par.id), media: media);
      if (!mounted) return true;
      setState(() {
        list.insert(0, c);
        likes[c.id] = 0;
        replyTo = null;
        sending = false;
      });
      app.posts.commented(_id);
      if (scroll.hasClients) scroll.animateTo(0, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => sending = false);
      toast(context, errText(e));
      return false;
    }
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

  void _reply(Comment c) {
    setState(() => replyTo = c);
    final u = c.ap?.username ?? '';
    if (c.parentId != null && u.isNotEmpty && c.author != context.me.id && !field.text.contains('@$u')) {
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
    final gone = {c.id, for (final x in list) if (x.parentId == c.id) x.id};
    setState(() => list.removeWhere((x) => gone.contains(x.id)));
    app.posts.commented(_id, -gone.length);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, me = context.me.id, staff = isStaff(context), author = widget.post.author;
    return ListenableBuilder(
      listenable: context.app.posts,
      builder: (context, _) {
        final total = context.app.posts.of(_id).comments;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Row(children: [
              Expanded(
                child: Text(total > 0 ? 'კომენტარები · $total' : 'კომენტარები', key: const ValueKey('cs-title'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              ),
              Text('ჯერ ახლები', style: TextStyle(color: c.muted, fontSize: 12.5)),
            ]),
          ),
          Divider(height: 1, color: c.line),
          Expanded(
            child: list.isEmpty
                ? (error != null
                    ? Empty(icon: 'comment', title: 'კომენტარები ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _more)
                    : loading || !done
                        ? const Center(child: SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 2.4)))
                        : Center(child: Text('ჯერ არავის დაუწერია. იყავი პირველი!', style: TextStyle(color: c.muted, fontSize: 14.5))))
                : ListView.builder(
                    key: const ValueKey('cs-list'),
                    controller: scroll,
                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                    itemCount: list.length + (done ? 0 : 1),
                    itemBuilder: (context, i) {
                      // near the end of what is here (five before it), the next ten are asked for
                      if (!done && i >= list.length - 5) WidgetsBinding.instance.addPostFrameCallback((_) => _more());
                      if (i >= list.length) {
                        return const Padding(padding: EdgeInsets.all(18), child: Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.2))));
                      }
                      final cm = list[i];
                      return _Arrive(
                        key: ValueKey('cm-${cm.id}'),
                        child: CommentTile(
                          c: cm,
                          reply: cm.parentId != null,
                          liked: liked.contains(cm.id),
                          likes: likes[cm.id] ?? cm.likes,
                          canDelete: cm.author == me || author == me || staff,
                          onReply: () => _reply(cm),
                          onLike: () => _like(cm),
                          onDelete: () => _delete(cm),
                        ),
                      );
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

/// The newest comments under a post in the feed, opened like an accordion: the last five (oldest of them first), all of
/// them in the window below, and a line to write one straight away.
class InlineComments extends StatefulWidget {
  const InlineComments({super.key, required this.post});
  final Post post;
  @override
  State<InlineComments> createState() => _InlineCommentsState();
}

class _InlineCommentsState extends State<InlineComments> {
  List<Comment>? last;
  Object? error;
  bool sending = false, _started = false;
  final field = TextEditingController();

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
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await context.app.api.commentsPage(widget.post.id, from: 0, count: 5);
      if (mounted) {
        setState(() {
          last = r.reversed.toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _send() async {
    final t = field.text.trim();
    if (t.isEmpty || sending) return;
    final app = context.app;
    setState(() => sending = true);
    try {
      final c = await app.api.addComment(widget.post.id, t);
      if (!mounted) return;
      field.clear();
      setState(() {
        final l = [...?last, c];
        last = l.length > 5 ? l.sublist(l.length - 5) : l;
        sending = false;
      });
      app.posts.commented(widget.post.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => sending = false);
      toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, l = last;
    final total = context.app.posts.of(widget.post.id).comments;
    return Container(
      key: ValueKey('inline-cm-${widget.post.id}'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (l == null)
          error != null
              ? TextButton(onPressed: _load, child: const Text('ვერ ჩაიტვირთა. ხელახლა ცდა'))
              : const Padding(padding: EdgeInsets.all(14), child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2))))
        else if (l.isEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 4), child: Text('ჯერ არავის დაუწერია. იყავი პირველი!', style: TextStyle(color: c.muted, fontSize: 14)))
        else
          for (final (i, cm) in l.indexed) _Unfold(order: i, child: _MiniComment(key: ValueKey('icm-${cm.id}'), c: cm)),
        if (l != null && l.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: ValueKey('all-cm-${widget.post.id}'),
              onPressed: () async {
                await showCommentsSheet(context, widget.post);
                // what was written or deleted in the window shows here too
                if (mounted) _load();
              },
              icon: PIcon('comment', size: 17, color: c.accent),
              label: Text(total > l.length ? 'ყველას ნახვა · $total' : 'ყველას ნახვა'),
            ),
          ),
        Row(children: [
          Avatar(p: context.me, size: 30),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: ValueKey('icm-field-${widget.post.id}'),
              controller: field,
              minLines: 1,
              maxLines: 3,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'დაწერე კომენტარი…',
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
                key: ValueKey('icm-send-${widget.post.id}'),
                tooltip: 'კომენტარის გაგზავნა',
                onPressed: can ? _send : null,
                icon: PIcon('send', size: 22, color: can ? c.accent : c.muted),
              );
            },
          ),
        ]),
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

/// a comment in the accordion: the face, the name and the words in a bubble, when
class _MiniComment extends StatelessWidget {
  const _MiniComment({super.key, required this.c});
  final Comment c;
  @override
  Widget build(BuildContext context) {
    final pc = context.pc, who = c.ap ?? Profile(id: c.author, name: '');
    var text = c.body.trim();
    if (c.sticker != null) text = '🙂 სტიკერი';
    if (c.media != null && c.sticker == null && text == '📷') text = '📷 ფოტო';
    return Padding(
      padding: EdgeInsets.fromLTRB(c.parentId != null ? 30 : 0, 6, 0, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Avatar(p: who, size: 28),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 7, 11, 8),
            decoration: BoxDecoration(color: pc.sunk, borderRadius: BorderRadius.circular(15)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: Text(who.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                const SizedBox(width: 6),
                Text(ago(c.createdAt), style: TextStyle(color: pc.muted, fontSize: 11.5)),
              ]),
              const SizedBox(height: 1),
              Text(text, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.35)),
            ]),
          ),
        ),
      ]),
    );
  }
}
