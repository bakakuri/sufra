// Voice messages: the phone's microphone (android/.../VoiceRec.kt) and the little player in the chat bubble.
// They are kind 'voice' with media {url, dur} as on the site, so a message recorded here plays there and back.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/icons.dart';
import '../ui/theme.dart';
import 'player.dart';

typedef Recorded = ({String path, int ms});

abstract class VoiceDevice {
  /// 'granted', 'denied' (refused now) or 'blocked' (only the phone's settings can allow it)
  Future<String> permission();
  Future<bool> start();

  /// how loud it is now, 0..1
  Future<double> level();

  /// the file and how long it is; null when nothing was recorded
  Future<Recorded?> stop();
  Future<void> cancel();

  /// the phone's settings for this app
  Future<void> settings();
}

class AndroidVoice implements VoiceDevice {
  static const _ch = MethodChannel('peera/voice');

  @override
  Future<String> permission() async {
    try {
      return await _ch.invokeMethod<String>('permission') ?? 'denied';
    } catch (_) {
      return 'denied';
    }
  }

  @override
  Future<bool> start() async {
    try {
      return await _ch.invokeMethod<bool>('start') == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<double> level() async {
    try {
      return ((await _ch.invokeMethod<num>('level')) ?? 0).toDouble().clamp(0, 1).toDouble();
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<Recorded?> stop() async {
    try {
      final r = await _ch.invokeMethod<Map>('stop');
      if (r == null) return null;
      return (path: '${r['path']}', ms: (r['ms'] as num).toInt());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _ch.invokeMethod('cancel');
    } catch (_) {}
  }

  @override
  Future<void> settings() async {
    try {
      await _ch.invokeMethod('settings');
    } catch (_) {}
  }
}

/// the tests put a pretend microphone here
VoiceDevice voiceDevice = AndroidVoice();

String clockOf(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// the one voice message playing now: starting another stops it
final _playingNow = ValueNotifier<Player?>(null);

/// A voice message in a bubble: play or pause, a row of bars filling as it plays, the time.
class VoiceNote extends StatefulWidget {
  const VoiceNote({super.key, required this.url, required this.seconds, required this.mine});
  final String url;
  final int seconds;
  final bool mine;
  @override
  State<VoiceNote> createState() => _VoiceNoteState();
}

class _VoiceNoteState extends State<VoiceNote> {
  Player? p;
  bool starting = false, _rewinding = false;

  @override
  void dispose() {
    final x = p;
    if (x != null) {
      if (_playingNow.value == x) _playingNow.value = null;
      x.removeListener(_changed);
      x.dispose();
    }
    super.dispose();
  }

  void _changed() {
    final x = p;
    if (x == null || !mounted) return;
    // at the end: back to the start, ready to play again
    if (x.ended && !_rewinding) {
      _rewinding = true;
      x.rewind().whenComplete(() => _rewinding = false);
    }
    setState(() {});
  }

  Future<void> _toggle() async {
    var x = p;
    if (x == null) {
      x = p = makePlayer(widget.url, loop: false)..addListener(_changed);
      await x.mute(false);
    }
    if (x.playing) {
      await x.pause();
      return;
    }
    final other = _playingNow.value;
    if (other != null && other != x) await other.pause();
    _playingNow.value = x;
    if (x.ended) await x.rewind();
    setState(() => starting = true);
    try {
      await x.play();
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = p;
    final fg = widget.mine ? c.onAccent : c.ink, soft = widget.mine ? c.onAccent.withValues(alpha: .4) : c.muted.withValues(alpha: .35);
    final total = x != null && x.duration > Duration.zero ? x.duration : Duration(seconds: widget.seconds);
    final pos = x?.position ?? Duration.zero, on = x != null && (x.playing || pos > Duration.zero);
    final part = on && total > Duration.zero ? (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0).toDouble() : 0.0;
    final loading = starting && x != null && !x.playing;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Semantics(
        button: true,
        label: x?.playing == true ? 'პაუზა' : 'მოსმენა',
        child: GestureDetector(
          key: const ValueKey('voice-play'),
          onTap: _toggle,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: widget.mine ? c.onAccent : c.accent, shape: BoxShape.circle),
            child: loading
                ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: widget.mine ? c.accent : c.onAccent))
                : Padding(
                    padding: EdgeInsets.only(left: x?.playing == true ? 0 : 2),
                    child: PIcon(x?.playing == true ? 'pause' : 'play', size: 18, color: widget.mine ? c.accent : c.onAccent),
                  ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 132, height: 24, child: CustomPaint(painter: _Bars(seed: widget.url.hashCode, part: part, on: fg, off: soft))),
        const SizedBox(height: 2),
        Text(clockOf(on ? pos : total), style: TextStyle(fontSize: 12, color: fg.withValues(alpha: .85), fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    ]);
  }
}

/// bars of a made-up but steady wave (the same message always looks the same), filled up to [part]
class _Bars extends CustomPainter {
  _Bars({required this.seed, required this.part, required this.on, required this.off});
  final int seed;
  final double part;
  final Color on, off;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 26;
    final w = size.width / n;
    var r = seed & 0x7fffffff;
    for (var i = 0; i < n; i++) {
      r = (r * 1103515245 + 12345) & 0x7fffffff;
      final h = size.height * (.25 + .75 * ((r >> 8) % 1000) / 1000 * (0.55 + .45 * (1 - ((i - n / 2).abs() / (n / 2)))));
      final x = i * w + w * .2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, (size.height - h) / 2, w * .6, h), const Radius.circular(2)),
        Paint()..color = (i + .5) / n <= part ? on : off,
      );
    }
  }

  @override
  bool shouldRepaint(_Bars old) => old.part != part || old.on != on || old.off != off || old.seed != seed;
}
