// WebRTC for the calls and the rooms, the way the site does it (chat.js newPC, rooms.js newRoomPeer): the camera and the
// microphone, a peer connection with Google's STUN servers, offers and answers, the remote picture. The tests put a
// pretend one in [rtcKit].
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as w;

const iceServers = [
  {
    'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'],
  },
];

/// What the calls and the rooms need.
abstract class Rtc {
  /// the camera and/or the microphone ([facing] 'user' or 'environment')
  Future<RtcMedia> media({bool audio = true, bool video = false, String facing = 'user', int width = 720, int? height});
  Future<RtcPeer> peer();

  /// a picture of a stream (mine mirrored), filling its box
  Widget view(Object? stream, {bool mirror = false, Key? key});

  /// a call's sound through the loudspeaker (video) or the earpiece
  Future<void> speaker(bool on);
}

abstract class RtcMedia {
  Object get stream;
  bool get hasAudio;
  bool get hasVideo;
  void setAudio(bool on);
  void setVideo(bool on);

  /// the microphone added later (a discussion: when the host gives the word)
  Future<void> addAudio();

  /// the other camera; false when there is none
  Future<bool> flip();
  Future<void> stop();
}

abstract class RtcPeer {
  void Function(Map<String, dynamic> ice)? onIce;

  /// 'connected', 'disconnected', 'failed', 'closed'
  void Function(String state)? onState;

  /// the other side's picture and sound (again as more tracks come)
  void Function(Object stream)? onStream;

  /// a call: my tracks as they are
  Future<void> addTracks(RtcMedia m);

  /// a room, as the one who offers: sound (mine only when [sendAudio]) and, in a study room, the picture
  Future<void> sendRecv(RtcMedia? m, {required bool sendAudio, required bool video});

  /// a room, after the other side's offer: the same, on the transceivers the offer made
  Future<void> answerWith(RtcMedia? m, {required bool sendAudio});

  /// a live broadcast: the host sends only, a viewer receives only
  Future<void> sendOnly(RtcMedia m);
  Future<void> recvOnly();

  /// my microphone into the room (or silence)
  Future<void> setAudioOut(RtcMedia? m, bool on);

  Future<Map<String, dynamic>> offer();
  Future<Map<String, dynamic>> answer();
  Future<void> setRemote(Map<String, dynamic> desc);
  Future<void> addIce(Map<String, dynamic> c);
  bool get hasRemote;
  bool get stable;
  Future<void> close();
}

/// the WebRTC in use (the tests put a pretend one)
Rtc rtcKit = WebRtc();

class WebRtc implements Rtc {
  @override
  Future<RtcMedia> media({bool audio = true, bool video = false, String facing = 'user', int width = 720, int? height}) async {
    final s = await w.navigator.mediaDevices.getUserMedia({
      'audio': audio ? {'echoCancellation': true, 'noiseSuppression': true} : false,
      'video': video
          ? {
              'facingMode': facing,
              'width': {'ideal': width},
              if (height != null) 'height': {'ideal': height},
            }
          : false,
    });
    return _Media(s, facing);
  }

  @override
  Future<RtcPeer> peer() async => _Peer(await w.createPeerConnection({'iceServers': iceServers, 'sdpSemantics': 'unified-plan'}));

  @override
  Widget view(Object? stream, {bool mirror = false, Key? key}) => _View(key: key, stream: stream is w.MediaStream ? stream : null, mirror: mirror);

  @override
  Future<void> speaker(bool on) async {
    try {
      await w.Helper.setSpeakerphoneOn(on);
    } catch (_) {}
  }
}

class _Media implements RtcMedia {
  _Media(this.s, this.facing);
  final w.MediaStream s;
  String facing;

  @override
  Object get stream => s;
  @override
  bool get hasAudio => s.getAudioTracks().isNotEmpty;
  @override
  bool get hasVideo => s.getVideoTracks().isNotEmpty;
  w.MediaStreamTrack? get audio => s.getAudioTracks().firstOrNull;
  w.MediaStreamTrack? get video => s.getVideoTracks().firstOrNull;

  @override
  void setAudio(bool on) {
    for (final t in s.getAudioTracks()) {
      t.enabled = on;
    }
  }

  @override
  void setVideo(bool on) {
    for (final t in s.getVideoTracks()) {
      t.enabled = on;
    }
  }

  @override
  Future<void> addAudio() async {
    if (hasAudio) return;
    final a = await w.navigator.mediaDevices.getUserMedia({
      'audio': {'echoCancellation': true, 'noiseSuppression': true},
      'video': false,
    });
    for (final t in a.getAudioTracks()) {
      await s.addTrack(t);
    }
  }

  @override
  Future<bool> flip() async {
    final v = video;
    if (v == null) return false;
    try {
      await w.Helper.switchCamera(v);
      facing = facing == 'user' ? 'environment' : 'user';
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    for (final t in s.getTracks()) {
      try {
        await t.stop();
      } catch (_) {}
    }
    try {
      await s.dispose();
    } catch (_) {}
  }
}

w.MediaStreamTrack? _audioOf(RtcMedia? m) => m is _Media ? m.audio : null;
w.MediaStreamTrack? _videoOf(RtcMedia? m) => m is _Media ? m.video : null;

class _Peer implements RtcPeer {
  _Peer(this.pc) {
    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      onIce?.call({'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex});
    };
    pc.onConnectionState = (s) {
      final v = switch (s) {
        w.RTCPeerConnectionState.RTCPeerConnectionStateConnected => 'connected',
        w.RTCPeerConnectionState.RTCPeerConnectionStateDisconnected => 'disconnected',
        w.RTCPeerConnectionState.RTCPeerConnectionStateFailed => 'failed',
        w.RTCPeerConnectionState.RTCPeerConnectionStateClosed => 'closed',
        _ => 'new',
      };
      onState?.call(v);
    };
    pc.onTrack = (e) async {
      // a call's tracks come with their stream; a room's transceivers bring tracks alone (the site adds them to one stream)
      if (e.streams.isNotEmpty) {
        _remote = e.streams.first;
      } else {
        final r = _remote ??= await w.createLocalMediaStream('peer-${identityHashCode(this)}');
        try {
          await r.addTrack(e.track);
        } catch (_) {}
      }
      final r = _remote;
      if (r != null) onStream?.call(r);
    };
  }

  final w.RTCPeerConnection pc;
  w.MediaStream? _remote;
  w.RTCRtpSender? _audioSender;
  bool _hasRemote = false;

  @override
  void Function(Map<String, dynamic> ice)? onIce;
  @override
  void Function(String state)? onState;
  @override
  void Function(Object stream)? onStream;

  @override
  bool get hasRemote => _hasRemote;
  @override
  bool get stable => pc.signalingState == null || pc.signalingState == w.RTCSignalingState.RTCSignalingStateStable;

  @override
  Future<void> addTracks(RtcMedia m) async {
    if (m is! _Media) return;
    for (final t in m.s.getTracks()) {
      await pc.addTrack(t, m.s);
    }
  }

  @override
  Future<void> sendRecv(RtcMedia? m, {required bool sendAudio, required bool video}) async {
    final ta = await pc.addTransceiver(kind: w.RTCRtpMediaType.RTCRtpMediaTypeAudio, init: w.RTCRtpTransceiverInit(direction: w.TransceiverDirection.SendRecv));
    _audioSender = ta.sender;
    await ta.sender.replaceTrack(sendAudio ? _audioOf(m) : null);
    if (video) {
      final tv = await pc.addTransceiver(kind: w.RTCRtpMediaType.RTCRtpMediaTypeVideo, init: w.RTCRtpTransceiverInit(direction: w.TransceiverDirection.SendRecv));
      await tv.sender.replaceTrack(_videoOf(m));
    }
  }

  @override
  Future<void> answerWith(RtcMedia? m, {required bool sendAudio}) async {
    for (final t in await pc.getTransceivers()) {
      final kind = t.receiver.track?.kind;
      await t.setDirection(w.TransceiverDirection.SendRecv);
      if (kind == 'audio') {
        _audioSender = t.sender;
        await t.sender.replaceTrack(sendAudio ? _audioOf(m) : null);
      } else {
        await t.sender.replaceTrack(_videoOf(m));
      }
    }
  }

  @override
  Future<void> sendOnly(RtcMedia m) async {
    final ta = await pc.addTransceiver(kind: w.RTCRtpMediaType.RTCRtpMediaTypeAudio, init: w.RTCRtpTransceiverInit(direction: w.TransceiverDirection.SendOnly));
    _audioSender = ta.sender;
    await ta.sender.replaceTrack(_audioOf(m));
    final tv = await pc.addTransceiver(kind: w.RTCRtpMediaType.RTCRtpMediaTypeVideo, init: w.RTCRtpTransceiverInit(direction: w.TransceiverDirection.SendOnly));
    await tv.sender.replaceTrack(_videoOf(m));
  }

  @override
  Future<void> recvOnly() async {
    for (final t in await pc.getTransceivers()) {
      await t.setDirection(w.TransceiverDirection.RecvOnly);
    }
  }

  @override
  Future<void> setAudioOut(RtcMedia? m, bool on) async {
    try {
      await _audioSender?.replaceTrack(on ? _audioOf(m) : null);
    } catch (_) {}
  }

  @override
  Future<Map<String, dynamic>> offer() async {
    final o = await pc.createOffer({});
    await pc.setLocalDescription(o);
    return {'type': o.type, 'sdp': o.sdp};
  }

  @override
  Future<Map<String, dynamic>> answer() async {
    final a = await pc.createAnswer({});
    await pc.setLocalDescription(a);
    return {'type': a.type, 'sdp': a.sdp};
  }

  @override
  Future<void> setRemote(Map<String, dynamic> desc) async {
    await pc.setRemoteDescription(w.RTCSessionDescription('${desc['sdp']}', '${desc['type']}'));
    _hasRemote = true;
  }

  @override
  Future<void> addIce(Map<String, dynamic> c) async {
    try {
      await pc.addCandidate(w.RTCIceCandidate('${c['candidate']}', c['sdpMid'] as String?, (c['sdpMLineIndex'] as num?)?.toInt()));
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    try {
      await pc.close();
    } catch (_) {}
    try {
      await _remote?.dispose();
    } catch (_) {}
  }
}

/// A stream's picture.
class _View extends StatefulWidget {
  const _View({super.key, required this.stream, required this.mirror});
  final w.MediaStream? stream;
  final bool mirror;
  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final r = w.RTCVideoRenderer();
  bool ready = false;

  @override
  void initState() {
    super.initState();
    r.initialize().then((_) {
      if (!mounted) return;
      r.srcObject = widget.stream;
      setState(() => ready = true);
    });
  }

  @override
  void didUpdateWidget(_View old) {
    super.didUpdateWidget(old);
    if (ready && old.stream != widget.stream) r.srcObject = widget.stream;
  }

  @override
  void dispose() {
    r.srcObject = null;
    r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ready
      ? w.RTCVideoView(r, mirror: widget.mirror, objectFit: w.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
      : const ColoredBox(color: Color(0xFF111827));
}
