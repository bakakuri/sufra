import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
  /// asks once for permission, registers this phone for the signed-in person, and reports taps;
  /// [onForeground] gets the ones that arrive while the app is open (the phone does not show those itself)
  Future<void> start(PeeraApi api, {required void Function(PushTarget) onOpen, void Function(String title, String body, PushTarget? to)? onForeground});

  /// this phone stops receiving the person's notifications (on sign-out)
  Future<void> stop(PeeraApi api);

  void dispose();
}

/// Firebase Cloud Messaging. The server sends to every phone in push_subs ("fcm:<token>").
class FcmPush implements PushService {
  final _subs = <StreamSubscription<Object?>>[];

  @override
  Future<void> start(PeeraApi api, {required void Function(PushTarget) onOpen, void Function(String title, String body, PushTarget? to)? onForeground}) async {
    try {
      await Firebase.initializeApp();
      final fm = FirebaseMessaging.instance;
      final perm = await fm.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await fm.getToken();
      if (token != null) await api.savePushToken(token);
      _subs.add(fm.onTokenRefresh.listen((t) => api.savePushToken(t).catchError((_) {})));
      _subs.add(FirebaseMessaging.onMessageOpenedApp.listen((m) {
        final to = PushTarget.fromData(m.data);
        if (to != null) onOpen(to);
      }));
      _subs.add(FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) onForeground?.call(n.title ?? '', n.body ?? '', PushTarget.fromData(m.data));
      }));
      // the app was closed and started by a tap on a notification
      final first = await fm.getInitialMessage();
      final to = first == null ? null : PushTarget.fromData(first.data);
      if (to != null) onOpen(to);
    } catch (_) {
      // no Google services on the phone, or no network: the app works without notifications
    }
  }

  @override
  Future<void> stop(PeeraApi api) async {
    try {
      final fm = FirebaseMessaging.instance;
      final t = await fm.getToken();
      if (t != null) await api.removePushToken(t);
      await fm.deleteToken();
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }
}
