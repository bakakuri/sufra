import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/auth/auth_api.dart';
import 'package:peera/data/photos.dart';
import 'package:peera/feed/compose_screen.dart';
import 'package:peera/main.dart';
import 'package:peera/profile/profile.dart';
import 'package:peera/push/push.dart';
import 'package:peera/data/api.dart';
import 'package:peera/shell/home_shell.dart';
import 'package:peera/ui/net_image.dart';

import 'fake_api.dart';

/// The app's own fonts, so the screenshots show real Georgian letters (and Latin from Noto Sans, emoji when the
/// build has fetched Noto Color Emoji).
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
  final emoji = File('test/fonts/NotoColorEmoji.ttf');
  if (emoji.existsSync()) {
    await (FontLoader('NotoColorEmoji')..addFont(Future.value(ByteData.sublistView(emoji.readAsBytesSync())))).load();
  }
}

final _pics = <String, Uint8List>{};

/// Pictures from test/img instead of the internet; the photo picker hands out the same files.
void useTestImages() {
  Uint8List pic(String name) => _pics.putIfAbsent(name, () {
        final f = File('test/img/$name.jpg');
        return (f.existsSync() ? f : File('test/img/sea.jpg')).readAsBytesSync();
      });
  netImage = (u) => MemoryImage(pic(u.split('/').last.replaceAll('.jpg', '')));
  photoSource = (camera) async => camera ? [pic('food')] : [pic('sunset'), pic('hills')];
  photoPrep = (b) async => PreparedPhoto(b, 640, 480);
}

/// Waits for the screen, the pictures on it included (they are decoded outside the test's clock).
Future<void> settle(WidgetTester t) async {
  await t.pumpAndSettle();
  for (var round = 0; round < 2; round++) {
    await t.runAsync(() async {
      for (final e in find.byType(Image).evaluate().toList()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await t.pumpAndSettle();
  }
}

/// A phone the size of the site's screenshots: 390 × 844 points at twice the pixels.
void phone(WidgetTester t, {double w = 390, double h = 844}) {
  t.view.physicalSize = Size(w * 2, h * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

/// The signed-in app on the fake server.
Future<FakeApi> shell(WidgetTester t, {ThemeMode mode = ThemeMode.light, VoidCallback? exit, FakeApi? api, PushService? push}) async {
  final a = api ?? FakeApi();
  await t.pumpWidget(PeeraApp(mode: mode, home: HomeShell(me: nino, api: a, push: push, onSignOut: () async {}, exit: exit)));
  await settle(t);
  return a;
}

final _now = DateTime.now();
final nino = Profile(id: 'u1', name: 'ნინო', surname: 'ბერიძე', username: 'nino.beridze', city: 'ქუთაისი', hue: 312, coins: 12450, onboarded: true);
final giorgi = Profile(
  id: 'u2',
  name: 'გიორგი',
  surname: 'კაპანაძე',
  username: 'gio.k',
  city: 'თბილისი',
  hue: 212,
  verified: true,
  bio: 'ფოტოგრაფი, მოგზაური. მიყვარს მთები და კარგი ყავა ☕',
  coverUrl: 'https://t/cover.jpg',
  lastSeen: _now,
);
final mariam = Profile(id: 'u3', name: 'მარიამ', surname: 'ჯავახიშვილი', username: 'mariami', city: 'ბათუმი', hue: 340, lastSeen: _now.subtract(const Duration(hours: 2)));
final luka = Profile(id: 'u4', name: 'ლუკა', surname: 'გელაშვილი', username: 'luka.g', city: 'თბილისი', hue: 140);
final ana = Profile(id: 'u5', name: 'ანა', surname: 'მელაძე', username: 'ana.m', city: 'რუსთავი', hue: 28);
final dato = Profile(id: 'u6', name: 'დათო', surname: 'ხარაბაძე', username: 'dato', city: 'გორი', hue: 260);
final tamar = Profile(id: 'u7', name: 'თამარ', surname: 'ლომიძე', username: 'tamo', city: 'ქუთაისი', hue: 190);
final nika = Profile(id: 'u8', name: 'ნიკა', surname: 'წიკლაური', username: 'nika.w', city: 'თელავი', hue: 8);
final everyone = [nino, giorgi, mariam, luka, ana, dato, tamar, nika];

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

/// Notifications without Firebase: the test plays the taps
class FakePush implements PushService {
  final calls = <String>[];
  void Function(PushTarget)? open;
  void Function(String, String, PushTarget?)? whileOpen;

  @override
  Future<void> start(PeeraApi api, {required void Function(PushTarget) onOpen, void Function(String title, String body, PushTarget? to)? onForeground}) async {
    calls.add('start');
    open = onOpen;
    whileOpen = onForeground;
    await api.savePushToken('tok');
  }

  @override
  Future<void> stop(PeeraApi api) async {
    calls.add('stop');
    await api.removePushToken('tok');
  }

  @override
  void dispose() => calls.add('dispose');
}
