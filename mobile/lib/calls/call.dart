// Voice and video calls with one person, the same as the site's (chat.js): the offer, the answer and the ICE go over
// the realtime channel 'call-<who>'; busy, declined, no answer in 35 seconds, ended. The call is on screen while it
// lasts; back asks before it ends.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api.dart';
import '../data/stores.dart';
import '../profile/profile.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'rtc.dart';

/// One call at a time: whom, voice or video, and where it stands.
class CallCenter extends ChangeNotifier {
  CallCenter(this.api);
  final PeeraApi api;

  /// 'idle', 'calling', 'incoming', 'connecting', 'live'
  String state = 'idle';
  String? peer;
  bool video = false, mic = true, cam = true, speaker = false;
  String status = '';
  RtcMedia? local;
  RtcPeer? pc;
  Object? remote;
  DateTime? since;
  Map<String, dynamic>? _offer;
  final _pendingIce = <Map<String, dynamic>>[];
  Timer? _t, _ring;
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _closed = false;

  /// the people whose calls do not ring (the ones I blocked)
  Set<String> _blocked = {};

  void listen() {
    if (_sub != null) return;
    _sub = api.callSignals().listen(_onSig, onError: (_) {});
    api.blocked().then((b) => _blocked = b.toSet()).catchError((_) => <String>{});
  }

  void close() {
    _closed = true;
    _sub?.cancel();
    _end();
  }

  void _set(String s, [String? text]) {
    state = s;
    if (text != null) status = text;
    if (!_closed) notifyListeners();
  }

  void _send(Map<String, dynamic> p) {
    final to = peer;
    if (to != null) api.callSignal(to, p).catchError((_) {});
  }

  Future<RtcPeer> _newPc() async {
    final p = await rtcKit.peer();
    p.onIce = (c) => _send({'t': 'ice', 'c': c});
    p.onStream = (s) {
      remote = s;
      if (!_closed) notifyListeners();
    };
    p.onState = (s) {
      if (pc != p) return;
      if (s == 'connected') {
        _t?.cancel();
        since ??= DateTime.now();
        _set('live', 'დაკავშირებულია');
      } else if (s == 'failed') {
        status = 'კავშირი ვერ დამყარდა. შეიძლება ქსელი ბლოკავს ზარს';
        _end();
      } else if (s == 'disconnected') {
        Timer(const Duration(seconds: 4), () {
          if (pc == p && state != 'live') _end();
        });
      }
    };
    return p;
  }

  /// a call to someone: null when it rings, or why it could not start
  Future<String?> start(String to, {required bool video}) async {
    if (state != 'idle') return 'ზარი უკვე მიმდინარეობს';
    try {
      local = await rtcKit.media(audio: true, video: video);
    } catch (_) {
      return 'მიკროფონზე ან კამერაზე წვდომა არ არის';
    }
    peer = to;
    this.video = video;
    mic = cam = true;
    speaker = video;
    remote = null;
    since = null;
    _set('calling', 'ირეკება…');
    unawaited(rtcKit.speaker(speaker));
    final p = pc = await _newPc();
    await p.addTracks(local!);
    final o = await p.offer();
    _send({'t': 'offer', 'sdp': o['sdp'], 'video': video, 'name': ''});
    _t = Timer(const Duration(seconds: 35), () {
      if (state == 'calling') {
        status = 'ვერ პასუხობს';
        _send({'t': 'end'});
        notifyListeners();
        Timer(const Duration(milliseconds: 1800), _end);
      }
    });
    return null;
  }

  Future<void> _onSig(Map<String, dynamic> p) async {
    final from = '${p['from'] ?? ''}';
    if (from.isEmpty || _blocked.contains(from)) return;
    final t = p['t'];
    if (t == 'offer') {
      if (state != 'idle') {
        await api.callSignal(from, {'t': 'busy'}).catchError((_) {});
        return;
      }
      peer = from;
      video = p['video'] == true;
      _offer = {'type': 'offer', 'sdp': p['sdp']};
      _pendingIce.clear();
      remote = null;
      since = null;
      _set('incoming', video ? 'ვიდეოზარი…' : 'ზარი…');
      _ringOn(true);
      _t = Timer(const Duration(seconds: 40), () {
        if (state == 'incoming') _end();
      });
      return;
    }
    if (from != peer) return;
    if (t == 'answer' && pc != null) {
      await pc!.setRemote({'type': 'answer', 'sdp': p['sdp']});
      for (final c in _pendingIce) {
        await pc!.addIce(c);
      }
      _pendingIce.clear();
      _set(state == 'calling' ? 'connecting' : state, 'უკავშირდება…');
    } else if (t == 'ice' && p['c'] is Map) {
      final c = Map<String, dynamic>.from(p['c'] as Map);
      if (pc != null && pc!.hasRemote) {
        await pc!.addIce(c);
      } else {
        _pendingIce.add(c);
      }
    } else if (t == 'busy') {
      _set(state, 'ახლა სხვა ზარზეა');
      Timer(const Duration(milliseconds: 1800), _end);
    } else if (t == 'decline') {
      _set(state, 'ზარი უარყო');
      Timer(const Duration(milliseconds: 1500), _end);
    } else if (t == 'end') {
      _end();
    }
  }

  /// the incoming call answered
  Future<String?> accept() async {
    if (state != 'incoming') return null;
    _ringOn(false);
    _t?.cancel();
    try {
      local = await rtcKit.media(audio: true, video: video);
    } catch (_) {
      _send({'t': 'decline'});
      _end();
      return 'მიკროფონზე წვდომა არ არის';
    }
    mic = cam = true;
    speaker = video;
    unawaited(rtcKit.speaker(speaker));
    _set('connecting', 'უკავშირდება…');
    final p = pc = await _newPc();
    await p.addTracks(local!);
    await p.setRemote(_offer!);
    for (final c in _pendingIce) {
      await p.addIce(c);
    }
    _pendingIce.clear();
    final a = await p.answer();
    _send({'t': 'answer', 'sdp': a['sdp']});
    return null;
  }

  void decline() {
    _send({'t': 'decline'});
    _end();
  }

  void hangUp() {
    _send({'t': 'end'});
    _end();
  }

  void toggleMic() {
    mic = !mic;
    local?.setAudio(mic);
    notifyListeners();
  }

  void toggleCam() {
    cam = !cam;
    local?.setVideo(cam);
    notifyListeners();
  }

  Future<void> flip() async {
    await local?.flip();
  }

  void toggleSpeaker() {
    speaker = !speaker;
    rtcKit.speaker(speaker);
    notifyListeners();
  }

  void _ringOn(bool on) {
    _ring?.cancel();
    _ring = null;
    if (!on) return;
    void beep() {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.vibrate();
    }

    beep();
    _ring = Timer.periodic(const Duration(milliseconds: 1600), (_) => beep());
  }

  void _end() {
    _ringOn(false);
    _t?.cancel();
    final p = pc, m = local;
    pc = null;
    local = null;
    remote = null;
    _offer = null;
    _pendingIce.clear();
    p?.close();
    m?.stop();
    if (state != 'idle') {
      state = 'idle';
      peer = null;
      since = null;
      if (!_closed) notifyListeners();
    }
  }
}

/// The call on screen: who, how it stands, the other's picture and mine; answer or decline, microphone, camera,
/// loudspeaker, end. It goes when the call ends.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final CallCenter call = context.app.calls;
  Timer? _tick;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && call.state == 'live') setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    call.removeListener(_changed);
    call.addListener(_changed);
  }

  @override
  void dispose() {
    _tick?.cancel();
    call.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (call.state == 'idle' && !_gone) {
      _gone = true;
      // what happened stays a moment
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
    setState(() {});
  }

  Future<void> _back() async {
    if (call.state == 'idle') {
      Navigator.of(context).pop();
      return;
    }
    if (call.state == 'incoming') {
      if (await confirm(context, title: 'ზარის უარყოფა', text: 'ზარი არ მიიღება.', yes: 'უარყოფა', danger: true)) call.decline();
      return;
    }
    if (await confirm(context, title: 'ზარის დასრულება', text: 'ზარი დასრულდება.', yes: 'დასრულება', danger: true)) call.hangUp();
  }

  String _clock() {
    final s = call.since;
    if (s == null) return call.status;
    final d = DateTime.now().difference(s);
    return '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, uid = call.peer;
    final who = uid == null ? null : app.people[uid] ?? Profile(id: uid, name: '…');
    final vid = call.video, incoming = call.state == 'incoming';
    Widget round(String key, String icon, String label, VoidCallback onTap, {Color? bg, Color fg = Colors.white, bool on = true}) => Column(mainAxisSize: MainAxisSize.min, children: [
          Material(
            color: bg ?? (on ? const Color(0x33FFFFFF) : Colors.white),
            shape: const CircleBorder(),
            child: InkWell(
              key: ValueKey(key),
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 62, height: 62, child: Center(child: PIcon(icon, size: 26, color: bg != null ? Colors.white : (on ? fg : const Color(0xFF111827))))),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ]);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) {
        if (!did) _back();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Stack(children: [
          if (vid && call.remote != null) Positioned.fill(child: rtcKit.view(call.remote, key: const ValueKey('call-remote'))),
          if (vid && call.local != null && call.cam)
            Positioned(
              right: 16,
              top: MediaQuery.paddingOf(context).top + 16,
              width: 110,
              height: 160,
              child: ClipRRect(borderRadius: BorderRadius.circular(14), child: rtcKit.view(call.local!.stream, mirror: true, key: const ValueKey('call-local'))),
            ),
          SafeArea(
            child: Column(children: [
              const SizedBox(height: 36),
              Text(vid ? 'ვიდეოზარი' : 'ხმოვანი ზარი', style: const TextStyle(color: Color(0xCCFFFFFF), fontWeight: FontWeight.w700)),
              if (!(vid && call.remote != null)) ...[
                const SizedBox(height: 28),
                if (who != null) Avatar(p: who, size: 120),
              ],
              const SizedBox(height: 16),
              Text(who?.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(_clock(), key: const ValueKey('call-status'), style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 15)),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: incoming
                    ? Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                        round('call-decline', 'hangup', 'უარყოფა', call.decline, bg: c.nope),
                        round('call-accept', 'phone', 'პასუხი', () async {
                          final e = await call.accept();
                          if (e != null && context.mounted) toast(context, e);
                        }, bg: c.vine),
                      ])
                    : Wrap(alignment: WrapAlignment.center, spacing: 18, runSpacing: 14, children: [
                        round('call-mic', call.mic ? 'mic' : 'micoff', call.mic ? 'მიკროფონი' : 'გამორთულია', call.toggleMic, on: call.mic),
                        if (vid) round('call-cam', 'video', call.cam ? 'კამერა' : 'გამორთულია', call.toggleCam, on: call.cam),
                        if (vid) round('call-flip', 'flip', 'შებრუნება', call.flip),
                        if (!vid) round('call-speaker', 'speaker', call.speaker ? 'დინამიკი' : 'ყურმილი', call.toggleSpeaker, on: !call.speaker),
                        round('call-end', 'hangup', 'დასრულება', call.hangUp, bg: c.nope),
                      ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A call to someone, from a conversation or a profile.
Future<void> callPerson(BuildContext context, String uid, {required bool video}) async {
  final app = context.app;
  await app.people.ensure([uid]);
  final e = await app.calls.start(uid, video: video);
  if (!context.mounted) return;
  if (e != null) {
    toast(context, e);
    return;
  }
  await showCallScreen(context);
}

bool _callOnScreen = false;

/// the call's screen, once
Future<void> showCallScreen(BuildContext context) async {
  if (_callOnScreen) return;
  _callOnScreen = true;
  try {
    final app = context.app, me = context.me;
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => AppScope(app: app, me: me, child: const CallScreen())));
  } finally {
    _callOnScreen = false;
  }
}
