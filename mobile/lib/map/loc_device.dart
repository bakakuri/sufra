// The phone's side of the live location: asking for it, where the phone is now, and the service that keeps sharing
// the place with the app closed (android/.../LocService.kt). The tests put a pretend phone here.
import 'package:flutter/services.dart';

import '../config.dart';

typedef Here = ({double lat, double lng, double acc});

abstract class LocDevice {
  /// 'granted', 'denied' (refused now) or 'blocked' (only the phone's settings can allow it); [ask] false only looks
  Future<String> permission({bool ask = true});

  /// where the phone is now (null when it cannot tell)
  Future<Here?> here();

  /// the service starts sharing with this phone's secret, as chosen; false when the phone did not let it start
  Future<bool> start({required String token, required String audience, required int minutes, required bool approx});
  Future<void> stop();
  Future<bool> running();

  /// the screen a notification asked for ('map'), once
  Future<String?> takeOpen();

  /// the phone's settings for this app (to allow the location after "don't ask again")
  Future<void> settings();
}

class AndroidLoc implements LocDevice {
  static const _ch = MethodChannel('peera/loc');

  @override
  Future<String> permission({bool ask = true}) async {
    try {
      return '${await _ch.invokeMethod<String>('permission', {'ask': ask}) ?? 'denied'}';
    } catch (_) {
      return 'denied';
    }
  }

  @override
  Future<Here?> here() async {
    try {
      final r = await _ch.invokeMethod<Map>('here');
      if (r == null) return null;
      return (lat: (r['lat'] as num).toDouble(), lng: (r['lng'] as num).toDouble(), acc: (r['acc'] as num? ?? 0).toDouble());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> start({required String token, required String audience, required int minutes, required bool approx}) async {
    try {
      return await _ch.invokeMethod<bool>('start', {
            'token': token,
            'aud': audience,
            'min': minutes,
            'approx': approx,
            'url': supaUrl,
            'key': supaAnonKey,
          }) ==
          true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _ch.invokeMethod('stop', {'tell': false});
    } catch (_) {}
  }

  @override
  Future<bool> running() async {
    try {
      return await _ch.invokeMethod<bool>('running') == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> takeOpen() async {
    try {
      return await _ch.invokeMethod<String>('takeOpen');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> settings() async {
    try {
      await _ch.invokeMethod('settings');
    } catch (_) {}
  }
}

LocDevice locDevice = AndroidLoc();
