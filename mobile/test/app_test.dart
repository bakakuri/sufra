import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/auth/auth_screen.dart';
import 'package:peera/main.dart';
import 'package:peera/shell/home_shell.dart';
import 'package:peera/shell/tab_bar.dart';

import 'helpers.dart';

Future<void> _back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await t.pumpAndSettle();
}

void main() {
  testWidgets('back undoes one step and never drops out of the app by surprise', (t) async {
    phone(t);
    var exits = 0;
    await t.pumpWidget(PeeraApp(home: HomeShell(me: nino, onSignOut: () async {}, exit: () => exits++)));
    await t.pumpAndSettle();
    final shell = t.state<HomeShellState>(find.byType(HomeShell));
    expect(shell.index, 0);

    // to the games tab, then back: the main tab again, the app still open
    await t.tap(find.byKey(const ValueKey('tab-games')));
    await t.pumpAndSettle();
    expect(shell.index, 5);
    await _back(t);
    expect(shell.index, 0);
    expect(exits, 0);

    // on the main tab the first back only asks
    await _back(t);
    expect(find.text(HomeShellState.exitHint), findsOneWidget);
    expect(exits, 0);
    // a second back within two seconds closes the app
    await _back(t);
    expect(exits, 1);
  });

  testWidgets('the seven tabs of the site, messages raised in the middle', (t) async {
    phone(t);
    await t.pumpWidget(PeeraApp(home: HomeShell(me: nino, onSignOut: () async {})));
    await t.pumpAndSettle();
    for (final tab in tabs) {
      expect(find.descendant(of: find.byKey(ValueKey('tab-${tab.id}')), matching: find.text(tab.label)), findsOneWidget);
    }
    await t.tap(find.byKey(const ValueKey('tab-chats')));
    await t.pumpAndSettle();
    expect(t.state<HomeShellState>(find.byType(HomeShell)).index, tabMid);
    await t.tap(find.byKey(const ValueKey('tab-me')));
    await t.pumpAndSettle();
    expect(find.text('@nino.beridze'), findsOneWidget);
    expect(find.text('12 450 ქოინი'), findsOneWidget);
  });

  testWidgets('sign in checks the fields, then calls the server', (t) async {
    phone(t);
    final api = FakeAuth();
    await t.pumpWidget(PeeraApp(home: AuthScreen(api: api)));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'შესვლა'));
    await t.pumpAndSettle();
    expect(find.text('ელფოსტის მისამართი არასწორია'), findsOneWidget);
    expect(api.calls, isEmpty);
    await t.enterText(find.byType(TextFormField).at(0), 'nino@peera.my');
    await t.enterText(find.byType(TextFormField).at(1), 'secret123');
    await t.tap(find.widgetWithText(FilledButton, 'შესვლა'));
    await t.pumpAndSettle();
    expect(api.calls, ['in nino@peera.my']);
  });

  testWidgets('sign up asks for 8 characters and says when the e-mail must be confirmed', (t) async {
    phone(t);
    final api = FakeAuth()..ready = false;
    await t.pumpWidget(PeeraApp(home: AuthScreen(api: api, startUp: true)));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), 'ნინო');
    await t.enterText(find.byType(TextFormField).at(1), 'nino@peera.my');
    await t.enterText(find.byType(TextFormField).at(2), 'short');
    await t.tap(find.widgetWithText(FilledButton, 'ანგარიშის შექმნა'));
    await t.pumpAndSettle();
    expect(find.text('პაროლი მინიმუმ 8 სიმბოლო უნდა იყოს'), findsOneWidget);
    await t.enterText(find.byType(TextFormField).at(2), 'longenough');
    await t.tap(find.widgetWithText(FilledButton, 'ანგარიშის შექმნა'));
    await t.pumpAndSettle();
    expect(api.calls, ['up nino@peera.my ნინო']);
    expect(find.textContaining('დადასტურების ბმული'), findsOneWidget);
  });
}
