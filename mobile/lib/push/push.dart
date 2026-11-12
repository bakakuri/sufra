import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../data/api.dart';

/// What a tapped notification opens: a conversation, a post, or the friends tab.
class PushTarget {
  const PushTarget({this.conv, this.post, this.tab});
  final int? conv, post;
  final String? tab;

  /// from the notification's data: the site's address (/#chat-12, /#post-34) and its kind
  static PushTarget? fromData(Map<String, dynamic> d) {
    final url = '${d['url'] ?? ''}', kind = '${d['kind'] ?? ''}';
    final chat = RegExp(r'#chat-(\d+)').firstMatch(url);
    if (chat != null) return PushTarget(conv: int.parse(chat.group(1)!));
    final post = RegExp(r'#post-(\d+)').firstMatch(url);
    if (post != null) return PushTarget(post: int.parse(post.group(1)!));
    if (kind == 'friend_req' || kind == 'friend_ok') return const PushTarget(tab: 'friends');
    return null;
  }
}

/// Notifications that reach the phone while the app is closed. The tests leave it out.
abstract class PushService {
  /// whether the phone lets the app show notifications (null until known)
  ValueListenable<bool?> get enabled;

  /// registers this phone for the signed-in person, asks once for permission, and reports taps;
  /// [onForeground] gets the ones that arrive while the app is open (the phone does not show those itself)
  Future<void> start(PeeraApi api, {required void Function(PushTarget) onOpen, void Function(String title, String body, PushTarget? to)? onForeground});

  /// looks again (back from the phone's settings)
  Future<void> refresh();

  /// the phone's notification settings for this app
  Future<void> openSettings();

  /// this phone stops receiving the person's notifications (on sign-out)
  Future<void> stop(PeeraApi api);

  void dispose();
}

/// Firebase Cloud Messaging. The server sends to every phone in push_subs ("fcm:<token>").
/// Anything that goes wrong is written to the admin panel's error log, so it can be seen and fixed.
class FcmPush implements PushService {
  final _subs = <StreamSubscription<Object?>>[];
  final _enabled = ValueNotifier<bool?>(null);
  static const _system = MethodChannel('peera/system');
  PeeraApi? _api;
  String? _token;
  bool _ready = false;

  @override
  ValueListenable<bool?> get enabled => _enabled;

  void _log(String step, Object e, [StackTrace? st]) {
    _api?.logError('push $step: $e', stack: '${st ?? ''}').catchError((_) {});
  }

  @override
  Future<void> start(PeeraApi api, {required void Function(PushTarget) onOpen, void Function(String title, String body, PushTarget? to)? onForeground}) async {
    _api = api;
    try {
      await Firebase.initializeApp();
    } catch (e, st) {
      _log('firebase', e, st);
      return;
    }
    _ready = true;
    final fm = FirebaseMessaging.instance;
    _subs.add(FirebaseMessaging.onMessageOpenedApp.listen((m) {
      final to = PushTarget.fromData(m.data);
      if (to != null) onOpen(to);
    }));
    _subs.add(FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n != null) onForeground?.call(n.title ?? '', n.body ?? '', PushTarget.fromData(m.data));
    }));
    _subs.add(fm.onTokenRefresh.listen((t) {
      _token = t;
      api.savePushToken(t).catchError((Object e) => _log('save', e));
    }));
    // the phone is registered whatever the answer to the question: once notifications are switched on they arrive
    await _register();
    try {
      final s = await fm.requestPermission();
      _enabled.value = s.authorizationStatus == AuthorizationStatus.authorized || s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e, st) {
      _log('permission', e, st);
    }
    // the app was closed and started by a tap on a notification
    try {
      final first = await fm.getInitialMessage();
      final to = first == null ? null : PushTarget.fromData(first.data);
      if (to != null) onOpen(to);
    } catch (e, st) {
      _log('open', e, st);
    }
  }

  int _tries = 0;
  Timer? _retry;

  Future<void> _register() async {
    final api = _api;
    if (api == null || !_ready || _token != null) return;
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t == null) throw StateError('no token');
      await api.savePushToken(t);
      _token = t;
      _retry?.cancel();
    } catch (e, st) {
      _tries++;
      // the first time, also what the phone itself says at each step (the plugin passes on only the last words)
      String why = '';
      if (_tries == 1) {
        try {
          why = await _system.invokeMethod<String>('pushDiagnose') ?? '';
        } catch (d) {
          why = 'diagnose: $d';
        }
      }
      _log('token #$_tries', '$e${why.isEmpty ? '' : ' | $why'}', st);
      // Google's service is sometimes not ready yet: again after 20 s, 1 min, 3 min, 10 min
      const waits = [20, 60, 180, 600];
      if (_tries <= waits.length) {
        _retry?.cancel();
        _retry = Timer(Duration(seconds: waits[_tries - 1]), _register);
      }
    }
  }

  @override
  Future<void> refresh() async {
    if (!_ready) return;
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      _enabled.value = s.authorizationStatus == AuthorizationStatus.authorized || s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {}
    if (_token == null) await _register();
  }

  @override
  Future<void> openSettings() async {
    try {
      await _system.invokeMethod<bool>('notificationSettings');
    } catch (e) {
      _log('settings', e);
    }
  }

  @override
  Future<void> stop(PeeraApi api) async {
    if (!_ready) return;
    try {
      final fm = FirebaseMessaging.instance;
      final t = _token ?? await fm.getToken();
      if (t != null) await api.removePushToken(t);
      await fm.deleteToken();
      _token = null;
    } catch (_) {}
  }

  @override
  void dispose() {
    _retry?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _enabled.dispose();
  }
}
