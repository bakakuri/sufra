// Places, help, rides, the match room, jobs, the kitchen and the toast book.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/community/events.dart';
import 'package:peera/community/help.dart';
import 'package:peera/community/jobs.dart';
import 'package:peera/community/kitchen.dart';
import 'package:peera/community/rides.dart';
import 'package:peera/community/sport.dart';
import 'package:peera/community/toasts.dart';
import 'package:peera/feed/compose_screen.dart';
import 'package:peera/home/services.dart';
import 'package:peera/people/person_screen.dart';
import 'package:peera/places/places.dart';
import 'package:peera/profile/profile.dart';

import 'fake_api.dart';
import 'helpers.dart';

Future<void> _open(WidgetTester t, String service) async {
  await t.tap(find.byKey(const ValueKey('tab-me')));
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
    expect(find.text('საუკეთესო ადგილი სასწავლად'), findsOneWidget);
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
    expect(find.text('შეფასებები · 3'), findsOneWidget);
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
    await _tap(t, 'fx-send');
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

  testWidgets('the kitchen: portions change the amounts, cooking a step at a time, the ingredients taken to an event, "I made it too", a new recipe', (t) async {
    phone(t);
    final api = FakeApi()..rsvps.add({'event_id': 70, 'user_id': 'u1', 'status': 'yes'});
    await shell(t, api: api);
    await _open(t, 'recipes');
    expect(find.byKey(const ValueKey('rcp-2')), findsOneWidget);
    await _tap(t, 'rcc-ცომეული');
    expect(find.byKey(const ValueKey('rcp-2')), findsNothing);
    await _tap(t, 'rcp-1');
    expect(find.byType(RecipeScreen), findsOneWidget);
    expect(find.text('4 პორცია'), findsOneWidget);
    await _tap(t, 'rc-less');
    await _tap(t, 'rc-less');
    expect(find.text('2 პორცია'), findsOneWidget);
    expect(find.text('250 გ'), findsOneWidget);
    expect(find.text('½ კგ'), findsOneWidget);
    expect(find.text('¼ კონა'), findsOneWidget);
    await _tap(t, 'rc-like');
    expect(api.calls, contains('rlike 1 true'));
    expect(find.text('გემრიელია · 13'), findsOneWidget);

    await _tap(t, 'rc-cook');
    expect(find.text('ნაბიჯი 1 / 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('ck-timer')), findsOneWidget);
    await _tap(t, 'ck-next');
    expect(find.text('ნაბიჯი 2 / 3'), findsOneWidget);
    await _back(t);
    expect(find.byType(CookScreen), findsNothing);
    expect(find.byType(RecipeScreen), findsOneWidget);

    await _tap(t, 'rc-event');
    await _tap(t, 'rce-i-3');
    await _tap(t, 'rce-ok');
    expect(api.calls, contains('items 70 ფქვილი (250 გ)|საქონლის ხორცი (½ კგ)|ხახვი (1)'));
    expect(find.byType(EventScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(RecipeScreen), findsOneWidget);

    await _tap(t, 'rc-made');
    await t.enterText(find.byKey(const ValueKey('rcm-note')), 'გამომივიდა');
    await _tap(t, 'rcm-ok');
    expect(api.calls, contains('cooked 1 false გამომივიდა'));
    expect(find.text('გამომივიდა'), findsOneWidget);
    await _back(t);

    await _tap(t, 'rc-new');
    await t.enterText(find.byKey(const ValueKey('rcf-title')), 'ლობიანი');
    await _tap(t, 'rcf-c-ცომეული');
    await _type(t, 'rcf-in-0', 'ლობიო');
    await _type(t, 'rcf-iq-0', '500 გ');
    await _type(t, 'rcf-st-0', 'მოხარშე ლობიო 1 საათი.');
    await _tap(t, 'rcf-ok');
    expect(api.calls, contains('recipe new ლობიანი 1 1'));
    expect(find.byType(RecipeScreen), findsOneWidget);
  });

  testWidgets('the toast book: liked, by occasion, mine changed, a new one, another posted', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'toasts');
    expect(find.byKey(const ValueKey('tc-1')), findsOneWidget);
    await _tap(t, 'tl-1');
    expect(api.calls, contains('tlike 1 true'));
    expect(find.text('31'), findsOneWidget);
    await _tap(t, 'tm-1');
    await _tap(t, 'tm-post');
    expect(find.byType(ComposeScreen), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is TextField && (w.controller?.text.startsWith('🍷 სუფრის სადღეგრძელო') ?? false)), findsOneWidget);
    await _back(t);
    expect(find.byType(ToastsScreen), findsOneWidget);

    await _tap(t, 'tso-friends');
    expect(api.calls, contains('toasts friends top'));
    expect(find.byKey(const ValueKey('tc-1')), findsNothing);
    await _tap(t, 'tm-2');
    await _tap(t, 'tm-edit');
    await t.enterText(find.byKey(const ValueKey('tn-title')), 'მეგობრების სადღეგრძელო');
    await _tap(t, 'tn-ok');
    expect(api.calls, contains('toast 2 friends მეგობრების სადღეგრძელო'));
    expect(find.text('მეგობრების სადღეგრძელო'), findsOneWidget);

    await _tap(t, 'ts-new');
    await _tap(t, 'tn-o-love');
    await t.enterText(find.byKey(const ValueKey('tn-title')), 'სიყვარულის სადღეგრძელო');
    await t.enterText(find.byKey(const ValueKey('tn-body')), 'გაუმარჯოს სიყვარულს, რომელიც ყველაფერს ძლევს.');
    await _tap(t, 'tn-ok');
    expect(api.calls, contains('toast new love სიყვარულის სადღეგრძელო'));
    expect(api.calls, contains('toasts friends new'));
  });

  test('amounts follow the portions; a step names its minutes', () {
    expect(scaleAmount('500 გ', .5), '250 გ');
    expect(scaleAmount('½ კონა', 2), '1 კონა');
    expect(scaleAmount('2–3 კბილი', 2), '4–6 კბილი');
    expect(scaleAmount('მარილი გემოვნებით', 3), 'მარილი გემოვნებით');
    expect(scaleAmount('1 კგ', 1.5), '1½ კგ');
    expect(stepMinutes('მოხარშე 12–15 წუთი.'), 15);
    expect(stepMinutes('გამოაცხვე 1 საათი'), 60);
    expect(stepMinutes('მოზილე ცომი'), 0);
    expect(cookTime(90), '1 სთ 30 წთ');
    expect(gel(0), 'უფასოდ');
    expect(salaryText({'salary_from': 1200}), '1,200 ₾-დან');
    expect(helpKind('blood').$3, '🩸');
    expect(occasionName('wedding'), 'ქორწილი');
  });
}
