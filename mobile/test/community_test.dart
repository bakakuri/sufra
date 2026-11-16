// Groups, pages and channels, events and the evening's planning, the market.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/chat/chat_screen.dart';
import 'package:peera/community/events.dart';
import 'package:peera/community/groups.dart';
import 'package:peera/community/market.dart';
import 'package:peera/community/page_pro.dart';
import 'package:peera/community/pages.dart';
import 'package:peera/feed/compose_screen.dart';
import 'package:peera/home/services.dart';
import 'package:peera/people/person_screen.dart';

import 'helpers.dart';

Future<void> _open(WidgetTester t, String service) async {
  await toProfile(t);
  await settle(t);
  openService(t.element(find.byType(PersonScreen).first), service);
  await settle(t);
}

/// words typed into a field that may be below the screen
Future<void> _type(WidgetTester t, String key, String text) async {
  await reveal(t, find.byKey(ValueKey(key), skipOffstage: false));
  await t.ensureVisible(find.byKey(ValueKey(key), skipOffstage: false));
  await settle(t);
  await t.enterText(find.byKey(ValueKey(key)), text);
}

Future<void> _tap(WidgetTester t, String key) async {
  // a list builds only what is near the screen
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

void main() {
  setUpAll(useTestImages);

  testWidgets('a group joined and written in; a closed one asked to join; back one step at a time', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'groups');
    expect(find.byType(GroupsScreen), findsOneWidget);
    expect(find.text('ჩემი ჯგუფები'), findsOneWidget);
    await _tap(t, 'grp-5');
    expect(find.byType(GroupScreen), findsOneWidget);
    expect(find.text('ჯგუფის წესები'), findsOneWidget);
    await _tap(t, 'g-join');
    expect(api.calls, contains('gjoin 5'));
    await _tap(t, 'g-post');
    expect(find.byType(ComposeScreen), findsOneWidget);
    expect(find.text('პოსტი: მთის მოყვარულები'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'შაბათს ყაზბეგზე მივდივართ');
    await t.pump();
    await _tap(t, 'c-pub');
    expect(api.calls, contains('post შაბათს ყაზბეგზე მივდივართ 0 group 5'));
    await _back(t);
    expect(find.byType(GroupScreen), findsNothing);
    expect(find.byType(GroupsScreen), findsOneWidget);

    await _tap(t, 'grp-6');
    expect(find.text('დახურული ჯგუფი'), findsOneWidget);
    await _tap(t, 'g-req');
    // the admin's questions are answered first
    await t.enterText(find.byKey(const ValueKey('greq-note')), 'თსუ-ში ვსწავლობ');
    await _tap(t, 'greq-send');
    expect(api.calls, isNot(contains('greq 6')));
    await t.enterText(find.byKey(const ValueKey('greq-a-0')), 'ზუსტ მეცნიერებათა');
    await t.enterText(find.byKey(const ValueKey('greq-a-1')), 'მესამე');
    await _tap(t, 'greq-send');
    expect(api.calls, contains('greq 6'));
    expect(api.calls, contains('greq-answers 6 ზუსტ მეცნიერებათა|მესამე'));
    expect(find.byKey(const ValueKey('g-reqx')), findsOneWidget);
  });

  testWidgets("a group's announcement, active members, topics, its own chat and events", (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'groups');
    await _tap(t, 'grp-5');
    expect(find.byKey(const ValueKey('g-pinned')), findsOneWidget);
    expect(find.text('მიმაგრებული'), findsOneWidget);
    expect(find.byKey(const ValueKey('g-stars')), findsOneWidget);
    await _tap(t, 'gtopic-ლაშქრობა');
    expect(api.calls, contains('gposts 5 ლაშქრობა'));
    expect(find.text('ამ რუბრიკაში ჯერ არაფერია'), findsOneWidget);
    await _tap(t, 'g-join');
    await _tap(t, 'g-post');
    // the topic being looked at is the new post's
    expect(find.byKey(const ValueKey('c-topic-ლაშქრობა')), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'კვირას თუშეთში');
    await t.pump();
    await _tap(t, 'c-pub');
    expect(api.calls, contains('post კვირას თუშეთში 0 group 5 topic ლაშქრობა'));
    await _tap(t, 'gtopic-all');
    await _tap(t, 'g-chat');
    expect(api.calls, contains('gchat 5'));
    expect(find.byType(ChatScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(GroupScreen), findsOneWidget);
    await _tap(t, 'gtb-events');
    expect(find.byKey(const ValueKey('ev-72')), findsOneWidget);
    expect(find.byKey(const ValueKey('g-event')), findsOneWidget);
    await _tap(t, 'gtb-about');
    expect(find.byKey(const ValueKey('g-about')), findsOneWidget);
    expect(find.text('# ფოტოები'), findsOneWidget);
  });

  testWidgets("my class's group managed: a request, a post approved, an admin; the invite with a QR code", (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'group');
    // no id: not found
    expect(find.text('ჯგუფი ვერ მოიძებნა'), findsOneWidget);
    await _back(t);
    openService(t.element(find.byType(PersonScreen).first), 'group', arg: '7');
    await settle(t);
    expect(find.byKey(const ValueKey('g-star')), findsOneWidget);
    await _tap(t, 'g-invite');
    expect(find.byKey(const ValueKey('ginv-qr')), findsOneWidget);
    await _back(t);
    await _tap(t, 'g-manage');
    expect(find.byType(GroupManageScreen), findsOneWidget);
    expect(find.text('მე-11 ბ-ში ვსწავლობდი'), findsOneWidget);
    expect(find.text('2014 წელს დავამთავრე'), findsOneWidget);
    await _tap(t, 'gm-ok-u4');
    expect(api.calls, contains('grespond 7 u4 true'));
    await _tap(t, 'gmt-pending');
    await _tap(t, 'gp-ok-102');
    expect(api.calls, contains('greview 102 true'));
    await _tap(t, 'gmt-members');
    await _tap(t, 'gm-role-u2');
    expect(api.calls, contains('grole 7 u2 admin'));
    await _tap(t, 'gm-mute-u3');
    await _tap(t, 'mute-60');
    expect(api.calls, contains('gmute 7 u3 60'));
    expect(find.textContaining('დადუმებულია'), findsOneWidget);
    await _tap(t, 'gmt-stats');
    expect(find.byKey(const ValueKey('gs-members')), findsOneWidget);
    await _tap(t, 'gmt-log');
    expect(find.byKey(const ValueKey('glog-3')), findsOneWidget);
    await _tap(t, 'gmt-settings');
    await _tap(t, 'gf-approval');
    await _type(t, 'gf-topic-new', 'სიახლეები');
    await _tap(t, 'gf-topic-add');
    expect(find.byKey(const ValueKey('gf-topic-სიახლეები')), findsOneWidget);
    await _type(t, 'gf-q-0', 'რომელ წელს დაამთავრე?');
    await _type(t, 'gf-words', 'რეკლამა, ფასდაკლება');
    await _tap(t, 'gf-ok');
    expect(api.calls.any((c) => c.startsWith('gupdate 7') && c.contains('topics') && c.contains('questions') && c.contains('blocked_words')), isTrue);
  });

  testWidgets('a new group from the list', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'groups');
    await _tap(t, 'groups-new');
    await t.enterText(find.byKey(const ValueKey('gf-name')), 'ქუთაისელები');
    await _tap(t, 'gf-ok');
    expect(api.calls, contains('newgroup ქუთაისელები false'));
    expect(find.byType(GroupScreen), findsOneWidget);
  });

  testWidgets('pages: one unfollowed, mine changed, a new channel', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'pages');
    expect(find.text('გამოწერილი'), findsWidgets);
    await _tap(t, 'pg-1');
    // following: how much I am told, or no more
    await _tap(t, 'p-follow');
    await _tap(t, 'pn-highlights');
    expect(api.calls, contains('pnotify 1 highlights'));
    await _tap(t, 'p-follow');
    await _tap(t, 'pn-unfollow');
    expect(api.calls, contains('pfollow 1 false'));
    await _back(t);
    await _tap(t, 'pg-2');
    await _tap(t, 'p-edit');
    await t.enterText(find.byKey(const ValueKey('pf-name')), 'სვანეთის ტურები');
    await _tap(t, 'pf-ok');
    expect(api.calls, contains('pupdate 2 სვანეთის ტურები'));
    await _back(t);
    await _tap(t, 'pages-new');
    await t.enterText(find.byKey(const ValueKey('pf-name')), 'ქუთაისის ამბები');
    await _tap(t, 'pf-ok');
    expect(api.calls, contains('newpage channel ქუთაისის ამბები'));
    expect(find.byType(PageScreen), findsOneWidget);
  });

  testWidgets('my business: its contacts and hours, reviews, numbers and co-admins', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'pages');
    await _tap(t, 'pg-2');
    expect(find.byKey(const ValueKey('p-rating')), findsOneWidget);
    await _tap(t, 'ptb-about');
    expect(find.byKey(const ValueKey('pa-hours')), findsOneWidget);
    expect(find.text('მესტია, სეტის მოედანი 3'), findsOneWidget);
    await _tap(t, 'pa-hours');
    expect(find.text('კვირა'), findsOneWidget);
    await _tap(t, 'ptb-reviews');
    expect(find.text('საუკეთესო ტური! გიდი ყველაფერს გვიყვებოდა.'), findsOneWidget);
    // a page's own people do not review it
    expect(find.byKey(const ValueKey('rv-write')), findsNothing);
    await _tap(t, 'p-stats');
    expect(find.byType(PageStatsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('ps-followers')), findsOneWidget);
    await _back(t);
    await _tap(t, 'p-admins');
    expect(find.byKey(const ValueKey('pam-u3')), findsOneWidget);
    await _tap(t, 'pa-add');
    await _tap(t, 'pick-u4');
    await _tap(t, 'pick-ok');
    await _tap(t, 'pa-role-admin');
    expect(api.calls, contains('padmin+ 2 u4 admin'));
    expect(find.byKey(const ValueKey('pam-u4')), findsOneWidget);
    await _back(t);
    // the business's details and hours
    await _tap(t, 'p-edit');
    await _type(t, 'pf-site', 'mta.ge');
    await _tap(t, 'pf-act-site');
    await _tap(t, 'pf-day-7');
    await _tap(t, 'pf-ok');
    expect(api.pageRows.firstWhere((p) => p['id'] == 2)['website'], 'https://mta.ge');
    expect(api.pageRows.firstWhere((p) => p['id'] == 2)['action'], 'site');
    expect((api.pageRows.firstWhere((p) => p['id'] == 2)['hours'] as Map)['7'], ['09:00', '19:00']);
  });

  testWidgets('a business written to and reviewed with stars', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'pages');
    await _tap(t, 'pg-3');
    await _tap(t, 'p-act');
    expect(api.calls, contains('dm u2'));
    expect(find.byType(ChatScreen), findsOneWidget);
    await _back(t);
    await _tap(t, 'ptb-reviews');
    expect(find.text('გემრიელია, ოღონდ რიგი იყო.'), findsOneWidget);
    await _tap(t, 'rv-write');
    await _tap(t, 'star-5');
    await t.enterText(find.byKey(const ValueKey('rv-body')), 'ყველაზე გემრიელი ხინკალი');
    await _tap(t, 'rv-send');
    expect(api.calls, contains('preview 3 5 ყველაზე გემრიელი ხინკალი'));
    expect(find.text('ყველაზე გემრიელი ხინკალი'), findsOneWidget);
    expect(find.text('ჩემი შეფასების შეცვლა'), findsOneWidget);
  });

  testWidgets("an event: coming, bringing something, the costs split and a debt received", (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'events');
    await _tap(t, 'ev-70');
    expect(find.byType(EventScreen), findsOneWidget);
    await t.tap(find.text('მოვდივარ'));
    await settle(t);
    expect(api.calls, contains('rsvp 70 yes'));
    await _tap(t, 'claim-2');
    expect(api.calls, contains('claim 2 true'));
    await _type(t, 'item-new', 'ტყემალი');
    await _tap(t, 'item-add');
    expect(api.calls, contains('item 70 ტყემალი'));
    await _type(t, 'cost-what', 'პიცა');
    await _type(t, 'cost-amount', '40');
    await _tap(t, 'cost-add');
    expect(api.calls, contains('cost 70 u1 40.0 პიცა'));
    expect(find.text('70 ₾'), findsOneWidget);
    await _tap(t, 'ev-got');
    expect(api.calls.any((c) => c.startsWith('pay 70 u3 u1')), isTrue);
  });

  testWidgets('a new event with a ready agenda and a leader', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'events');
    await _tap(t, 'events-new');
    await t.enterText(find.byKey(const ValueKey('ef-title')), 'შეხვედრა');
    await t.enterText(find.byKey(const ValueKey('ef-place')), 'ბიბლიოთეკა');
    await t.enterText(find.byKey(const ValueKey('ef-items')), 'ყავა, ნამცხვარი');
    await _tap(t, 'ef-ok');
    expect(api.calls, contains('event შეხვედრა ბიბლიოთეკა ყავა,ნამცხვარი'));
    expect(find.byType(EventScreen), findsOneWidget);
    await _tap(t, 'ag-classic');
    expect(api.calls, contains('agenda 71 9'));
    expect(find.text('გაცნობა'), findsOneWidget);
    await _tap(t, 'ev-tamada');
    await _tap(t, 'tam-u1');
    expect(api.calls, contains('tamada 71 u1'));
  });

  testWidgets('the market: kept, a message to the seller, mine sold, a new item', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'market');
    expect(find.byType(MarketScreen), findsOneWidget);
    await _tap(t, 'mki-90');
    await _tap(t, 'mk-save');
    expect(api.calls, contains('lsave 90 true'));
    await _tap(t, 'mk-chat');
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('გამარჯობა! „ნარდის დაფა“ ისევ იყიდება?'), findsOneWidget);
    await _back(t);
    await _back(t);
    await _tap(t, 'mkc-sport');
    expect(find.byKey(const ValueKey('mki-90')), findsNothing);
    await _tap(t, 'mki-91');
    await _tap(t, 'mk-sold');
    expect(api.calls, contains('lstatus 91 sold'));
    await _back(t);
    await _tap(t, 'mk-new');
    await t.enterText(find.byKey(const ValueKey('lf-title')), 'ნარდი');
    await t.enterText(find.byKey(const ValueKey('lf-price')), '50');
    await _tap(t, 'lf-ok');
    expect(api.calls, contains('listing ნარდი 50.0 tech ქუთაისი 0'));
  });
}
