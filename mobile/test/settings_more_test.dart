// The settings' last pieces: the economy mode, my data in one file, deleting the account.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/data/stores.dart';
import 'package:peera/people/person_screen.dart';
import 'package:peera/settings/settings_screens.dart';
import 'package:peera/ui/look.dart';

import 'helpers.dart';

Future<void> _settings(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('tab-me')));
  await settle(t);
  openPage(t.element(find.byType(PersonScreen).first), const SettingsScreen());
  await settle(t);
}

Finder get _list => find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first;

void main() {
  setUpAll(useTestImages);

  testWidgets('the economy mode: the feed shows photos on a touch', (t) async {
    phone(t);
    await shell(t);
    await _settings(t);
    await t.tap(find.byKey(const ValueKey('set-look')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('look-eco')));
    await settle(t);
    expect(ecoMode.value, isTrue);
    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.textContaining('ეკონომიური რეჟიმი'), findsOneWidget);
    await t.binding.handlePopRoute();
    await settle(t);
    await t.tap(find.byKey(const ValueKey('tab-home')));
    await settle(t);
    expect(find.byKey(const ValueKey('eco-101')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('eco-101')));
    await settle(t);
    expect(find.byKey(const ValueKey('eco-101')), findsNothing);
    ecoMode.value = false;
  });

  testWidgets('my data downloaded into one file', (t) async {
    phone(t);
    final api = await shell(t);
    await _settings(t);
    await t.scrollUntilVisible(find.byKey(const ValueKey('set-export')), 300, scrollable: _list);
    await t.tap(find.byKey(const ValueKey('set-export')));
    await settle(t);
    expect(api.calls, contains('export'));
    final f = savedFiles['peera-data.json'];
    expect(f, isNotNull);
    expect((jsonDecode(utf8.decode(f!)) as Map)['profile']['name'], 'ნინო ბერიძე');
    expect(find.text('შენახულია ჩამოტვირთვებში: peera-data.json'), findsOneWidget);
  });

  testWidgets('deleting the account asks for "წაშლა" first', (t) async {
    phone(t);
    final api = await shell(t);
    await _settings(t);
    await t.scrollUntilVisible(find.byKey(const ValueKey('set-delete')), 300, scrollable: _list);
    await t.tap(find.byKey(const ValueKey('set-delete')));
    await settle(t);
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('del-go')));
    await settle(t);
    expect(api.calls, isNot(contains('delete account')));
    await t.enterText(find.byKey(const ValueKey('del-confirm')), 'წაშლა');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('del-go')));
    await settle(t);
    expect(api.calls, contains('delete account'));
    expect(find.byType(DeleteAccountScreen), findsNothing);
  });
}
