// Rooms (rooms.js), the same as the site's and with it: the study room (video, everyone on camera, a host who leads
// the agenda and gives the floor), the discussion (voice; the host gives the word, the others raise a hand), the live
// broadcast (one camera, the others watch, comment, send hearts and gifts). Everyone is joined to everyone (a mesh,
// the lower id offers); a live's host offers to each viewer.
import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../people/albums.dart';
import '../people/profile_parts.dart';
import '../profile/profile.dart';
import '../ui/bits.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'rtc.dart';

const roomKinds = [('supra', 'სასწავლო ოთახი'), ('birja', 'დისკუსია'), ('live', 'ლაივი')];
const roomTopics = [('study', 'სწავლა'), ('career', 'კარიერა'), ('tech', 'ტექნოლოგიები'), ('culture', 'კულტურა'), ('sport', 'სპორტი'), ('music', 'მუსიკა'), ('other', 'სხვა')];

/// the study room's agenda (rooms.js TOASTS)
const roomAgenda = ['გაცნობა და დღის გეგმა', 'წინა თემის გამეორება', 'ახალი თემის ახსნა', 'კითხვები და პასუხები', 'ერთად ამოხსნა', 'შესვენება', 'ქვიზი', 'შეჯამება', 'შემდეგი შეხვედრის გეგმა'];

/// how many fit in a room (everyone is joined to everyone)
const roomCap = {'supra': 8, 'birja': 12, 'live': 26};

String roomKindName(Object? k) => roomKinds.firstWhere((x) => x.$1 == k, orElse: () => roomKinds.first).$2;
String roomTopic(Object? k) => roomTopics.firstWhere((x) => x.$1 == k, orElse: () => roomTopics.last).$2;
String roomIcon(Object? k) => k == 'supra' ? 'video' : (k == 'live' ? 'live' : 'mic');

/// The open rooms of a kind, and a new one.
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key, this.kind = 'supra'});
  final String kind;
  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  late String kind = roomKinds.any((k) => k.$1 == widget.kind) ? widget.kind : 'supra';
  List<Map<String, dynamic>>? rows;
  Object? error;
  int _gen = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final g = ++_gen, app = context.app;
    try {
      final r = await app.api.rooms(kind);
      await app.people.ensure([for (final x in r) '${x['host']}']);
      if (mounted && g == _gen) {
        setState(() {
          rows = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && g == _gen) setState(() => error = e);
    }
  }

  Future<void> _new() async {
    final id = await newRoomSheet(context, kind);
    if (id != null && mounted) await openRoom(context, id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, r = rows, app = context.app;
    final hint = switch (kind) {
      'supra' => 'ვიდეო-შეხვედრა კურსელებთან: ერთად მეცადინეობა, წამყვანი, დღის გეგმა.',
      'birja' => 'ხმოვანი დისკუსია: მასპინძელი სიტყვას აძლევს, დანარჩენები უსმენენ და ხელს სწევენ.',
      _ => 'ერთი კამერა, ბევრი მაყურებელი: კომენტარები, გულები, საჩუქრები.',
    };
    return Scaffold(
      appBar: peeraBar(context, title: 'ოთახები', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: FilledButton.icon(
            key: const ValueKey('rooms-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: _new,
            icon: PIcon('plus', size: 17, color: c.onAccent),
            label: Text(kind == 'live' ? 'ეთერი' : 'ოთახი'),
          ),
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: SegmentedButton<String>(
              key: const ValueKey('rk'),
              showSelectedIcon: false,
              segments: [for (final (k, n) in roomKinds) ButtonSegment(value: k, label: Text(k == 'supra' ? 'სასწავლო' : n))],
              selected: {kind},
              onSelectionChanged: (v) {
                setState(() {
                  kind = v.first;
                  rows = null;
                });
                _load();
              },
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 6), child: Text(hint, style: TextStyle(color: c.muted))),
          if (r == null && error == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (r == null)
            Empty(icon: roomIcon(kind), title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
          else if (r.isEmpty)
            Empty(icon: roomIcon(kind), title: 'ახლა ღია ოთახი არ არის', text: 'გახსენი შენი და მოიწვიე მეგობრები.', action: kind == 'live' ? 'ეთერის დაწყება' : 'ოთახის გახსნა', onAction: _new)
          else
            for (final x in r)
              Builder(builder: (context) {
                final h = '${x['host']}', who = app.people[h] ?? Profile(id: h, name: '…');
                return ListTile(
                  key: ValueKey('room-${x['id']}'),
                  leading: Stack(clipBehavior: Clip.none, children: [
                    Avatar(p: who, size: 46),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: kind == 'live' ? c.nope : c.accent, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
                        child: PIcon(roomIcon(kind), size: 12, color: Colors.white),
                      ),
                    ),
                  ]),
                  title: Text('${x['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${who.name}${kind == 'birja' ? ' · ${roomTopic(x['topic'])}' : ''} · ${ago(asTime(x['created_at']))}${x['is_private'] == true ? ' · 🔒' : ''}'),
                  trailing: kind == 'live' ? const PTag('LIVE', kind: 'warn') : const PIcon('chev', size: 18),
                  onTap: () async {
                    await openRoom(context, asInt(x['id']));
                    _load();
                  },
                );
              }),
        ]),
      ),
    );
  }
}

/// A new room: its kind, its title, the topic (a discussion), private (a study room, by invitation). Its id.
Future<int?> newRoomSheet(BuildContext context, String kind0) {
  final app = context.app, me = context.me;
  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => AppScope(app: app, me: me, child: _NewRoom(kind: kind0)),
  );
}

class _NewRoom extends StatefulWidget {
  const _NewRoom({required this.kind});
  final String kind;
  @override
  State<_NewRoom> createState() => _NewRoomState();
}

class _NewRoomState extends State<_NewRoom> {
  late String kind = widget.kind, topic = 'study';
  final title = TextEditingController();
  bool private = false, busy = false;

  Future<void> _go() async {
    final t = title.text.trim();
    if (t.length < 3) {
      toast(context, 'დაწერე სათაური');
      return;
    }
    setState(() => busy = true);
    try {
      final id = await context.app.api.createRoom(kind: kind, title: t, topic: topic, private: private);
      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('ახალი ოთახი', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              key: const ValueKey('nr-kind'),
              showSelectedIcon: false,
              segments: [for (final (k, n) in roomKinds) ButtonSegment(value: k, label: Text(k == 'supra' ? 'სასწავლო' : n))],
              selected: {kind},
              onSelectionChanged: (v) => setState(() => kind = v.first),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('nr-title'),
              controller: title,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: 'სათაური',
                hintText: kind == 'supra' ? 'მაგ. მათემატიკა: მზადება გამოცდისთვის' : (kind == 'birja' ? 'მაგ. რომელი ფაკულტეტი ავირჩიოთ?' : 'მაგ. ლექცია ხელოვნურ ინტელექტზე'),
                counterText: '',
              ),
            ),
            if (kind == 'birja') ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final (k, n) in roomTopics)
                  ChoiceChip(
                    key: ValueKey('nr-tp-$k'),
                    label: Text(n),
                    selected: topic == k,
                    showCheckmark: false,
                    selectedColor: c.accentSoft,
                    side: BorderSide(color: topic == k ? c.accent : c.line),
                    onSelected: (_) => setState(() => topic = k),
                  ),
              ]),
            ],
            if (kind == 'supra')
              SwitchListTile(
                key: const ValueKey('nr-private'),
                contentPadding: EdgeInsets.zero,
                value: private,
                onChanged: (v) => setState(() => private = v),
                title: const Text('მხოლოდ მოწვეულებისთვის'),
                subtitle: const Text('სიაში არ გამოჩნდება, შემოსვლა ბმულით ან მოწვევით'),
              ),
            const SizedBox(height: 6),
            Text(
              kind == 'live' ? 'ეთერს შენი კამერით დაიწყებ. მეგობრებს შეტყობინება მიუვათ.' : 'ოთახში ${roomCap[kind]} ადამიანამდე ეტევა.',
              style: TextStyle(color: c.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            FilledButton(key: const ValueKey('nr-ok'), style: FilledButton.styleFrom(minimumSize: const Size(0, 46)), onPressed: busy ? null : _go, child: Text(kind == 'live' ? 'ეთერის დაწყება' : 'გახსნა')),
          ]),
        ),
      ),
    );
  }
}

/// a room opened (one, however many times asked)
bool _roomOnScreen = false;
Future<void> openRoom(BuildContext context, int id) async {
  if (_roomOnScreen) return;
  _roomOnScreen = true;
  try {
    await openPage(context, RoomScreen(id: id), full: true);
  } finally {
    _roomOnScreen = false;
  }
}

class _P {
  _P(this.uid);
  final String uid;
  late final Future<RtcPeer> pc;
  Object? stream;
  final pending = <Map<String, dynamic>>[];
  bool closed = false;
}

/// One room: its people (pictures or faces), the host's panel, my microphone and camera; live: the broadcast with its
/// comments, hearts and gifts. Back leaves the room (the host is asked first: the room ends for everyone).
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.id});
  final int id;
  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  Map<String, dynamic>? r;
  bool loaded = false;
  String? gone;
  RoomLink? link;
  StreamSubscription<Map<String, Map<String, dynamic>>>? _ps;
  StreamSubscription<(String, Map<String, dynamic>)>? _es;
  RtcMedia? local;
  bool mic = false, cam = false, hand = false, joinedOnce = false, left = false;
  Map<String, Map<String, dynamic>> present = {};
  final peers = <String, _P>{};
  Map<String, dynamic> st = {};
  final comments = <Map<String, dynamic>>[];
  final fx = <(int, String)>[];
  int _fxN = 0;
  DateTime _lastHeart = DateTime(2000);
  final say = TextEditingController(), custom = TextEditingController();
  late PeeraApi api;
  late String me;
  bool _started = false;

  String get kind => '${r?['kind'] ?? 'supra'}';
  bool get supra => kind == 'supra';
  bool get live => kind == 'live';
  String get host => '${r?['host'] ?? ''}';
  bool get isHost => host == me;
  List<String> get speakers => [for (final x in (st['speakers'] is List ? st['speakers'] as List : [host])) '$x'];
  List<String> get hands => [for (final x in (st['hands'] is List ? st['hands'] as List : const [])) '$x'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    api = context.app.api;
    me = api.myId;
    _start();
  }

  @override
  void dispose() {
    _leave(false);
    say.dispose();
    custom.dispose();
    super.dispose();
  }

  Map<String, dynamic> _meta() {
    final p = context.me;
    return {'n': p.name, 'h': p.hue, 'a': p.avatarUrl ?? '', 'mic': mic, 'cam': cam, 'host': isHost};
  }

  Future<void> _start() async {
    Map<String, dynamic>? x;
    try {
      x = await api.room(widget.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          loaded = true;
          gone = errText(e);
        });
      }
      return;
    }
    if (!mounted) return;
    if (x == null || x['live'] != true) {
      setState(() {
        r = x;
        loaded = true;
        gone = 'ოთახი დაიხურა';
      });
      return;
    }
    final row = x;
    setState(() {
      r = row;
      loaded = true;
      st = {'toast': -1, 'custom': '', 'book': '', 'floor': null, 'speakers': ['${row['host']}'], 'hands': <String>[]};
    });
    await context.app.people.ensure([host]);
    if (supra) {
      try {
        local = await rtcKit.media(audio: true, video: true, width: 480, height: 640);
        mic = cam = true;
      } catch (_) {
        if (mounted) toast(context, 'კამერაზე ან მიკროფონზე წვდომა არ არის. ოთახს მხოლოდ უყურებ');
      }
    } else if (live && isHost) {
      try {
        local = await rtcKit.media(audio: true, video: true, width: 720, height: 1280);
        mic = cam = true;
      } catch (_) {
        if (!mounted) return;
        toast(context, 'კამერაზე წვდომა არ არის. ლაივი ვერ დაიწყება');
        _leave(true);
        Navigator.of(context).pop();
        return;
      }
    } else if (isHost) {
      await _mic(true);
    }
    if (!mounted || left) return;
    final l = link = api.roomLink(widget.id);
    _ps = l.presence.listen(_onPresence);
    _es = l.events.listen(_onEvent);
    unawaited(rtcKit.speaker(true));
    await l.join(_meta());
    l.send('hello', {});
    if (mounted) setState(() {});
  }

  void _track() => link?.track(_meta());

  // ---------- who is in ----------
  void _onPresence(Map<String, Map<String, dynamic>> now) {
    if (left || !mounted) return;
    if (!joinedOnce) {
      joinedOnce = true;
      if (now.keys.where((k) => k != me).length >= (roomCap[kind] ?? 8)) {
        toast(context, 'ოთახი სავსეა (${roomCap[kind]} ადამიანი)');
        _leave(false);
        setState(() => gone = 'ოთახი სავსეა');
        return;
      }
    }
    present = now;
    context.app.people.ensure([for (final k in now.keys) k]);
    for (final k in now.keys) {
      if (k == me || peers.containsKey(k)) continue;
      if (live) {
        if (isHost) _offerTo(_newPeer(k));
      } else {
        final p = _newPeer(k);
        if (me.compareTo(k) < 0) _offerTo(p);
      }
    }
    for (final k in [...peers.keys]) {
      if (!now.containsKey(k)) _closePeer(k);
    }
    if (isHost && hands.any((h) => !now.containsKey(h))) _setSt({'hands': [for (final h in hands) if (now.containsKey(h)) h]});
    setState(() {});
  }

  // ---------- the connections ----------
  _P _newPeer(String uid) {
    final p = _P(uid);
    peers[uid] = p;
    p.pc = rtcKit.peer().then((pc) {
      pc.onIce = (c) => link?.send('sig', {'to': uid, 'ice': c});
      pc.onStream = (s) {
        if (mounted && !p.closed) setState(() => p.stream = s);
      };
      pc.onState = (s) {
        if (s != 'failed' || p.closed) return;
        _closePeer(uid);
        // one more try a moment later, if they are still here
        Timer(const Duration(milliseconds: 1500), () {
          if (left || !present.containsKey(uid) || peers.containsKey(uid)) return;
          if (live) {
            if (isHost) _offerTo(_newPeer(uid));
          } else {
            final n = _newPeer(uid);
            if (me.compareTo(uid) < 0) _offerTo(n);
          }
        });
      };
      return pc;
    });
    return p;
  }

  void _closePeer(String uid) {
    final p = peers.remove(uid);
    if (p == null) return;
    p.closed = true;
    p.pc.then((pc) => pc.close()).catchError((_) {});
  }

  Future<void> _addLocal(RtcPeer pc, bool fromOffer) async {
    if (live) {
      if (fromOffer) {
        await pc.recvOnly();
      } else if (local != null) {
        await pc.sendOnly(local!);
      }
      return;
    }
    if (fromOffer) {
      await pc.answerWith(local, sendAudio: supra || mic);
    } else {
      await pc.sendRecv(local, sendAudio: supra || mic, video: supra);
    }
  }

  Future<void> _offerTo(_P p) async {
    try {
      final pc = await p.pc;
      if (p.closed) return;
      await _addLocal(pc, false);
      final o = await pc.offer();
      link?.send('sig', {'to': p.uid, 'sdp': o});
    } catch (_) {}
  }

  Future<void> _flush(_P p, RtcPeer pc) async {
    for (final c in [...p.pending]) {
      await pc.addIce(c);
    }
    p.pending.clear();
  }

  Future<void> _onSig(Map<String, dynamic> m) async {
    final from = '${m['from'] ?? ''}';
    if (m['to'] != me || from.isEmpty) return;
    if (live && !isHost && from != host) return;
    var p = peers[from];
    final sdp = m['sdp'] is Map ? Map<String, dynamic>.from(m['sdp'] as Map) : null;
    try {
      if (sdp?['type'] == 'offer') {
        if (p != null) {
          final pc = await p.pc;
          if (!pc.stable || pc.hasRemote) {
            _closePeer(from);
            p = null;
          }
        }
        final q = p ?? _newPeer(from);
        final pc = await q.pc;
        await pc.setRemote(sdp!);
        await _addLocal(pc, true);
        final a = await pc.answer();
        link?.send('sig', {'to': from, 'sdp': a});
        await _flush(q, pc);
      } else if (sdp?['type'] == 'answer' && p != null) {
        final pc = await p.pc;
        await pc.setRemote(sdp!);
        await _flush(p, pc);
      } else if (m['ice'] is Map && p != null) {
        final c = Map<String, dynamic>.from(m['ice'] as Map);
        final pc = await p.pc;
        if (pc.hasRemote) {
          await pc.addIce(c);
        } else {
          p.pending.add(c);
        }
      }
    } catch (_) {}
  }

  // ---------- what the others send ----------
  void _onEvent((String, Map<String, dynamic>) e) {
    if (left || !mounted) return;
    final (name, p) = e;
    final from = '${p['from'] ?? ''}';
    switch (name) {
      case 'sig':
        _onSig(p);
      case 'state':
        if (from != host || p['st'] is! Map) return;
        final was = speakers.contains(me);
        setState(() => st = Map<String, dynamic>.from(p['st'] as Map));
        if (!supra && !live) {
          final now = speakers.contains(me);
          if (!was && now) {
            hand = false;
            toast(context, 'მასპინძელმა სიტყვა მოგცა. ჩართე მიკროფონი');
          }
          if (!now && mic) _mic(false);
        }
      case 'hello':
        if (isHost) link?.send('state', {'st': st});
      case 'clink':
        _fx('👏 ${context.app.people[from]?.name.split(' ').first ?? ''}');
      case 'cmt':
        _comment({'n': '${p['n'] ?? ''}', 't': '${p['t'] ?? ''}', 'host': p['host'] == true});
      case 'heart':
        _fx('❤️');
      case 'gift':
        _fx('${p['e'] ?? '🎁'}');
        _comment({'n': '${p['n'] ?? ''}', 't': 'აჩუქა ${p['e'] ?? '🎁'}', 'gift': true});
      case 'hand':
        if (!isHost) return;
        final h = hands.where((x) => x != from).toList();
        if (p['up'] == true && !speakers.contains(from)) h.add(from);
        _setSt({'hands': h});
      case 'end':
        toast(context, live ? 'ლაივი დასრულდა' : (supra ? 'წამყვანმა ოთახი დაასრულა' : 'მასპინძელმა ოთახი დახურა'));
        _leave(false);
        setState(() => gone = 'ოთახი დაიხურა');
    }
  }

  void _comment(Map<String, dynamic> m) {
    setState(() {
      comments.add(m);
      if (comments.length > 40) comments.removeAt(0);
    });
  }

  /// a clap, a heart, a gift floating up for a moment
  void _fx(String s) {
    final id = ++_fxN;
    setState(() => fx.add((id, s)));
    Timer(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() => fx.removeWhere((x) => x.$1 == id));
    });
  }

  void _setSt(Map<String, dynamic> patch) {
    if (!isHost) return;
    setState(() => st = {...st, ...patch});
    link?.send('state', {'st': st});
  }

  // ---------- my microphone and camera ----------
  Future<void> _mic(bool on) async {
    if (on && local?.hasAudio != true) {
      try {
        if (local == null) {
          local = await rtcKit.media(audio: true);
        } else {
          await local!.addAudio();
        }
      } catch (_) {
        if (mounted) toast(context, 'მიკროფონზე წვდომა არ არის');
        return;
      }
    }
    local?.setAudio(on);
    mic = on && (local?.hasAudio ?? false);
    for (final p in peers.values) {
      p.pc.then((pc) => pc.setAudioOut(local, mic || supra)).catchError((_) {});
    }
    _track();
    if (mounted) setState(() {});
  }

  void _cam() {
    if (local?.hasVideo != true) return;
    cam = !cam;
    local!.setVideo(cam);
    _track();
    setState(() {});
  }

  void _micTap() {
    if (!supra && !live && !speakers.contains(me)) {
      toast(context, 'ჯერ აწიე ხელი, მასპინძელი სიტყვას მოგცემს');
      return;
    }
    _mic(!mic);
  }

  void _hand() {
    if (speakers.contains(me)) {
      toast(context, 'უკვე ლაპარაკობ');
      return;
    }
    hand = !hand;
    link?.send('hand', {'up': hand});
    toast(context, hand ? 'ხელი აწიე. მასპინძელი გნახავს' : 'ხელი დაუშვი');
    setState(() {});
  }

  void _leave(bool end) {
    if (left) return;
    left = true;
    if (isHost && end && r != null && gone == null) {
      link?.send('end', {});
      api.endRoom(widget.id).catchError((_) {});
    }
    for (final k in [...peers.keys]) {
      _closePeer(k);
    }
    local?.stop();
    local = null;
    _ps?.cancel();
    _es?.cancel();
    link?.leave();
    link = null;
  }

  Future<void> _back() async {
    if (gone != null || left || r == null) {
      Navigator.of(context).pop();
      return;
    }
    if (isHost) {
      final ok = await confirm(
        context,
        title: live ? 'ლაივის დასრულება' : (supra ? 'ოთახის დასრულება' : 'ოთახის დახურვა'),
        text: 'ყველა გავა ოთახიდან.',
        yes: 'დასრულება',
        danger: true,
      );
      if (!ok || !mounted) return;
      _leave(true);
    } else {
      _leave(false);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _invite() async {
    final x = r;
    if (x == null) return;
    final pick = await pickFriends(context, title: 'ოთახში მოწვევა', action: 'მოწვევა', skip: {...present.keys});
    if (pick == null || pick.isEmpty || !mounted) return;
    try {
      final n = await api.inviteToRoom(widget.id, pick);
      if (mounted) toast(context, n > 0 ? 'მოწვევა გაეგზავნა $n მეგობარს' : 'მოწვევა ვერ გაიგზავნა');
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  // ---------- the host's panel ----------
  Future<void> _agendaPick() async {
    final c = context.pc;
    final i = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: c.surface,
      builder: (s) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < roomAgenda.length; i++)
              ListTile(
                key: ValueKey('tpl-$i'),
                leading: CircleAvatar(radius: 14, backgroundColor: s.pc.accentSoft, child: Text('${i + 1}', style: TextStyle(color: s.pc.accent, fontWeight: FontWeight.w800, fontSize: 12))),
                title: Text(roomAgenda[i]),
                onTap: () => Navigator.of(s).pop(i),
              ),
          ]),
        ),
      ),
    );
    if (i != null) _setSt({'toast': i, 'custom': '', 'book': '', 'floor': null});
  }

  Future<void> _floorPick() async {
    final app = context.app, c = context.pc;
    final others = [for (final k in present.keys) if (k != me) k];
    final u = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(key: const ValueKey('tpf-me'), leading: const Text('🎓', style: TextStyle(fontSize: 22)), title: const Text('სიტყვა ისევ წამყვანს'), onTap: () => Navigator.of(s).pop('')),
          for (final k in others)
            if (app.people[k] case final p?) ListTile(key: ValueKey('tpf-$k'), leading: Avatar(p: p, size: 34), title: Text(p.name), onTap: () => Navigator.of(s).pop(k)),
        ]),
      ),
    );
    if (u != null) _setSt({'floor': u.isEmpty ? null : u});
  }

  Future<void> _bookPick() async {
    List<Map<String, dynamic>> rows = const [];
    try {
      rows = await api.toastBook();
    } catch (_) {}
    if (!mounted) return;
    final c = context.pc;
    final id = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: c.surface,
      builder: (s) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .6,
        builder: (s, sc) => ListView(controller: sc, children: [
          if (rows.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('წიგნი ცარიელია')),
          for (final x in rows) ListTile(key: ValueKey('tpb-${x['id']}'), title: Text('${x['title']}'), onTap: () => Navigator.of(s).pop(asInt(x['id']))),
        ]),
      ),
    );
    if (id == null || !mounted) return;
    final t = await api.toastText(id).catchError((_) => null);
    if (t != null) _setSt({'custom': '${t['title'] ?? ''}', 'book': '${t['body'] ?? ''}', 'toast': -1, 'floor': null});
  }

  // ---------- the screen ----------
  Profile _who(String uid) {
    final m = present[uid];
    return context.app.people[uid] ?? Profile(id: uid, name: '${m?['n'] ?? '…'}', hue: asInt(m?['h'], 200), avatarUrl: '${m?['a'] ?? ''}'.isEmpty ? null : '${m?['a']}');
  }

  Widget _tile(String uid, {double h = 220}) {
    final c = context.pc, mine = uid == me, p = _who(uid), m = mine ? null : present[uid];
    final stream = mine ? local?.stream : peers[uid]?.stream;
    final camOn = mine ? cam && (local?.hasVideo ?? false) : m?['cam'] != false;
    final micOn = mine ? mic : m?['mic'] == true;
    final floor = st['floor'] == uid || (st['floor'] == null && uid == host);
    return Container(
      key: ValueKey('tile-$uid'),
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: floor && supra ? c.gold : Colors.transparent, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        if (stream != null && camOn) rtcKit.view(stream, mirror: mine, key: ValueKey('vid-$uid')) else Center(child: Avatar(p: p, size: 64)),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Row(children: [
            if (uid == host) const Text('🎓 ', style: TextStyle(fontSize: 13)),
            Expanded(
              child: Text(mine ? 'მე' : p.name.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 4)])),
            ),
            if (!micOn) const PIcon('micoff', size: 16, color: Colors.white),
          ]),
        ),
      ]),
    );
  }

  Widget _face(String uid, {bool speaking = false}) {
    final c = context.pc, mine = uid == me, p = _who(uid), m = present[uid], micOn = mine ? mic : m?['mic'] == true;
    return SizedBox(
      key: ValueKey('face-$uid'),
      width: 82,
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: speaking && micOn ? c.vine : Colors.transparent, width: 2.5)),
            child: Avatar(p: p, size: speaking ? 62 : 50),
          ),
          if (speaking)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: micOn ? c.vine : c.muted, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
                child: PIcon(micOn ? 'mic' : 'micoff', size: 11, color: Colors.white),
              ),
            ),
          if (hands.contains(uid)) const Positioned(left: -4, top: -4, child: Text('✋', style: TextStyle(fontSize: 18))),
        ]),
        const SizedBox(height: 4),
        Text(mine ? 'მე' : p.name.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
        if (uid == host) Text('მასპინძელი', style: TextStyle(color: c.muted, fontSize: 11)),
      ]),
    );
  }

  Widget _bar(List<Widget> kids) => SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 10), child: Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 10, children: kids)),
      );

  Widget _round(String key, String icon, String label, VoidCallback onTap, {bool on = true, Color? bg}) {
    final c = context.pc;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Material(
        color: bg ?? (on ? c.accentSoft : c.sunk),
        shape: const CircleBorder(),
        child: InkWell(
          key: ValueKey(key),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 54, height: 54, child: Center(child: PIcon(icon, size: 23, color: bg != null ? Colors.white : (on ? c.accent : c.muted)))),
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11.5, color: c.muted)),
    ]);
  }

  Widget _supra() {
    final c = context.pc, ids = [me, for (final k in present.keys) if (k != me) k];
    final ti = asInt(st['toast'], -1), cu = '${st['custom'] ?? ''}', book = '${st['book'] ?? ''}';
    final topic = cu.isNotEmpty ? cu : (ti >= 0 && ti < roomAgenda.length ? roomAgenda[ti] : 'შეხვედრა იწყება…');
    final fl = st['floor'] as String?;
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Container(
            key: const ValueKey('room-topic'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('🎓 წამყვანი · ${_who(host).name}', style: TextStyle(color: c.accent, fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 4),
              Text(topic, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              if (book.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(book, style: const TextStyle(fontSize: 14.5, height: 1.4))),
              if (fl != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('სიტყვა აქვს: ${_who(fl).name}', style: TextStyle(color: c.muted))),
            ]),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: ids.length > 1 ? 2 : 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: ids.length > 1 ? .78 : 1.1,
            children: [for (final u in ids) _tile(u)],
          ),
          if (isHost) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('წამყვანის პანელი', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton(
                    key: const ValueKey('tp-next'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: () => _setSt({'toast': (ti + 1) % roomAgenda.length, 'custom': '', 'book': '', 'floor': null}),
                    child: const Text('შემდეგი თემა'),
                  ),
                  OutlinedButton(key: const ValueKey('tp-list'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: _agendaPick, child: const Text('დღის გეგმა')),
                  OutlinedButton(key: const ValueKey('tp-floor'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: _floorPick, child: const Text('სიტყვის მიცემა')),
                  OutlinedButton(key: const ValueKey('tp-book'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: _bookPick, child: const Text('სადღეგრძელოების წიგნი')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(key: const ValueKey('tp-custom'), controller: custom, maxLength: 120, decoration: const InputDecoration(hintText: 'საკუთარი თემა', counterText: '', isDense: true))),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('tp-show'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: () {
                      final v = custom.text.trim();
                      if (v.isEmpty) return;
                      custom.clear();
                      _setSt({'custom': v, 'book': '', 'toast': -1, 'floor': null});
                    },
                    child: const Text('ჩვენება'),
                  ),
                ]),
              ]),
            ),
          ],
        ]),
      ),
      _bar([
        _round('rb-mic', mic ? 'mic' : 'micoff', mic ? 'მიკროფონი' : 'ჩუმად', _micTap, on: mic),
        _round('rb-cam', 'video', cam ? 'კამერა' : 'გამორთულია', _cam, on: cam),
        if (local?.hasVideo ?? false)
          _round('rb-flip', 'flip', 'შებრუნება', () => local?.flip()),
        _round('rb-clink', 'heart', 'ტაში', () {
          link?.send('clink', {});
          _fx('👏 მე');
        }),
        _round('rb-leave', 'hangup', isHost ? 'დასრულება' : 'გასვლა', _back, bg: c.nope),
      ]),
    ]);
  }

  Widget _birja() {
    final c = context.pc, sp = speakers, all = [me, for (final k in present.keys) if (k != me) k];
    final talking = [for (final u in all) if (sp.contains(u)) u], listening = [for (final u in all) if (!sp.contains(u)) u];
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              PTag(roomTopic(r?['topic']), kind: 'ad'),
              const SizedBox(width: 8),
              Expanded(child: Text('${all.length} ოთახში', style: TextStyle(color: c.muted))),
            ]),
          ),
          const SecHead('ლაპარაკობენ'),
          Wrap(spacing: 8, runSpacing: 12, children: [for (final u in talking) _face(u, speaking: true)]),
          SecHead('უსმენენ · ${listening.length}'),
          if (listening.isEmpty) Text('ჯერ არავინ', style: TextStyle(color: c.muted)) else Wrap(spacing: 8, runSpacing: 12, children: [for (final u in listening) _face(u)]),
          if (isHost) ...[
            SecHead('ხელი აწიეს · ${hands.length}'),
            if (hands.isEmpty) Text('ჯერ არავის', style: TextStyle(color: c.muted)),
            for (final u in hands)
              ListTile(
                key: ValueKey('hand-$u'),
                contentPadding: EdgeInsets.zero,
                leading: Avatar(p: _who(u), size: 38),
                title: Text(_who(u).name),
                trailing: FilledButton(
                  key: ValueKey('rsp-$u'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                  onPressed: () => _setSt({'speakers': [...sp, u], 'hands': [for (final h in hands) if (h != u) h]}),
                  child: const Text('სიტყვა'),
                ),
              ),
            for (final u in talking)
              if (u != me)
                ListTile(
                  key: ValueKey('spk-$u'),
                  contentPadding: EdgeInsets.zero,
                  leading: Avatar(p: _who(u), size: 38),
                  title: Text(_who(u).name),
                  trailing: OutlinedButton(
                    key: ValueKey('runsp-$u'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                    onPressed: () => _setSt({'speakers': [for (final s in sp) if (s != u) s]}),
                    child: const Text('მსმენელად'),
                  ),
                ),
          ],
        ]),
      ),
      _bar([
        _round('rb-mic', mic ? 'mic' : 'micoff', mic ? 'მიკროფონი' : 'ჩუმად', _micTap, on: mic),
        if (!sp.contains(me)) _round('rb-hand', 'help', hand ? 'ხელი აწეულია' : 'ხელის აწევა', _hand, on: hand),
        _round('rb-leave', 'hangup', isHost ? 'დახურვა' : 'გასვლა', _back, bg: c.nope),
      ]),
    ]);
  }

  Widget _live() {
    final c = context.pc, viewers = present.keys.where((k) => k != host).length;
    final stream = isHost ? local?.stream : peers[host]?.stream;
    final waiting = isHost ? 'კამერა ირთვება…' : (joinedOnce && !present.containsKey(host) ? 'მასპინძელი ეთერში ჯერ არ არის…' : 'ეთერს ვუკავშირდები…');
    final who = _who(host);
    return Stack(fit: StackFit.expand, children: [
      Container(color: Colors.black),
      if (stream != null) rtcKit.view(stream, mirror: isHost, key: const ValueKey('live-video')) else Center(child: Text(waiting, key: const ValueKey('live-wait'), style: const TextStyle(color: Colors.white70))),
      Positioned(
        left: 12,
        right: 12,
        top: MediaQuery.paddingOf(context).top + 8,
        child: Row(children: [
          Avatar(p: who, size: 34),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(who.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              Text('${r?['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          const PTag('LIVE', kind: 'warn'),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const PIcon('eye', size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text('$viewers', key: const ValueKey('live-count'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
      Positioned(
        left: 12,
        right: 80,
        bottom: 84 + MediaQuery.paddingOf(context).bottom,
        height: 220,
        child: ListView(reverse: true, children: [
          for (final m in comments.reversed.take(12))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${m['n']}${m['host'] == true ? ' 🎙' : ''}  ', style: TextStyle(color: m['gift'] == true ? c.gold : const Color(0xFFFDE68A), fontWeight: FontWeight.w800)),
                  TextSpan(text: '${m['t']}', style: const TextStyle(color: Colors.white)),
                ]),
                style: const TextStyle(fontSize: 13.5, shadows: [Shadow(blurRadius: 4)]),
              ),
            ),
        ]),
      ),
      SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('lv-in'),
                  controller: say,
                  maxLength: 200,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sayLive(),
                  decoration: InputDecoration(
                    hintText: 'კომენტარი…',
                    hintStyle: const TextStyle(color: Colors.white60),
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0x55000000),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                  ),
                ),
              ),
              if (isHost) ...[
                IconBtn('flip', key: const ValueKey('lv-flip'), label: 'კამერის შებრუნება', color: Colors.white, onTap: () => local?.flip()),
                IconBtn(mic ? 'mic' : 'micoff', key: const ValueKey('lv-mic'), label: 'მიკროფონი', color: Colors.white, onTap: () => _mic(!mic)),
                IconBtn('hangup', key: const ValueKey('lv-end'), label: 'ეთერის დასრულება', color: c.nope, onTap: _back),
              ] else ...[
                IconBtn('heart', key: const ValueKey('lv-heart'), label: 'გული', color: const Color(0xFFFB7185), onTap: _heart),
                IconBtn('gift', key: const ValueKey('lv-gift'), label: 'საჩუქარი', color: c.gold, onTap: _gift),
                IconBtn('x', key: const ValueKey('lv-leave'), label: 'გასვლა', color: Colors.white, onTap: _back),
              ],
            ]),
          ),
        ),
      ),
    ]);
  }

  void _sayLive() {
    final v = say.text.trim();
    if (v.isEmpty) return;
    say.clear();
    final p = context.me;
    final m = {'t': v, 'n': p.name.split(' ').first, 'h': p.hue, 'host': isHost};
    link?.send('cmt', m);
    _comment(m);
  }

  void _heart() {
    _fx('❤️');
    final now = DateTime.now();
    if (now.difference(_lastHeart).inMilliseconds < 350) return;
    _lastHeart = now;
    link?.send('heart', {});
  }

  Future<void> _gift() async {
    final c = context.pc;
    final e = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (s) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: Text('საჩუქარი ${_who(host).name.split(' ').first}-ს · შენ გაქვს ${context.me.coins} მონეტა', style: const TextStyle(fontWeight: FontWeight.w800))),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (em, name, price, _) in giftList.where((g) => g.$3 <= 1000))
                InkWell(
                  key: ValueKey('lg-$em'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(s).pop(em),
                  child: Container(
                    width: 76,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(border: Border.all(color: s.pc.line), borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      Text(em, style: const TextStyle(fontSize: 26)),
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                      Text('$price', style: TextStyle(color: s.pc.muted, fontSize: 11)),
                    ]),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
    if (e == null || !mounted) return;
    try {
      final bal = await api.liveGift(widget.id, e);
      if (!mounted) return;
      link?.send('gift', {'e': e, 'n': context.me.name.split(' ').first});
      _fx(e);
      toast(context, 'გაიგზავნა $e · დაგრჩა $bal მონეტა');
    } catch (x) {
      if (mounted) toast(context, '$x'.contains('not_enough') ? 'მონეტები არ გყოფნის' : errText(x));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = r;
    final body = !loaded
        ? const Center(child: CircularProgressIndicator())
        : gone != null
            ? Empty(icon: roomIcon(x?['kind']), title: gone!, text: 'სხვა ოთახებს სიაში ნახავ.', action: 'უკან', onAction: () => Navigator.of(context).pop())
            : live
                ? _live()
                : supra
                    ? _supra()
                    : _birja();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) {
        if (!did) _back();
      },
      child: Scaffold(
        backgroundColor: live && gone == null && loaded ? Colors.black : null,
        appBar: live && gone == null && loaded
            ? null
            : peeraBar(context, title: '${x?['title'] ?? roomKindName(x?['kind'])}', actions: [
                if (gone == null && x != null) ...[
                  IconBtn('users', key: const ValueKey('room-invite'), label: 'მოწვევა', onTap: _invite),
                  IconBtn('share', key: const ValueKey('room-share'), label: 'გაზიარება', onTap: () => shareText(context, '${x['title']}\n$siteUrl/#room-${x['id']}')),
                ],
              ]),
        body: Stack(children: [
          Positioned.fill(child: body),
          // claps, hearts and gifts float up
          for (var i = 0; i < fx.length; i++)
            Positioned(
              key: ValueKey('fx-${fx[i].$1}'),
              right: 24 + (fx[i].$1 % 4) * 14.0,
              bottom: 140 + (i % 5) * 36.0,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1600),
                builder: (_, v, ch) => Opacity(opacity: (1 - v).clamp(0, 1), child: Transform.translate(offset: Offset(0, -80 * v), child: ch)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: fx[i].$2.length > 3 ? c.surface : Colors.transparent, borderRadius: BorderRadius.circular(999)),
                  child: Text(fx[i].$2, style: const TextStyle(fontSize: 22)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
