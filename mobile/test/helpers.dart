import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/auth/auth_api.dart';
import 'package:peera/profile/profile.dart';

/// The app's own fonts, so the screenshots show real Georgian letters (and Latin from Noto Sans).
Future<void> loadFonts() async {
  final ge = FontLoader('NotoSansGeorgian');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    ge.addFont(rootBundle.load('assets/fonts/NotoSansGeorgian-$w.ttf'));
  }
  await ge.load();
  final cond = FontLoader('NotoSansGeorgianCondensed');
  for (final w in ['', 'Bold', 'ExtraBold']) {
    cond.addFont(rootBundle.load('assets/fonts/NotoSansGeorgian-Condensed$w.ttf'));
  }
  await cond.load();
  final la = FontLoader('NotoSans');
  for (final f in ['NotoSans-Regular.ttf', 'NotoSans-Bold.ttf']) {
    la.addFont(Future.value(ByteData.sublistView(File('test/fonts/$f').readAsBytesSync())));
  }
  await la.load();
}

/// A phone the size of the site's screenshots: 390 × 844 points at twice the pixels.
void phone(WidgetTester t, {double w = 390, double h = 844}) {
  t.view.physicalSize = Size(w * 2, h * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

final nino = Profile(id: 'u1', name: 'ნინო', surname: 'ბერიძე', username: 'nino.beridze', city: 'ქუთაისი', hue: 312, coins: 12450, onboarded: true);

/// Sign-in that answers from memory
class FakeAuth implements AuthApi {
  final calls = <String>[];
  Object? fail;
  bool ready = true;
  @override
  Future<void> signIn(String email, String password) async {
    calls.add('in $email');
    if (fail != null) throw fail!;
  }

  @override
  Future<bool> signUp(String email, String password, String name) async {
    calls.add('up $email $name');
    if (fail != null) throw fail!;
    return ready;
  }

  @override
  Future<void> resetPassword(String email) async => calls.add('reset $email');
  @override
  Future<void> completeOnboarding({required String name, required DateTime birthday, required String username, required String city}) async =>
      calls.add('onboard $name $username $city ${birthday.year}');
  @override
  Future<Profile?> myProfile() async => nino;
  @override
  Future<void> signOut() async => calls.add('out');
}
