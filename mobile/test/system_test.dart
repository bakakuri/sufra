// The app and the phone around it: error reports to the admin panel, a new version offered and installed, links
// to the site opening their place here, photos and words shared from another app becoming a post.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/data/api.dart';
import 'package:peera/feed/compose_screen.dart';
import 'package:peera/people/person_screen.dart';
import 'package:peera/settings/settings_screens.dart';
import 'package:peera/system/phone.dart';
import 'package:peera/system/updates.dart';

import 'fake_api.dart';
import 'fake_phone.dart';
import 'helpers.dart';

void main() {
  setUpAll(useTestImages);

  testWidgets('a failed action with the server is reported once, with the phone and the build; a network hiccup is not', (t) async {
    phone(t);
    phoneBridge = FakePhone();
    final api = await shell(t);
    await toProfile(t);
    api.updateFail = Exception('permission denied for table profiles');
    Future<void> tryPic() async {
      await t.tap(find.byKey(const ValueKey('pro-avatar')));
      await settle(t);
      await t.tap(find.text('ფოტოს ატვირთვა გალერეიდან'));
      await settle(t);
    }

    await tryPic();
    expect(api.errors, hasLength(1));
    final e = api.errors.single;
    expect(e['msg'], contains('permission denied'));
    expect(e['ua'], contains('Android 14'));
    expect(e['ua'], contains('Test Phone'));
    expect(e['ver'], startsWith('app-b'));
    expect('${e['page']}', startsWith('tab '));
    // the same again: not twice
    await t.pump(const Duration(seconds: 4));
    await tryPic();
    expect(api.errors, hasLength(1));
    // no network: left out
    api.updateFail = const SocketException('Failed host lookup');
    await t.pump(const Duration(seconds: 4));
    await tryPic();
    expect(api.errors, hasLength(1));
    api.updateFail = null;
  });

  test('people are read only with columns anyone signed in may read (the chosen look is not one of them)', () {
    expect(SupaApi.personSel.split(','), isNot(contains('look')));
  });

  testWidgets('a profile the server will not read: said so with a retry and reported, not an endless spinner', (t) async {
    phone(t);
    phoneBridge = FakePhone();
    final api = await shell(t, api: FakeApi()..personFail = Exception('permission denied for table profiles'));
    await toProfile(t);
    // the posts stand below the head of the page
    await t.scrollUntilVisible(find.text('პოსტები ვერ ჩაიტვირთა'), 300, scrollable: find.descendant(of: find.byType(PersonScreen), matching: find.byType(Scrollable)).first);
    await settle(t);
    expect(find.text('პოსტები ვერ ჩაიტვირთა'), findsOneWidget);
    expect(api.errors.map((e) => '${e['msg']}'), contains(contains('permission denied')));
    // the server answers again: the retry brings the posts
    api.personFail = null;
    await t.ensureVisible(find.text('ხელახლა ცდა'));
    await settle(t);
    await t.tap(find.text('ხელახლა ცდა'));
    await settle(t);
    expect(find.text('პოსტები ვერ ჩაიტვირთა'), findsNothing);
  });

  testWidgets('a new version: offered a moment after the start, downloaded with a bar, checked and handed to the installer; the settings show it', (t) async {
    phone(t);
    final ph = FakePhone();
    phoneBridge = ph;
    currentBuild = () => 100;
    fetchRelease = () async => {
          'build': 105,
          'name': '0.6',
          'notes': 'ონლაინ ნარდი და ახალი იკონი',
          'apks': {
            'arm64-v8a': {'url': 'https://example.org/Peera-arm64.apk', 'sha256': 'ab12', 'size': 41000000},
            'armeabi-v7a': {'url': 'https://example.org/Peera-arm32.apk', 'sha256': 'cd34', 'size': 39000000},
          },
        };
    final got = <String>[];
    downloadFile = (url, path, progress) async {
      got.add('$url → $path');
      progress(.5);
      progress(1);
      return true;
    };
    await shell(t);
    await t.pump(const Duration(seconds: 4));
    await settle(t);
    expect(find.byKey(const ValueKey('update-offer')), findsOneWidget);
    expect(find.textContaining('ონლაინ ნარდი და ახალი იკონი'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('update-go')));
    await settle(t);
    expect(got, ['https://example.org/Peera-arm64.apk → /phone/cache/updates/Peera-105.apk']);
    expect(ph.installs, [('/phone/cache/updates/Peera-105.apk', 'ab12')]);
    expect(find.byKey(const ValueKey('update-progress')), findsNothing);

    // the settings: this build, the newer one, and a look again on a tap
    await toProfile(t);
    await t.ensureVisible(find.byKey(const ValueKey('pro-settings')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('pro-settings')));
    await settle(t);
    await t.scrollUntilVisible(find.byKey(const ValueKey('set-update')), 300, scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first);
    await settle(t);
    expect(find.textContaining('ვერსია 100 · ხელმისაწვდომია 105'), findsOneWidget);
    // one the phone does not yet allow: its settings, after asking
    ph.installAllowed = false;
    await t.tap(find.byKey(const ValueKey('set-update')));
    await settle(t);
    await t.tap(find.text('განახლება').last);
    await settle(t);
    expect(find.text('პარამეტრები'), findsWidgets);
    await t.tap(find.widgetWithText(TextButton, 'პარამეტრები'));
    await settle(t);
    expect(ph.askedToAllow, isTrue);
    expect(ph.installs, hasLength(1));
    // the newest already: said so
    currentBuild = () => 105;
    await t.tap(find.byKey(const ValueKey('set-update')));
    await settle(t);
    expect(find.text('უახლესი ვერსია გაქვს'), findsOneWidget);
    currentBuild = () => 0;
    fetchRelease = () async => null;
  });

  testWidgets('a new version put off is not offered again at the next start', (t) async {
    phone(t);
    currentBuild = () => 100;
    fetchRelease = () async => {
          'build': 101,
          'apks': {
            'arm64-v8a': {'url': 'https://example.org/a.apk', 'sha256': 'x', 'size': 1},
          },
        };
    await shell(t);
    await t.pump(const Duration(seconds: 4));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('update-later')));
    await settle(t);
    await t.pumpWidget(const SizedBox());
    await shell(t);
    await t.pump(const Duration(seconds: 4));
    await settle(t);
    expect(find.byKey(const ValueKey('update-offer')), findsNothing);
    currentBuild = () => 0;
    fetchRelease = () async => null;
  });

  testWidgets('links to the site: a person and a post open here; another site\'s link does nothing', (t) async {
    phone(t);
    final ph = FakePhone();
    phoneBridge = ph;
    await shell(t);
    ph.arrive({'kind': 'link', 'url': 'https://www.peera.my/#user-u2'});
    await settle(t);
    expect(find.byType(PersonScreen), findsOneWidget);
    expect(find.text('გიორგი კაპანაძე'), findsWidgets);
    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.byType(PersonScreen), findsNothing);
    ph.arrive({'kind': 'link', 'url': 'https://peera.my/#post-106'});
    await settle(t);
    expect(find.textContaining('ახალი აპი ვცადე'), findsWidgets);
    await t.binding.handlePopRoute();
    await settle(t);
    // another site's link that came by mistake: nothing
    ph.arrive({'kind': 'link', 'url': 'https://example.org/#post-106'});
    await settle(t);
    expect(find.byType(PersonScreen), findsNothing);
  });

  testWidgets('photos and words shared from another app begin a new post', (t) async {
    phone(t);
    final ph = FakePhone();
    phoneBridge = ph;
    await shell(t);
    await t.runAsync(() async {
      ph.arrive({
        'kind': 'share',
        'text': 'შეხედეთ რა ლამაზია',
        'files': [
          {'path': 'test/img/sea.jpg', 'mime': 'image/jpeg'},
          {'path': 'test/img/hills.jpg', 'mime': 'image/jpeg'},
        ],
      });
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(t);
    expect(find.byType(ComposeScreen), findsOneWidget);
    final cs = t.widget<ComposeScreen>(find.byType(ComposeScreen));
    expect(cs.photos, hasLength(2));
    expect(cs.text, 'შეხედეთ რა ლამაზია');
    expect(find.text('შეხედეთ რა ლამაზია'), findsOneWidget);
    // back: asked before the shared things are thrown away
    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.byType(ComposeScreen), findsOneWidget);
  });
}
