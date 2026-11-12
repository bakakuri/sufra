import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// A video made ready to upload: the file (a lighter copy when the original was big), a picture for its poster,
/// its size on screen and its length.
class VideoReady {
  const VideoReady({required this.path, this.poster, this.w = 0, this.h = 0, this.dur = 0, this.bytes = 0});
  final String path;
  final String? poster;
  final int w, h, bytes;
  final double dur;
}

/// The server keeps files up to 50 MB.
const maxUploadBytes = 50 * 1024 * 1024;

class VideoTooBig implements Exception {
  const VideoTooBig();
  @override
  String toString() => 'ვიდეო ძალიან დიდია — მაქსიმუმ 50 მბ. სცადე უფრო მოკლე.';
}

const _ch = MethodChannel('peera/video');

/// Choosing a video from the phone (the tests put in their own).
Future<String?> Function() videoPicker = () async {
  final f = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
  return f?.path;
};

/// Making it ready (the tests skip the phone's encoder).
Future<VideoReady> Function(String path, void Function(double) onProgress) videoPrep = prepareVideo;

Future<Map<String, dynamic>> _info(String path) async => Map<String, dynamic>.from(await _ch.invokeMethod<Map<Object?, Object?>>('info', {'path': path}) ?? const {});

/// Big or very sharp videos are made 720p (H.264, about 2.5 Mbit/s) by the phone's own encoder, as the site does
/// in the browser; small ones go as they are. A frame from the start becomes the poster.
Future<VideoReady> prepareVideo(String path, void Function(double) onProgress) async {
  var info = await _info(path);
  int field(String k) => (info[k] as num?)?.toInt() ?? 0;
  var out = path;
  final short = min(field('w'), field('h'));
  if (field('size') > 15 * 1024 * 1024 || short > 1080) {
    _ch.setMethodCallHandler((c) async {
      if (c.method == 'progress') onProgress((c.arguments as num).toDouble());
    });
    try {
      out = await _ch.invokeMethod<String>('compress', {'path': path, 'shortSide': short > 720 ? 720 : 0}) ?? path;
    } finally {
      _ch.setMethodCallHandler(null);
    }
    info = await _info(out);
  }
  onProgress(1);
  String? poster;
  try {
    poster = await _ch.invokeMethod<String>('poster', {'path': out});
  } catch (_) {}
  final bytes = File(out).lengthSync();
  if (bytes > maxUploadBytes) throw const VideoTooBig();
  return VideoReady(path: out, poster: poster, w: field('w'), h: field('h'), dur: field('dur') / 1000, bytes: bytes);
}

/// Stops a compression in progress (the screen was closed).
Future<void> cancelVideoPrep() async {
  try {
    await _ch.invokeMethod('cancel');
  } catch (_) {}
}
