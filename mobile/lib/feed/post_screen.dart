import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/rich_body.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'post_card.dart';

/// A post on its own with all its comments; replies sit under the comment they answer. Back closes it.
class PostScreen extends StatefulWidget {
  const PostScreen({super.key, required this.post, this.focus = false});
  final Post post;

  /// open with the comment field ready to type in
  final bool focus;

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  List<Comment>? list;
  Object? error;
  Comment? replyTo;
  bool sending = false;
  final field = TextEditingController();
  final focus = FocusNode();
  final scroll = ScrollController();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
    if (widget.focus) WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
  }

  @override
  void dispose() {
    field.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.app;
    try {
      final r = await app.api.comments(widget.post.id);
      if (!mounted) return;
      setState(() {
        list = r;
        error = null;
      });
      final s = app.posts.of(widget.post.id);
      if (s.comments != r.length) app.posts.commented(widget.post.id, r.length - s.comments);
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
      final c = await app.api.addComment(widget.post.id, t, parentId: replyTo?.id);
      if (!mounted) return;
      field.clear();
      setState(() {
        list = [...?list, c];
        replyTo = null;
        sending = false;
      });
      app.posts.commented(widget.post.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => sending = false);
      toast(context, errText(e));
    }
  }

  void _reply(Comment c) {
    setState(() => replyTo = c);
    focus.requestFocus();
  }

  /// top-level comments in order, each followed by the replies to it (and to its replies)
  List<(Comment, bool)> _threads(List<Comment> all) {
    final byId = {for (final c in all) c.id: c};
    int root(Comment c) {
      var x = c;
      for (var i = 0; i < 20 && x.parentId != null && byId.containsKey(x.parentId); i++) {
        x = byId[x.parentId]!;
      }
      return x.id;
    }

    final kids = <int, List<Comment>>{};
    final tops = <Comment>[];
    for (final c in all) {
      final r = root(c);
      if (r == c.id) {
        tops.add(c);
      } else {
        (kids[r] ??= []).add(c);
      }
    }
    return [
      for (final t in tops) ...[(t, false), for (final k in kids[t.id] ?? const <Comment>[]) (k, true)],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final rows = list == null ? const <(Comment, bool)>[] : _threads(list!);
    return Scaffold(
      appBar: peeraBar(context, title: 'პოსტი'),
      body: Column(children: [
        Expanded(
          child: ListView(controller: scroll, padding: const EdgeInsets.only(bottom: 16), children: [
            PostCard(post: widget.post, inPostScreen: true, onDeleted: () => Navigator.of(context).pop(true)),
            Container(height: 8, color: c.bg),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(list == null ? 'კომენტარები' : 'კომენტარები · ${list!.length}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            if (error != null && list == null)
              Empty(icon: 'comment', title: 'კომენტარები ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
            else if (list == null)
              const Padding(padding: EdgeInsets.all(28), child: Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.4))))
            else if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Text('ჯერ არავის დაუწერია. იყავი პირველი!', style: TextStyle(color: c.muted, fontSize: 14.5)),
              )
            else
              for (final (cm, reply) in rows) _CommentTile(c: cm, reply: reply, onReply: () => _reply(cm)),
          ]),
        ),
        _InputBar(
          me: context.me,
          field: field,
          focus: focus,
          sending: sending,
          replyTo: replyTo,
          onCancelReply: () => setState(() => replyTo = null),
          onSend: _send,
        ),
      ]),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.c, required this.reply, required this.onReply});
  final Comment c;
  final bool reply;
  final VoidCallback onReply;
  @override
  Widget build(BuildContext context) {
    final pc = context.pc, who = c.ap ?? Profile(id: c.author, name: '');
    return Padding(
      padding: EdgeInsets.fromLTRB(reply ? 58 : 14, 6, 14, 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(onTap: () => openPerson(context, who), child: Avatar(p: who, size: reply ? 28 : 34)),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
              decoration: BoxDecoration(color: pc.sunk, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GestureDetector(onTap: () => openPerson(context, who), child: NameLine(who, size: 13.5)),
                const SizedBox(height: 2),
                RichBody(c.body, style: const TextStyle(fontSize: 14.5, height: 1.4)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 3),
              child: Row(children: [
                Text(ago(c.createdAt), style: TextStyle(color: pc.muted, fontSize: 12.5)),
                if (c.likes > 0) Text(' · ❤️ ${c.likes}', style: TextStyle(color: pc.muted, fontSize: 12.5)),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: onReply,
                  style: TextButton.styleFrom(
                    foregroundColor: pc.muted,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontFamily: fontBody, fontFamilyFallback: fontFallback, fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                  child: const Text('პასუხი'),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.me,
    required this.field,
    required this.focus,
    required this.sending,
    required this.replyTo,
    required this.onCancelReply,
    required this.onSend,
  });
  final Profile me;
  final TextEditingController field;
  final FocusNode focus;
  final bool sending;
  final Comment? replyTo;
  final VoidCallback onCancelReply, onSend;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (replyTo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 6, 0),
              child: Row(children: [
                PIcon('reply', size: 17, color: c.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('პასუხი: ${(replyTo!.ap?.name ?? '').split(' ').first}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: 13.5)),
                ),
                IconBtn('x', label: 'პასუხის გაუქმება', size: 18, color: c.muted, onTap: onCancelReply),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Avatar(p: me, size: 34)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: field,
                  focusNode: focus,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'დაწერე კომენტარი…',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: c.accent, width: 1.5)),
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: field,
                builder: (_, __) {
                  final can = field.text.trim().isNotEmpty && !sending;
                  return IconButton(
                    tooltip: 'გაგზავნა',
                    onPressed: can ? onSend : null,
                    icon: sending
                        ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.2))
                        : PIcon('send', size: 24, color: can ? c.accent : c.muted),
                  );
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
