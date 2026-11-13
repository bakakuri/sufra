import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/auth/auth_api.dart';
import 'package:peera/data/photos.dart';
import 'package:peera/feed/compose_screen.dart';
import 'package:peera/joker/session.dart';
import 'package:peera/map/live_map.dart';
import 'package:peera/map/loc_device.dart';
import 'package:peera/media/player.dart';
import 'package:peera/media/video_tools.dart';
import 'package:peera/media/voice.dart';
import 'package:peera/main.dart';
import 'package:peera/profile/profile.dart';
import 'package:peera/push/push.dart';
import 'package:peera/settings/frame_photo.dart';
import 'package:peera/ui/look.dart';
import 'package:peera/data/api.dart';
import 'package:peera/shell/home_shell.dart';
import 'package:peera/stories/stories.dart';
import 'package:peera/ui/net_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  photoFrame = (context, src, {required aspect, required max, required title}) async => (bytes: src, w: max, h: (max / aspect).round());
  themeChoice.value = ThemeMode.system;
  textZoom.value = 1;
  makePlayer = (u, {bool loop = true}) => FakePlayer();
  SharedPreferences.setMockInitialValues({});
  jokerRandom = () => Random(7);
  // the map draws no pictures in the tests (its own background shows), and the phone's location is pretend
  mapTile = (u) => MemoryImage(_clear);
  locDevice = FakeLoc();
  voiceDevice = FakeVoice();
  storyClock = false;
  videoPicker = () async => '/phone/clip.mp4';
  videoPrep = (path, progress) async {
    progress(.5);
    progress(1);
    return const VideoReady(path: '/phone/clip.mp4', poster: '/phone/poster.jpg', w: 720, h: 1280, dur: 14, bytes: 9 * 1024 * 1024);
  };
}

/// A microphone that records whatever the test says
class FakeVoice implements VoiceDevice {
  final calls = <String>[];
  String answer = 'granted';
  int ms = 3200;
  @override
  Future<String> permission() async => answer;
  @override
  Future<bool> start() async {
    calls.add('start');
    return true;
  }

  @override
  Future<double> level() async => .5;
  @override
  Future<Recorded?> stop() async {
    calls.add('stop');
    return (path: '/phone/voice.m4a', ms: ms);
  }

  @override
  Future<void> cancel() async => calls.add('cancel');
  @override
  Future<void> settings() async => calls.add('settings');
}

/// A video that is always ready, a third of the way in, and draws nothing (the poster under it shows)
class FakePlayer extends Player {
  bool _playing = false;
  @override
  bool get ready => true;
  @override
  bool get playing => _playing;
  @override
  bool get buffering => false;
  @override
  bool get failed => false;
  @override
  bool get started => false;
  @override
  bool get ended => false;
  @override
  Duration get position => const Duration(seconds: 5);
  @override
  Duration get duration => const Duration(seconds: 15);
  @override
  Size get size => const Size(720, 1280);
  @override
  Future<void> prepare() async {}
  @override
  Future<void> play() async {
    _playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    _playing = false;
    notifyListeners();
  }

  @override
  Future<void> rewind() => pause();
  @override
  Future<void> mute(bool on) async {}
  @override
  Widget view() => const SizedBox.expand();
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
final nino = Profile(id: 'u1', name: 'ნინო ბერიძე', surname: 'ბერიძე', username: 'nino.beridze', city: 'ქუთაისი', hue: 312, coins: 12450, onboarded: true);
final giorgi = Profile(
  id: 'u2',
  name: 'გიორგი კაპანაძე',
  surname: 'კაპანაძე',
  username: 'gio.k',
  city: 'თბილისი',
  hue: 212,
  verified: true,
  bio: 'ფოტოგრაფი, მოგზაური. მიყვარს მთები და კარგი ყავა ☕',
  coverUrl: 'https://t/cover.jpg',
  lastSeen: _now,
);
final mariam = Profile(id: 'u3', name: 'მარიამ ჯავახიშვილი', surname: 'ჯავახიშვილი', username: 'mariami', city: 'ბათუმი', hue: 340, lastSeen: _now.subtract(const Duration(hours: 2)));
final luka = Profile(id: 'u4', name: 'ლუკა გელაშვილი', surname: 'გელაშვილი', username: 'luka.g', city: 'თბილისი', hue: 140);
final ana = Profile(id: 'u5', name: 'ანა მელაძე', surname: 'მელაძე', username: 'ana.m', city: 'რუსთავი', hue: 28);
final dato = Profile(id: 'u6', name: 'დათო ხარაბაძე', surname: 'ხარაბაძე', username: 'dato', city: 'გორი', hue: 260);
final tamar = Profile(id: 'u7', name: 'თამარ ლომიძე', surname: 'ლომიძე', username: 'tamo', city: 'ქუთაისი', hue: 190);
final nika = Profile(id: 'u8', name: 'ნიკა წიკლაური', surname: 'წიკლაური', username: 'nika.w', city: 'თელავი', hue: 8);
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
  final on = ValueNotifier<bool?>(true);

  @override
  ValueListenable<bool?> get enabled => on;

  @override
  Future<void> refresh() async => calls.add('refresh');

  @override
  Future<void> openSettings() async => calls.add('settings');
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

final _clear = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

/// a pretend phone for the live location: allowed, in Tbilisi, its service records what it was told
class FakeLoc implements LocDevice {
  String perm = 'granted';
  Here? at = (lat: 41.7151, lng: 44.8271, acc: 12.0);
  final calls = <String>[];
  bool on = false;
  String? open;

  @override
  Future<String> permission({bool ask = true}) async {
    calls.add('permission');
    return perm;
  }

  @override
  Future<Here?> here() async => at;

  @override
  Future<bool> start({required String token, required String audience, required int minutes, required bool approx}) async {
    calls.add('start $token $audience $minutes $approx');
    on = true;
    return true;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    on = false;
  }

  @override
  Future<bool> running() async => on;

  @override
  Future<String?> takeOpen() async {
    final o = open;
    open = null;
    return o;
  }

  @override
  Future<void> settings() async => calls.add('settings');
}
