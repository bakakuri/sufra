import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/mentions.dart';
import '../ui/net_image.dart';
import '../ui/stickers.dart';
import '../ui/theme.dart';
import '../ui/translate.dart';
import '../ui/widgets.dart';
import 'compose_screen.dart';
import 'photo_viewer.dart';
import 'post_actions.dart';
import 'post_card.dart';

/// A post on its own with all its comments (feed.js openComments): replies sit under the comment they answer, the
/// long threads folded; a comment can be liked, answered, translated, deleted, and be a sticker or a photo. Back
/// closes it.
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
  Set<int> liked = {};
  final likes = <int, int>{};
  final opened = <int>{};
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
        likes
          ..clear()
          ..addAll({for (final c in r) c.id: c.likes});
      });
      final s = app.posts.of(widget.post.id);
      if (s.comments != r.length) app.posts.commented(widget.post.id, r.length - s.comments);
      app.api.commentLikes([for (final c in r) c.id]).then((l) {
        if (mounted) setState(() => liked = l);
      }).catchError((_) {});
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  /// sends a comment: words, or a sticker or a photo (their words are only a placeholder the site hides)
  Future<bool> _post(String body, {Map<String, dynamic>? media}) async {
    if (sending) return false;
    final app = context.app, par = replyTo;
    setState(() => sending = true);
    try {
      final c = await app.api.addComment(widget.post.id, body, parentId: par == null ? null : (par.parentId ?? par.id), media: media);
      if (!mounted) return true;
      setState(() {
        list = [...?list, c];
        likes[c.id] = 0;
        replyTo = null;
        sending = false;
      });
      app.posts.commented(widget.post.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
      });
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
    final gone = {c.id, for (final x in list ?? const <Comment>[]) if (x.parentId == c.id) x.id};
    setState(() => list = [for (final x in list!) if (!gone.contains(x.id)) x]);
    app.posts.commented(widget.post.id, -gone.length);
  }

  /// top-level comments in order, each followed by the replies to it (and to its replies)
  List<(Comment, List<Comment>)> _threads(List<Comment> all) {
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
    return [for (final t in tops) (t, kids[t.id] ?? const <Comment>[])];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, me = context.me.id;
    final threads = list == null ? const <(Comment, List<Comment>)>[] : _threads(list!);
    final staff = isStaff(context), postAuthor = widget.post.author;
    Widget tile(Comment cm, bool reply) => _CommentTile(
          key: ValueKey('cm-${cm.id}'),
          c: cm,
          reply: reply,
          liked: liked.contains(cm.id),
          likes: likes[cm.id] ?? cm.likes,
          canDelete: cm.author == me || postAuthor == me || staff,
          onReply: () => _reply(cm),
          onLike: () => _like(cm),
          onDelete: () => _delete(cm),
        );
    final rows = <Widget>[];
    for (final (top, kids) in threads) {
      rows.add(tile(top, false));
      final hid = kids.length > 3 && !opened.contains(top.id) ? kids.length - 2 : 0;
      if (hid > 0) {
        rows.add(Padding(
          padding: const EdgeInsets.only(left: 58),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: ValueKey('cmore-${top.id}'),
              onPressed: () => setState(() => opened.add(top.id)),
              icon: PIcon('reply', size: 16, color: c.accent),
              label: Text('კიდევ $hid პასუხის ნახვა'),
            ),
          ),
        ));
      }
      for (final k in kids.skip(hid)) {
        rows.add(tile(k, true));
      }
    }
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
              ...rows,
          ]),
        ),
        MentionSuggest(field: field),
        _InputBar(
          field: field,
          focus: focus,
          sending: sending,
          replyTo: replyTo,
          onCancelReply: () => setState(() => replyTo = null),
          onSend: _send,
          onSticker: _sticker,
          onPhoto: _photo,
        ),
      ]),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    super.key,
    required this.c,
    required this.reply,
    required this.liked,
    required this.likes,
    required this.canDelete,
    required this.onReply,
    required this.onLike,
    required this.onDelete,
  });
  final Comment c;
  final bool reply, liked, canDelete;
  final int likes;
  final VoidCallback onReply, onLike, onDelete;

  /// the words the site keeps for a sticker or a photo are not shown
  String get _text {
    final b = c.body.trim();
    if (c.sticker != null && (b == '✨' || b == stickerLabel(c.sticker!))) return '';
    if (c.media != null && b == '📷') return '';
    return b;
  }

  @override
  Widget build(BuildContext context) {
    final pc = context.pc, who = c.ap ?? Profile(id: c.author, name: ''), text = _text, m = c.media;
    Widget act(String key, String label, VoidCallback onTap, {Color? color}) => TextButton(
          key: ValueKey('$key-${c.id}'),
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: color ?? pc.muted,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontFamily: fontBody, fontFamilyFallback: fontFallback, fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
          child: Text(label),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(reply ? 58 : 14, 6, 14, 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(onTap: () => openPerson(context, who), child: Avatar(p: who, size: reply ? 28 : 34)),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
              decoration: BoxDecoration(color: c.sticker != null && text.isEmpty ? Colors.transparent : pc.sunk, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GestureDetector(onTap: () => openPerson(context, who), child: NameLine(who, size: 13.5)),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  TranslatableBody(text, compact: true, style: const TextStyle(fontSize: 14.5, height: 1.4)),
                ],
                if (c.sticker != null) Padding(padding: const EdgeInsets.only(top: 4), child: StickerView(c.sticker!, size: 110)),
                if (m != null && c.sticker == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      key: ValueKey('cimg-${c.id}'),
                      onTap: () => openPhotos(context, [m]),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220, maxHeight: 260),
                        child: AspectRatio(aspectRatio: m.w > 0 && m.h > 0 ? m.w / m.h : 4 / 3, child: PImage(m.small, radius: 12)),
                      ),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(ago(c.createdAt), style: TextStyle(color: pc.muted, fontSize: 12.5))),
                act('clike', liked ? 'მოგწონს' : 'მოწონება', onLike, color: liked ? pc.accent : null),
                act('creply', 'პასუხი', onReply),
                if (canDelete) act('cdel', 'წაშლა', onDelete),
                if (likes > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      PIcon('heartfill', size: 13, color: pc.nope),
                      const SizedBox(width: 3),
                      Text('$likes', style: TextStyle(color: pc.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ]),
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
    required this.field,
    required this.focus,
    required this.sending,
    required this.replyTo,
    required this.onCancelReply,
    required this.onSend,
    required this.onSticker,
    required this.onPhoto,
  });
  final TextEditingController field;
  final FocusNode focus;
  final bool sending;
  final Comment? replyTo;
  final VoidCallback onCancelReply, onSend, onSticker, onPhoto;

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
            padding: const EdgeInsets.fromLTRB(4, 8, 6, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              IconBtn('smile', key: const ValueKey('c-stk'), label: 'სმაილები და სტიკერები', size: 23, color: c.muted, onTap: sending ? null : onSticker),
              IconBtn('image', key: const ValueKey('c-img'), label: 'ფოტო', size: 23, color: c.muted, onTap: sending ? null : onPhoto),
              const SizedBox(width: 2),
              Expanded(
                child: TextField(
                  controller: field,
                  focusNode: focus,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: replyTo == null ? 'დაწერე კომენტარი…' : 'უპასუხე ${(replyTo!.ap?.name ?? '').split(' ').first}-ს…',
                    isDense: true,
                    counterText: '',
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
