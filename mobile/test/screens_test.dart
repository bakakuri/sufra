// Pictures of the screens at phone size, light and dark: test/goldens/*.png.
// They are written with `flutter test --update-goldens` (the build does that) and are there to be looked at.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/feed/compose_screen.dart';
import 'package:peera/home/calendar.dart';
import 'package:peera/home/home_cards.dart';
import 'package:peera/home/services.dart';
import 'package:peera/people/albums.dart';
import 'package:peera/people/cards.dart';
import 'package:peera/people/coins.dart';
import 'package:peera/people/cv_edit.dart';
import 'package:peera/people/edu.dart';
import 'package:peera/people/family.dart';
import 'package:peera/people/person_screen.dart';
import 'package:peera/people/profile_parts.dart';
import 'package:peera/people/verify.dart';
import 'package:peera/auth/auth_screen.dart';
import 'package:peera/auth/onboarding_screen.dart';
import 'package:peera/data/models.dart';
import 'package:peera/data/stores.dart';
import 'package:peera/joker/engine.dart';
import 'package:peera/joker/joker_tab.dart';
import 'package:peera/joker/online.dart';
import 'package:peera/joker/online_screen.dart';
import 'package:peera/joker/session.dart';
import 'package:peera/joker/table_screen.dart';
import 'package:peera/main.dart';
import 'package:peera/profile/profile.dart';

import 'fake_api.dart';
import 'helpers.dart';

/// a Joker table at a chosen moment: the bots (level 4) play every seat until [at] says stop
Future<JokerSession> _joker(WidgetTester t, ThemeMode m, String len, int seed, bool Function(JokerGame) at) async {
  final g = JokerGame.start(len, rng: Random(seed));
  var guard = 0;
  while (!at(g) && g.phase != 'over' && guard++ < 5000) {
    switch (g.phase) {
      case 'trump':
        g.setTrump(g.botTrump(g.cur));
      case 'bid':
        g.bid(g.cur, g.botBid(g.cur, 4));
      case 'play':
        if (g.win != null) {
          g.collect();
        } else {
          final mv = g.botPlay(g.cur, 4);
          g.play(g.cur, mv.c, jm: mv.jm, js: mv.js);
        }
      case 'handover':
        g.nextHand();
    }
  }
  final s = JokerSession()
    ..g = g
    ..seats = ['f1', 'm1', 'f3'];
  await t.pumpWidget(PeeraApp(mode: m, home: AppScope(app: AppState(FakeApi()), me: nino, child: JokerTableScreen(session: s))));
  await settle(t);
  return s;
}

Future<void> _shot(WidgetTester t, String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

void main() {
  setUpAll(() async {
    await loadFonts();
    useTestImages();
  });

  for (final dark in [false, true]) {
    final m = dark ? ThemeMode.dark : ThemeMode.light, k = dark ? 'dark' : 'light';

    testWidgets('sign in ($k)', (t) async {
      phone(t);
      await t.pumpWidget(PeeraApp(mode: m, home: AuthScreen(api: FakeAuth())));
      await t.pumpAndSettle();
      await _shot(t, '01-signin-$k');
    });

    testWidgets('sign up ($k)', (t) async {
      phone(t);
      await t.pumpWidget(PeeraApp(mode: m, home: AuthScreen(api: FakeAuth(), startUp: true)));
      await t.pumpAndSettle();
      await _shot(t, '02-signup-$k');
    });

    testWidgets('onboarding ($k)', (t) async {
      phone(t);
      await t.pumpWidget(PeeraApp(mode: m, home: OnboardingScreen(api: FakeAuth(), me: Profile(id: 'u2', name: 'გიორგი'), onDone: () {})));
      await t.pumpAndSettle();
      await _shot(t, '03-onboarding-$k');
    });

    testWidgets('feed ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await _shot(t, '04-feed-$k');
      // further down: the long text, the poll, the shared post
      await t.drag(find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first, const Offset(0, -720));
      await settle(t);
      await _shot(t, '05-feed-more-$k');
    });

    testWidgets('reactions ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.drag(find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first, const Offset(0, -560));
      await settle(t);
      await t.ensureVisible(find.byKey(const ValueKey('react-102')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('react-102')));
      await settle(t);
      await _shot(t, '06-reactions-$k');
    });

    testWidgets('post and comments ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.ensureVisible(find.byKey(const ValueKey('comments-101')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('comments-101')));
      await settle(t);
      FocusManager.instance.primaryFocus?.unfocus();
      await t.drag(find.byType(Scrollable).first, const Offset(0, -420));
      await settle(t);
      await _shot(t, '07-comments-$k');
    });

    testWidgets('writing a post ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('compose')));
      await settle(t);
      await t.enterText(find.byType(TextField), 'შაბათ-კვირას კახეთში ვიყავით 🍇 ღვინის ქარხანა, სიღნაღი და ბევრი სიცილი');
      await t.tap(find.text('ფოტო'));
      await settle(t);
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(t);
      await _shot(t, '08-compose-$k');
    });

    testWidgets('friends ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('tab-friends')));
      await settle(t);
      await _shot(t, '09-friends-requests-$k');
      await t.tap(find.byKey(const ValueKey('seg-0')));
      await settle(t);
      await _shot(t, '10-friends-$k');
      await t.tap(find.byKey(const ValueKey('seg-2')));
      await settle(t);
      await _shot(t, '11-friends-suggested-$k');
    });

    testWidgets('a person ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.text('გიორგი კაპანაძე').first);
      await settle(t);
      await _shot(t, '12-person-$k');
      final list = find.descendant(of: find.byType(PersonScreen).first, matching: find.byType(Scrollable)).first;
      await t.drag(list, const Offset(0, -420));
      await settle(t);
      await _shot(t, '42-person-grid-$k');
      await t.tap(find.byKey(const ValueKey('ptab-cv')));
      await settle(t);
      await t.drag(list, const Offset(0, -300));
      await settle(t);
      await _shot(t, '43-person-cv-$k');
      await t.scrollUntilVisible(find.byKey(const ValueKey('pro-more')), -300, scrollable: list);
      await settle(t);
      await t.tap(find.byKey(const ValueKey('pro-more')));
      await settle(t);
      await t.tap(find.text('საჩუქრის გაგზავნა'));
      await settle(t);
      await _shot(t, '44-gift-$k');
    });

    testWidgets('my profile ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('tab-me')));
      await settle(t);
      await _shot(t, '13-profile-$k');
      final list = find.descendant(of: find.byType(PersonScreen).first, matching: find.byType(Scrollable)).first;
      await t.drag(list, const Offset(0, -380));
      await settle(t);
      await _shot(t, '45-profile-space-$k');
      await t.ensureVisible(find.byKey(const ValueKey('space-row')));
      await settle(t);
      await t.scrollUntilVisible(find.byKey(const ValueKey('space-badges')), 120,
          scrollable: find.descendant(of: find.byKey(const ValueKey('space-row')), matching: find.byType(Scrollable)).first);
      await t.ensureVisible(find.byKey(const ValueKey('space-badges')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('space-badges')));
      await settle(t);
      await _shot(t, '46-badges-$k');
      await t.binding.handlePopRoute();
      await settle(t);
      await t.ensureVisible(find.byKey(const ValueKey('space-row')));
      await settle(t);
      await t.scrollUntilVisible(find.byKey(const ValueKey('space-stories')), 120,
          scrollable: find.descendant(of: find.byKey(const ValueKey('space-row')), matching: find.byType(Scrollable)).first);
      await t.ensureVisible(find.byKey(const ValueKey('space-stories')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('space-stories')));
      await settle(t);
      await _shot(t, '47-archive-$k');
      await t.binding.handlePopRoute();
      await settle(t);
      await t.ensureVisible(find.byKey(const ValueKey('space-row')));
      await settle(t);
      await t.scrollUntilVisible(find.byKey(const ValueKey('space-namedays')), 120,
          scrollable: find.descendant(of: find.byKey(const ValueKey('space-row')), matching: find.byType(Scrollable)).first);
      await t.ensureVisible(find.byKey(const ValueKey('space-namedays')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('space-namedays')));
      await settle(t);
      await _shot(t, '48-namedays-$k');
      await t.binding.handlePopRoute();
      await settle(t);
      await t.scrollUntilVisible(find.byKey(const ValueKey('pro-share')), -300, scrollable: list);
      await settle(t);
      await t.tap(find.byKey(const ValueKey('pro-share')));
      await settle(t);
      await _shot(t, '49-qr-$k');
    });

    testWidgets('chats ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('tab-chats')));
      await settle(t);
      await _shot(t, '14-chats-$k');
      await t.tap(find.text('გიორგი კაპანაძე').first);
      await settle(t);
      await _shot(t, '15-chat-$k');
      // recording a voice message
      await t.tap(find.byKey(const ValueKey('chat-mic')));
      await t.pump(const Duration(seconds: 7));
      await t.pump(const Duration(milliseconds: 300));
      await _shot(t, '41-chat-voice-$k');
      await t.tap(find.byKey(const ValueKey('voice-cancel')));
      await settle(t);
    });

    testWidgets('clips ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('tab-clips')));
      await settle(t);
      await _shot(t, '17-clips-$k');
    });

    testWidgets('a story ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('story-u2')));
      await settle(t);
      await _shot(t, '18-story-$k');
    });

    testWidgets('a new clip ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('tab-clips')));
      await settle(t);
      await t.tap(find.byTooltip('კლიპის ატვირთვა'));
      await settle(t);
      await t.enterText(find.byType(TextField), 'გუდაური, პირველი თოვლი ❄️');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(t);
      await _shot(t, '19-new-clip-$k');
    });

    testWidgets('joker tab ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('tab-joker')));
      await settle(t);
      await _shot(t, '20-joker-$k');
    });

    testWidgets('joker: my bid ($k)', (t) async {
      phone(t);
      await _joker(t, m, 'quick', 5, (g) => g.phase == 'bid' && g.cur == 0 && g.n >= 5);
      await _shot(t, '21-joker-bid-$k');
    });

    testWidgets('joker: my move ($k)', (t) async {
      phone(t);
      await _joker(t, m, 'quick', 11, (g) => g.phase == 'play' && g.cur == 0 && g.win == null && g.trick.length == 2 && g.n >= 6 && g.lastT != null);
      await _shot(t, '22-joker-play-$k');
    });

    testWidgets('joker: the score sheet ($k)', (t) async {
      phone(t);
      await _joker(t, m, 'full', 3, (g) => g.h == 13 && g.phase == 'bid' && g.cur == 0);
      await t.tap(find.byTooltip('ქულების ფურცელი'));
      await settle(t);
      await _shot(t, '23-joker-sheet-$k');
    });

    testWidgets('joker: the trump of a nine-card hand ($k)', (t) async {
      phone(t);
      await _joker(t, m, 'nines', 8, (g) => g.phase == 'trump' && g.cur == 0);
      await _shot(t, '24-joker-trump-$k');
    });

    testWidgets('joker: the end ($k)', (t) async {
      phone(t);
      final s = await _joker(t, m, 'quick', 2, (g) => false);
      s.reward = 10;
      s.g!.score[0] = s.g!.score.reduce(max) + 40;
      s.setHint(true); // the table draws again
      await settle(t);
      await _shot(t, '25-joker-over-$k');
    });

    testWidgets('dating: turning it on ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('tab-date')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('gender-f')));
      await t.tap(find.byKey(const ValueKey('seeking-m')));
      await t.pump();
      await settle(t);
      await _shot(t, '26-dating-setup-$k');
    });

    testWidgets('dating: a card ($k)', (t) async {
      phone(t);
      await shell(t, mode: m, api: FakeApi()..dating = const DatingMe(adult: true, on: true, gender: 'm', seeking: 'f', photo: true));
      await t.tap(find.byKey(const ValueKey('tab-date')));
      await settle(t);
      await _shot(t, '27-dating-card-$k');
      // half way to the right: the stamp shows
      final g = await t.startGesture(t.getCenter(find.byKey(const ValueKey('dcard-u5'))));
      await g.moveBy(const Offset(30, 0));
      await t.pump();
      await g.moveBy(const Offset(70, 10));
      await t.pump();
      await _shot(t, '28-dating-drag-$k');
      await g.up();
      await settle(t);
    });

    testWidgets('dating: a pair ($k)', (t) async {
      phone(t);
      await shell(t, mode: m, api: FakeApi()..dating = const DatingMe(adult: true, on: true, gender: 'm', seeking: 'f', photo: true));
      await t.tap(find.byKey(const ValueKey('tab-date')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('date-like')));
      await settle(t);
      await _shot(t, '29-dating-pair-$k');
      await t.tap(find.text('სვაიპის გაგრძელება'));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('dseg-2')));
      await settle(t);
      await _shot(t, '30-dating-pairs-$k');
    });

    testWidgets('joker with people: the waiting room and the table ($k)', (t) async {
      phone(t);
      final api = FakeApi();
      api.jk[60] = const JkTable(id: 60, host: 'u1', len: 'quick', seats: ['u1', 'u2', null, null], pub: true, state: {'srv': true});
      await shell(t, mode: m, api: api);
      await t.tap(find.byKey(const ValueKey('tab-joker')));
      await settle(t);
      await t.scrollUntilVisible(find.byKey(const ValueKey('jtable-60')), 250, scrollable: find.descendant(of: find.byType(JokerTab), matching: find.byType(Scrollable)).first);
      await settle(t);
      await _shot(t, '31-joker-online-list-$k');
      await t.tap(find.byKey(const ValueKey('jtable-60')));
      await settle(t);
      await _shot(t, '32-joker-wait-$k');
      await t.scrollUntilVisible(find.byKey(const ValueKey('jstart')), 200, scrollable: find.descendant(of: find.byType(OnlineTableScreen), matching: find.byType(Scrollable)).first);
      await t.tap(find.byKey(const ValueKey('jstart')));
      await settle(t);
      final j = t.widget<JokerTableScreen>(find.byType(JokerTableScreen)).session as OnlineJoker;
      for (var i = 0; i < 30 && !j.myTurn; i++) {
        await t.pump(const Duration(seconds: 1));
      }
      await settle(t);
      await _shot(t, '33-joker-online-$k');
    });

    testWidgets('the live map ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('tab-friends')));
      await settle(t);
      await t.tap(find.byTooltip('ლაივ რუკა'));
      await settle(t);
      await _shot(t, '34-map-$k');
      await t.tap(find.byKey(const ValueKey('map-share')));
      await settle(t);
      await _shot(t, '35-map-share-$k');
    });

    testWidgets('the bell ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('bell')));
      await settle(t);
      await _shot(t, '36-notes-$k');
    });

    testWidgets('settings ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('tab-me')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('pro-settings')));
      await settle(t);
      await _shot(t, '37-settings-$k');
      await t.tap(find.byKey(const ValueKey('set-privacy')));
      await settle(t);
      await _shot(t, '38-privacy-$k');
      await t.binding.handlePopRoute();
      await settle(t);
      await t.tap(find.byKey(const ValueKey('set-notif')));
      await settle(t);
      await _shot(t, '39-notif-settings-$k');
    });

    testWidgets('editing the profile ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('tab-me')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('edit-profile')));
      await settle(t);
      await _shot(t, '40-edit-profile-$k');
    });

    testWidgets('search ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byTooltip('ძებნა'));
      await settle(t);
      await t.enterText(find.byType(TextField), 'ნი');
      await t.pump(const Duration(milliseconds: 400));
      await settle(t);
      await _shot(t, '16-search-$k');
    });

    /// a page opened over my profile, the way its button opens it
    Future<BuildContext> onMe(WidgetTester t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('tab-me')));
      await settle(t);
      return t.element(find.byType(PersonScreen).first);
    }

    Future<void> page(WidgetTester t, Widget w, String name) async {
      openPage(await onMe(t), w, full: true);
      await settle(t);
      await _shot(t, '$name-$k');
    }

    testWidgets('albums ($k)', (t) async => page(t, const AlbumsScreen(), '50-albums'));
    testWidgets('an album ($k)', (t) async => page(t, const AlbumScreen(id: 1), '51-album'));
    testWidgets('the family tree ($k)', (t) async => page(t, TreeScreen(uid: nino.id), '52-tree'));
    testWidgets('coins ($k)', (t) async => page(t, const CoinsScreen(), '53-coins'));
    testWidgets('my CV ($k)', (t) async => page(t, const CvEditScreen(), '54-cv-edit'));
    testWidgets('a surname ($k)', (t) async => page(t, const SurnameScreen(surname: 'ბერიძე'), '56-surname'));
    testWidgets('a greeting card ($k)', (t) async => page(t, CardPicker(uid: giorgi.id, toName: giorgi.name), '58-card'));
    testWidgets('verification ($k)', (t) async => page(t, const VerifyScreen(), '59-verify'));
    testWidgets('classmates ($k)', (t) async => page(
        t,
        const ClassmatesScreen(edu: [
          {'k': 'school', 'n': '41-ე საჯარო სკოლა', 'c': 'ქუთაისი', 'y1': 2017, 'cls': 'ა', 'key': 'ქუთაისი-41'},
        ]),
        '60-classmates'));

    testWidgets('the home page, everything on it ($k)', (t) async {
      phone(t);
      firstStepsOn = true;
      addTearDown(() => firstStepsOn = false);
      final now = DateTime.now();
      final api = FakeApi()
        ..settings = {
          'banner': {'on': true, 'text': 'ახალი: საერთო ალბომები ქორწილისა და სუფრისთვის!', 'link': '#albums', 'cta': 'ნახვა', 'tone': 'fest'},
        }
        ..memory(90, 1, 'პირველი დღე უნივერსიტეტში 🎓 ყველას გისურვებთ წარმატებას!')
        ..memory(91, 3, 'სკოლის ბოლო ზარი')
        ..bdays.add({'id': mariam.id, 'name': mariam.name, 'hue': mariam.hue, 'avatar_url': null, 'month': now.month, 'day': now.day});
      api.promoRows.addAll([
        {'id': 5, 'kind': 'post', 'brand': 'Peera', 'title': 'საერთო ალბომები', 'body': 'ქორწილის, სუფრის და ლაშქრობის ფოტოები ერთ ადგილას: ყველა სტუმარი თავისას ამატებს.', 'media_url': 'https://t/food.jpg', 'media_type': 'image', 'w': 520, 'h': 520, 'link': '#albums', 'cta': 'ალბომის შექმნა', 'every': 6, 'active': true},
        {'id': 6, 'kind': 'story', 'brand': 'ბიბლიოთეკა', 'media_url': 'https://t/sea.jpg', 'media_type': 'image', 'link': '#calendar', 'active': true},
      ]);
      api.adRows.add((9, 108));
      await shell(t, mode: m, api: api);
      await _shot(t, '61-home-top-$k');
      await t.drag(find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first, const Offset(0, -620));
      await settle(t);
      await _shot(t, '61-home-mid-$k');
      await t.drag(find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first, const Offset(0, -1300));
      await settle(t);
      await _shot(t, '61-home-feed-$k');
    });

    testWidgets('all services ($k)', (t) async {
      servicesMenu(await onMe(t));
      await settle(t);
      await _shot(t, '62-services-$k');
    });

    testWidgets('making something ($k)', (t) async {
      createMenu(await onMe(t), write: ({photos = false, poll = false}) async {});
      await settle(t);
      await _shot(t, '63-create-$k');
    });

    testWidgets('first steps, where from ($k)', (t) async => page(t, const FirstStepsScreen(start: 2), '64-first-steps'));
    testWidgets('first steps, people ($k)', (t) async => page(t, const FirstStepsScreen(start: 3), '64-first-steps-people'));
    testWidgets('the calendar ($k)', (t) async {
      final api = FakeApi()..bdays.add({'id': mariam.id, 'name': mariam.name, 'hue': mariam.hue, 'avatar_url': null, 'month': DateTime.now().month, 'day': DateTime.now().day});
      phone(t);
      await shell(t, mode: m, api: api);
      await t.tap(find.byKey(const ValueKey('tab-me')));
      await settle(t);
      openPage(t.element(find.byType(PersonScreen).first), const CalendarScreen(), full: true);
      await settle(t);
      await _shot(t, '69-calendar-$k');
    });

    testWidgets('my topics ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('topics')));
      await settle(t);
      await _shot(t, '66-topics-$k');
    });

    testWidgets('inviting friends ($k)', (t) async {
      inviteSheet(await onMe(t));
      await settle(t);
      await _shot(t, '68-invite-$k');
    });

    testWidgets('a poll written ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('compose-poll')));
      await settle(t);
      await t.enterText(find.byKey(const ValueKey('poll-q')), 'სად შევხვდეთ შაბათს?');
      await t.enterText(find.byKey(const ValueKey('poll-o-0')), 'კაფეში');
      await t.enterText(find.byKey(const ValueKey('poll-o-1')), 'ბიბლიოთეკაში');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(t);
      await _shot(t, '70-compose-poll-$k');
      expect(find.byType(ComposeScreen), findsOneWidget);
    });

    testWidgets('a school added ($k)', (t) async {
      openPage(await onMe(t), const EduScreen(), full: true);
      await settle(t);
      await t.tap(find.byKey(const ValueKey('edu-add')));
      await settle(t);
      await _shot(t, '55-edu-$k');
    });

    testWidgets('the games card ($k)', (t) async {
      gamesCard(await onMe(t), giorgi, const JokerLine(rating: 1640, games: 38, wins: 17), mine: false);
      await settle(t);
      await _shot(t, '57-games-card-$k');
    });
  }
}
