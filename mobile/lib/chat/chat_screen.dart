import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../feed/photo_viewer.dart';
import '../feed/post_screen.dart';
import '../people/person_screen.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/rich_body.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'chats_tab.dart';

/// Opens a conversation over the whole app (the tab bar steps aside); back returns to where you were.
Future<void> openChat(BuildContext context, int convId) => openPage(context, ChatScreen(convId: convId), full: true);

/// One conversation: messages as they arrive (live), older ones as you scroll up, text and photos to send.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.convId});
  final int convId;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  /// newest first, as the list is drawn from the bottom up
  final msgs = <Message>[];
  bool loading = true, older = false, done = false, sending = false;
  Object? error;
  StreamSubscription<Message>? _live;
  final field = TextEditingController();
  final scroll = ScrollController();
  late final AppState app;
  bool _started = false;
  int _tmp = -1;

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (scroll.position.extentAfter < 600) _older();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    app = context.app;
    // after this frame: the tab bar's badge listens to the same store
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) app.chats.opened(widget.convId);
    });
    _live = app.api.liveMessages(widget.convId).listen(_arrived, onError: (_) {});
    _load();
  }

  @override
  void dispose() {
    _live?.cancel();
    app.chats.closed(widget.convId);
    field.dispose();
    scroll.dispose();
    super.dispose();
  }

  Chat? get chat => app.chats.chats.where((c) => c.convId == widget.convId).firstOrNull;

  Future<void> _load() async {
    try {
      final r = await app.api.messages(widget.convId);
      await app.people.ensure(r.map((m) => m.sender));
      if (!mounted) return;
      setState(() {
        final mine = msgs.where((m) => m.sending).toList();
        msgs
          ..clear()
          ..addAll(r.where((m) => !m.gone))
          ..insertAll(0, mine);
        loading = false;
        done = r.length < 50;
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e;
        });
      }
    }
  }

  Future<void> _older() async {
    if (older || done || loading || msgs.isEmpty) return;
    setState(() => older = true);
    try {
      final r = await app.api.messages(widget.convId, before: msgs.where((m) => !m.sending).lastOrNull?.createdAt);
      await app.people.ensure(r.map((m) => m.sender));
      if (!mounted) return;
      setState(() {
        final have = msgs.map((m) => m.id).toSet();
        msgs.addAll(r.where((m) => !m.gone && have.add(m.id)));
        done = r.length < 50;
        older = false;
      });
    } catch (_) {
      if (mounted) setState(() => older = false);
    }
  }

  void _arrived(Message m) {
    if (!mounted) return;
    app.people.ensure([m.sender]);
    setState(() {
      final i = msgs.indexWhere((x) => x.id == m.id);
      if (i >= 0) {
        msgs[i] = m;
      } else if (!m.gone) {
        msgs.insert(0, m);
      }
    });
    if (m.sender != app.api.myId) app.chats.opened(widget.convId);
  }

  Future<void> _send({String body = '', String kind = 'text', Map<String, dynamic>? media}) async {
    final temp = Message(id: _tmp--, convId: widget.convId, sender: app.api.myId, body: body, kind: kind, media: media, createdAt: DateTime.now(), sending: true);
    setState(() => msgs.insert(0, temp));
    try {
      final m = await app.api.send(widget.convId, body: body, kind: kind, media: media);
      if (!mounted) return;
      setState(() {
        msgs.removeWhere((x) => x.id == temp.id);
        if (!msgs.any((x) => x.id == m.id)) msgs.insert(0, m);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => msgs.removeWhere((x) => x.id == temp.id));
      toast(context, errText(e));
    }
  }

  void _sendText() {
    final t = field.text.trim();
    if (t.isEmpty) return;
    field.clear();
    _send(body: t);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> _sendPhoto() async {
    if (sending) return;
    final List<Uint8List> got;
    try {
      got = await photoSource(false);
    } catch (_) {
      if (mounted) toast(context, 'ფოტო ვერ გავხსენი');
      return;
    }
    if (got.isEmpty || !mounted) return;
    setState(() => sending = true);
    try {
      for (final b in got.take(5)) {
        final m = await app.api.uploadPhoto(await photoPrep(b));
        await _send(kind: 'image', media: {'url': m.url, if (m.sm != null) 'sm': m.sm, 'w': m.w, 'h': m.h});
      }
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
    if (mounted) setState(() => sending = false);
  }

  void _openOther() {
    final o = chat?.other;
    if (o == null) return;
    openPage(context, PersonScreen(uid: o, initial: app.people[o]), full: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return ListenableBuilder(
      listenable: Listenable.merge([app.chats, app.people]),
      builder: (context, _) {
        final ch = chat, other = ch?.other == null ? null : app.people[ch!.other!];
        final title = ch == null ? '' : (ch.isGroup ? ((ch.title ?? '').isEmpty ? 'ჯგუფი' : ch.title!) : (other?.fullName ?? ''));
        final sub = ch == null
            ? ''
            : ch.isGroup
                ? '${ch.members.length + 1} წევრი'
                : lastSeenText(other?.lastSeen);
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 60,
            leading: backButton(context),
            titleSpacing: 0,
            title: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openOther,
              child: Row(children: [
                if (other != null) Avatar(p: other, size: 40, online: other.online) else GroupAvatar(id: widget.convId, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700))),
                      if (other?.verified == true) const Verified(size: 14),
                    ]),
                    if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 12.5, color: sub == 'ონლაინ' ? c.vine : c.muted, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ]),
            ),
          ),
          body: Column(children: [
            Expanded(child: _list(context, ch)),
            _Composer(field: field, sending: sending, onSend: _sendText, onPhoto: _sendPhoto),
          ]),
        );
      },
    );
  }

  Widget _list(BuildContext context, Chat? ch) {
    final c = context.pc;
    if (loading) return const Center(child: SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 2.4)));
    if (error != null && msgs.isEmpty) {
      return Empty(icon: 'msg', title: 'შეტყობინებები ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load);
    }
    if (msgs.isEmpty) {
      return Empty(icon: 'msg', title: 'ჯერ არაფერი გიწერიათ', text: 'დაწერე პირველი შეტყობინება.');
    }
    final group = ch?.isGroup == true, me = app.api.myId;
    return ListView.builder(
      controller: scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      itemCount: msgs.length + 1,
      itemBuilder: (_, i) {
        if (i == msgs.length) {
          return Padding(
            padding: const EdgeInsets.all(14),
            child: Center(
              child: older
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                  : done
                      ? Text('მიმოწერის დასაწყისი', style: TextStyle(color: c.muted, fontSize: 12.5))
                      : const SizedBox(height: 20),
            ),
          );
        }
        final m = msgs[i];
        final newer = i > 0 ? msgs[i - 1] : null, olderM = i + 1 < msgs.length ? msgs[i + 1] : null;
        final dayStart = olderM == null || !_sameDay(olderM.createdAt, m.createdAt);
        final runStart = dayStart || olderM.sender != m.sender || olderM.kind == 'system';
        final runEnd = newer == null || newer.sender != m.sender || !_sameDay(newer.createdAt, m.createdAt) || newer.kind == 'system';
        return Column(children: [
          if (dayStart)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(12)),
                child: Text(dayLabel(m.createdAt), style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ),
          _Bubble(
            m: m,
            mine: m.sender == me,
            who: app.people[m.sender],
            showName: group && runStart && m.sender != me,
            showAvatar: group && runEnd && m.sender != me,
            group: group,
            tail: runEnd,
          ),
        ]);
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m, required this.mine, this.who, this.showName = false, this.showAvatar = false, this.group = false, this.tail = true});
  final Message m;
  final bool mine, showName, showAvatar, group, tail;
  final Profile? who;

  /// what the app cannot show yet: a line saying what it is, opened on the site
  (String, String)? _other() {
    final md = m.media ?? const {};
    if (m.kind == 'voice') return ('🎤', 'ხმოვანი შეტყობინება');
    if (md['story'] != null) return ('📸', 'ისტორიაზე პასუხი');
    if (md['sticker'] != null) return ('🙂', 'სტიკერი');
    if (md['card'] != null) return ('💌', 'ბარათი');
    if (md['loc'] != null) return ('📍', 'მდებარეობა');
    if (md['game'] != null) return ('🎲', 'თამაშის მოწვევა');
    if (md['call'] != null) return ('📹', 'ჯგუფური ვიდეოზარი');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    if (m.kind == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
        child: Text(m.body, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 13)),
      );
    }
    final bg = mine ? c.accent : c.surface, fg = mine ? c.onAccent : c.ink;
    const r = Radius.circular(20), small = Radius.circular(6);
    final shape = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: !mine && tail ? small : r,
      bottomRight: mine && tail ? small : r,
    );
    final time = Text(
      '${m.edited ? 'რედ. · ' : ''}${hhmm(m.createdAt)}${m.sending ? ' · იგზავნება' : ''}',
      style: TextStyle(fontSize: 11, color: mine ? fg.withValues(alpha: .75) : c.muted),
    );
    Widget inner;
    final photo = m.photo, post = (m.media ?? const {})['post'], other = _other();
    if (m.deleted) {
      inner = _box(context, shape, mine ? c.accent.withValues(alpha: .35) : c.sunk,
          Text('შეტყობინება წაიშალა', style: TextStyle(fontStyle: FontStyle.italic, color: mine ? c.onAccent : c.muted)), time);
    } else if (photo != null) {
      final ratio = photo.w > 0 && photo.h > 0 ? (photo.w / photo.h).clamp(.6, 1.8).toDouble() : 1.0;
      inner = GestureDetector(
        onTap: () => openPhotos(context, [photo]),
        child: ClipRRect(
          borderRadius: shape,
          child: SizedBox(
            width: 240,
            child: AspectRatio(
              aspectRatio: ratio,
              child: Stack(fit: StackFit.expand, children: [
                PImage(photo.small),
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                    child: Text(hhmm(m.createdAt), style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    } else if (post is Map) {
      final id = asInt(post['id']);
      inner = GestureDetector(
        onTap: () async {
          final app = context.app;
          final p = await app.api.post(id).catchError((_) => null);
          if (p == null) {
            if (context.mounted) toast(context, 'ეს პოსტი აღარ არის ხელმისაწვდომი');
            return;
          }
          await app.posts.load([p]);
          if (context.mounted) await openPage(context, PostScreen(post: p), full: true);
        },
        child: _box(
          context,
          shape,
          bg,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('📝 ${post['by'] ?? ''}-ის პოსტი', style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
            if ('${post['t'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('${post['t']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 14)),
              ),
          ]),
          time,
        ),
      );
    } else if (other != null) {
      inner = GestureDetector(
        onTap: () => launchUrl(Uri.parse('$siteUrl/#chats'), mode: LaunchMode.externalApplication),
        child: _box(
          context,
          shape,
          bg,
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(other.$1, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Flexible(child: Text(other.$2, style: TextStyle(color: fg, fontWeight: FontWeight.w600))),
          ]),
          time,
          note: 'საიტზე ნახე',
        ),
      );
    } else {
      inner = _box(context, shape, bg, RichBody(m.body, style: TextStyle(fontSize: 15.5, height: 1.35, color: fg)), time);
    }

    final w = MediaQuery.sizeOf(context).width;
    final bubble = ConstrainedBox(constraints: BoxConstraints(maxWidth: w * .76), child: inner);
    return Padding(
      padding: EdgeInsets.only(top: showName ? 8 : 1.5, bottom: tail ? 5 : 1.5),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (group && !mine)
            SizedBox(
              width: 36,
              child: showAvatar && who != null ? Align(alignment: Alignment.bottomLeft, child: Avatar(p: who!, size: 30)) : null,
            ),
          Flexible(
            child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
              if (showName)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 3),
                  child: Text(who?.name ?? '', style: TextStyle(color: c.accent, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              Opacity(opacity: m.sending ? .7 : 1, child: bubble),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _box(BuildContext context, BorderRadius shape, Color bg, Widget body, Widget time, {String? note}) {
    final c = context.pc;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 8, 13, 6),
      decoration: BoxDecoration(color: bg, borderRadius: shape, border: mine ? null : Border.all(color: c.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Align(alignment: Alignment.centerLeft, widthFactor: 1, child: body),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (note != null) Text('$note · ', style: TextStyle(fontSize: 11, color: mine ? c.onAccent.withValues(alpha: .75) : c.accent, fontWeight: FontWeight.w600)),
          time,
        ]),
      ]),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.field, required this.sending, required this.onSend, required this.onPhoto});
  final TextEditingController field;
  final bool sending;
  final VoidCallback onSend, onPhoto;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            sending
                ? const Padding(padding: EdgeInsets.all(14), child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2)))
                : IconBtn('image', label: 'ფოტოს გაგზავნა', color: c.vine, onTap: onPhoto),
            Expanded(
              child: TextField(
                controller: field,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'შეტყობინება…',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: c.accent, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 4),
            ListenableBuilder(
              listenable: field,
              builder: (_, __) {
                final can = field.text.trim().isNotEmpty;
                return Semantics(
                  key: const ValueKey('chat-send'),
                  button: true,
                  label: 'გაგზავნა',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: can ? onSend : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: can ? c.accent : c.sunk, shape: BoxShape.circle),
                      child: Padding(padding: const EdgeInsets.only(left: 2), child: PIcon('send', size: 21, color: can ? c.onAccent : c.muted, stroke: 2)),
                    ),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}
