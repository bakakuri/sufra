// A new version of the app, from inside it: the release names its build, what changed and its files (one for each
// kind of phone processor) with their checksums. The app asks once for each new build; "განახლება" downloads it
// with a bar, checks it is that very file, and hands it to the phone's installer (Android asks the person, and the
// first time it asks to allow installs from Peera). The settings show the build and look again on a tap.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'phone.dart';

/// a version on offer
class AppRelease {
  const AppRelease({required this.build, required this.name, required this.notes, required this.files});
  final int build;
  final String name, notes;

  /// processor kind ('arm64-v8a', 'armeabi-v7a') → the file, its checksum, its size
  final Map<String, ({String url, String sha256, int size})> files;

  static AppRelease? fromJson(Object? v) {
    if (v is! Map) return null;
    final b = v['build'];
    final apks = v['apks'];
    if (b is! int || apks is! Map) return null;
    final files = <String, ({String url, String sha256, int size})>{};
    apks.forEach((k, f) {
      if (f is Map && f['url'] is String && '${f['url']}'.startsWith('https://')) {
        files['$k'] = (url: f['url'] as String, sha256: '${f['sha256'] ?? ''}', size: f['size'] is int ? f['size'] as int : 0);
      }
    });
    if (files.isEmpty) return null;
    return AppRelease(build: b, name: '${v['name'] ?? ''}', notes: '${v['notes'] ?? ''}', files: files);
  }

  /// the file for this phone: the 64-bit one when it runs it
  ({String url, String sha256, int size})? fileFor(List<String> abis) {
    for (final a in [...abis, 'arm64-v8a', 'armeabi-v7a']) {
      if (files.containsKey(a) && (abis.isEmpty || abis.contains(a))) return files[a];
    }
    return null;
  }
}

/// the release on offer now (the tests hand one over)
Future<Object?> Function() fetchRelease = () async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  try {
    // a new address every few minutes, so no cache keeps an old one
    final rq = await c.getUrl(Uri.parse('$updateFeed?t=${DateTime.now().millisecondsSinceEpoch ~/ 300000}'));
    final rs = await rq.close().timeout(const Duration(seconds: 20));
    if (rs.statusCode != 200) return null;
    return jsonDecode(await rs.transform(utf8.decoder).join());
  } catch (_) {
    return null;
  } finally {
    c.close(force: true);
  }
};

/// this build's number (the tests set one)
int Function() currentBuild = () => appBuild;

/// a file downloaded to [path], with its progress (0…1); false when it could not be
Future<bool> Function(String url, String path, void Function(double) progress) downloadFile = (url, path, progress) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final rs = await (await c.getUrl(Uri.parse(url))).close();
    if (rs.statusCode != 200) return false;
    final f = File(path);
    await f.parent.create(recursive: true);
    final out = f.openWrite();
    var got = 0;
    final all = rs.contentLength;
    await for (final part in rs) {
      out.add(part);
      got += part.length;
      if (all > 0) progress(got / all);
    }
    await out.close();
    return true;
  } catch (_) {
    return false;
  } finally {
    c.close(force: true);
  }
};

class Updates extends ChangeNotifier {
  AppRelease? latest;
  bool checking = false;
  DateTime? _at;

  int get build => currentBuild();

  /// a newer one is on offer
  bool get newer => latest != null && build > 0 && latest!.build > build;

  /// looks for a new version (at most every six hours unless [force])
  Future<AppRelease?> check({bool force = false}) async {
    if (checking) return null;
    if (!force && _at != null && DateTime.now().difference(_at!) < const Duration(hours: 6)) return newer ? latest : null;
    checking = true;
    notifyListeners();
    try {
      latest = AppRelease.fromJson(await fetchRelease());
      _at = DateTime.now();
    } finally {
      checking = false;
      notifyListeners();
    }
    return newer ? latest : null;
  }

  static const _skipKey = 'update.skip';

  /// once a run, a new version is offered (not again for one put off with "მოგვიანებით")
  Future<void> offer(BuildContext context) async {
    final r = await check();
    if (r == null || !context.mounted) return;
    final p = await SharedPreferences.getInstance();
    if (p.getInt(_skipKey) == r.build || !context.mounted) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        key: const ValueKey('update-offer'),
        title: const Text('ახალი ვერსია'),
        content: Text([r.name.isNotEmpty ? 'Peera ${r.name}' : 'Peera, ვერსია ${r.build}', if (r.notes.isNotEmpty) r.notes].join('\n\n')),
        actions: [
          TextButton(key: const ValueKey('update-later'), onPressed: () => Navigator.pop(d, false), child: const Text('მოგვიანებით')),
          FilledButton(key: const ValueKey('update-go'), onPressed: () => Navigator.pop(d, true), child: const Text('განახლება')),
        ],
      ),
    );
    if (!context.mounted) return;
    if (yes == true) {
      await install(context, r);
    } else if (yes == false) {
      await p.setInt(_skipKey, r.build);
    }
  }

  /// downloads [r] with a bar and opens the installer
  Future<void> install(BuildContext context, AppRelease r) async {
    final dev = await phoneBridge.device();
    final f = r.fileFor(dev?.abis ?? const []);
    if (!context.mounted) return;
    if (f == null || dev == null || dev.cache.isEmpty) {
      toast(context, 'ამ ტელეფონისთვის განახლება ვერ მოიძებნა');
      return;
    }
    if (!await phoneBridge.canInstall()) {
      if (!context.mounted) return;
      final go = await confirm(context,
          title: 'ნებართვა', text: 'განახლების დასაყენებლად ტელეფონმა Peera-ს ნება უნდა მისცეს, აპები დააყენოს. ჩართე პარამეტრებში და დაბრუნდი.', yes: 'პარამეტრები');
      if (go) await phoneBridge.allowInstall();
      return;
    }
    if (!context.mounted) return;
    final progress = ValueNotifier<double>(0);
    final path = '${dev.cache}/updates/Peera-${r.build}.apk';
    final nav = Navigator.of(context, rootNavigator: true);
    var open = true;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (d) => PopScope(
        canPop: false,
        child: AlertDialog(
          key: const ValueKey('update-progress'),
          title: const Text('იტვირთება განახლება'),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, v, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              LinearProgressIndicator(value: v),
              const SizedBox(height: 8),
              Text('${(v * 100).round()}%${f.size > 0 ? ' · ${(f.size / 1048576).toStringAsFixed(1)} მბ' : ''}', style: TextStyle(color: context.pc.muted)),
            ]),
          ),
        ),
      ),
    ).whenComplete(() => open = false));
    final ok = await downloadFile(f.url, path, (v) => progress.value = v);
    if (open) nav.pop();
    if (!context.mounted) return;
    if (!ok) {
      toast(context, 'განახლება ვერ ჩამოიტვირთა. სცადე მოგვიანებით');
      return;
    }
    final res = await phoneBridge.install(path, f.sha256);
    if (!context.mounted) return;
    if (res == 'bad') toast(context, 'ჩამოტვირთული ფაილი დაზიანებულია. სცადე თავიდან');
    if (res == 'fail') toast(context, 'დაყენება ვერ დაიწყო');
  }
}
