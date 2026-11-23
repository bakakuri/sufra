// The phone itself, for the app (android/.../PhoneBridge.kt): what phone and Android it is, a link to the site or a
// share from another app that opened Peera, and installing a downloaded update. The tests put a pretend phone here.
import 'package:flutter/services.dart';

typedef Device = ({String model, String android, int sdk, List<String> abis, String cache});

abstract class Phone {
  Future<Device?> device();

  /// the link or share that opened the app, once: {kind: 'link', url} or {kind: 'share', text, files: [{path, mime}]}
  Future<Map<String, dynamic>?> take();

  /// the phone lets this app install (Android asks once, in its settings)
  Future<bool> canInstall();
  Future<void> allowInstall();

  /// the installer for the file at [path], when it is the one with this checksum: 'ok', 'bad' or 'fail'
  Future<String> install(String path, String sha256);

  /// something arrived while the app runs (a link or a share): the app takes it
  set onArrived(void Function() f);
}

class AndroidPhone implements Phone {
  static const _ch = MethodChannel('peera/system');

  @override
  set onArrived(void Function() f) => _ch.setMethodCallHandler((c) async {
        if (c.method == 'arrived') f();
        return null;
      });

  @override
  Future<Device?> device() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('device');
      if (m == null) return null;
      return (
        model: '${m['maker'] ?? ''} ${m['model'] ?? ''}'.trim(),
        android: '${m['android'] ?? ''}',
        sdk: m['sdk'] is int ? m['sdk'] as int : 0,
        abis: [for (final a in (m['abis'] as List? ?? const [])) '$a'],
        cache: '${m['cache'] ?? ''}',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> take() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('take');
      return m;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> canInstall() async {
    try {
      return await _ch.invokeMethod<bool>('canInstall') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> allowInstall() async {
    try {
      await _ch.invokeMethod('allowInstall');
    } catch (_) {}
  }

  @override
  Future<String> install(String path, String sha256) async {
    try {
      return await _ch.invokeMethod<String>('install', {'path': path, 'sha256': sha256}) ?? 'fail';
    } catch (_) {
      return 'fail';
    }
  }
}

Phone phoneBridge = AndroidPhone();
