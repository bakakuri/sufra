// Places, help, rides, the match room and jobs.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/community/help.dart';
import 'package:peera/community/jobs.dart';
import 'package:peera/community/rides.dart';
import 'package:peera/community/sport.dart';
import 'package:peera/feed/compose_screen.dart';
import 'package:peera/home/services.dart';
import 'package:peera/people/person_screen.dart';
import 'package:peera/places/places.dart';
import 'package:peera/profile/profile.dart';

import 'helpers.dart';

Future<void> _open(WidgetTester t, String service) async {
  await toProfile(t);
  await settle(t);
  openService(t.element(find.byType(PersonScreen).first), service);
  await settle(t);
}

Future<void> _tap(WidgetTester t, String key) async {
  await reveal(t, find.byKey(ValueKey(key), skipOffstage: false));
  await t.ensureVisible(find.byKey(ValueKey(key), skipOffstage: false));
  await settle(t);
  await t.tap(find.byKey(ValueKey(key)));
  await settle(t);
}

Future<void> _back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await settle(t);
}

Future<void> _type(WidgetTester t, String key, String text) async {
  await reveal(t, find.byKey(ValueKey(key), skipOffstage: false));
  await t.ensureVisible(find.byKey(ValueKey(key), skipOffstage: false));
  await settle(t);
  await t.enterText(find.byKey(ValueKey(key)), text);
  await t.pump();
}

final _admin = Profile(id: 'u1', name: 'ნინო ბერიძე', surname: 'ბერიძე', username: 'nino.beridze', city: 'ქუთაისი', hue: 312, onboarded: true, role: 'admin');

void main() {
  setUpAll(useTestImages);

  testWidgets('places: by kind on the map, in a list; one place with its route, call, a review with a photo, "I am here"', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'places');
    expect(find.byType(PlacesScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('pl-map')), findsOneWidget);
    expect(find.text('ამ ხედზე · 2'), findsOneWidget);
    await _tap(t, 'plk-cafe');
    expect(api.calls, contains('places cafe'));
    expect(find.byKey(const ValueKey('spot-1')), findsNothing);
    expect(find.byKey(const ValueKey('spot-2')), findsOneWidget);
    await _tap(t, 'plk-');
    await t.tap(find.text('სია'));
    await settle(t);
    expect(find.text('ახლოს · 2'), findsOneWidget);
    await _tap(t, 'spot-1');
    expect(find.byType(PlaceScreen), findsOneWidget);
    expect(find.text('შეფასებები · 2'), findsOneWidget);
    await reveal(t, find.text('საუკეთესო ადგილი სასწავლად', skipOffstage: false));
    expect(find.text('საუკეთესო ადგილი სასწავლად', skipOffstage: false), findsOneWidget);
    await _tap(t, 'pl-route');
    expect(openedLinks.last, startsWith('https://www.openstreetmap.org/directions?to=41.6995'));
    await _tap(t, 'pl-call');
    expect(openedLinks.last, 'tel:+995322000000');
    await _tap(t, 'pl-review');
    await t.tap(find.byKey(const ValueKey('rv-s4')));
    await t.pump();
    await t.enterText(find.byKey(const ValueKey('rv-body')), 'კარგი ადგილია');
    await _tap(t, 'rv-photo');
    await _tap(t, 'rv-ok');
    expect(api.calls, contains('review 1 4 კარგი ადგილია 1'));
    await reveal(t, find.text('შეფასებები · 3', skipOffstage: false));
    expect(find.text('შეფასებები · 3', skipOffstage: false), findsOneWidget);
    await _tap(t, 'pl-here');
    expect(find.byType(ComposeScreen), findsOneWidget);
    expect(find.text('📍 ეროვნული ბიბლიოთეკა'), findsOneWidget);
    // nothing written: back leaves without asking, one step at a time
    await _back(t);
    expect(find.byType(ComposeScreen), findsNothing);
    expect(find.byType(PlaceScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(PlaceScreen), findsNothing);
    expect(find.byType(PlacesScreen), findsOneWidget);
  });

  testWidgets('a new place: marked at my location, one like it nearby is asked about', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'places');
    await _tap(t, 'pl-new');
    await t.enterText(find.byKey(const ValueKey('plf-name')), 'კაფე');
    await _tap(t, 'plf-k-bar');
    await _tap(t, 'plf-ok');
    expect(find.text('მონიშნე ადგილი რუკაზე'), findsOneWidget);
    await _tap(t, 'plf-me');
    expect(find.text('41.71510, 44.82710'), findsOneWidget);
    await _tap(t, 'plf-ok');
    expect(find.text('ასეთი ადგილი უკვე არის?'), findsOneWidget);
    await _tap(t, 'plf-force');
    expect(api.calls, contains('place new კაფე bar'));
    expect(find.byType(PlaceScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(PlacesScreen), findsOneWidget);
  });

  testWidgets('help: by kind, told about blood requests in my region, one answered, mine resolved, a new one with photos', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'help');
    expect(find.byKey(const ValueKey('hc-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('hc-3')), findsNothing);
    await _tap(t, 'hlf-pets');
    expect(find.byKey(const ValueKey('hc-1')), findsNothing);
    expect(find.byKey(const ValueKey('hc-2')), findsOneWidget);
    await _tap(t, 'hlf-');
    await _tap(t, 'hl-done');
    expect(find.byKey(const ValueKey('hc-3')), findsOneWidget);

    await _tap(t, 'hl-set');
    await _tap(t, 'hs-blood');
    await _tap(t, 'hs-ok');
    expect(find.text('აირჩიე რეგიონი'), findsOneWidget);
    await _tap(t, 'hs-region');
    await t.tap(find.text('იმერეთი').last);
    await settle(t);
    await _tap(t, 'hs-bt');
    await t.tap(find.text('A+').last);
    await settle(t);
    await _tap(t, 'hs-ok');
    expect(api.calls, contains('helper იმერეთი A+ true false false'));
    expect(find.text('შეტყობინებები ჩართულია · იმერეთი · დონორი A+'), findsOneWidget);

    await _tap(t, 'hc-1');
    expect(find.byType(HelpRequestScreen), findsOneWidget);
    await _tap(t, 'hr-contact');
    expect(openedLinks.last, 'tel:+995555123456');
    await _tap(t, 'hr-offer');
    await t.enterText(find.byKey(const ValueKey('ho-note')), 'შემიძლია ხვალ დილით');
    await _tap(t, 'ho-send');
    expect(api.calls, contains('offer 1 შემიძლია ხვალ დილით'));
    expect(find.byKey(const ValueKey('hr-unoffer')), findsOneWidget);
    await _back(t);

    await _tap(t, 'hc-2');
    expect(find.byKey(const ValueKey('ho-u2')), findsOneWidget);
    await _tap(t, 'hr-resolve');
    await t.tap(find.widgetWithText(TextButton, 'მოგვარდა'));
    await settle(t);
    expect(api.calls, contains('resolve 2'));
    expect(find.byKey(const ValueKey('hr-resolve')), findsNothing);
    await _back(t);

    await _tap(t, 'hl-new');
    await _tap(t, 'hn-k-lost_pet');
    await t.enterText(find.byKey(const ValueKey('hn-title')), 'დაიკარგა კატა');
    await _tap(t, 'hn-photo');
    expect(find.byKey(const ValueKey('hn-rm-1')), findsOneWidget);
    await _tap(t, 'hn-ok');
    expect(api.calls, contains('helpnew lost_pet დაიკარგა კატა'));
    expect(api.calls.where((c) => c.startsWith('upload')).length, 2);
    expect(find.byType(HelpRequestScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(HelpScreen), findsOneWidget);
  });

  testWidgets('rides: found to Batumi and booked for two, the booking withdrawn; my ride: a passenger confirmed, the ride cancelled; a new one', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'rides');
    expect(find.byKey(const ValueKey('rc-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('rc-2')), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('rd-to')), 'ბათუმი');
    await _tap(t, 'rd-go');
    expect(find.byKey(const ValueKey('rc-2')), findsNothing);
    await _tap(t, 'rc-1');
    expect(find.byType(RideScreen), findsOneWidget);
    expect(find.text('თავისუფალი 3 / 3 · 25 ₾ ერთ ადგილზე'), findsOneWidget);
    await _tap(t, 'rb-more');
    expect(find.text('2 ადგილი'), findsOneWidget);
    await _tap(t, 'rd-book');
    expect(api.calls, contains('book 1 2'));
    expect(find.text('მოთხოვნა გაგზავნილია · 2 ადგილი'), findsOneWidget);
    await _tap(t, 'rd-quit');
    await t.tap(find.widgetWithText(TextButton, 'გაუქმება'));
    await settle(t);
    expect(api.calls, contains('unbook 1'));
    expect(find.byKey(const ValueKey('rd-book')), findsOneWidget);
    await _back(t);

    await t.tap(find.text('ჩემი'));
    await settle(t);
    expect(api.calls, contains('rides mine'));
    expect(find.text('1 ახალი მოთხოვნა'), findsOneWidget);
    await _tap(t, 'rc-2');
    await _tap(t, 'bk-ok-u4');
    expect(api.calls, contains('respond 2 u4 true'));
    expect(find.byKey(const ValueKey('bk-chat-u4')), findsOneWidget);
    await _tap(t, 'rd-cancel');
    await t.tap(find.widgetWithText(TextButton, 'გაუქმება'));
    await settle(t);
    expect(api.calls, contains('ridecancel 2'));
    expect(find.text('მძღოლმა გააუქმა'), findsOneWidget);
    await _back(t);

    await _tap(t, 'rd-new');
    await t.enterText(find.byKey(const ValueKey('rf-to')), 'ბათუმი');
    await _tap(t, 'rf-more');
    await _type(t, 'rf-price', '30');
    await _tap(t, 'rf-ok');
    expect(api.calls, contains('ride ქუთაისი ბათუმი 4 30'));
    expect(find.byType(RideScreen), findsOneWidget);
  });

  testWidgets('the match room: a free prediction, the live chat, the finished match and my predictions', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'sport');
    expect(find.byKey(const ValueKey('fx-new')), findsNothing);
    expect(find.byKey(const ValueKey('fx-2')), findsNothing);
    await _tap(t, 'fx-1');
    expect(find.byType(FixtureScreen), findsOneWidget);
    expect(find.text('დღეს ვიგებთ!'), findsOneWidget);
    await _tap(t, 'fxp-X');
    await _tap(t, 'fx-go');
    expect(api.calls, contains('predict 1 X'));
    expect(find.text('შენი პროგნოზი: ფრე · უფასო'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('fx-msg')), 'გოოოლ!');
    // the toast above may still cover the send button: the keyboard's send
    await t.testTextInput.receiveAction(TextInputAction.send);
    await settle(t);
    expect(api.calls, contains('fxsay 1 გოოოლ!'));
    expect(find.text('გოოოლ!'), findsOneWidget);
    api.fxLive.add({'id': 99, 'fixture_id': 1, 'user_id': 'u3', 'body': 'ვაა, რა გოლია!', 'created_at': DateTime.now().toIso8601String()});
    await t.pump();
    await settle(t);
    expect(find.text('ვაა, რა გოლია!'), findsOneWidget);
    await _back(t);
    await t.tap(find.text('დასრულებული'));
    await settle(t);
    expect(find.text('2:1'), findsOneWidget);
    await t.tap(find.text('ჩემი'));
    await settle(t);
    expect(find.text('შენი: მასპინძელი · მოგება +5'), findsOneWidget);
  });

  testWidgets('the match room for a moderator: a new match and its result', (t) async {
    phone(t);
    final api = await shell(t, me: _admin);
    await _open(t, 'sport');
    await _tap(t, 'fx-new');
    await t.enterText(find.byKey(const ValueKey('fxn-home')), 'საქართველო');
    await t.enterText(find.byKey(const ValueKey('fxn-away')), 'ესპანეთი');
    await _tap(t, 'fxn-ok');
    expect(api.calls, contains('fixture საქართველო ესპანეთი'));
    expect(find.byType(FixtureScreen), findsOneWidget);
    await _type(t, 'fs-h', '2');
    await _type(t, 'fs-a', '0');
    await _tap(t, 'fs-ok');
    await t.tap(find.widgetWithText(TextButton, 'დადასტურება'));
    await settle(t);
    expect(api.calls, contains('settle 3 2 0'));
  });

  testWidgets('the match room: matches that came by themselves show their live score, under their day, by league; a finished one is under the finished', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'sport');
    // the one on now first, with its score; the one over (its result not yet confirmed) is not a coming one
    expect(find.text('ახლა მიმდინარე'), findsOneWidget);
    expect(find.text('1:0'), findsOneWidget);
    expect(find.text('ხვალ'), findsOneWidget);
    expect(find.byKey(const ValueKey('fx-5')), findsNothing);
    // no staff line for everyone else
    expect(find.byKey(const ValueKey('fx-sync')), findsNothing);
    // how people predicted, as three green bars with their shares
    expect(api.calls, contains('pools 2'));
    expect(find.descendant(of: find.byKey(const ValueKey('fxsplit-4')), matching: find.textContaining('%')), findsNWidgets(3));
    expect(find.descendant(of: find.byKey(const ValueKey('fxsplit-4')), matching: find.text('67%')), findsOneWidget);
    // one league
    await _tap(t, 'fxlg-პრემიერ ლიგა');
    expect(find.byKey(const ValueKey('fx-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('fx-1')), findsNothing);
    await _tap(t, 'fxlg-all');
    expect(find.byKey(const ValueKey('fx-1')), findsOneWidget);
    // the live one: its score in the head of the page
    await _tap(t, 'fx-4');
    expect(t.widget<Text>(find.byKey(const ValueKey('fx-score'))).data, '1:0');
    expect(find.text('ცოცხლად'), findsOneWidget);
    await _back(t);
    // the finished ones: the one waiting for staff, with the source's score
    await t.tap(find.text('დასრულებული'));
    await settle(t);
    expect(find.byKey(const ValueKey('fx-5')), findsOneWidget);
    expect(find.text('3:3'), findsOneWidget);
  });

  testWidgets('the match room for a moderator: a finished match confirmed in one tap, a team named right, how the automatic matches do', (t) async {
    phone(t);
    final api = await shell(t, me: _admin);
    await _open(t, 'sport');
    final list = find.descendant(of: find.byType(SportScreen), matching: find.byType(Scrollable)).first;
    expect(find.text('შედეგი დასადასტურებელია · 1'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const ValueKey('fx-sync')), 300, scrollable: list);
    expect(find.textContaining('ავტომატური მატჩები ჩართულია'), findsOneWidget);
    await _tap(t, 'fxok-5');
    expect(find.textContaining('რეალ მადრიდი 3:3 Unknownia'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'დადასტურება'));
    await settle(t);
    expect(api.calls, contains('settle 5 3 3'));
    expect(find.text('შედეგი დასადასტურებელია · 1'), findsNothing);
    // a name set right
    await _tap(t, 'fx-4');
    await _tap(t, 'fs-names');
    expect(find.text('ეს სახელი ამ გუნდის შემდეგ მატჩებსაც გადაჰყვება.'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('fn-a')), 'ტოტენჰემ ჰოტსპური');
    await _tap(t, 'fn-ok');
    expect(api.calls, contains('fxnames 4 არსენალი ტოტენჰემ ჰოტსპური'));
    expect(find.text('ტოტენჰემ ჰოტსპური'), findsWidgets);
    // a look that went wrong is said (the list looks again on coming back)
    api.syncState = {'on': true, 'error': 'http 403: restricted'};
    await _back(t);
    await t.scrollUntilVisible(find.byKey(const ValueKey('fx-sync')), 300, scrollable: list);
    expect(find.textContaining('შეცდომა — http 403'), findsOneWidget);
  });

  testWidgets('jobs: by category, one applied to; mine: a CV seen, a candidate invited, closed; a new vacancy; mine and applied', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'jobs');
    expect(find.byKey(const ValueKey('job-1')), findsOneWidget);
    await _tap(t, 'jbc-it');
    expect(api.calls, contains('jobs it'));
    expect(find.byKey(const ValueKey('job-2')), findsNothing);
    await _tap(t, 'job-1');
    expect(find.text('2,500–4,000 ₾'), findsOneWidget);
    await _tap(t, 'jb-apply');
    expect(find.byKey(const ValueKey('ja-cv')), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('ja-cover')), 'React-ის გამოცდილება მაქვს');
    await _tap(t, 'ja-send');
    expect(api.calls, contains('apply 1 React-ის გამოცდილება მაქვს'));
    expect(find.text('ახალი'), findsOneWidget);
    await _back(t);
    await _tap(t, 'jbc-');

    await _tap(t, 'job-2');
    expect(find.byKey(const ValueKey('app-u2')), findsOneWidget);
    await _tap(t, 'app-cv-u2');
    expect(api.calls, contains('appst 2 u2 seen'));
    expect(find.text('ფოტოგრაფი'), findsWidgets);
    await _back(t);
    expect(find.text('ფოტოგრაფი'), findsNothing);
    await _tap(t, 'app-inv-u2');
    expect(api.calls, contains('appst 2 u2 invited'));
    await _tap(t, 'jb-toggle');
    expect(api.calls, contains('jobst 2 closed'));
    await _back(t);

    await _tap(t, 'jb-new');
    await t.enterText(find.byKey(const ValueKey('jf-title')), 'მზარეული');
    await _tap(t, 'jf-t-part');
    await _type(t, 'jf-s1', '1500');
    await _tap(t, 'jf-ok');
    expect(api.calls, contains('job მზარეული it part 1500'));
    expect(find.byType(JobScreen), findsOneWidget);
    await _back(t);

    await _tap(t, 'jb-mine');
    expect(find.byType(MyJobsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('myapp-1')), findsOneWidget);
  });
}
