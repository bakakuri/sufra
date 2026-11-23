// A pretend phone for the tests: what arrives from outside (a link, a share), and the installer.
import 'package:peera/system/phone.dart';

class FakePhone implements Phone {
  Map<String, dynamic>? pending;
  bool installAllowed = true, askedToAllow = false;
  final installs = <(String, String)>[];
  void Function()? _arrived;

  @override
  set onArrived(void Function() f) => _arrived = f;

  /// a link or a share comes while the app runs
  void arrive(Map<String, dynamic> m) {
    pending = m;
    _arrived?.call();
  }

  @override
  Future<Device?> device() async => (model: 'Test Phone', android: '14', sdk: 34, abis: const ['arm64-v8a', 'armeabi-v7a'], cache: '/phone/cache');

  @override
  Future<Map<String, dynamic>?> take() async {
    final m = pending;
    pending = null;
    return m;
  }

  @override
  Future<bool> canInstall() async => installAllowed;

  @override
  Future<void> allowInstall() async => askedToAllow = true;

  @override
  Future<String> install(String path, String sha256) async {
    installs.add((path, sha256));
    return 'ok';
  }
}
