import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/chat/chat_screen.dart';
import 'package:peera/feed/compose_screen.dart';
import 'package:peera/feed/feed_tab.dart';
import 'package:peera/home/calendar.dart';
import 'package:peera/home/home_cards.dart';
import 'package:peera/people/albums.dart';
import 'package:peera/people/cards.dart';
import 'package:peera/people/family.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';
import 'helpers.dart';

Future<void> _back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await settle(t);
}

/// the feed's own list (photos and the stories scroll sideways)
final _feed = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

Future<void> _to(WidgetTester t, String key, [double delta = 300]) async {
  await t.scrollUntilVisible(find.byKey(ValueKey(key)), delta, scrollable: _feed);
  await settle(t);
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(ValueKey(key), skipOffstage: false));
  await settle(t);
  await t.tap(find.byKey(ValueKey(key)));
  await settle(t);
}

Future<void> _calm(WidgetTester t) async {
  await t.pump(const Duration(seconds: 5));
  await settle(t);
}

void main() {
  setUpAll(useTestImages);

  testWidgets("the admin's banner: its button opens the page, the cross hides that text for good", (t) async {
    phone(t);
    SharedPreferences.setMockInitialValues({});
    final api = FakeApi()
      ..settings = {
        'banner': {'on': true, 'text': 'ახალი: საერთო ალბომები!', 'link': '#albums', 'cta': 'ნახვა', 'tone': 'fest'},
      };
    await shell(t, api: api);
    expect(find.text('ახალი: საერთო ალბომები!'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('banner-go')));
    await settle(t);
    expect(find.byType(AlbumsScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(AlbumsScreen), findsNothing);
    await t.tap(find.byKey(const ValueKey('banner-x')));
    await settle(t);
    expect(find.text('ახალი: საერთო ალბომები!'), findsNothing);
    // the app opened again: still hidden
    await t.pumpWidget(const SizedBox());
    await shell(t, api: api);
    expect(find.text('ახალი: საერთო ალბომები!'), findsNothing);
    // a new text shows again
    api.settings = {
      'banner': {'on': true, 'text': 'შაბათს სერვერზე სამუშაოებია', 'tone': 'warn'},
    };
    await t.pumpWidget(const SizedBox());
    await shell(t, api: api);
    expect(find.text('შაბათს სერვერზე სამუშაოებია'), findsOneWidget);
    expect(find.byKey(const ValueKey('banner-go')), findsNothing);
  });

  testWidgets("friends' days in the stories: the ring, a greeting from the sheet, the calendar; back one step at a time", (t) async {
    phone(t);
    final now = DateTime.now();
    final api = FakeApi()..bdays.add({'id': giorgi.id, 'name': giorgi.name, 'hue': giorgi.hue, 'avatar_url': null, 'month': now.month, 'day': now.day});
    await shell(t, api: api);
    expect(find.byKey(const ValueKey('story-remind')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('story-remind')), matching: find.text('დღეს')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('story-remind')));
    await settle(t);
    expect(find.text('არ დაგავიწყდეს'), findsOneWidget);
    expect(find.text('გიორგი კაპანაძე · დაბადების დღე'), findsOneWidget);
    await t.tap(find.byKey(ValueKey('greet-${giorgi.id}-b')));
    await settle(t);
    expect(find.byType(CardPicker), findsOneWidget);
    await _back(t);
    expect(find.byType(CardPicker), findsNothing);
    expect(find.text('არ დაგავიწყდეს'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('rem-calendar')));
    await settle(t);
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.text(['იანვარი', 'თებერვალი', 'მარტი', 'აპრილი', 'მაისი', 'ივნისი', 'ივლისი', 'აგვისტო', 'სექტემბერი', 'ოქტომბერი', 'ნოემბერი', 'დეკემბერი'][now.month - 1]), findsOneWidget);
    expect(find.text('გიორგი კაპანაძე · დაბადების დღე'), findsOneWidget);
    await _back(t);
    expect(find.byType(CalendarScreen), findsNothing);
    expect(find.text('არ დაგავიწყდეს'), findsNothing);
  });

  testWidgets('sponsored: a post among the posts with its button and hiding, a paid post with its tag, a story', (t) async {
    phone(t);
    SharedPreferences.setMockInitialValues({});
    final api = FakeApi();
    api.promoRows.addAll([
      {'id': 5, 'kind': 'post', 'brand': 'Peera', 'title': 'საერთო ალბომები', 'body': 'ქორწილის ფოტოები ერთ ადგილას', 'link': '#albums', 'cta': 'ალბომის შექმნა', 'every': 6, 'active': true},
      {'id': 6, 'kind': 'story', 'brand': 'ბიბლიოთეკა', 'media_url': 'https://t/sea.jpg', 'media_type': 'image', 'link': '#calendar', 'cta': 'გაიგე მეტი', 'active': true},
    ]);
    api.adRows.add((9, 108));
    await shell(t, api: api);
    // the story ring stands after mine
    expect(find.byKey(const ValueKey('story-promo-6')), findsOneWidget);
    await _to(t, 'promo-5');
    expect(find.text('საერთო ალბომები'), findsOneWidget);
    expect(api.calls, contains('promo 5'));
    await _tap(t, 'promo-go-5');
    expect(api.calls, contains('promo 5 click'));
    expect(find.byType(AlbumsScreen), findsOneWidget);
    await _back(t);
    await _tap(t, 'promo-more-5');
    await t.tap(find.byKey(const ValueKey('promo-hide')));
    await settle(t);
    expect(find.byKey(const ValueKey('promo-5'), skipOffstage: false), findsNothing);
    await _calm(t);
    // the paid post after the sixth, counted once
    await _to(t, 'ad-9');
    expect(find.descendant(of: find.byKey(const ValueKey('ad-9')), matching: find.text('რეკლამა')), findsOneWidget);
    expect(api.calls.where((x) => x == 'ad 9').length, 1);
    // the story: open, seen, its button, back
    await t.scrollUntilVisible(find.byKey(const ValueKey('story-promo-6')), -400, scrollable: _feed);
    await settle(t);
    await t.tap(find.byKey(const ValueKey('story-promo-6')));
    await settle(t);
    expect(find.byKey(const ValueKey('promo-story-go')), findsOneWidget);
    expect(api.calls, contains('promo 6'));
    await _back(t);
    expect(find.byKey(const ValueKey('promo-story-go')), findsNothing);
    await t.tap(find.byKey(const ValueKey('story-promo-6')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('promo-story-go')));
    await settle(t);
    expect(api.calls, contains('promo 6 click'));
    expect(find.byType(CalendarScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(CalendarScreen), findsNothing);
    // hidden on this phone: the next start has no promo post
    await t.pumpWidget(const SizedBox());
    await shell(t, api: api);
    expect(find.byKey(const ValueKey('promo-5'), skipOffstage: false), findsNothing);
  });

  testWidgets('the feed: for you, friends, the newest; my topics followed and a hashtag of my own', (t) async {
    phone(t);
    feedStartMode = 'for';
    addTearDown(() => feedStartMode = 'new');
    final api = FakeApi();
    await shell(t, api: api);
    final feed = t.state<FeedTabState>(find.byType(FeedTab));
    expect(feed.mode, 'for');
    expect(feed.posts, isNotEmpty);
    // friends: only my friends' posts and mine
    await _tap(t, 'feed-friends');
    expect(feed.posts.map((p) => p.author).toSet().difference({nino.id, giorgi.id, mariam.id, luka.id}), isEmpty);
    expect(find.byKey(const ValueKey('post-104'), skipOffstage: false), findsNothing);
    await _tap(t, 'feed-new');
    expect(feed.posts.first.id, 101);
    // my topics
    await _tap(t, 'topics');
    expect(find.text('ჩემი თემები'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('topic-5')));
    await settle(t);
    expect(api.calls, contains('tags +მოგზაურობა,მთა,ზღვა,ლაშქრობა'));
    await t.enterText(find.byKey(const ValueKey('tag-new')), '#სვანეთი');
    await t.tap(find.byKey(const ValueKey('tag-add')));
    await settle(t);
    expect(api.calls, contains('tags +სვანეთი'));
    expect(find.byKey(const ValueKey('tag-სვანეთი')), findsOneWidget);
    await t.tap(find.descendant(of: find.byKey(const ValueKey('tag-სვანეთი')), matching: find.byType(Icon)).first);
    await settle(t);
    expect(api.calls, contains('tags -სვანეთი'));
    await _back(t);
    expect(find.text('ჩემი თემები'), findsNothing);
    // for you with a topic followed: the post on მთა comes in, the friend's posts lean up
    await _tap(t, 'feed-for');
    expect(feed.posts.any((p) => p.id == 107), isTrue);
  });

  testWidgets('first steps: the card, a photo, where I am from, a person added, a first post from an idea', (t) async {
    phone(t);
    SharedPreferences.setMockInitialValues({});
    firstStepsOn = true;
    addTearDown(() => firstStepsOn = false);
    final api = FakeApi();
    await shell(t, api: api);
    expect(find.byKey(const ValueKey('fsteps')), findsOneWidget);
    expect(find.text('2 / 5 შესრულებულია'), findsOneWidget);
    await _tap(t, 'fs-photo');
    expect(find.text('დაამატე პროფილის ფოტო'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('fs-main')));
    await settle(t);
    expect(api.calls, contains('me avatar_url'));
    // school: skipped
    expect(find.text('სად სწავლობ ან სწავლობდი?'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('fs-skip')));
    await settle(t);
    // where from: the city is there already
    expect(find.text('ქუთაისი'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('fs-main')));
    await settle(t);
    expect(api.calls, contains('me city,home_region,home_place'));
    // five people: one asked
    await t.tap(find.byKey(ValueKey('fs-add-${tamar.id}')));
    await settle(t);
    expect(api.calls, contains('add ${tamar.id}'));
    expect(find.text('3/5'), findsOneWidget);
    await _calm(t);
    await t.tap(find.byKey(const ValueKey('fs-main')));
    await settle(t);
    // a first post from an idea
    await t.tap(find.byKey(const ValueKey('fs-idea-0')));
    await settle(t);
    expect(find.byType(ComposeScreen), findsOneWidget);
    expect(find.text('გამარჯობა, კურსელებო! 👋'), findsOneWidget);
    await t.tap(find.text('გამოქვეყნება'));
    await settle(t);
    expect(api.calls, contains('post გამარჯობა, კურსელებო! 👋 0'));
    await _calm(t);
    // the card counted the photo; hidden with its cross
    expect(find.text('3 / 5 შესრულებულია'), findsOneWidget);
    await _tap(t, 'fs-hide');
    expect(find.byKey(const ValueKey('fsteps')), findsNothing);
  });

  testWidgets('on this day: the memory, all of them by year, sharing one as a new post', (t) async {
    phone(t);
    final api = FakeApi()
      ..memory(90, 1, 'პირველი დღე უნივერსიტეტში 🎓')
      ..memory(91, 3, 'სკოლის ბოლო ზარი');
    await shell(t, api: api);
    await _to(t, 'memo');
    expect(find.text('ამ დღეს, 1 წლის წინ'), findsOneWidget);
    expect(find.text('პირველი დღე უნივერსიტეტში 🎓'), findsOneWidget);
    await _tap(t, 'memo-all');
    expect(find.text('სკოლის ბოლო ზარი'), findsOneWidget);
    expect(find.text('${DateTime.now().year - 3}'), findsOneWidget);
    await _back(t);
    await _tap(t, 'memo-share');
    expect(find.byType(ComposeScreen), findsOneWidget);
    expect(find.textContaining('მოგონება ${DateTime.now().year - 1} წლიდან 💭'), findsOneWidget);
  });

  testWidgets('the top bar: new guests counted, the services menu opens the app’s own pages, the create menu writes a poll', (t) async {
    phone(t);
    final api = await shell(t);
    expect(find.descendant(of: find.byKey(const ValueKey('guests')), matching: find.text('2')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('guests')));
    await settle(t);
    expect(find.descendant(of: find.byKey(const ValueKey('guests')), matching: find.text('2')), findsNothing);
    await _back(t);
    // all services: the tree here, the schedule on the site (marked)
    await t.tap(find.byKey(const ValueKey('services')));
    await settle(t);
    expect(find.byKey(const ValueKey('menu-rooms-birja')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('menu-tree')));
    await settle(t);
    expect(find.byType(TreeScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(TreeScreen), findsNothing);
    // a poll from the create menu
    await t.tap(find.byKey(const ValueKey('create')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('create-cpoll')));
    await settle(t);
    expect(find.byKey(const ValueKey('poll-box')), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('poll-q')), 'სად შევხვდეთ?');
    await t.enterText(find.byKey(const ValueKey('poll-o-0')), 'კაფეში');
    await t.tap(find.text('გამოქვეყნება'));
    await settle(t);
    expect(find.text('გამოკითხვას სჭირდება კითხვა და მინიმუმ 2 პასუხი'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('poll-o-1')), 'ბიბლიოთეკაში');
    await t.tap(find.byKey(const ValueKey('poll-add')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('poll-o-2')), 'პარკში');
    await _calm(t);
    await t.tap(find.text('გამოქვეყნება'));
    await settle(t);
    expect(api.calls, contains('post  0 poll სად შევხვდეთ? კაფეში/ბიბლიოთეკაში/პარკში'));
    expect(find.byType(ComposeScreen), findsNothing);
  });

  testWidgets('the services strip: a side card turns to the middle, the middle one opens; the numbers show', (t) async {
    phone(t);
    final api = await shell(t);
    expect(find.byKey(const ValueKey('svc-schedule')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('svc-side-1')));
    await settle(t);
    expect(find.byKey(const ValueKey('svc-exams')), findsOneWidget);
    expect(find.text('2 ცოცხლად'), findsOneWidget);
    // three more to the classmates, which the app opens itself (no school yet: the school page)
    for (var i = 0; i < 2; i++) {
      await t.tap(find.byKey(ValueKey('svc-side-${i + 2}')));
      await settle(t);
    }
    await t.tap(find.byKey(const ValueKey('svc-classmates')));
    await settle(t);
    expect(find.text('ჩემი განათლება'), findsOneWidget);
    await _back(t);
    expect(find.text('ჩემი განათლება'), findsNothing);
    expect(api.calls.where((x) => x.startsWith('mates')), isEmpty);
  });

  testWidgets('people you may know inside the feed: added from the card', (t) async {
    phone(t);
    final api = await shell(t);
    await _to(t, 'suggest');
    await t.tap(find.byKey(ValueKey('sug-add-${tamar.id}')));
    await settle(t);
    expect(api.calls, contains('add ${tamar.id}'));
    expect(find.descendant(of: find.byKey(ValueKey('sug-${tamar.id}')), matching: find.text('გაგზავნილია')), findsOneWidget);
  });

  testWidgets('the welcome gift is said once; inviting friends from it tells the coins and who came', (t) async {
    phone(t);
    SharedPreferences.setMockInitialValues({});
    final api = FakeApi()..welcome = 100;
    await shell(t, api: api);
    expect(find.text('მოგესალმებით Peera-ზე!'), findsOneWidget);
    await t.tap(find.text('მეგობრების მოწვევა'));
    await settle(t);
    expect(find.text('მოიწვიე მეგობრები'), findsOneWidget);
    expect(find.textContaining('100 მონეტას მიიღებს საჩუქრად'), findsOneWidget);
    expect(find.textContaining('50 მონეტას თითოეულზე'), findsOneWidget);
    expect(find.text('შენი ბმულით დარეგისტრირდა 3 · +100 მონეტა'), findsOneWidget);
    expect(find.textContaining('https://www.peera.my/?i=nino.beridze'), findsOneWidget);
    await _back(t);
    expect(find.text('მოიწვიე მეგობრები'), findsNothing);
    // once only
    await t.pumpWidget(const SizedBox());
    await shell(t, api: api);
    expect(find.text('მოგესალმებით Peera-ზე!'), findsNothing);
  });
}
