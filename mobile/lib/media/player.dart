import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../ui/icons.dart';
import '../ui/net_image.dart';

/// One video from a link, played on screen. The tests use a quiet stand-in.
abstract class Player extends ChangeNotifier {
  bool get ready;
  bool get playing;
  bool get buffering;
  bool get failed;

  /// has shown a frame (until then the poster stays)
  bool get started;
  bool get ended;
  Duration get position;
  Duration get duration;
  Size get size;

  /// starts loading, without playing (the next clip, so a swipe lands on a ready one)
  Future<void> prepare();
  Future<void> play();
  Future<void> pause();

  /// paused and back at the start
  Future<void> rewind();
  Future<void> mute(bool on);
  Widget view();
}

/// Where players come from (the tests put in their own).
Player Function(String url, {bool loop}) makePlayer = (u, {bool loop = true}) => NetPlayer(u, loop: loop);

class NetPlayer extends Player {
  /// a link, or a file on the phone (a path starting with "/": the video about to be uploaded)
  NetPlayer(String url, {this.loop = true})
      : c = url.startsWith('/')
            ? VideoPlayerController.file(File(url), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true))
            : VideoPlayerController.networkUrl(Uri.parse(url), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
  final VideoPlayerController c;
  final bool loop;
  Future<void>? _init;
  bool _gone = false, _muted = true, _wantPlay = false;

  Future<void> _ensure() => _init ??= () async {
        c.addListener(_changed);
        try {
          await c.initialize();
          await c.setLooping(loop);
          await c.setVolume(_muted ? 0 : 1);
        } catch (_) {}
        if (!_gone) notifyListeners();
      }();

  void _changed() {
    if (!_gone) notifyListeners();
  }

  VideoPlayerValue get _v => c.value;
  @override
  bool get ready => _v.isInitialized;
  @override
  bool get playing => _v.isPlaying;
  @override
  bool get buffering => _v.isBuffering;
  @override
  bool get failed => _v.hasError;
  @override
  bool get started => _v.isInitialized && (_v.position > Duration.zero || _v.isPlaying);
  @override
  bool get ended => _v.isCompleted;
  @override
  Duration get position => _v.position;
  @override
  Duration get duration => _v.duration;
  @override
  Size get size => _v.size;

  @override
  Future<void> prepare() => _ensure();

  @override
  Future<void> play() async {
    _wantPlay = true;
    await _ensure();
    if (!_gone && _wantPlay && ready) await c.play();
  }

  @override
  Future<void> pause() async {
    _wantPlay = false;
    if (ready) await c.pause();
  }

  @override
  Future<void> rewind() async {
    _wantPlay = false;
    if (!ready) return;
    await c.pause();
    await c.seekTo(Duration.zero);
  }

  @override
  Future<void> mute(bool on) async {
    _muted = on;
    if (ready) await c.setVolume(on ? 0 : 1);
  }

  @override
  Widget view() => VideoPlayer(c);

  @override
  void dispose() {
    _gone = true;
    c.removeListener(_changed);
    c.dispose();
    super.dispose();
  }
}

/// A video in its frame: the poster until the first picture, a spinner while it waits, a line when it cannot play.
class VideoBox extends StatelessWidget {
  const VideoBox({super.key, required this.player, this.poster, this.fit = BoxFit.contain, this.waiting = true});
  final Player player;
  final String? poster;
  final BoxFit fit;

  /// show the spinner while it loads (only for the one meant to play)
  final bool waiting;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          final sz = player.size;
          return Stack(fit: StackFit.expand, children: [
            const ColoredBox(color: Colors.black),
            if (poster != null) PImage(poster!, fit: fit, background: Colors.black),
            if (player.ready && sz.width > 0 && sz.height > 0)
              ClipRect(child: FittedBox(fit: fit, child: SizedBox(width: sz.width, height: sz.height, child: player.view()))),
            if (player.failed)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    PIcon('clips', size: 40, color: Colors.white70),
                    SizedBox(height: 10),
                    Text('ეს ვიდეო ვერ ჩაირთო', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  ]),
                ),
              )
            else if (waiting && (!player.ready || (player.buffering && player.playing)))
              const Center(child: SizedBox.square(dimension: 34, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))),
          ]);
        },
      );
}
