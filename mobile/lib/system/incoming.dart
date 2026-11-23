// What opens the app from outside: a link to the site (www.peera.my/#post-12, #user-…, a group, a page…) shows that
// place here when the app has it and in a browser tab otherwise; photos, a video, words or a link shared from
// another app begin a new post.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../home/promos.dart';
import 'phone.dart';

/// a link to the site
bool isSiteLink(String url) {
  final u = Uri.tryParse(url.trim());
  return u != null && (u.scheme == 'https' || u.scheme == 'http') && (u.host == 'www.peera.my' || u.host == 'peera.my');
}

/// a link to the site, shown here: its part after "#" is the site's page; the front page is the feed
Future<void> openSiteLink(BuildContext context, String url) async {
  final u = Uri.tryParse(url.trim());
  if (u == null) return;
  final f = u.fragment;
  if (f.isEmpty) {
    context.app.goHome?.call();
    return;
  }
  await openLink(context, '#$f');
}

/// what the phone brought, as the app shows it
Future<void> handleIncoming(BuildContext context, Map<String, dynamic> m) async {
  if (m['kind'] == 'link') {
    final url = '${m['url'] ?? ''}';
    if (isSiteLink(url)) await openSiteLink(context, url);
    return;
  }
  if (m['kind'] != 'share') return;
  final photos = <Uint8List>[];
  String? video;
  for (final f in (m['files'] as List? ?? const [])) {
    if (f is! Map) continue;
    final path = '${f['path'] ?? ''}', mime = '${f['mime'] ?? ''}';
    if (path.isEmpty) continue;
    if (mime.startsWith('image/')) {
      try {
        photos.add(await File(path).readAsBytes());
      } catch (_) {}
    } else if (mime.startsWith('video/') && video == null) {
      video = path;
    }
  }
  final text = '${m['text'] ?? ''}'.trim();
  if (photos.isEmpty && video == null && text.isEmpty) return;
  if (!context.mounted) return;
  await openPage(
    context,
    ComposeScreen(text: text, photos: photos, videoPath: photos.isEmpty ? video : null),
    full: true,
  );
}

/// takes what the phone holds for the app (at the start, on coming back, when it arrives) and shows it
Future<void> takeIncoming(BuildContext? Function() context) async {
  final m = await phoneBridge.take();
  final ctx = context();
  if (m == null || ctx == null || !ctx.mounted) return;
  await handleIncoming(ctx, m);
}
