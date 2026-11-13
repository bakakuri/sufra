// Pictures of the screens at phone size, light and dark: test/goldens/*.png.
// They are written with `flutter test --update-goldens` (the build does that) and are there to be looked at.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      await t.tap(find.byTooltip('ახალი პოსტი'));
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
    });

    testWidgets('my profile ($k)', (t) async {
      phone(t);
      await shell(t, mode: m);
      await t.tap(find.byKey(const ValueKey('tab-me')));
      await settle(t);
      await _shot(t, '13-profile-$k');
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
  }
}
