import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../feed/photo_viewer.dart';
import '../feed/post_actions.dart';
import '../feed/post_screen.dart';
import '../map/live_map.dart';
import '../map/loc_device.dart';
import '../media/voice.dart';
import '../people/albums.dart';
import '../people/cards.dart';
import '../people/person_screen.dart';
import '../people/profile_parts.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/look.dart';
import '../ui/net_image.dart';
import '../ui/rich_body.dart';
import '../ui/stickers.dart';
import '../ui/theme.dart';
import '../ui/translate.dart';
import '../ui/widgets.dart';
import 'chat_tools.dart';
import 'chats_tab.dart';

/// Opens a conversation over the whole app (the tab bar steps aside); back returns to where you were.
Future<void> openChat(BuildContext context, int convId) => openPage(context, ChatScreen(convId: convId), full: true);

/// the reactions offered first under a message (chat.js MREACT)
const messageReactions = ['❤️', '😂', '😮', '😢', '👍', '🍷', '🔥', '🙏'];

/// A message in one line (chat.js snip): for replies, the pinned bar and search.
String snip(Message? m) {
  if (m == null) return 'შეტყობინება';
  final md = m.media ?? const {};
  if (m.deleted) return 'წაშლილი შეტყობინება';
  if (m.kind == 'voice') return '🎤 ხმოვანი';
  if (m.kind == 'image') return '📷 ფოტო';
  if (md['sticker'] != null) return 'სტიკერი';
  if (md['card'] != null) return '🎉 მისალოცი ბარათი';
  if (md['loc'] != null) return '📍 ლოკაცია';
  if (md['post'] != null) return '📝 პოსტი';
  if (md['call'] != null) return '📹 ჯგუფური ვიდეოზარი';
  if (md['story'] != null) return md['act'] == 'react' ? '${m.body} ისტორიაზე' : 'ისტორიაზე: ${m.body.length > 80 ? m.body.substring(0, 80) : m.body}';
  return m.body.length > 90 ? m.body.substring(0, 90) : m.body;
}

/// One conversation (chat.js openChat): messages as they arrive (live), older ones as you scroll up; text, photos,
/// voice, stickers, places and cards to send; a message held for its menu (a reaction, reply, copy, forward, pin,
/// edit, delete for everyone, complaint), a double tap for ❤️; who is typing, who has seen it, the pinned message,
/// disappearing messages.
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
  StreamSubscription<(int, String, String?)>? _reactSub;
  StreamSubscription<String>? _typeSub;
  final field = TextEditingController();
  final focus = FocusNode();
  final scroll = ScrollController();
  late final AppState app;
  bool _started = false;
  int _tmp = -1;

  /// message → (person → emoji)
  final reacts = <int, Map<String, String>>{};

  /// messages answered that are not among the loaded ones
  final quoted = <int, Message>{};
  Message? replyTo, editing;
  int? pinned, ttl;
  Message? pinMsg;
  Map<String, DateTime?> seen = {};
  final typingNow = <String, Timer>{};
  int _typedAt = 0;
  int? flash;
  Timer? _flashT;
  final _keys = <int, GlobalKey>{};

  // a voice message being recorded: for how long, how loud now
  bool recording = false;
  int recMs = 0;
  double recLevel = 0;
  Timer? _recTick;
  static const recMax = 120000;

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (scroll.position.extentAfter < 600) _older();
    });
    field.addListener(_typed);
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
    _reactSub = app.api.liveReactions(widget.convId).listen((r) {
      final (mid, uid, e) = r;
      if (uid == app.api.myId && reacts[mid]?[uid] == e) return;
      if (mounted) setState(() => _setReact(mid, uid, e));
    }, onError: (_) {});
    _typeSub = app.api.typing(widget.convId).listen((u) {
      if (!mounted || !(chat?.members.contains(u) ?? false)) return;
      typingNow[u]?.cancel();
      setState(() => typingNow[u] = Timer(const Duration(milliseconds: 4500), () {
            if (mounted) setState(() => typingNow.remove(u));
          }));
    }, onError: (_) {});
    _load();
    _meta();
  }

  @override
  void dispose() {
    _recTick?.cancel();
    _flashT?.cancel();
    if (recording) voiceDevice.cancel();
    _live?.cancel();
    _reactSub?.cancel();
    _typeSub?.cancel();
    for (final t in typingNow.values) {
      t.cancel();
    }
    app.chats.closed(widget.convId);
    field.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  Chat? get chat => app.chats.chats.where((c) => c.convId == widget.convId).firstOrNull;

  Message? _find(int id) => msgs.where((m) => m.id == id).firstOrNull ?? quoted[id];

  void _setReact(int mid, String uid, String? e) {
    final r = reacts[mid] ??= {};
    e == null ? r.remove(uid) : r[uid] = e;
  }

  void _typed() {
    if (field.text.trim().isEmpty) return;
    final n = DateTime.now().millisecondsSinceEpoch;
    if (n - _typedAt < 2500) return;
    _typedAt = n;
    app.api.sendTyping(widget.convId);
  }

  Future<void> _meta() async {
    try {
      final (p, t) = await app.api.chatMeta(widget.convId);
      Message? pm;
      if (p != null && _find(p) == null) pm = await app.api.message(p);
      if (mounted) {
        setState(() {
          pinned = p;
          ttl = t;
          pinMsg = pm;
        });
      }
    } catch (_) {}
    try {
      final s = await app.api.chatSeen(widget.convId);
      if (mounted) setState(() => seen = s);
    } catch (_) {}
  }

  Future<void> _reactsFor(Iterable<Message> list) async {
    try {
      final r = await app.api.messageReactions([for (final m in list) if (m.id > 0) m.id]);
      if (mounted) setState(() => reacts.addAll(r));
    } catch (_) {}
  }

  /// the answered messages that are older than the loaded ones
  Future<void> _quotes(Iterable<Message> list) async {
    final miss = {for (final m in list) if (m.replyTo != null && _find(m.replyTo!) == null) m.replyTo!};
    for (final id in miss.take(20)) {
      try {
        final q = await app.api.message(id);
        if (q != null && mounted) setState(() => quoted[id] = q);
      } catch (_) {}
    }
  }

  Future<void> _load() async {
    try {
      final r = await app.api.messages(widget.convId);
      await app.people.ensure(r.map((m) => m.sender));
      final o = chat?.other;
      if (o != null) app.people.ensure([o], fresh: true);
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
      _reactsFor(r);
      _quotes(r);
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e;
        });
      }
    }
  }

  Future<bool> _older() async {
    if (older || done || loading || msgs.isEmpty) return false;
    setState(() => older = true);
    try {
      final r = await app.api.messages(widget.convId, before: msgs.where((m) => !m.sending).lastOrNull?.createdAt);
      await app.people.ensure(r.map((m) => m.sender));
      if (!mounted) return false;
      setState(() {
        final have = msgs.map((m) => m.id).toSet();
        msgs.addAll(r.where((m) => !m.gone && have.add(m.id)));
        done = r.length < 50;
        older = false;
      });
      _reactsFor(r);
      _quotes(r);
      return true;
    } catch (_) {
      if (mounted) setState(() => older = false);
      return false;
    }
  }

  void _arrived(Message m) {
    if (!mounted) return;
    app.people.ensure([m.sender]);
    typingNow.remove(m.sender)?.cancel();
    setState(() {
      final i = msgs.indexWhere((x) => x.id == m.id);
      if (i >= 0) {
        msgs[i] = m;
      } else if (!m.gone) {
        msgs.insert(0, m);
      }
      if (m.deleted && pinned == m.id) pinned = null;
    });
    if (m.kind == 'system') _meta();
    if (m.sender != app.api.myId) app.chats.opened(widget.convId);
  }

  Future<void> _send({String body = '', String kind = 'text', Map<String, dynamic>? media}) async {
    final rep = replyTo;
    final temp = Message(
        id: _tmp--, convId: widget.convId, sender: app.api.myId, body: body, kind: kind, media: media, replyTo: rep?.id, createdAt: DateTime.now(), sending: true);
    setState(() {
      msgs.insert(0, temp);
      replyTo = null;
    });
    try {
      final m = await app.api.send(widget.convId, body: body, kind: kind, media: media, replyTo: rep?.id);
      if (!mounted) return;
      setState(() {
        msgs.removeWhere((x) => x.id == temp.id);
        if (!msgs.any((x) => x.id == m.id)) msgs.insert(0, m);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        msgs.removeWhere((x) => x.id == temp.id);
        replyTo ??= rep;
      });
      // the words are not lost: back in the field to send again
      if (kind == 'text' && field.text.isEmpty) field.text = body;
      toast(context, errText(e));
    }
  }

  Future<void> _sendText() async {
    final t = field.text.trim();
    if (t.isEmpty) return;
    field.clear();
    final ed = editing;
    if (ed != null) {
      setState(() => editing = null);
      try {
        await app.api.editMessage(ed.id, t);
        if (!mounted) return;
        setState(() {
          final i = msgs.indexWhere((x) => x.id == ed.id);
          if (i >= 0) msgs[i] = ed.copyWith(body: t, edited: true);
        });
      } catch (e) {
        if (!mounted) return;
        field.text = t;
        setState(() => editing = ed);
        toast(context, errText(e));
      }
      return;
    }
    _send(body: t);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> _sendPhoto({bool camera = false}) async {
    if (sending) return;
    final List<Uint8List> got;
    try {
      got = await photoSource(camera);
    } catch (_) {
      if (mounted) toast(context, 'ფოტო ვერ გავხსენი');
      return;
    }
    if (got.isEmpty || !mounted) return;
    setState(() => sending = true);
    try {
      for (final b in got.take(5)) {
        final pic = got.length == 1 ? await editPicked(context, b) : b;
        final m = await app.api.uploadPhoto(await photoPrep(pic));
        await _send(kind: 'image', media: {'url': m.url, if (m.sm != null) 'sm': m.sm, 'w': m.w, 'h': m.h});
      }
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
    if (mounted) setState(() => sending = false);
  }

  Future<void> _sticker() async {
    final r = await pickSticker(context);
    if (r == null || !mounted) return;
    if (r.emoji != null) {
      final v = field.value, at = v.selection.isValid ? v.selection.baseOffset : v.text.length;
      field.value = TextEditingValue(text: v.text.substring(0, at) + r.emoji! + v.text.substring(at), selection: TextSelection.collapsed(offset: at + r.emoji!.length));
      focus.requestFocus();
      return;
    }
    await _send(body: stickerLabel(r.sticker!) ?? '✨', media: {'sticker': r.sticker});
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> _location() async {
    final p = await locDevice.permission();
    if (!mounted) return;
    if (p != 'granted') {
      toast(context, 'ლოკაციაზე წვდომა არ მოგვეცა. ჩართე ტელეფონის პარამეტრებში');
      return;
    }
    toast(context, 'ლოკაციას ვადგენ…');
    final h = await locDevice.here();
    if (!mounted) return;
    if (h == null) {
      toast(context, 'ლოკაცია ვერ დადგინდა');
      return;
    }
    await _send(body: '📍 ლოკაცია', media: {
      'loc': {'lat': double.parse(h.lat.toStringAsFixed(6)), 'lng': double.parse(h.lng.toStringAsFixed(6)), 'acc': h.acc.round()},
    });
  }

  Future<void> _more() async {
    final ch = chat, other = ch?.other;
    final pick = await pickFrom(context, 'დამატება', [
      ('photo', 'image', 'ფოტო'),
      ('camera', 'camera', 'კამერა'),
      ('loc', 'pin', 'ჩემი ლოკაცია'),
      if (other != null) ('card', 'card', 'მისალოცი ბარათი'),
    ]);
    if (!mounted) return;
    switch (pick) {
      case 'photo':
        await _sendPhoto();
      case 'camera':
        await _sendPhoto(camera: true);
      case 'loc':
        await _location();
      case 'card':
        final p = app.people[other!];
        await openCardPicker(context, uid: other, toName: p?.name ?? '', kind: 'g');
        _load();
    }
  }

  /// the microphone button: asks for the microphone once, then records until "send" or "cancel" (2 minutes at most)
  Future<void> _voice() async {
    if (recording || sending) return;
    final p = await voiceDevice.permission();
    if (!mounted) return;
    if (p != 'granted') {
      if (p == 'blocked' &&
          await confirm(context, title: 'მიკროფონი დაკეტილია', text: 'ხმოვანი შეტყობინებისთვის ტელეფონის პარამეტრებში მიეცი Peera-ს მიკროფონის ნება.', yes: 'პარამეტრები')) {
        await voiceDevice.settings();
      } else if (p != 'blocked' && mounted) {
        toast(context, 'მიკროფონზე წვდომა არ არის');
      }
      return;
    }
    if (!await voiceDevice.start()) {
      if (mounted) toast(context, 'ჩაწერა ვერ დაიწყო');
      return;
    }
    if (!mounted) {
      voiceDevice.cancel();
      return;
    }
    setState(() {
      recording = true;
      recMs = 0;
      recLevel = 0;
    });
    _recTick = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      final l = await voiceDevice.level();
      if (!mounted || !recording) return;
      setState(() {
        recMs += 250;
        recLevel = l;
      });
      if (recMs >= recMax) _voiceSend();
    });
  }

  void _voiceCancel() {
    if (!recording) return;
    _recTick?.cancel();
    setState(() => recording = false);
    voiceDevice.cancel();
  }

  Future<void> _voiceSend() async {
    if (!recording) return;
    _recTick?.cancel();
    setState(() {
      recording = false;
      sending = true;
    });
    try {
      final r = await voiceDevice.stop();
      if (r == null || r.ms < 600) {
        if (mounted) toast(context, 'ძალიან მოკლეა. ილაპარაკე და მერე დააჭირე გაგზავნას');
        return;
      }
      final url = await app.api.uploadVoice(r.path);
      final dur = (r.ms / 1000).round().clamp(1, recMax ~/ 1000);
      await _send(kind: 'voice', media: {'url': url, 'dur': dur});
      if (scroll.hasClients) scroll.jumpTo(0);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _openOther() {
    final o = chat?.other;
    if (o == null) {
      if (chat?.isGroup == true) _chatMore();
      return;
    }
    openPage(context, PersonScreen(uid: o, initial: app.people[o]), full: true);
  }

  // ---------- a message's menu ----------

  Future<void> _react(Message m, String emoji) async {
    if (m.deleted || m.id < 0) return;
    final me = app.api.myId, cur = reacts[m.id]?[me], next = cur == emoji ? null : emoji;
    setState(() => _setReact(m.id, me, next));
    try {
      await app.api.reactMessage(m.id, next, had: cur != null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _setReact(m.id, me, cur));
      toast(context, errText(e));
    }
  }

  Future<void> _actions(Message m) async {
    if (m.id < 0 || m.kind == 'system') return;
    HapticFeedback.selectionClick();
    final me = app.api.myId, mine = m.sender == me, md = m.media ?? const {};
    final plain = m.kind == 'text' && md['sticker'] == null && md['card'] == null && md['loc'] == null && md['fwd'] == null;
    final canEdit = mine && plain && !m.deleted && DateTime.now().difference(m.createdAt) < const Duration(hours: 48);
    final myR = reacts[m.id]?[me];
    final a = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.pc.surface,
      builder: (s) {
        final c = s.pc;
        Widget item(String k, String icon, String label, {bool danger = false}) => ListTile(
              key: ValueKey('ma-$k'),
              leading: PIcon(icon, color: danger ? c.nope : c.ink),
              title: Text(label, style: TextStyle(color: danger ? c.nope : c.ink, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(s).pop(k),
            );
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (!m.deleted)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    for (final e in [if (myR != null && !messageReactions.contains(myR)) myR, ...messageReactions])
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Material(
                          color: myR == e ? c.accentSoft : c.sunk,
                          shape: const CircleBorder(),
                          child: InkWell(
                            key: ValueKey('mr-$e'),
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(s).pop('r:$e'),
                            child: SizedBox.square(dimension: 46, child: Center(child: Text(reactionGlyph(e), style: const TextStyle(fontSize: 24)))),
                          ),
                        ),
                      ),
                    Material(
                      color: c.sunk,
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: const ValueKey('mr-more'),
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(s).pop('rmore'),
                        child: SizedBox.square(dimension: 46, child: Center(child: PIcon('plus', size: 20, color: c.muted))),
                      ),
                    ),
                  ]),
                ),
              const SizedBox(height: 6),
              if (!m.deleted) item('reply', 'reply', 'პასუხი'),
              if (!m.deleted && plain && m.body.isNotEmpty) item('copy', 'copy', 'კოპირება'),
              if (!m.deleted) item('fwd', 'fwd', 'გადაგზავნა'),
              if (!m.deleted) item('pin', 'pin', pinned == m.id ? 'მიმაგრების მოხსნა' : 'მიმაგრება'),
              if (canEdit) item('edit', 'edit', 'რედაქტირება'),
              if (mine && !m.deleted) item('unsend', 'trash', 'ყველასთვის წაშლა', danger: true),
              if (!mine) item('report', 'flag', 'საჩივარი'),
            ]),
          ),
        );
      },
    );
    if (a == null || !mounted) return;
    if (a.startsWith('r:')) return _react(m, a.substring(2));
    switch (a) {
      case 'rmore':
        final r = await pickSticker(context);
        if (r?.emoji != null && mounted) await _react(m, r!.emoji!);
      case 'reply':
        setState(() {
          replyTo = m;
          editing = null;
        });
        focus.requestFocus();
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.body));
        if (mounted) toast(context, 'დაკოპირდა');
      case 'fwd':
        await forwardMessage(context, m, mine ? context.me.name : (app.people[m.sender]?.name ?? ''));
      case 'pin':
        final on = pinned != m.id;
        if (await attempt(context, () => app.api.pinMessage(widget.convId, on ? m.id : null)) && mounted) {
          setState(() {
            pinned = on ? m.id : null;
            pinMsg = on ? m : null;
          });
        }
      case 'edit':
        setState(() {
          editing = m;
          replyTo = null;
        });
        field.text = m.body;
        field.selection = TextSelection.collapsed(offset: m.body.length);
        focus.requestFocus();
      case 'unsend':
        if (await attempt(context, () => app.api.unsendMessage(m.id)) && mounted) {
          setState(() {
            final i = msgs.indexWhere((x) => x.id == m.id);
            if (i >= 0) msgs[i] = m.copyWith(deleted: true, body: '', clearMedia: true);
            if (pinned == m.id) pinned = null;
          });
        }
      case 'report':
        await reportSheet(context, 'message', '${m.id}');
    }
  }

  Future<void> _reactors(Message m) async {
    final r = reacts[m.id];
    if (r == null || r.isEmpty) return;
    final me = app.api.myId;
    await app.people.ensure(r.keys);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('რეაქციები', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          for (final e in r.entries)
            ListTile(
              key: ValueKey('rx-${e.key}'),
              leading: Avatar(p: app.people[e.key] ?? Profile(id: e.key, name: '…'), size: 40),
              title: Text(e.key == me ? 'შენ' : (app.people[e.key]?.name ?? ''), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: e.key == me ? const Text('შეეხე მოსაშორებლად') : null,
              trailing: Text(reactionGlyph(e.value), style: const TextStyle(fontSize: 24)),
              onTap: () {
                Navigator.of(s).pop();
                if (e.key == me) {
                  _react(m, e.value);
                } else {
                  openPage(context, PersonScreen(uid: e.key, initial: app.people[e.key]), full: true);
                }
              },
            ),
        ]),
      ),
    );
  }

  /// scrolls to a message (older ones are loaded until it is found) and lights it up for a moment
  Future<void> _jump(int id) async {
    var tries = 0;
    while (!msgs.any((m) => m.id == id) && !done && tries++ < 20) {
      if (!await _older()) break;
    }
    if (!mounted) return;
    if (!msgs.any((m) => m.id == id)) {
      toast(context, 'ეს შეტყობინება აღარ მოიძებნა');
      return;
    }
    setState(() => flash = id);
    // the list is lazy: move towards it until it is built, then bring it to the middle
    for (var i = 0; i < 40 && mounted; i++) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(ctx, alignment: .5, duration: const Duration(milliseconds: 300));
        break;
      }
      if (!scroll.hasClients) break;
      final p = scroll.position;
      final idx = msgs.indexWhere((m) => m.id == id);
      final atTop = msgs.indexWhere((m) => _keys[m.id]?.currentContext != null);
      final to = (p.pixels + (idx > atTop ? 600 : -600)).clamp(p.minScrollExtent, p.maxScrollExtent).toDouble();
      if (to == p.pixels) break;
      scroll.jumpTo(to);
      await WidgetsBinding.instance.endOfFrame;
    }
    _flashT?.cancel();
    _flashT = Timer(const Duration(milliseconds: 1600), () {
      if (mounted && flash == id) setState(() => flash = null);
    });
  }

  // ---------- the conversation's menu ----------

  Future<void> _chatMore() async {
    final ch = chat;
    if (ch == null) return;
    final pick = await pickFrom(context, 'საუბარი', [
      ('search', 'search', 'ძებნა საუბარში'),
      ('media', 'image', 'ფოტოები და ბმულები'),
      ('mute', 'mute', ch.muted ? 'ხმის ჩართვა' : 'დადუმება'),
      ('arch', 'archive', ch.archived ? 'არქივიდან ამოღება' : 'არქივში გადატანა'),
      ('ttl', 'timer', 'თვითგაქრობადი შეტყობინებები'),
      if (ch.isGroup) ...[
        ('members', 'users', 'წევრები'),
        ('add', 'uadd', 'წევრის დამატება'),
        ('rename', 'edit', 'სახელის შეცვლა'),
        ('leave', 'out', 'ჯგუფიდან გასვლა'),
      ] else if (ch.other != null) ...[
        ('profile', 'user', 'პროფილის ნახვა'),
        ('report', 'flag', 'საჩივარი'),
        ('block', 'lock', 'დაბლოკვა'),
      ],
    ]);
    if (!mounted || pick == null) return;
    switch (pick) {
      case 'search':
        final id = await openPage<int>(context, ChatSearchScreen(convId: widget.convId), full: true);
        if (id != null && mounted) await _jump(id);
      case 'media':
        await openPage(context, ChatMediaScreen(convId: widget.convId), full: true);
      case 'mute':
        await muteSheet(context, ch);
      case 'arch':
        final on = !ch.archived;
        if (await attempt(context, () => app.api.archiveChat(ch.convId, on)) && mounted) {
          toast(context, on ? 'გადავიდა არქივში. ახალი მესიჯი თავად ამოიღებს, თუ საუბარი დადუმებული არ არის' : 'ამოვიდა არქივიდან');
          await app.chats.load();
        }
      case 'ttl':
        final v = await ttlSheet(context, ttl);
        if (v == null || !mounted) return;
        final secs = v == 0 ? null : v;
        if (await attempt(context, () => app.api.setChatTtl(widget.convId, secs)) && mounted) {
          setState(() => ttl = secs);
          toast(context, secs != null ? 'თვითგაქრობა ჩაირთო' : 'თვითგაქრობა გამოირთო');
        }
      case 'members':
        await groupMembers(context, ch);
      case 'add':
        final sel = await pickFriends(context, title: 'წევრის დამატება', action: 'დამატება', skip: ch.members.toSet());
        if (sel == null || sel.isEmpty || !mounted) return;
        if (await attempt(context, () => app.api.addToGroupChat(ch.convId, sel)) && mounted) {
          toast(context, 'დაემატა');
          await app.chats.load();
        }
      case 'rename':
        final t = await askText(context, title: 'სახელის შეცვლა', initial: ch.title ?? '', hint: 'ჯგუფის სახელი', max: 80);
        if (t == null || t.isEmpty || !mounted) return;
        if (await attempt(context, () => app.api.renameGroupChat(ch.convId, t)) && mounted) await app.chats.load();
      case 'leave':
        if (!await confirm(context, title: 'ჯგუფიდან გასვლა', text: 'ამ ჯგუფის შეტყობინებებს აღარ მიიღებ.', yes: 'გასვლა', danger: true) || !mounted) return;
        if (await attempt(context, () => app.api.leaveGroupChat(ch.convId)) && mounted) {
          await app.chats.load();
          if (mounted) Navigator.of(context).maybePop();
        }
      case 'profile':
        _openOther();
      case 'report':
        await reportSheet(context, 'user', ch.other!);
      case 'block':
        final p = app.people[ch.other!] ?? Profile(id: ch.other!, name: '');
        if (await blockPerson(context, p) && mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return ListenableBuilder(
      listenable: Listenable.merge([app.chats, app.people]),
      builder: (context, _) {
        final ch = chat, other = ch?.other == null ? null : app.people[ch!.other!];
        final title = ch == null ? '' : (ch.isGroup ? ((ch.title ?? '').isEmpty ? 'ჯგუფი' : ch.title!) : (other?.fullName ?? ''));
        final typers = [for (final u in typingNow.keys) app.people[u]?.name.split(' ').first ?? ''];
        var sub = ch == null
            ? ''
            : ch.isGroup
                ? '${ch.members.length + 1} წევრი'
                : lastSeenText(other?.lastSeen);
        if (typers.isNotEmpty) sub = '${ch?.isGroup == true ? '${typers.take(2).join(', ')} ' : ''}წერს…';
        final pm = pinned == null ? null : (_find(pinned!) ?? pinMsg);
        // back while recording throws the recording away (one step), back with a reply or an edit open closes that
        // first; then the conversation
        final busyBack = recording || replyTo != null || editing != null;
        return PopScope(
          canPop: !busyBack,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (recording) {
              _voiceCancel();
            } else {
              if (editing != null) field.clear();
              setState(() {
                replyTo = null;
                editing = null;
              });
            }
          },
          child: Scaffold(
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
                        if (ch?.muted == true) Padding(padding: const EdgeInsets.only(left: 4), child: PIcon('mute', size: 14, color: c.muted)),
                      ]),
                      if (sub.isNotEmpty || ttl != null)
                        Row(children: [
                          if (ttl != null) ...[
                            PIcon('timer', size: 13, color: c.muted),
                            Text(' ${ttlNames[ttl] ?? ''}${sub.isEmpty ? '' : ' · '}', style: TextStyle(fontSize: 12.5, color: c.muted)),
                          ],
                          Flexible(
                            child: Text(sub,
                                key: const ValueKey('chat-sub'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: sub == 'ონლაინ' || typers.isNotEmpty ? c.vine : c.muted, fontWeight: FontWeight.w500)),
                          ),
                        ]),
                    ]),
                  ),
                ]),
              ),
              actions: [IconBtn('more', key: const ValueKey('chat-more'), label: 'მეტი', onTap: _chatMore)],
            ),
            body: Column(children: [
              if (pm != null)
                Material(
                  color: c.surface,
                  child: InkWell(
                    key: const ValueKey('pin-bar'),
                    onTap: () => _jump(pm.id),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                      child: Row(children: [
                        PIcon('pin', size: 18, color: c.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('მიმაგრებული', style: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: 12.5)),
                            Text(snip(pm), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                          ]),
                        ),
                        IconBtn('x', key: const ValueKey('unpin'), label: 'მოხსნა', size: 18, color: c.muted, onTap: () async {
                          if (await attempt(context, () => app.api.pinMessage(widget.convId, null)) && mounted) setState(() => pinned = null);
                        }),
                      ]),
                    ),
                  ),
                ),
              Expanded(child: _list(context, ch)),
              if (replyTo != null || editing != null)
                _ReplyBar(
                  icon: editing != null ? 'edit' : 'reply',
                  title: editing != null ? 'რედაქტირება' : (replyTo!.sender == app.api.myId ? 'შენ' : (app.people[replyTo!.sender]?.name.split(' ').first ?? 'პასუხი')),
                  text: snip(editing ?? replyTo),
                  onClose: () {
                    if (editing != null) field.clear();
                    setState(() {
                      replyTo = null;
                      editing = null;
                    });
                  },
                ),
              recording
                  ? _RecordBar(ms: recMs, level: recLevel, onCancel: _voiceCancel, onSend: _voiceSend)
                  : _Composer(field: field, focus: focus, sending: sending, editing: editing != null, onSend: _sendText, onMore: _more, onSticker: _sticker, onMic: _voice),
            ]),
          ),
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
    // "seen" under my last message when it is the newest one
    final last = msgs.where((m) => m.kind != 'system').firstOrNull;
    String? seenText;
    if (last != null && last.sender == me && !last.deleted && !last.sending) {
      final by = [for (final e in seen.entries) if (e.value != null && !e.value!.isBefore(last.createdAt)) e];
      seenText = by.isEmpty ? 'გაგზავნილია' : (group ? 'ნახა ${by.length}' : 'ნანახია · ${hhmm(by.first.value!)}');
    }
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
        final q = m.replyTo == null || m.deleted ? null : _find(m.replyTo!);
        return Column(key: _keys.putIfAbsent(m.id, GlobalKey.new), children: [
          if (dayStart)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(12)),
                child: Text(dayLabel(m.createdAt), style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(color: flash == m.id ? c.accentSoft : Colors.transparent, borderRadius: BorderRadius.circular(14)),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPress: () => _actions(m),
              onDoubleTap: () => _react(m, '❤️'),
              child: _Bubble(
                m: m,
                mine: m.sender == me,
                who: app.people[m.sender],
                showName: group && runStart && m.sender != me,
                showAvatar: group && runEnd && m.sender != me,
                group: group,
                tail: runEnd,
                reacts: reacts[m.id],
                me: me,
                quote: m.replyTo != null && !m.deleted
                    ? (
                        q == null ? 'პასუხი' : (q.sender == me ? 'შენ' : (app.people[q.sender]?.name.split(' ').first ?? '')),
                        snip(q),
                      )
                    : null,
                onQuote: m.replyTo == null ? null : () => _jump(m.replyTo!),
                onReacts: () => _reactors(m),
              ),
            ),
          ),
          if (i == 0 && seenText != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  PIcon(seenText == 'გაგზავნილია' ? 'check' : 'eye', size: 13, color: c.muted),
                  const SizedBox(width: 3),
                  Text(seenText, key: const ValueKey('seen'), style: TextStyle(color: c.muted, fontSize: 11.5)),
                ]),
              ),
            ),
        ]);
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

/// the disappearing times' names
const ttlNames = {3600: '1 საათი', 86400: '24 საათი', 604800: '7 დღე'};

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.m,
    required this.mine,
    required this.me,
    this.who,
    this.showName = false,
    this.showAvatar = false,
    this.group = false,
    this.tail = true,
    this.reacts,
    this.quote,
    this.onQuote,
    this.onReacts,
  });
  final Message m;
  final bool mine, showName, showAvatar, group, tail;
  final Profile? who;
  final String me;
  final Map<String, String>? reacts;

  /// the message answered: who and what
  final (String, String)? quote;
  final VoidCallback? onQuote, onReacts;

  /// what the app cannot show yet: a line saying what it is, opened on the site
  (String, String)? _other() {
    final md = m.media ?? const {};
    if (m.kind == 'voice') return ('🎤', 'ხმოვანი შეტყობინება'); // one without a link
    if (md['sticker'] != null && stickerSvg('${md['sticker']}') == null) return ('🙂', 'სტიკერი');
    if (md['card'] != null) return ('💌', 'ბარათი');
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
    final md = m.media ?? const {};
    final time = Row(mainAxisSize: MainAxisSize.min, children: [
      Text(
        '${m.edited && !m.deleted ? 'რედაქტირებული · ' : ''}${hhmm(m.createdAt)}${m.sending ? ' · იგზავნება' : ''}',
        style: TextStyle(fontSize: 11, color: mine ? fg.withValues(alpha: .75) : c.muted),
      ),
      if (m.expiresAt != null) Padding(padding: const EdgeInsets.only(left: 3), child: PIcon('timer', size: 11, color: mine ? fg.withValues(alpha: .75) : c.muted)),
    ]);
    Widget small2(Widget w) => Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          w,
          Padding(padding: const EdgeInsets.only(top: 3, left: 4, right: 4), child: time),
        ]);
    Widget inner;
    final photo = m.photo, post = md['post'], other = _other(), loc = md['loc'], story = md['story'];
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
    } else if (md['sticker'] is String && stickerSvg('${md['sticker']}') != null) {
      inner = small2(StickerView('${md['sticker']}', size: 130));
    } else if (md['card'] is Map) {
      inner = small2(GreetingCard(card: md['card'] as Map, width: 220));
    } else if (loc is Map && asNum(loc['lat']) != null && asNum(loc['lng']) != null) {
      inner = small2(LocCard(lat: asNum(loc['lat'])!, lng: asNum(loc['lng'])!, acc: asNum(loc['acc'])));
    } else if (story != null && '${md['url'] ?? ''}'.startsWith('http')) {
      final react = md['act'] == 'react';
      inner = small2(Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          PIcon('story', size: 14, color: c.muted),
          const SizedBox(width: 4),
          Text(react ? (mine ? 'რეაქცია ისტორიაზე' : 'რეაქცია შენს ისტორიაზე') : (mine ? 'პასუხი ისტორიაზე' : 'პასუხი შენს ისტორიაზე'),
              style: TextStyle(color: c.muted, fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => openPhotos(context, [Media(url: '${md['url']}')]),
          child: SizedBox(width: 110, height: 170, child: PImage(md['type'] == 'video' ? '${md['poster'] ?? md['url']}' : '${md['url']}', radius: 14)),
        ),
        const SizedBox(height: 4),
        if (react)
          Text(reactionGlyph(m.body), style: const TextStyle(fontSize: 34))
        else
          _box(context, shape, bg, RichBody(m.body, style: TextStyle(fontSize: 15.5, height: 1.35, color: fg)), const SizedBox.shrink()),
      ]));
    } else if (m.kind == 'voice' && '${md['url'] ?? ''}'.isNotEmpty) {
      inner = _box(context, shape, bg, VoiceNote(url: '${md['url']}', seconds: asInt(md['dur']), mine: mine), time);
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
          Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ('${post['img'] ?? ''}'.startsWith('http')) ...[
              SizedBox.square(dimension: 54, child: PImage('${post['img']}', radius: 10)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('📝 ${post['by'] ?? ''}-ის პოსტი', style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                if ('${post['t'] ?? ''}'.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('${post['t']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 14)),
                  ),
              ]),
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
      final style = TextStyle(fontSize: 15.5, height: 1.35, color: fg);
      inner = _box(context, shape, bg, mine ? RichBody(m.body, style: style) : TranslatableBody(m.body, style: style, compact: true), time);
    }

    final q = quote;
    final head = <Widget>[
      if (md['fwd'] != null && !m.deleted)
        Padding(
          padding: const EdgeInsets.only(bottom: 3, left: 4, right: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            PIcon('fwd', size: 13, color: c.muted),
            const SizedBox(width: 3),
            Flexible(child: Text('გადმოგზავნილი · ${md['fwd']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12, fontStyle: FontStyle.italic))),
          ]),
        ),
      if (q != null)
        GestureDetector(
          key: ValueKey('quote-${m.id}'),
          onTap: onQuote,
          child: Container(
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
            decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: c.accent, width: 3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(q.$1, style: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: 12.5)),
              Text(q.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 13)),
            ]),
          ),
        ),
    ];
    final rx = reacts ?? const <String, String>{};
    Widget? pill;
    if (rx.isNotEmpty && !m.deleted) {
      final cnt = <String, int>{};
      for (final e in rx.values) {
        cnt[e] = (cnt[e] ?? 0) + 1;
      }
      final top = (cnt.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(3).map((e) => reactionGlyph(e.key)).join();
      pill = GestureDetector(
        key: ValueKey('mreact-${m.id}'),
        onTap: onReacts,
        child: Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: rx.containsKey(me) ? c.accent : c.line),
          ),
          child: Text('$top${rx.length > 1 ? ' ${rx.length}' : ''}', style: TextStyle(fontSize: 13, color: c.ink, fontWeight: FontWeight.w700)),
        ),
      );
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
              ...head.map((h) => ConstrainedBox(constraints: BoxConstraints(maxWidth: w * .7), child: h)),
              Opacity(opacity: m.sending ? .7 : 1, child: bubble),
              if (pill != null) pill,
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

class _Tiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => mapTile(getTileUrl(coordinates, options));
}

/// A shared place: a small still map with a pin; a touch opens it on OpenStreetMap.
class LocCard extends StatelessWidget {
  const LocCard({super.key, required this.lat, required this.lng, this.acc});
  final double lat, lng;
  final double? acc;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, at = LatLng(lat, lng);
    final href = 'https://www.openstreetmap.org/?mlat=${lat.toStringAsFixed(6)}&mlon=${lng.toStringAsFixed(6)}#map=16/${lat.toStringAsFixed(5)}/${lng.toStringAsFixed(5)}';
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication),
      child: Container(
        width: 240,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // the economy mode draws no map
          if (!ecoMode.value)
          SizedBox(
            height: 130,
            child: IgnorePointer(
              child: FlutterMap(
                options: MapOptions(initialCenter: at, initialZoom: 15, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'my.peera.app', tileProvider: _Tiles()),
                  MarkerLayer(markers: [Marker(point: at, width: 34, height: 34, alignment: Alignment.topCenter, child: PIcon('pin', size: 34, color: c.nope, stroke: 2.4))]),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
            child: Row(children: [
              PIcon('pin', size: 18, color: c.accent),
              const SizedBox(width: 6),
              const Expanded(child: Text('ლოკაცია', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700))),
              Text('${acc != null && acc! > 0 && acc! < 1000 ? '±${acc!.round()} მ · ' : ''}რუკაზე', style: TextStyle(color: c.muted, fontSize: 12.5)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({required this.icon, required this.title, required this.text, required this.onClose});
  final String icon, title, text;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Container(
      key: const ValueKey('reply-bar'),
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 2),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: Row(children: [
        PIcon(icon, size: 18, color: c.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: 13)),
            Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 13)),
          ]),
        ),
        IconBtn('x', key: const ValueKey('reply-x'), label: 'გაუქმება', size: 18, color: c.muted, onTap: onClose),
      ]),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.field,
    required this.focus,
    required this.sending,
    required this.editing,
    required this.onSend,
    required this.onMore,
    required this.onSticker,
    required this.onMic,
  });
  final TextEditingController field;
  final FocusNode focus;
  final bool sending, editing;
  final VoidCallback onSend, onMore, onSticker, onMic;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 6, 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            sending
                ? const Padding(padding: EdgeInsets.all(14), child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2)))
                : IconBtn('plus', key: const ValueKey('chat-plus'), label: 'დამატება', color: c.vine, onTap: onMore),
            Expanded(
              child: TextField(
                controller: field,
                focusNode: focus,
                minLines: 1,
                maxLines: 5,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'შეტყობინება…',
                  isDense: true,
                  counterText: '',
                  contentPadding: const EdgeInsets.fromLTRB(16, 11, 4, 11),
                  suffixIcon: IconBtn('smile', key: const ValueKey('chat-stk'), label: 'სმაილები და სტიკერები', size: 22, color: c.muted, onTap: onSticker),
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
                // with nothing written the button records a voice message, as in the site's chat
                return Semantics(
                  key: ValueKey(can ? 'chat-send' : 'chat-mic'),
                  button: true,
                  label: can ? (editing ? 'შენახვა' : 'გაგზავნა') : 'ხმოვანი შეტყობინება',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: can ? onSend : (sending ? null : onMic),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: can ? c.accent : c.accentSoft, shape: BoxShape.circle),
                      child: can
                          ? (editing
                              ? PIcon('check', size: 22, color: c.onAccent, stroke: 2.2)
                              : Padding(padding: const EdgeInsets.only(left: 2), child: PIcon('send', size: 21, color: c.onAccent, stroke: 2)))
                          : PIcon('mic', size: 22, color: c.accent, stroke: 2),
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

/// Recording a voice message, in place of the writing line: throw away, the time and a dot that grows with the
/// voice, send. Two minutes at most (then it goes by itself).
class _RecordBar extends StatelessWidget {
  const _RecordBar({required this.ms, required this.level, required this.onCancel, required this.onSend});
  final int ms;
  final double level;
  final VoidCallback onCancel, onSend;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, left = _ChatScreenState.recMax - ms;
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
          child: Row(children: [
            IconBtn('trash', key: const ValueKey('voice-cancel'), label: 'გაუქმება', color: c.nope, onTap: onCancel),
            const SizedBox(width: 6),
            SizedBox.square(
              dimension: 22,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 10 + 12 * level,
                  height: 10 + 12 * level,
                  decoration: BoxDecoration(color: c.nope, shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(clockOf(Duration(milliseconds: ms)),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.ink, fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(width: 10),
            Expanded(
              child: Text(left <= 15000 ? 'დარჩა ${(left / 1000).ceil()} წამი' : 'იწერება…',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: left <= 15000 ? c.nope : c.muted, fontSize: 14)),
            ),
            Semantics(
              key: const ValueKey('voice-send'),
              button: true,
              label: 'ხმოვანის გაგზავნა',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                  child: Padding(padding: const EdgeInsets.only(left: 2), child: PIcon('send', size: 21, color: c.onAccent, stroke: 2)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
