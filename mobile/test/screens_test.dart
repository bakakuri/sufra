// Pictures of the screens at phone size, light and dark: test/goldens/*.png.
// They are written with `flutter test --update-goldens` (the build does that) and are there to be looked at.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/auth/auth_screen.dart';
import 'package:peera/auth/onboarding_screen.dart';
import 'package:peera/main.dart';
import 'package:peera/profile/profile.dart';
import 'package:peera/shell/home_shell.dart';

import 'helpers.dart';

void main() {
  setUpAll(loadFonts);

  for (final dark in [false, true]) {
    final m = dark ? ThemeMode.dark : ThemeMode.light, k = dark ? 'dark' : 'light';

    testWidgets('sign in ($k)', (t) async {
      phone(t);
      await t.pumpWidget(PeeraApp(mode: m, home: AuthScreen(api: FakeAuth())));
      await t.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/1-signin-$k.png'));
    });

    testWidgets('sign up ($k)', (t) async {
      phone(t);
      await t.pumpWidget(PeeraApp(mode: m, home: AuthScreen(api: FakeAuth(), startUp: true)));
      await t.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/2-signup-$k.png'));
    });

    testWidgets('onboarding ($k)', (t) async {
      phone(t);
      await t.pumpWidget(PeeraApp(mode: m, home: OnboardingScreen(api: FakeAuth(), me: Profile(id: 'u2', name: 'გიორგი'), onDone: () {})));
      await t.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/3-onboarding-$k.png'));
    });

    testWidgets('home ($k)', (t) async {
      phone(t);
      await t.pumpWidget(PeeraApp(mode: m, home: HomeShell(me: nino, onSignOut: () async {})));
      await t.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/4-home-$k.png'));
    });

    testWidgets('profile ($k)', (t) async {
      phone(t);
      await t.pumpWidget(PeeraApp(mode: m, home: HomeShell(me: nino, onSignOut: () async {})));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('tab-me')));
      await t.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/5-profile-$k.png'));
    });

    testWidgets('chats tab ($k)', (t) async {
      phone(t);
      await t.pumpWidget(PeeraApp(mode: m, home: HomeShell(me: nino, onSignOut: () async {})));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('tab-chats')));
      await t.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/6-chats-$k.png'));
    });
  }
}
