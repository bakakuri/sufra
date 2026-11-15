// The team's panel: the numbers, reports, all content, people, verification, ads, a notification to many, the site's
// banner and sections, masked words, the phones' errors, the log; what a moderator sees; back one tab at a time.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/admin/admin.dart';
import 'package:peera/home/services.dart';
import 'package:peera/people/person_screen.dart';
import 'package:peera/profile/profile.dart';

import 'helpers.dart';

final _admin = Profile(id: 'u1', name: 'ნინო ბერიძე', surname: 'ბერიძე', username: 'nino.beridze', city: 'ქუთაისი', hue: 312, onboarded: true, role: 'admin');
final _mod = Profile(id: 'u1', name: 'ნინო ბერიძე', surname: 'ბერიძე', username: 'nino.beridze', city: 'ქუთაისი', hue: 312, onboarded: true, role: 'moderator');

Future<void> _open(WidgetTester t, {String? tab}) async {
  await t.tap(find.byKey(const ValueKey('tab-me')));
  await settle(t);
  openService(t.element(find.byType(PersonScreen).first), 'admin', arg: tab);
  await settle(t);
}

Finder _k(String key) => find.byKey(ValueKey(key));

Future<void> _tap(WidgetTester t, String key) async {
  await reveal(t, find.byKey(ValueKey(key), skipOffstage: false));
  await t.ensureVisible(find.byKey(ValueKey(key), skipOffstage: false));
  await settle(t);
  await t.tap(_k(key));
  await settle(t);
}

/// a button inside one card
Future<void> _tapIn(WidgetTester t, String card, String key) async {
  final f = find.descendant(of: _k(card), matching: _k(key));
  await t.ensureVisible(f);
  await settle(t);
  await t.tap(f);
  await settle(t);
}

Future<void> _type(WidgetTester t, String key, String text) async {
  await reveal(t, find.byKey(ValueKey(key), skipOffstage: false));
  await t.ensureVisible(find.byKey(ValueKey(key), skipOffstage: false));
  await settle(t);
  await t.enterText(_k(key), text);
  await t.pump();
}

Future<void> _yes(WidgetTester t, String word) async {
  await t.tap(find.widgetWithText(TextButton, word));
  await settle(t);
}

Future<void> _back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await settle(t);
}

void main() {
  setUpAll(useTestImages);

  testWidgets('the numbers and what waits; reports grouped: a post hidden resolves its reports, a profile limited, one reopened; back walks the tabs', (t) async {
    phone(t);
    final api = await shell(t, me: _admin);
    await _open(t);
    expect(find.byType(AdminScreen), findsOneWidget);
    expect(find.text('1,520'), findsOneWidget);
    expect(find.text('საჩივრები · 3'), findsOneWidget);
    expect(find.text('ვერიფიკაცია · 1'), findsOneWidget);
    expect(find.text('რეკლამა · 1'), findsOneWidget);
    await reveal(t, find.byKey(const ValueKey('ao-notify'), skipOffstage: false));
    expect(_k('ao-notify'), findsOneWidget);

    await _tap(t, 'at-reports');
    expect(_k('rep-post-105'), findsOneWidget);
    expect(_k('rep-user-u6'), findsOneWidget);
    expect(find.descendant(of: _k('rep-post-105'), matching: find.text('2 საჩივარი')), findsOneWidget);
    expect(find.text('დედაჩემის ხაჭაპური 😋'), findsOneWidget);
    expect(find.text('„იგივე რეკლამა ყველგან“'), findsOneWidget);

    await _tapIn(t, 'rep-post-105', 'rep-hide');
    expect(api.calls, containsAll(['modhide post 105 true', 'resolve report 1 resolved', 'resolve report 2 resolved']));
    expect(_k('rep-post-105'), findsNothing);
    expect(find.text('საჩივრები · 1'), findsOneWidget);

    await _tapIn(t, 'rep-user-u6', 'rep-ban');
    expect(find.text('მომხმარებლის შეზღუდვა'), findsOneWidget);
    await _yes(t, 'შეზღუდვა');
    expect(api.calls, containsAll(['ban u6 true', 'resolve report 3 resolved']));
    expect(find.text('საჩივრები არ არის'), findsOneWidget);

    await t.tap(find.text('გადაწყვეტილი'));
    await settle(t);
    expect(_k('rep-post-105'), findsOneWidget);
    await _tapIn(t, 'rep-user-u6', 'rep-reopen');
    expect(api.calls, contains('resolve report 3 open'));
    expect(_k('rep-user-u6'), findsNothing);

    // back: the reports, then the numbers, then out
    await _tap(t, 'at-log');
    expect(find.text('ნინო ბერიძე შეზღუდა: დათო'), findsOneWidget);
    expect(find.text('სისტემა დამალა: პოსტი #105'), findsOneWidget);
    await _back(t);
    expect(find.text('გადაწყვეტილი'), findsOneWidget);
    await _back(t);
    expect(find.text('1,520'), findsOneWidget);
    await _back(t);
    expect(find.byType(AdminScreen), findsNothing);
    expect(find.byType(PersonScreen), findsWidgets);
  });

  testWidgets('all content: by kind and words, a post hidden, a room ended for everyone, its author', (t) async {
    phone(t);
    final api = await shell(t, me: _admin);
    await _open(t, tab: 'content');
    expect(_k('acr-post-101'), findsOneWidget);
    await _tap(t, 'ach-101');
    expect(api.calls, contains('modhide post 101 true'));
    expect(find.descendant(of: _k('acr-post-101'), matching: find.text('დამალულია')), findsOneWidget);

    await _type(t, 'ac-q', 'მცხეთ');
    await t.pump(const Duration(milliseconds: 400));
    await settle(t);
    expect(api.calls, contains('content posts მცხეთ false'));
    expect(_k('acr-post-101'), findsOneWidget);
    expect(_k('acr-post-102'), findsNothing);

    await t.enterText(_k('ac-q'), '');
    await t.pump(const Duration(milliseconds: 400));
    await settle(t);
    await _tap(t, 'act-room');
    expect(_k('acr-room-30'), findsOneWidget);
    await _tap(t, 'ace-30');
    await _yes(t, 'დასრულება');
    expect(api.calls, contains('roomend 30'));
    expect(_k('ace-30'), findsNothing);
    expect(find.descendant(of: _k('acr-room-30'), matching: find.text('დასრულდა')), findsOneWidget);

    await _tap(t, 'aca-30');
    expect(_k('aus-info'), findsOneWidget);
    expect(find.text('გიორგი კაპანაძე'), findsWidgets);
  });

  testWidgets('people: found, written to from the team, given a role; a selfie approved; ads paused and a page ad approved', (t) async {
    phone(t);
    final api = await shell(t, me: _admin);
    await _open(t, tab: 'users');
    expect(api.calls, contains('users new'));
    await _type(t, 'au-q', 'გიორგი');
    await t.pump(const Duration(milliseconds: 400));
    await settle(t);
    expect(api.calls, contains('users new გიორგი'));
    expect(_k('au-u2'), findsOneWidget);
    expect(_k('au-u3'), findsNothing);

    await _tap(t, 'au-u2');
    expect(find.textContaining('user@example.com'), findsOneWidget);
    await _tap(t, 'aus-msg');
    await t.enterText(_k('al-text'), 'შენი პოსტი წაიშალა, რადგან წესებს არღვევდა');
    await t.tap(_k('al-ok'));
    await settle(t);
    expect(api.calls, contains('notify u2 შენი პოსტი წაიშალა, რადგან წესებს არღვევდა'));

    await _tap(t, 'au-u2');
    await _tap(t, 'aus-role-moderator');
    expect(find.text('როლის შეცვლა'), findsOneWidget);
    await _yes(t, 'შეცვლა');
    expect(api.calls, contains('role u2 moderator'));

    await _tap(t, 'at-verify');
    expect(_k('vr-5'), findsOneWidget);
    expect(find.text('ანა მელაძე'), findsOneWidget);
    await _tap(t, 'av-ok-5');
    expect(api.calls, contains('verify 5 true'));
    expect(find.text('მოთხოვნები არ არის'), findsOneWidget);

    await _tap(t, 'at-promo');
    expect(_k('pr-1'), findsOneWidget);
    expect(find.textContaining('1,200 ნახა · 84 დააჭირა · 7.0% დაჭერის წილი'), findsOneWidget);
    await _tap(t, 'ap-act-1');
    expect(api.calls, contains('promo 1 active false'));
    expect(find.descendant(of: _k('pr-1'), matching: find.text('პაუზაზეა')), findsOneWidget);

    await t.tap(find.textContaining('გვერდების'));
    await settle(t);
    expect(_k('pad-9'), findsOneWidget);
    expect(find.text('მთის ტურები'), findsOneWidget);
    await _tap(t, 'ad-ok-9');
    expect(api.calls, contains('ad 9 true'));
  });

  testWidgets("Peera's own ad written; a notification to many after asking, a test to me; the banner and a section switched off", (t) async {
    phone(t);
    final api = await shell(t, me: _admin);
    await _open(t, tab: 'promo');
    await _tap(t, 'ap-new-post');
    expect(find.byType(PromoEditor), findsOneWidget);
    // a link that is not the site's is not taken
    await _type(t, 'pe-title', 'ახალი სასწავლო ოთახები');
    await _type(t, 'pe-link', 'javascript:alert(1)');
    await _tap(t, 'pe-ok');
    expect(find.byType(PromoEditor), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('promo new')), isEmpty);
    await _tap(t, 'pe-l#rooms');
    await _tap(t, 'pe-photo');
    await _tap(t, 'pe-ok');
    expect(api.calls, contains('promo new post ახალი სასწავლო ოთახები'));
    expect(find.byType(PromoEditor), findsNothing);
    expect(_k('pr-2'), findsOneWidget);

    await _tap(t, 'at-notify');
    expect(find.text('მიიღებს 1500 ადამიანი'), findsOneWidget);
    await _type(t, 'an-t', 'Peera-ზე ახალი რეცეპტებია 🍲');
    await _tap(t, 'an-l#recipes');
    await _tap(t, 'an-test');
    expect(api.calls, contains('broadcast me Peera-ზე ახალი რეცეპტებია 🍲'));
    await _tap(t, 'an-go');
    expect(find.text('შეტყობინების გაგზავნა'), findsOneWidget);
    await _yes(t, 'გაგზავნა');
    expect(api.calls, contains('broadcast all Peera-ზე ახალი რეცეპტებია 🍲'));
    await reveal(t, find.byKey(const ValueKey('bc-2'), skipOffstage: false));
    expect(_k('bc-2'), findsOneWidget);

    await _tap(t, 'at-site');
    await _tap(t, 'bn-on');
    await _type(t, 'bn-t', 'გილოცავთ ახალ წელს! 🎄');
    await _tap(t, 'bn-tone');
    await t.tap(find.text('დღესასწაული'));
    await settle(t);
    expect(_k('bn-pv'), findsOneWidget);
    await _tap(t, 'bn-save');
    expect(api.calls, contains('setting banner true'));
    expect(api.settings['banner'], containsPair('tone', 'fest'));
    await _tap(t, 'feat-rooms');
    expect(api.calls, contains('setting features [rooms]'));
    expect(_k('feat-shop'), findsNothing);
    expect(_k('feat-games'), findsNothing);
  });

  testWidgets('masked words added and removed; the errors from phones grouped and cleared; pages verified', (t) async {
    phone(t);
    final api = await shell(t, me: _admin);
    await _open(t, tab: 'words');
    expect(_k('bw-ცუდი'), findsOneWidget);
    await _type(t, 'bw-i', 'სისულელე');
    await _tap(t, 'bw-add');
    expect(api.calls, contains('word სისულელე'));
    expect(_k('bw-სისულელე'), findsOneWidget);
    await t.tap(find.descendant(of: _k('bw-ცუდი'), matching: find.byTooltip('წაშლა')));
    await settle(t);
    expect(api.calls, contains('unword ცუდი'));
    expect(_k('bw-ცუდი'), findsNothing);

    await _tap(t, 'at-errors');
    expect(find.text('TypeError: x is null'), findsOneWidget);
    expect(find.textContaining('3-ჯერ · 3 ადამიანი'), findsOneWidget);
    await _tap(t, 'err-0');
    await _tap(t, 'err-del-0');
    expect(api.calls, contains('errdel TypeError: x is null'));

    await _tap(t, 'at-pages');
    expect(_k('apg-1'), findsOneWidget);
    await _tap(t, 'apv-1');
    expect(api.calls, contains('pverify 1 false'));
  });

  testWidgets('a moderator: no notifications or site; someone without a role goes to the site', (t) async {
    phone(t);
    await shell(t, me: _mod);
    await _open(t, tab: 'site');
    expect(find.byType(AdminScreen), findsOneWidget);
    expect(find.text('1,520'), findsOneWidget);
    expect(_k('at-reports'), findsOneWidget);
    expect(_k('at-notify'), findsNothing);
    expect(_k('at-site'), findsNothing);
    await reveal(t, find.byKey(const ValueKey('ao-notify'), skipOffstage: false));
    expect(find.byKey(const ValueKey('ao-notify'), skipOffstage: false), findsNothing);
    await _tap(t, 'at-users');
    await _tap(t, 'au-u2');
    expect(_k('aus-msg'), findsOneWidget);
    expect(_k('aus-role-moderator'), findsNothing);
    await _back(t);
    await _back(t);
    await _back(t);
    expect(find.byType(AdminScreen), findsNothing);

    await shell(t);
    await _open(t);
    expect(find.byType(AdminScreen), findsNothing);
  });
}
