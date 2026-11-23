// What breaks on people's phones reaches the admin panel, as on the site (js/core.js errReport → client_errors):
// uncaught errors of the app and failed actions with the server, each once per run, at most a few; the phone, its
// Android and the app's build go with them. Network hiccups are left out. Only for someone signed in.
import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';

import '../config.dart';

class ErrorReporter {
  /// sends one report (set by the signed-in app; none before)
  static Future<void> Function(Map<String, dynamic> row)? send;

  /// the phone, its Android, the app's build
  static String ua = 'Peera app b$appBuild';

  /// where in the app it happened (the open tab)
  static String Function() page = () => '';

  static final _seen = <String>{};
  static int _n = 0;

  /// at most this many a run
  static const most = 8;

  static final _noise = RegExp(
      r'SocketException|HttpException|HandshakeException|ClientException|TimeoutException|Failed host lookup|Connection (closed|reset|refused)|Network is unreachable|JWT expired|Refresh Token|AuthRetryableFetchException|Software caused connection abort',
      caseSensitive: false);

  /// uncaught errors: the framework's and the rest
  static void install() {
    final before = FlutterError.onError;
    FlutterError.onError = (d) {
      before?.call(d);
      report(d.exception, d.stack, where: d.library);
    };
    PlatformDispatcher.instance.onError = (e, st) {
      report(e, st);
      return false;
    };
  }

  /// a failure worth knowing about (a caught one, too)
  static void report(Object error, StackTrace? stack, {String? where}) {
    final s = send;
    if (s == null || _n >= most) return;
    final msg = '$error'.trim();
    if (msg.isEmpty || _noise.hasMatch(msg) || error is SocketException || error is TimeoutException) return;
    final st = '${stack ?? ''}';
    // the first line of the app's own code it went through
    final src = RegExp(r'package:peera/[^\s)]+').firstMatch(st)?.group(0) ?? (where ?? '');
    final key = '${msg.length > 120 ? msg.substring(0, 120) : msg}|$src';
    if (!_seen.add(key)) return;
    _n++;
    String cut(String v, int n) => v.length > n ? v.substring(0, n) : v;
    final line = RegExp(r':(\d+):(\d+)').firstMatch(src);
    s({
      'msg': cut(msg, 500),
      'src': cut(src, 300),
      if (line != null) 'line': int.parse(line.group(1)!),
      if (line != null) 'col': int.parse(line.group(2)!),
      'stack': cut(st, 2000),
      'page': cut(page(), 200),
      'ua': cut(ua, 300),
      'ver': cut('app-b$appBuild', 20),
    }).catchError((_) {});
  }

  /// the tests start every run afresh
  @visibleForTesting
  static void reset() {
    _seen.clear();
    _n = 0;
  }
}
