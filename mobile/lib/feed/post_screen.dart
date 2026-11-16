import 'package:flutter/material.dart';

import '../data/models.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/stickers.dart';
import '../ui/theme.dart';
import '../ui/translate.dart';
import '../ui/widgets.dart';
import 'comment_tree.dart';
import 'photo_viewer.dart';
import 'post_card.dart';

// One comment as Facebook shows it (its face, its words in a bubble, when, liking and answering), and the line
// that writes one. A post is never a page of its own: it opens as the comments window (comments_sheet.dart).

/// One comment: the face, the words (or a sticker, a photo), when, a like, an answer, deleting it.
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.c,
    this.depth = 0,
    this.answered,
    required this.liked,
    required this.likes,
    required this.canDelete,
    required this.onReply,
    required this.onLike,
    required this.onDelete,
  });
  final Comment c;

  /// its step: 0 a comment, 1 an answer, 2 an answer to an answer (and further)
  final int depth;

  /// the comment it answers (named over it)
  final Comment? answered;
  final bool liked, canDelete;
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
    final to = answered?.ap;
    return Padding(
      padding: EdgeInsets.fromLTRB(commentIndent[depth], 6, 14, 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(onTap: () => openPerson(context, who), child: Avatar(p: who, size: commentAvatar[depth])),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // an answer says whom it answers
            if (depth > 0 && to != null)
              Padding(
                key: ValueKey('cto-${c.id}'),
                padding: const EdgeInsets.only(left: 6, bottom: 3),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  PIcon('reply', size: 12, color: pc.muted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'პასუხი · '),
                        TextSpan(text: to.name, style: TextStyle(color: pc.accent, fontWeight: FontWeight.w800)),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: pc.muted, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
              ),
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

/// Writing a comment: a smile or a sticker, a photo, the words, send; answering someone shows over it.
class CommentInputBar extends StatelessWidget {
  const CommentInputBar({
    super.key,
    required this.field,
    required this.focus,
    required this.sending,
    required this.replyTo,
    required this.onCancelReply,
    required this.onSend,
    required this.onSticker,
    required this.onPhoto,
    this.fieldKey,
  });
  final TextEditingController field;
  final FocusNode focus;
  final bool sending;
  final Comment? replyTo;
  final VoidCallback onCancelReply, onSend, onSticker, onPhoto;

  /// the field's key (two writing places may be on screen at once)
  final Key? fieldKey;

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
                  key: fieldKey,
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
