import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/auth/auth_screen.dart';
import 'package:peera/chat/chat_screen.dart';
import 'package:peera/clips/clip_composer.dart';
import 'package:peera/clips/clip_feed.dart';
import 'package:peera/data/models.dart';
import 'package:peera/dating/dating_setup.dart';
import 'package:peera/stories/stories.dart';
import 'package:peera/feed/compose_screen.dart';
import 'package:peera/feed/comments_sheet.dart';
import 'package:peera/feed/post_screen.dart';
import 'package:peera/games/games_tab.dart';
import 'package:peera/joker/engine.dart';
import 'package:peera/joker/joker_tab.dart';
import 'package:peera/joker/online.dart';
import 'package:peera/joker/online_screen.dart';
import 'package:peera/joker/table_screen.dart';
import 'package:peera/nardi/nardi_tab.dart';
import 'package:peera/main.dart';
import 'package:peera/map/live_map.dart';
import 'package:peera/map/loc_device.dart';
import 'package:peera/media/voice.dart';
import 'package:peera/data/stores.dart';
import 'package:peera/people/albums.dart';
import 'package:peera/people/cards.dart';
import 'package:peera/people/coins.dart';
import 'package:peera/people/cv_edit.dart';
import 'package:peera/people/edu.dart';
import 'package:peera/people/family.dart';
import 'package:peera/people/my_space.dart';
import 'package:peera/people/verify.dart';
import 'package:peera/people/friends_tab.dart';
import 'package:peera/people/person_screen.dart';
import 'package:peera/people/photos.dart';
import 'package:peera/notes/notes_screen.dart';
import 'package:peera/home/services.dart';
import 'package:peera/profile/profile.dart';
import 'package:peera/people/namedays.dart';
import 'package:peera/push/push.dart';
import 'package:peera/settings/edit_profile.dart';
import 'package:peera/settings/settings_screens.dart';
import 'package:peera/shell/home_shell.dart';
import 'package:peera/shell/tab_bar.dart';
import 'package:peera/ui/sparkles.dart';
import 'package:peera/ui/icons.dart';
import 'package:peera/ui/look.dart';
import 'package:peera/ui/widgets.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';
import 'helpers.dart';

Future<void> _back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await settle(t);
}

/// scrolls the dating card's form until [f] is built and on screen ([delta] < 0 goes up)
Future<void> _formTo(WidgetTester t, Finder f, [double delta = 250]) async {
  await t.scrollUntilVisible(f, delta, scrollable: find.descendant(of: find.byType(DatingSetup), matching: find.byType(Scrollable)).first);
  await settle(t);
}

/// the feed's own list (photos inside it scroll sideways)
final _feed = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

Future<void> _tab(WidgetTester t, String id) async {
  await t.tap(find.byKey(ValueKey('tab-$id')));
  await settle(t);
}

/// Joker's page: the games tab, then Joker's card
Future<void> _jokerPage(WidgetTester t) async {
  await _tab(t, 'joker');
  await t.tap(find.byKey(const ValueKey('games-joker')));
  await settle(t);
}

void main() {
  setUpAll(useTestImages);

  testWidgets('back undoes one step and never drops out of the app by surprise', (t) async {
    phone(t);
    var exits = 0;
    await shell(t, exit: () => exits++);
    final s = t.state<HomeShellState>(find.byType(HomeShell));
    expect(s.index, 0);

    // friends tab → a friend's page (inside the tab) → back: the list → back: the main tab
    await _tab(t, 'friends');
    await t.tap(find.byKey(const ValueKey('seg-0')));
    await settle(t);
    await t.tap(find.text('გიორგი კაპანაძე').first);
    await settle(t);
    expect(find.byType(PersonScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(PersonScreen), findsNothing);
    expect(s.index, 1);
    await _back(t);
    expect(s.index, 0);

    // a conversation opens over everything; back closes only it
    await _tab(t, 'chats');
    await t.tap(find.text('გიორგი კაპანაძე').first);
    await settle(t);
    expect(find.byType(ChatScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(ChatScreen), findsNothing);
    expect(s.index, tabMid);
    await _back(t);
    expect(s.index, 0);

    // a post's comments open under it like an accordion, their window over them; back closes one at a time
    await t.ensureVisible(find.byKey(const ValueKey('comments-101')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('comments-101')));
    await settle(t);
    expect(find.byKey(const ValueKey('inline-cm-101')), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('all-cm-101')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('all-cm-101')));
    await settle(t);
    expect(find.byType(CommentsPanel), findsOneWidget);
    await _back(t);
    expect(find.byType(CommentsPanel), findsNothing);
    expect(find.byKey(const ValueKey('inline-cm-101')), findsOneWidget);
    await _back(t);
    expect(find.byKey(const ValueKey('inline-cm-101')), findsNothing);
    expect(s.index, 0);
    expect(exits, 0);

    // tab after tab: back walks them back one at a time
    await _tab(t, 'friends');
    await _tab(t, 'chats');
    await _back(t);
    expect(s.index, 1);
    await _back(t);
    expect(s.index, 0);

    // the logo leads home from any page: from the notifications over the app, opened on another tab
    await _tab(t, 'friends');
    await t.tap(find.byKey(const ValueKey('bell')).first);
    await settle(t);
    expect(find.byType(NotesScreen), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('top-logo')).last);
    await settle(t);
    expect(find.byType(NotesScreen), findsNothing);
    expect(s.index, 0);
    await _back(t);
    expect(s.index, 1);
    await _back(t);
    expect(s.index, 0);
    expect(exits, 0);

    // on the main tab the first back only asks; a second one within two seconds closes the app
    await _back(t);
    expect(find.text(HomeShellState.exitHint), findsOneWidget);
    expect(exits, 0);
    await _back(t);
    expect(exits, 1);
  });

  testWidgets('the seven tabs as pictures: the Peera mark, my picture in a ring, messages raised in the middle, unread on the badges', (t) async {
    phone(t);
    await shell(t);
    final s = t.state<HomeShellState>(find.byType(HomeShell));
    for (final tab in tabs) {
      // no words under them: a picture each, the word only as its tooltip
      expect(find.byKey(ValueKey('tab-${tab.id}')), findsOneWidget);
      expect(find.descendant(of: find.byKey(ValueKey('tab-${tab.id}')), matching: find.text(tab.label)), findsNothing);
      expect(find.descendant(of: find.byKey(ValueKey('tab-${tab.id}')), matching: find.byTooltip(tab.label)), findsOneWidget);
    }
    expect(find.descendant(of: find.byKey(const ValueKey('tab-home')), matching: find.byType(PeeraMark)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('tab-me')), matching: find.byType(Avatar)), findsOneWidget);
    expect(tabs.firstWhere((x) => x.id == 'joker').label, 'თამაშები');
    // 2 from გიორგი + 5 in the group; one friend request
    expect(find.descendant(of: find.byKey(const ValueKey('tab-chats')), matching: find.text('7')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('tab-friends')), matching: find.text('1')), findsOneWidget);
    // making something: the round "+" over the feed, none in the header; it stays in its place as the feed scrolls
    expect(find.byTooltip('შექმნა'), findsNothing);
    final plus = find.byKey(const ValueKey('create'));
    final at = t.getTopLeft(plus);
    await t.drag(_feed, const Offset(0, -500));
    await settle(t);
    expect(t.getTopLeft(plus), at);
    await t.tap(plus);
    await settle(t);
    expect(find.byKey(const ValueKey('create-cpost')), findsOneWidget);
    await _back(t);
    // only on the feed
    await _tab(t, 'clips');
    expect(find.byKey(const ValueKey('create')), findsNothing);
    await _tab(t, 'home');
    expect(s.index, 0);
    expect(find.byKey(const ValueKey('create')), findsOneWidget);
    // my picture on the feed leads to my profile too
    await toFeed(t);
    await t.tap(find.byKey(const ValueKey('compose-me')));
    await settle(t);
    expect(s.index, tabs.indexWhere((x) => x.id == 'me'));
    await _back(t);
    expect(s.index, 0);
    await _tab(t, 'me');
    expect(find.text('@nino.beridze'), findsOneWidget);
    expect(find.text('12 450'), findsOneWidget);
  });

  testWidgets('small pictures sit in a ring and now and then stars and Peera marks scatter from them; mine on the bar most often', (t) async {
    phone(t);
    sparklesOn = true;
    addTearDown(() => sparklesOn = false);
    await shell(t);
    final me = find.byKey(const ValueKey('me-sparkles'));
    Finder burstIn(Finder f) => find.descendant(of: f, matching: find.byKey(const ValueKey('sparkles')));
    // nothing flies before the first burst; mine comes a little after the start
    expect(burstIn(me), findsNothing);
    await t.pump(const Duration(milliseconds: 1000));
    await t.pump(const Duration(milliseconds: 300));
    expect(burstIn(me), findsOneWidget);
    expect(t.binding.hasScheduledFrame, isTrue);
    // the feed's small pictures: each in its ring, ready to sparkle (the big ones and the story rings' own pictures
    // are not ringed twice)
    final post = find.byKey(const ValueKey('post-101'));
    expect(find.descendant(of: post, matching: find.byType(Sparkles)), findsWidgets);
    expect(find.descendant(of: find.byKey(const ValueKey('story-me')), matching: find.byType(Sparkles)), findsOneWidget);
    expect(t.widget<Avatar>(find.descendant(of: find.byKey(const ValueKey('story-me')), matching: find.byType(Avatar))).ringed, isFalse);
    // within a dozen seconds the others have had their turn too
    for (var i = 0; i < 120; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(burstIn(post), findsWidgets);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('the feed: posts, a reaction picked and taken back, a vote', (t) async {
    phone(t);
    final api = await shell(t);
    expect(find.text('გიორგი კაპანაძე'), findsWidgets);
    expect(find.textContaining('მზის ჩასვლა'), findsOneWidget);

    // მარიამ's post has no reaction of mine yet: the button opens the seven
    await t.scrollUntilVisible(find.byKey(const ValueKey('react-102')), 300, scrollable: _feed);
    await settle(t);
    await t.tap(find.byKey(const ValueKey('react-102')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('react-😂')));
    await settle(t);
    expect(api.calls, contains('react 102 😂'));
    // tapping again takes it back
    await t.tap(find.byKey(const ValueKey('react-102')));
    await settle(t);
    expect(api.calls.last, 'react 102 null');

    await t.scrollUntilVisible(find.text('მთაში'), 300, scrollable: _feed);
    await t.ensureVisible(find.text('მთაში'));
    await settle(t);
    await t.tap(find.text('მთაში'));
    await settle(t);
    expect(api.calls.last, 'vote 103 1');
    expect(find.text('55%'), findsOneWidget);
  });

  testWidgets('comments: the last five under the post, all of them in the window, one answered', (t) async {
    phone(t);
    final api = await shell(t);
    await t.ensureVisible(find.byKey(const ValueKey('comments-101')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('comments-101')));
    await settle(t);
    // the last five comments (here three; the answer to the first is folded), the oldest of them first, the first one
    // saying it has an answer
    expect(api.calls, contains('cpage 101 0 5'));
    final rows = [for (final id in [1, 3, 4]) t.getTopLeft(find.byKey(ValueKey('icm-$id'))).dy];
    expect(rows, orderedEquals([...rows]..sort()));
    expect(find.byKey(const ValueKey('icm-2')), findsNothing);
    // the answers come right under their comment, as on Facebook, and open there
    final inl = find.byKey(const ValueKey('inline-cm-101'));
    final tg = find.descendant(of: inl, matching: find.byKey(const ValueKey('cthread-1')));
    expect(find.descendant(of: tg, matching: find.text('ყველა 2 პასუხის ნახვა')), findsOneWidget);
    expect(t.getTopLeft(tg).dy, greaterThan(t.getTopLeft(find.byKey(const ValueKey('icm-1'))).dy));
    expect(t.getTopLeft(tg).dy, lessThan(t.getTopLeft(find.byKey(const ValueKey('icm-3'))).dy));
    await t.ensureVisible(tg);
    await settle(t);
    await t.tap(tg);
    await settle(t);
    expect(find.byKey(const ValueKey('icm-2')), findsOneWidget);
    expect(find.descendant(of: inl, matching: find.byKey(const ValueKey('cto-2'))), findsOneWidget);
    // answered right there
    final r2 = find.descendant(of: inl, matching: find.byKey(const ValueKey('creply-2')));
    await t.ensureVisible(r2);
    await settle(t);
    await t.tap(r2);
    await settle(t);
    expect(find.byKey(const ValueKey('icm-to-101')), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('icm-field-101')), 'მეც მინდა');
    await t.pump();
    await t.tap(find.byTooltip('კომენტარის გაგზავნა'));
    await settle(t);
    expect(api.calls, contains('comment 101 მეც მინდა ↩2'));
    expect(find.descendant(of: inl, matching: find.text('მეც მინდა')), findsOneWidget);
    expect(find.byKey(const ValueKey('icm-to-101')), findsNothing);
    // one written straight from the feed, sent with the keyboard's own send key
    await t.enterText(find.byKey(const ValueKey('icm-field-101')), 'რა ლამაზია');
    await t.pump();
    await t.testTextInput.receiveAction(TextInputAction.send);
    await settle(t);
    expect(api.calls, contains('comment 101 რა ლამაზია'));
    expect(find.descendant(of: find.byKey(const ValueKey('inline-cm-101')), matching: find.text('რა ლამაზია')), findsOneWidget);

    // all of them, the newest first, in the window
    await t.ensureVisible(find.byKey(const ValueKey('all-cm-101')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('all-cm-101')));
    await settle(t);
    expect(api.calls, contains('cpage 101 0 15'));
    final panel = find.byType(CommentsPanel);
    Finder inP(Finder f) => find.descendant(of: panel, matching: f);
    expect(inP(find.text('კომენტარები · 7')), findsOneWidget);
    // an answer is folded under its comment until asked for, as on Facebook
    expect(inP(find.text('ჯვრის მონასტერთან ახლოს 🙂')), findsNothing);
    expect(inP(find.text('ყველა 3 პასუხის ნახვა')), findsOneWidget);
    await t.tap(inP(find.byKey(const ValueKey('cthread-1'))));
    await settle(t);
    expect(inP(find.text('ჯვრის მონასტერთან ახლოს 🙂')), findsOneWidget);
    // one step in, saying whom it answers; the answer to it one step further, folded under it
    expect(inP(find.byKey(const ValueKey('cto-2'))), findsOneWidget);
    expect(inP(find.text('ზუსტად, მცხეთის თავზე')), findsNothing);
    // (the list builds only what is near the screen)
    final list = inP(find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)).first;
    await t.scrollUntilVisible(inP(find.byKey(const ValueKey('cthread-2'))), 100, scrollable: list);
    await settle(t);
    await t.tap(inP(find.byKey(const ValueKey('cthread-2'))));
    await settle(t);
    await t.scrollUntilVisible(inP(find.text('ზუსტად, მცხეთის თავზე')), 100, scrollable: list);
    await settle(t);
    // the three steps, each one further in
    int depthOf(String s) =>
        t.widget<CommentTile>(find.descendant(of: panel, matching: find.ancestor(of: find.text(s, skipOffstage: false), matching: find.byType(CommentTile, skipOffstage: false)), skipOffstage: false).first).depth;
    expect([depthOf('რა ლამაზია! სად არის ზუსტად?'), depthOf('ჯვრის მონასტერთან ახლოს 🙂'), depthOf('ზუსტად, მცხეთის თავზე')], [0, 1, 2]);
    expect(inP(find.byKey(const ValueKey('cto-5'))), findsOneWidget);
    // an answer can be answered too
    expect(inP(find.byKey(const ValueKey('creply-2'))), findsOneWidget);
    await t.scrollUntilVisible(inP(find.byKey(const ValueKey('creply-1'))), -100, scrollable: list);
    await settle(t);
    await t.tap(inP(find.byKey(const ValueKey('creply-1'))));
    await settle(t);
    expect(inP(find.text('პასუხი: მარიამ')), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('cs-field')), 'ზაფხულში ისევ წავალთ');
    await t.pump();
    await t.tap(inP(find.byTooltip('გაგზავნა')));
    await settle(t);
    expect(api.calls, contains('comment 101 ზაფხულში ისევ წავალთ ↩1'));
    expect(inP(find.text('ზაფხულში ისევ წავალთ')), findsOneWidget);
    expect(inP(find.text('კომენტარები · 8')), findsOneWidget);
    // an answer to one already two steps in stays on that step, names its author and is tagged with them
    await t.scrollUntilVisible(inP(find.byKey(const ValueKey('creply-5'))), 100, scrollable: list);
    await settle(t);
    await t.tap(inP(find.byKey(const ValueKey('creply-5'))));
    await settle(t);
    final f = t.widget<TextField>(find.byKey(const ValueKey('cs-field')));
    expect(f.controller!.text, startsWith('@luka.g '));
    await t.enterText(find.byKey(const ValueKey('cs-field')), '${f.controller!.text}მეც იქ ვიყავი');
    await t.pump();
    await t.tap(inP(find.byTooltip('გაგზავნა')));
    await settle(t);
    expect(api.calls, contains('comment 101 @luka.g მეც იქ ვიყავი ↩5'));
    final mine = api.lastComment!;
    expect(mine.parentId, 2);
    expect(inP(find.byKey(ValueKey('cto-${mine.id}'))), findsOneWidget);
    expect(inP(find.descendant(of: find.byKey(ValueKey('cto-${mine.id}')), matching: find.textContaining('ლუკა'))), findsOneWidget);
  });

  testWidgets('writing a post with two photos puts it at the top of the feed', (t) async {
    phone(t);
    final api = await shell(t);
    await t.tap(find.byKey(const ValueKey('compose')));
    await settle(t);
    expect(find.byType(ComposeScreen), findsOneWidget);
    await t.enterText(find.byType(TextField), 'პირველი პოსტი აპიდან');
    await t.tap(find.text('ფოტო'));
    await settle(t);
    expect(find.text('2/10'), findsOneWidget);
    await t.tap(find.text('გამოქვეყნება'));
    await settle(t);
    expect(api.calls.where((c) => c.startsWith('upload')).length, 2);
    expect(api.calls, contains('post პირველი პოსტი აპიდან 2'));
    expect(find.byType(ComposeScreen), findsNothing);
    expect(find.text('პირველი პოსტი აპიდან'), findsOneWidget);
  });

  testWidgets('a half-written post asks before it is thrown away', (t) async {
    phone(t);
    await shell(t);
    await t.tap(find.byKey(const ValueKey('compose')));
    await settle(t);
    await t.enterText(find.byType(TextField), 'ჯერ არ დამიმთავრებია');
    await t.pump();
    await _back(t);
    expect(find.text('პოსტი არ გამოქვეყნდება'), findsOneWidget);
    // back again closes only the question
    await _back(t);
    expect(find.text('პოსტი არ გამოქვეყნდება'), findsNothing);
    expect(find.byType(ComposeScreen), findsOneWidget);
  });

  testWidgets('friend requests: accepted from the list', (t) async {
    phone(t);
    final api = await shell(t);
    await _tab(t, 'friends');
    // the request waits first
    expect(find.textContaining('მეგობრობას გთხოვს'), findsOneWidget);
    await t.tap(find.text('დადასტურება'));
    await settle(t);
    expect(api.calls, contains('accept u5'));
    expect(find.textContaining('მეგობრობას გთხოვს'), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('tab-friends')), matching: find.text('1')), findsNothing);
  });

  testWidgets('friends: my relatives from the family tree with its words, then the friends online now, then all of them', (t) async {
    phone(t);
    final api = FakeApi();
    // გიორგი is my brother in my tree (he said yes); ლუკა was asked and has not answered yet
    api.kinRows.add({'id': 9, 'owner': 'u1', 'anchor': null, 'relative': 'u2', 'name': null, 'relation': 'sibling', 'sex': 'm', 'born': null, 'died': null, 'status': 'ok'});
    await shell(t, api: api);
    await _tab(t, 'friends');
    await t.tap(find.byKey(const ValueKey('seg-0')));
    await settle(t);
    expect(find.descendant(of: find.byKey(const ValueKey('seg-0')), matching: find.text('ყველა მეგობარი')), findsOneWidget);
    expect(find.text('ნათესავები'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('kin-u2')), matching: find.text('ძმა')), findsOneWidget);
    expect(find.byKey(const ValueKey('kin-u4')), findsNothing);
    // the friends online now: only them, in a row
    expect(find.text('ონლაინ მეგობრები'), findsOneWidget);
    expect(find.byKey(const ValueKey('fr-on-u2')), findsOneWidget);
    expect(find.byKey(const ValueKey('fr-on-u3')), findsNothing);
    final y = [for (final k in ['kin-u2', 'fr-on-u2']) t.getTopLeft(find.byKey(ValueKey(k))).dy];
    expect(y[0], lessThan(y[1]));
    expect(t.getTopLeft(find.text('ყველა მეგობარი').last).dy, greaterThan(y[1]));
    // a relative opens their profile
    await t.tap(find.byKey(const ValueKey('kin-u2')));
    await settle(t);
    expect(find.byType(PersonScreen), findsOneWidget);
    await _back(t);
    // with no relatives on Peera, the family tree is offered
    api.kinRows.removeWhere((r) => r['id'] == 9);
    await t.drag(find.byKey(const ValueKey('kin-u2')), const Offset(0, 300));
    await settle(t);
    expect(find.byKey(const ValueKey('kin-hint')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('kin-hint')));
    await settle(t);
    expect(find.byType(TreeScreen), findsOneWidget);
  });

  testWidgets('a conversation: read on open, a reply sent, a message arriving live', (t) async {
    phone(t);
    final api = await shell(t);
    await _tab(t, 'chats');
    await t.tap(find.text('გიორგი კაპანაძე').first);
    await settle(t);
    expect(find.text('ხვალ 7-ზე შევხვდეთ?'), findsOneWidget);
    expect(api.calls, contains('read 1'));
    await t.enterText(find.byType(TextField), 'კი, შევხვდეთ 👍');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('chat-send')));
    await settle(t);
    expect(api.calls, contains('send 1 text კი, შევხვდეთ 👍'));
    expect(find.text('კი, შევხვდეთ 👍'), findsOneWidget);
    api.push(1, 'u2', 'სუპერ, გელოდები!');
    await settle(t);
    expect(find.text('სუპერ, გელოდები!'), findsOneWidget);
    await _back(t);
    // its unread are gone from the badge: only the group's five stay
    expect(find.descendant(of: find.byKey(const ValueKey('tab-chats')), matching: find.text('5')), findsOneWidget);
  });

  testWidgets('a message from another conversation shows at the top and opens it', (t) async {
    phone(t);
    final api = await shell(t);
    api.liveNote.add({'kind': 'message', 'actor': 'u3', 'ref': {'conv': 2, 'text': 'სად ხარ? 🙂'}});
    await settle(t);
    expect(find.text('სად ხარ? 🙂'), findsOneWidget);
    await t.tap(find.text('სად ხარ? 🙂'));
    await settle(t);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(api.calls, contains('read 2'));
    // back closes the conversation, nothing else
    await _back(t);
    expect(find.byType(ChatScreen), findsNothing);
    expect(t.state<HomeShellState>(find.byType(HomeShell)).index, 0);
  });

  testWidgets('clips: one to a screen, ❤️ and comments, back goes one step', (t) async {
    phone(t);
    final api = await shell(t);
    await _tab(t, 'clips');
    expect(find.textContaining('გუდაურში'), findsOneWidget);
    // მარიამ's clip already has my ❤️; გიორგი's does not
    await t.tap(find.byKey(const ValueKey('clip-like-301')));
    await settle(t);
    expect(api.calls, contains('react 301 ❤️'));
    expect(find.text('133'), findsOneWidget);
    // a clip's comments come up over it, the same as a post's (no page of its own)
    await t.tap(find.byKey(const ValueKey('clip-comments-301')));
    await settle(t);
    expect(find.byType(CommentsPanel), findsOneWidget);
    await _back(t);
    expect(find.byType(CommentsPanel), findsNothing);
    expect(find.textContaining('გუდაურში'), findsOneWidget);
    // swipe up: the next clip
    await t.fling(find.byType(ClipFeed), const Offset(0, -500), 1500);
    await settle(t);
    expect(find.textContaining('ბათუმის'), findsOneWidget);
    await _back(t);
    expect(t.state<HomeShellState>(find.byType(HomeShell)).index, 0);
  });

  testWidgets('a new clip: chosen, made ready, published at the top', (t) async {
    phone(t);
    final api = await shell(t);
    await _tab(t, 'clips');
    await t.tap(find.byTooltip('კლიპის ატვირთვა'));
    await settle(t);
    expect(find.byType(ClipComposer), findsOneWidget);
    expect(find.textContaining('9.0 მბ'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'ჩემი პირველი კლიპი');
    await t.tap(find.text('გამოქვეყნება'));
    await settle(t);
    expect(api.calls, containsAll(['video 720x1280', 'clip ჩემი პირველი კლიპი']));
    expect(find.byType(ClipComposer), findsNothing);
    expect(find.text('ჩემი პირველი კლიპი'), findsOneWidget);
  });

  testWidgets('stories: watched, answered, closed with back', (t) async {
    phone(t);
    final api = await shell(t);
    expect(find.byType(StoriesBar), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('story-u2')));
    await settle(t);
    expect(find.byType(StoryViewer), findsOneWidget);
    // გიორგი's first one was seen: it starts at the second
    expect(api.calls, contains('seen 402'));
    await t.tap(find.byKey(const ValueKey('story-react-❤️')));
    await settle(t);
    expect(api.calls, contains('story react 402 ❤️'));
    await t.enterText(find.byType(TextField), 'რა ლამაზია!');
    await t.tap(find.byKey(const ValueKey('story-send')));
    await settle(t);
    expect(api.calls, contains('story reply 402 რა ლამაზია!'));
    await _back(t);
    expect(find.byType(StoryViewer), findsNothing);
    expect(t.state<HomeShellState>(find.byType(HomeShell)).index, 0);
  });

  testWidgets('my story: a photo added, then who saw it', (t) async {
    phone(t);
    final api = await shell(t);
    await t.tap(find.byKey(const ValueKey('story-me')));
    await settle(t);
    await t.tap(find.text('ფოტო გალერეიდან'));
    await settle(t);
    // the stickers' step, then up it goes
    await t.tap(find.byKey(const ValueKey('sc-ok')));
    await settle(t);
    expect(api.calls, containsAll(['story photo', 'story https://t/hills.jpg']));
    await t.tap(find.byKey(const ValueKey('story-me')));
    await settle(t);
    expect(find.byType(StoryViewer), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('story-views')));
    await settle(t);
    expect(find.text('ნახვები · 2'), findsOneWidget);
    // back closes the list first, then the stories
    await _back(t);
    expect(find.text('ნახვები · 2'), findsNothing);
    expect(find.byType(StoryViewer), findsOneWidget);
    await _back(t);
    expect(find.byType(StoryViewer), findsNothing);
  });

  test('a notification knows what it opens', () {
    expect(PushTarget.fromData({'url': '/#chat-12', 'kind': 'message'})!.conv, 12);
    expect(PushTarget.fromData({'url': '/#post-34', 'kind': 'comment'})!.post, 34);
    expect(PushTarget.fromData({'url': '/#notifications', 'kind': 'friend_req'})!.tab, 'friends');
    expect(PushTarget.fromData({'url': '/#games', 'kind': 'game'}), isNull);
  });

  testWidgets('notifications: this phone is registered, a tap opens its place, sign-out stops them', (t) async {
    phone(t);
    final push = FakePush();
    final api = await shell(t, push: push);
    expect(push.calls, ['start']);
    expect(api.calls, contains('push+ tok'));

    push.open!(const PushTarget(conv: 1));
    await settle(t);
    expect(find.byType(ChatScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(ChatScreen), findsNothing);

    // a post never opens as a page of its own: it comes up with its comments over where one is
    push.open!(const PushTarget(post: 101));
    await settle(t);
    expect(find.byKey(const ValueKey('cs-post-101')), findsOneWidget);
    await _back(t);
    expect(find.byType(CommentsPanel), findsNothing);

    push.open!(const PushTarget(tab: 'friends'));
    await settle(t);
    expect(t.state<HomeShellState>(find.byType(HomeShell)).index, 1);

    // with the app open: a line at the bottom
    push.whileOpen!('Peera', 'მარიამ · ახალი კომენტარი: სუპერ!', const PushTarget(post: 101));
    await t.pump();
    expect(find.text('მარიამ · ახალი კომენტარი: სუპერ!'), findsOneWidget);

    await _tab(t, 'me');
    // notifications switched off on the phone: the profile says so and opens the setting
    expect(find.text('შეტყობინებები გამორთულია'), findsNothing);
    push.on.value = false;
    await t.pump();
    expect(find.text('შეტყობინებები გამორთულია'), findsOneWidget);
    await t.ensureVisible(find.text('ჩართვა'));
    await settle(t);
    await t.tap(find.text('ჩართვა'));
    expect(push.calls, contains('settings'));
    // signing out is in the settings now, as on the site
    await t.ensureVisible(find.byKey(const ValueKey('pro-settings')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('pro-settings')));
    await settle(t);
    await t.scrollUntilVisible(find.byKey(const ValueKey('set-out')), 300, scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first);
    await t.ensureVisible(find.byKey(const ValueKey('set-out')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('set-out')));
    await settle(t);
    await t.tap(find.widgetWithText(TextButton, 'გასვლა'));
    await settle(t);
    expect(push.calls, contains('stop'));
    expect(api.calls, contains('push- tok'));
  });

  testWidgets('joker: a quick game against the bots; back leaves the table, the game goes on from the tab', (t) async {
    phone(t);
    SharedPreferences.setMockInitialValues({});
    final api = await shell(t);
    // the games: backgammon's card and the big card's button open backgammon; Joker's card opens Joker
    await _tab(t, 'joker');
    expect(find.byType(GamesTab), findsOneWidget);
    expect(find.text('ონლაინ ნარდი და ჯოკერი'), findsOneWidget);
    expect(find.text('ჯერ არ არის ხელმისაწვდომი'), findsNothing);
    await t.tap(find.byKey(const ValueKey('games-nardi')));
    await settle(t);
    expect(find.byType(NardiTab), findsOneWidget);
    await _back(t);
    expect(find.byType(NardiTab), findsNothing);
    await t.tap(find.byKey(const ValueKey('games-play')));
    await settle(t);
    expect(find.byType(NardiTab), findsOneWidget);
    await _back(t);
    expect(find.byType(GamesTab), findsOneWidget);
    expect(find.byType(JokerTab), findsNothing);
    await t.tap(find.byKey(const ValueKey('games-joker')));
    await settle(t);
    expect(find.text('ჯოკერი ოთხ კაცზე'), findsOneWidget);
    expect(find.byType(JokerTab), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('joker-new-quick')));
    await settle(t);
    expect(find.byType(JokerTableScreen), findsOneWidget);
    final s = t.widget<JokerTableScreen>(find.byType(JokerTableScreen)).session;
    final g = s.g!;
    expect(g.len, 'quick');

    /// the bots move by themselves; this waits for my turn (or [until])
    Future<void> wait({bool Function()? until}) async {
      for (var i = 0; i < 80; i++) {
        if (until != null ? until() : s.myTurn) return;
        await t.pump(const Duration(milliseconds: 500));
      }
      fail('the table stopped: ${g.phase} ${g.cur}');
    }

    Future<void> playHand() async {
      final h0 = g.h;
      while (g.h == h0) {
        await wait(until: () => s.myTurn || g.h != h0);
        if (g.h != h0) break;
        await t.pump();
        if (g.phase == 'trump') {
          await t.tap(find.byKey(const ValueKey('jtrump-h')));
        } else if (g.phase == 'bid') {
          final f = g.forbidden(0);
          expect(find.byKey(const ValueKey('joker-status')), findsOneWidget);
          await t.tap(find.byKey(ValueKey('jbid-${f == 0 ? 1 : 0}')));
        } else {
          final c = g.legal(0).first;
          await t.tap(find.byKey(ValueKey('jcard-${c.key}')));
          await t.pumpAndSettle();
          if (c.joker) {
            await t.tap(find.byKey(ValueKey(g.trick.isEmpty ? 'jcall-hi-h' : 'jcall-hi')));
          }
        }
        await t.pump();
      }
    }

    await playHand();
    expect(g.h, 1);
    expect(g.hist.length, greaterThanOrEqualTo(1));
    expect(find.byKey(const ValueKey('pips-0')), findsOneWidget);

    // back: the table closes, the game waits on the tab
    await _back(t);
    expect(find.byType(JokerTableScreen), findsNothing);
    expect(find.byKey(const ValueKey('joker-current')), findsOneWidget);
    final before = jsonOf(g);
    await t.pump(const Duration(seconds: 5));
    expect(jsonOf(g), before, reason: 'the bots wait while the table is closed');

    // on again, one more hand; a joker or not, the cards played are the ones allowed
    await t.tap(find.byKey(const ValueKey('joker-continue')));
    await settle(t);
    await playHand();
    expect(g.h, 2);

    // the sheet over the table is one step back
    await t.tap(find.byTooltip('ქულების ფურცელი'));
    await settle(t);
    expect(find.text('ქულების ფურცელი'), findsWidgets);
    await _back(t);
    expect(find.byType(JokerTableScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(JokerTableScreen), findsNothing);
    // and from the tab back to the feed, never out
    await _back(t);
    expect(find.byKey(const ValueKey('joker-current')), findsNothing);
    expect(api.calls.where((c) => c.startsWith('game ')), isEmpty);
  });

  testWidgets('joker: the game is kept on the phone and continues after the app is opened again', (t) async {
    phone(t);
    SharedPreferences.setMockInitialValues({});
    await shell(t);
    await _jokerPage(t);
    await t.tap(find.byKey(const ValueKey('joker-new-nines')));
    await settle(t);
    final s1 = t.widget<JokerTableScreen>(find.byType(JokerTableScreen)).session;
    for (var i = 0; i < 40 && !s1.myTurn; i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    final saved = jsonOf(s1.g!);
    await _back(t);
    // a new start of the app: the game is read back
    await t.pumpWidget(const SizedBox());
    await shell(t);
    await _jokerPage(t);
    expect(find.byKey(const ValueKey('joker-current')), findsOneWidget);
    expect(find.textContaining('ცხრიანები · ხელი'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('joker-continue')));
    await settle(t);
    final s2 = t.widget<JokerTableScreen>(find.byType(JokerTableScreen)).session;
    expect(jsonOf(s2.g!), saved);
    await _back(t);
    // given up: it is gone
    await t.tap(find.byKey(const ValueKey('joker-quit')));
    await settle(t);
    await t.tap(find.text('დასრულება').last);
    await settle(t);
    expect(find.byKey(const ValueKey('joker-current')), findsNothing);
  });

  testWidgets('joker: a won game is told to the server once, and the coins it brought are shown', (t) async {
    phone(t);
    SharedPreferences.setMockInitialValues({});
    final api = await shell(t);
    await _jokerPage(t);
    await t.tap(find.byKey(const ValueKey('joker-new-quick')));
    await settle(t);
    final s = t.widget<JokerTableScreen>(find.byType(JokerTableScreen)).session;
    await _back(t);
    // the last hand is scored and I have the most points
    s.g!
      ..score = [900, 100, 50, -200]
      ..h = 8
      ..cur = -1
      ..phase = 'over';
    await t.tap(find.byKey(const ValueKey('joker-continue')));
    await settle(t);
    expect(find.byKey(const ValueKey('joker-over')), findsOneWidget);
    expect(find.text('მოიგე!'), findsOneWidget);
    expect(find.text('+10 მონეტა'), findsOneWidget);
    expect(api.calls.where((c) => c == 'game joker won').length, 1);
    // opened again: not told twice
    await _back(t);
    expect(find.text('შედეგის ნახვა'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('joker-continue')));
    await settle(t);
    expect(api.calls.where((c) => c.startsWith('game ')).length, 1);
    // a new game from the end
    await t.tap(find.byKey(const ValueKey('joker-again')));
    await settle(t);
    expect(s.g!.phase, isNot('over'));
    expect(s.reward, isNull);
    await _back(t);
  });

  testWidgets('dating: turned on with a card; a like that makes a pair, a no, a super like; the pair opens a conversation', (t) async {
    phone(t);
    final api = await shell(t);
    await _tab(t, 'date');
    expect(find.text('გაიცანი ახალი ადამიანები'), findsOneWidget);
    final save = find.byKey(const ValueKey('dating-save'));
    await _formTo(t, save);
    await t.tap(save);
    await settle(t);
    expect(find.text('აირჩიე, ვინ ხარ'), findsOneWidget);
    await _formTo(t, find.byKey(const ValueKey('gender-f')), -250);
    await t.tap(find.byKey(const ValueKey('gender-f')));
    await t.tap(find.byKey(const ValueKey('seeking-m')));
    for (final x in ['მთა', 'ყავა']) {
      await _formTo(t, find.byKey(ValueKey('interest-$x')));
      await t.tap(find.byKey(ValueKey('interest-$x')));
      await t.pump();
    }
    await _formTo(t, save);
    await t.tap(save);
    await settle(t);
    expect(api.calls, contains('dating on f m მთა,ყავა'));
    // the line that says it was saved goes away by itself
    await t.pump(const Duration(seconds: 5));
    await settle(t);

    // the deck: ანა on top; a like makes a pair
    expect(find.byKey(const ValueKey('dcard-u5')), findsOneWidget);
    expect(find.text('ანა'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('date-like')));
    await settle(t);
    expect(api.calls, contains('swipe u5 like'));
    expect(find.byKey(const ValueKey('pair-title')), findsOneWidget);
    // the sheet is one step back
    await _back(t);
    expect(find.byKey(const ValueKey('pair-title')), findsNothing);
    expect(find.byKey(const ValueKey('dcard-u6')), findsOneWidget);

    // dragged to the left: no
    await t.drag(find.byKey(const ValueKey('dcard-u6')), const Offset(-320, 0));
    await settle(t);
    expect(api.calls, contains('swipe u6 nope'));
    // dragged a little: it comes back, nothing is sent
    await t.drag(find.byKey(const ValueKey('dcard-u7')), const Offset(50, 0));
    await settle(t);
    expect(api.calls.where((c) => c.startsWith('swipe u7')), isEmpty);
    expect(find.byKey(const ValueKey('dcard-u7')), findsOneWidget);
    // a super like
    await t.tap(find.byKey(const ValueKey('date-super')));
    await settle(t);
    expect(api.calls, contains('swipe u7 super'));
    expect(find.text('ახლა ახალი ადამიანები აღარ არის'), findsOneWidget);

    // the pairs: a tap opens the conversation, back comes to the pairs
    await t.tap(find.byKey(const ValueKey('dseg-2')));
    await settle(t);
    expect(find.byKey(const ValueKey('pair-u5')), findsOneWidget);
    expect(find.byKey(const ValueKey('pair-u3')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('pair-u5')));
    await settle(t);
    expect(api.calls, contains('dm u5'));
    expect(find.byType(ChatScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.byKey(const ValueKey('pair-u5')), findsOneWidget);
  });

  testWidgets('dating: changes to the card are asked about before they are lost; dating can be turned off', (t) async {
    phone(t);
    final api = FakeApi()..dating = const DatingMe(adult: true, on: true, gender: 'm', seeking: 'f', bio: 'ლაშქრობა', interests: ['მთა']);
    await shell(t, api: api);
    await _tab(t, 'date');
    await t.tap(find.byTooltip('გაცნობის პროფილი'));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('dating-bio')), 'ლაშქრობა და ჭადრაკი');
    await t.pump();
    await _back(t);
    expect(find.text('ცვლილებები არ შეინახება'), findsOneWidget);
    await t.tap(find.text('გასვლა'));
    await settle(t);
    expect(find.byKey(const ValueKey('dating-bio')), findsNothing);
    expect(find.byKey(const ValueKey('dcard-u5')), findsOneWidget);
    // off
    await t.tap(find.byTooltip('გაცნობის პროფილი'));
    await settle(t);
    await _formTo(t, find.byKey(const ValueKey('dating-off')));
    await t.tap(find.byKey(const ValueKey('dating-off')));
    await settle(t);
    await t.tap(find.text('გამორთვა').last);
    await settle(t);
    expect(api.calls, contains('dating off'));
    expect(find.text('გაიცანი ახალი ადამიანები'), findsOneWidget);
  });

  testWidgets('dating: under 18 it stays closed', (t) async {
    phone(t);
    await shell(t, api: FakeApi()..dating = const DatingMe(adult: false));
    await _tab(t, 'date');
    expect(find.text('გაცნობა მხოლოდ 18+ მომხმარებლებისთვისაა'), findsOneWidget);
    expect(find.byKey(const ValueKey('dating-save')), findsNothing);
  });

  testWidgets('joker with friends: a table, the length, an invitation, the start; moves go to the server; back keeps the seat', (t) async {
    phone(t);
    SharedPreferences.setMockInitialValues({});
    final api = await shell(t);
    await _jokerPage(t);
    await t.scrollUntilVisible(find.byKey(const ValueKey('joker-friends-table')), 250, scrollable: find.descendant(of: find.byType(JokerTab), matching: find.byType(Scrollable)).first);
    await settle(t);
    await t.tap(find.byKey(const ValueKey('joker-friends-table')));
    await settle(t);
    expect(api.calls, contains('jk new 50'));
    expect(find.byType(OnlineTableScreen), findsOneWidget);
    expect(find.text('მაგიდა #50'), findsOneWidget);
    expect(find.text('შენ'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('jlen-full')));
    await settle(t);
    expect(api.calls, contains('jk set 50 full'));
    // invite a friend
    await t.scrollUntilVisible(find.byKey(const ValueKey('jinvite')), 200, scrollable: find.descendant(of: find.byType(OnlineTableScreen), matching: find.byType(Scrollable)).first);
    await t.tap(find.byKey(const ValueKey('jinvite')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('jfriend-u2')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('jinvite-send')));
    await settle(t);
    expect(api.calls, contains('jk invite 50 u2'));
    // the line that says it was sent goes away by itself
    await t.pump(const Duration(seconds: 5));
    await settle(t);
    // start: three bots sit down
    await t.scrollUntilVisible(find.byKey(const ValueKey('jstart')), 200, scrollable: find.descendant(of: find.byType(OnlineTableScreen), matching: find.byType(Scrollable)).first);
    await t.tap(find.byKey(const ValueKey('jstart')));
    await settle(t);
    expect(api.calls, contains('jk start 50'));
    expect(find.byType(JokerTableScreen), findsOneWidget);
    final j = t.widget<JokerTableScreen>(find.byType(JokerTableScreen)).session as OnlineJoker;
    expect(find.text('რეზო'), findsNothing); // my own seat is at the bottom
    expect(find.descendant(of: find.byType(JokerTableScreen), matching: find.byWidgetPredicate((w) => w is AnimatedContainer && '${w.key}'.contains('plate-'))), findsNWidgets(3));
    expect(find.text('სალომე'), findsNWidgets(2)); // on her plate and in the little notebook

    // the server moves the bots each time the table is ticked; my moves go to it
    final h0 = j.g!.h;
    for (var i = 0; i < 120 && j.g!.h == h0; i++) {
      if (j.myTurn) {
        final g = j.g!;
        if (g.phase == 'bid') {
          final f = g.forbidden(0);
          await t.tap(find.byKey(ValueKey('jbid-${f == 0 ? 1 : 0}')));
        } else if (g.phase == 'trump') {
          await t.tap(find.byKey(const ValueKey('jtrump-none')));
        } else {
          final c = g.legal(0).first;
          await t.tap(find.byKey(ValueKey('jcard-${c.key}')));
          await t.pumpAndSettle();
          if (c.joker) await t.tap(find.byKey(ValueKey(g.trick.isEmpty ? 'jcall-hi-h' : 'jcall-hi')));
        }
        await t.pump();
      }
      await t.pump(const Duration(seconds: 1));
    }
    expect(j.g!.h, h0 + 1);
    expect(api.calls.where((c) => c == 'jk act bid').length, 1);
    expect(api.calls.where((c) => c == 'jk act card').length, greaterThanOrEqualTo(1));
    // the hand is on the score sheet the server keeps
    expect(j.g!.hist.where((r) => !r.pr), isNotEmpty);

    // back: the table screen closes, the table is in the list
    await _back(t);
    expect(find.byType(OnlineTableScreen), findsNothing);
    expect(find.byKey(const ValueKey('jtable-50')), findsOneWidget);
  });

  test('a notification about a Joker table or a pair opens its place', () {
    expect(PushTarget.fromData({'url': '/#jktable-12', 'kind': 'jk_invite'})?.jk, 12);
    expect(PushTarget.fromData({'url': '/#date', 'kind': 'match'})?.tab, 'date');
  });

  testWidgets('live map: who shares; my place shared by the phone with the app closed; stop; a person; back steps out', (t) async {
    phone(t);
    final loc = FakeLoc();
    locDevice = loc;
    final api = await shell(t);
    await _tab(t, 'friends');
    await t.tap(find.byTooltip('ლაივ რუკა'));
    await settle(t);
    expect(find.byType(LiveMapScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('map-p-u2')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-p-u3')), findsOneWidget);

    // share with everyone for 8 hours: rough by default then, as on the site
    await t.tap(find.byKey(const ValueKey('map-share')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('ls-aud-public')));
    await t.tap(find.byKey(const ValueKey('ls-min-480')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('ls-go')));
    await settle(t);
    expect(loc.calls, contains('permission'));
    expect(api.calls, contains('loc token'));
    expect(loc.calls, contains('start tok-1 public 480 true'));
    expect(find.byKey(const ValueKey('map-on')), findsOneWidget);
    expect(find.textContaining('ფონზეც · ყველას · მიახლოებით'), findsOneWidget);
    // the server has it now (the phone's service started it); the line at the bottom goes away
    api.share = MyShare(audience: 'public', approx: true, device: true, expiresAt: DateTime.now().add(const Duration(hours: 8)));
    await t.pump(const Duration(seconds: 5));
    await settle(t);
    expect(find.byKey(const ValueKey('map-on')), findsOneWidget);

    // stop: the server and the phone's service both
    await t.tap(find.byKey(const ValueKey('map-stop')));
    await settle(t);
    expect(api.calls, contains('loc stop'));
    expect(loc.calls.last, 'stop');
    expect(find.byKey(const ValueKey('map-share')), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    await settle(t);

    // a person: the map flies there, a second tap opens the card; a message from it
    await t.tap(find.byKey(const ValueKey('map-p-u2')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('map-p-u2')));
    await settle(t);
    expect(find.text('ახლა აქ არის'), findsOneWidget);
    expect(find.textContaining('მოძრაობს'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('peek-chat')));
    await settle(t);
    expect(api.calls, contains('dm u2'));
    expect(find.byType(ChatScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(LiveMapScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(LiveMapScreen), findsNothing);
    expect(find.byKey(const ValueKey('seg-0')), findsOneWidget);
  });

  testWidgets('live map: the phone does not allow the location — it says so, and offers the settings', (t) async {
    phone(t);
    final loc = FakeLoc()..perm = 'blocked';
    locDevice = loc;
    final api = await shell(t);
    await _tab(t, 'friends');
    await t.tap(find.byTooltip('ლაივ რუკა'));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('map-share')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('ls-go')));
    await settle(t);
    expect(api.calls.where((c) => c == 'loc token'), isEmpty);
    expect(find.text('ლოკაციაზე წვდომა გამორთულია. ჩართე ტელეფონის პარამეტრებში'), findsOneWidget);
    await t.tap(find.text('პარამეტრები'));
    await t.pump();
    expect(loc.calls, contains('settings'));
    await _back(t);
  });

  testWidgets('the live location notice opens the map', (t) async {
    phone(t);
    final loc = FakeLoc()..open = 'map';
    locDevice = loc;
    await shell(t);
    await settle(t);
    expect(find.byType(LiveMapScreen), findsOneWidget);
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

  testWidgets('the bell: new ones counted, each opens what it is about and is read then, back comes back', (t) async {
    phone(t);
    final api = await shell(t);
    // three unread on the bell
    expect(find.descendant(of: find.byKey(const ValueKey('bell')), matching: find.text('3')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('bell')));
    await settle(t);
    expect(find.byType(NotesScreen), findsOneWidget);
    expect(find.textContaining('რა მაგარია! სად გადაიღე?'), findsOneWidget);
    expect(find.textContaining('გიგზავნის მეგობრობის მოთხოვნას'), findsOneWidget);
    // as on Facebook: the bell's number goes, but each stays unread (tinted, a dot) until it is opened
    expect(api.calls.where((c) => c.startsWith('read')), isEmpty);
    expect(find.byKey(const ValueKey('note-dot-70')), findsOneWidget);

    // a comment opens the post, and is read now
    await t.tap(find.byKey(const ValueKey('note-70')));
    await settle(t);
    expect(api.calls, contains('read 70'));
    expect(find.byType(CommentsPanel), findsOneWidget);
    expect(find.byKey(const ValueKey('cs-post-106')), findsOneWidget);
    await _back(t);
    expect(find.byType(NotesScreen), findsOneWidget);

    // a request opens the friends' requests over the notifications; back comes to them again (one step)
    await t.tap(find.textContaining('გიგზავნის მეგობრობის მოთხოვნას'));
    await settle(t);
    expect(find.byType(FriendsTab), findsOneWidget);
    await _back(t);
    expect(find.byType(FriendsTab), findsNothing);
    expect(find.byType(NotesScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(NotesScreen), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('bell')), matching: find.text('3')), findsNothing);
  });

  testWidgets('the notifications as Facebook has them: all or unread, "…" marks, removes, turns a kind off', (t) async {
    phone(t);
    final api = await shell(t);
    await t.tap(find.byKey(const ValueKey('bell')));
    await settle(t);
    expect(find.text('ახალი'), findsOneWidget);
    expect(find.text('ადრე'), findsOneWidget);
    // only the unread: the three new ones, not ლუკა's older mention
    await t.tap(find.byKey(const ValueKey('nf-un')));
    await settle(t);
    expect(find.byKey(const ValueKey('note-70')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-68')), findsNothing);
    await t.tap(find.byKey(const ValueKey('nf-all')));
    await settle(t);
    // "…" on a read one: unread again, with its dot
    await t.tap(find.byKey(const ValueKey('note-more-68')));
    await settle(t);
    expect(find.text('წაუკითხავად მონიშვნა'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nm-read')));
    await settle(t);
    expect(api.calls, contains('unread 68'));
    expect(find.byKey(const ValueKey('note-dot-68')), findsOneWidget);
    // removed
    await t.tap(find.byKey(const ValueKey('note-more-68')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('nm-del')));
    await settle(t);
    expect(api.calls, contains('note del 68'));
    expect(find.byKey(const ValueKey('note-68')), findsNothing);
    // the comments' kind turned off, as the settings' switch
    await t.tap(find.byKey(const ValueKey('note-more-70')));
    await settle(t);
    expect(find.text('კომენტარები, პასუხები, ხსენებები'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nm-off')));
    await settle(t);
    expect(api.calls, contains('me notif'));
    expect(((api.me['notif'] as Map)['off'] as Map)['comments'], true);
    // the request answered on its line
    await t.tap(find.byKey(const ValueKey('nreq-ok-69')));
    await settle(t);
    expect(find.text('ახლა მეგობრები ხართ'), findsOneWidget);
    // all read from the top's "…"
    await t.tap(find.byKey(const ValueKey('notes-more')));
    await settle(t);
    await t.tap(find.text('ყველას წაკითხულად მონიშვნა'));
    await settle(t);
    expect(api.calls, contains('read all'));
    expect(find.byKey(const ValueKey('note-dot-71')), findsNothing);
  });

  testWidgets('settings: privacy and notification switches are saved, unblocking, the look', (t) async {
    phone(t);
    final api = await shell(t);
    await _tab(t, 'me');
    await t.tap(find.byKey(const ValueKey('pro-settings')));
    await settle(t);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('1 ტიპი გამორთულია · ღამით ჩუმად'), findsOneWidget);

    // privacy: hide the online status, only friends may write, unblock ნიკა
    await t.tap(find.byKey(const ValueKey('set-privacy')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('priv-online')));
    await settle(t);
    expect(api.me['privacy']['online'], false);
    await t.tap(find.byKey(const ValueKey('priv-dm-friends')));
    await settle(t);
    expect(api.me['privacy'], {'dm': 'friends', 'online': false});
    await t.pump(const Duration(seconds: 5));
    await settle(t);
    await t.scrollUntilVisible(find.byKey(ValueKey('unblock-${nika.id}')), 300, scrollable: find.descendant(of: find.byType(PrivacyScreen), matching: find.byType(Scrollable)).first);
    await t.tap(find.byKey(ValueKey('unblock-${nika.id}')));
    await settle(t);
    expect(api.calls, contains('unblock ${nika.id}'));
    expect(find.text('დაბლოკილი არავინ გყავს.'), findsOneWidget);
    await _back(t);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('ონლაინ სტატუსი დამალულია · მოგწერენ მეგობრები'), findsOneWidget);

    // notifications: comments off, the quiet hours kept with their zone
    await t.pump(const Duration(seconds: 5));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('set-notif')));
    await settle(t);
    await t.ensureVisible(find.byKey(const ValueKey('ncat-comments')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('ncat-comments')));
    await settle(t);
    expect(api.me['notif'], {
      'off': {'promo': true, 'comments': true},
      'quiet': {'on': true, 'from': 23, 'to': 8, 'tz': 'Asia/Tbilisi'},
    });
    await t.scrollUntilVisible(find.byKey(const ValueKey('quiet')), -300, scrollable: find.descendant(of: find.byType(NotifSettingsScreen), matching: find.byType(Scrollable)).first);
    await settle(t);
    await t.tap(find.byKey(const ValueKey('quiet')));
    await settle(t);
    expect(api.me['notif']['quiet']['on'], false);
    await _back(t);

    // the look: dark, bigger text (kept on the phone)
    await t.tap(find.byKey(const ValueKey('set-look')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('look-theme-ThemeMode.dark')));
    await t.tap(find.byKey(const ValueKey('look-zoom-1.1')));
    await settle(t);
    expect(themeChoice.value, ThemeMode.dark);
    expect(textZoom.value, 1.1);
    expect((await SharedPreferences.getInstance()).getString('look.theme'), 'dark');
    await _back(t);
    await _back(t);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(t.state<HomeShellState>(find.byType(HomeShell)).index, 6);
    themeChoice.value = ThemeMode.system;
    textZoom.value = 1;
  });

  testWidgets('editing my profile: a new picture and fields saved in one go; back with changes asks', (t) async {
    phone(t);
    final api = await shell(t);
    await _tab(t, 'me');
    await t.tap(find.byKey(const ValueKey('edit-profile')));
    await settle(t);
    expect(find.byType(EditProfileScreen), findsOneWidget);

    // a change, then back: asked; staying keeps the page
    await t.enterText(find.byKey(const ValueKey('ep-bio')), 'ახალი ტექსტი ჩემზე');
    await settle(t);
    await _back(t);
    expect(find.text('ცვლილებები არ შეინახება'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'არა'));
    await settle(t);
    expect(find.byType(EditProfileScreen), findsOneWidget);

    // the @name keeps only what the site allows
    await t.enterText(find.byKey(const ValueKey('ep-user')), 'Nino Beridze!');
    await settle(t);
    expect(find.text('ninoberidze'), findsOneWidget);

    // a new picture (framed, uploaded at once), then save
    await t.tap(find.byKey(const ValueKey('ep-avatar')));
    await settle(t);
    expect(api.calls, contains('upload 640x640'));

    // a taken @name is said plainly, nothing leaves the page
    api.updateFail = Exception('duplicate key value violates unique constraint "profiles_username_key"');
    await t.tap(find.byKey(const ValueKey('ep-save-top')));
    await settle(t);
    expect(find.text('ეს მომხმარებლის სახელი დაკავებულია'), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsOneWidget);
    api.updateFail = null;
    await t.pump(const Duration(seconds: 5));
    await t.tap(find.byKey(const ValueKey('ep-save-top')));
    await settle(t);
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(api.me['bio'], 'ახალი ტექსტი ჩემზე');
    expect(api.me['username'], 'ninoberidze');
    expect(api.me['avatar_url'], 'https://t/hills.jpg');
    expect(api.me['home_region'], 'იმერეთი');
  });

  testWidgets('voice: recorded with the time running, back throws it away, sent with its length, played', (t) async {
    phone(t);
    final mic = FakeVoice();
    voiceDevice = mic;
    final api = await shell(t);
    await _tab(t, 'chats');
    await t.tap(find.text('გიორგი კაპანაძე').first);
    await settle(t);
    // nothing written: the round button records
    expect(find.byKey(const ValueKey('chat-send')), findsNothing);
    await t.tap(find.byKey(const ValueKey('chat-mic')));
    await t.pump();
    expect(find.byKey(const ValueKey('voice-send')), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(find.text('0:02'), findsOneWidget);

    // back: the recording is thrown away, the conversation stays
    await _back(t);
    expect(mic.calls, ['start', 'cancel']);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-mic')), findsOneWidget);

    // again, and send: uploaded, then a voice message with its length
    await t.tap(find.byKey(const ValueKey('chat-mic')));
    await t.pump(const Duration(seconds: 3));
    await t.tap(find.byKey(const ValueKey('voice-send')));
    await settle(t);
    expect(api.calls, containsAllInOrder(['voice /phone/voice.m4a', 'send 1 voice ']));
    expect(find.text('0:03'), findsOneWidget);

    // it plays (and pauses)
    PIcon? icon(String n) => find.byWidgetPredicate((w) => w is PIcon && w.name == n).evaluate().map((e) => e.widget as PIcon).firstOrNull;
    await t.tap(find.byKey(const ValueKey('voice-play')).first);
    await settle(t);
    expect(icon('pause'), isNotNull);
    expect(find.text('0:05'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('voice-play')).first);
    await settle(t);
    expect(icon('pause'), isNull);
  });

  Finder pro() => find.descendant(of: find.byType(PersonScreen).first, matching: find.byType(Scrollable)).first;
  Future<void> proTo(WidgetTester t, Finder f) async {
    await t.scrollUntilVisible(f, 250, scrollable: pro());
    await t.ensureVisible(f);
    await settle(t);
  }

  /// a shortcut in the sideways "my space" row (the ones past the edge count as off screen for finders)
  Future<void> spaceTo(WidgetTester t, String k) async {
    await t.ensureVisible(find.byKey(const ValueKey('space-row')));
    await settle(t);
    await t.scrollUntilVisible(find.byKey(ValueKey('space-$k')), 120,
        scrollable: find.descendant(of: find.byKey(const ValueKey('space-row')), matching: find.byType(Scrollable)).first);
    await t.ensureVisible(find.byKey(ValueKey('space-$k')));
    await settle(t);
  }

  /// a button of the profile page, brought on screen first
  Future<void> tapPro(WidgetTester t, String key) async {
    await t.ensureVisible(find.byKey(ValueKey(key)));
    await settle(t);
    await t.tap(find.byKey(ValueKey(key)));
    await settle(t);
  }

  testWidgets("someone's profile as on the site: the visit, chips, numbers, grid, tabs, more, block", (t) async {
    phone(t);
    final api = await shell(t);
    await _tab(t, 'friends');
    await t.tap(find.byKey(const ValueKey('seg-0')));
    await settle(t);
    await t.tap(find.text('გიორგი კაპანაძე').first);
    await settle(t);
    // my visit counts among their guests
    expect(api.calls, contains('visit u2'));
    expect(find.text('@gio.k'), findsOneWidget);
    // the bio is a thought in a cloud by the picture
    expect(find.descendant(of: find.byKey(const ValueKey('pro-thought')), matching: find.text(giorgi.bio!)), findsOneWidget);
    // everything else folded under "ინფორმაცია · name", opened by kind
    expect(find.descendant(of: find.byKey(const ValueKey('pro-info')), matching: find.textContaining('გიორგი კაპანაძე', findRichText: true)), findsOneWidget);
    expect(find.byKey(const ValueKey('chip-joker')), findsNothing);
    await tapPro(t, 'pro-info');
    expect(find.descendant(of: find.byKey(const ValueKey('chip-joker')), matching: find.text('1640 რეიტინგი · 38 თამაში · 17 მოგება')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('chip-surname')), matching: find.text('კაპანაძე')), findsOneWidget);
    // someone else's page shows only what is filled in
    expect(find.text('დაამატე'), findsNothing);
    await tapPro(t, 'pro-info');
    expect(find.byKey(const ValueKey('chip-joker')), findsNothing);
    // the numbers: posts, friends, the likes their posts got, the friends we share
    expect(find.descendant(of: find.byKey(const ValueKey('stat-mutual')), matching: find.text('12')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('stat-friends')), matching: find.text('248')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('stat-likes')), matching: find.text('1 240')), findsOneWidget);
    expect(find.byKey(const ValueKey('stat-coins')), findsNothing);

    // the posts are posts, whole, as on Facebook; a post's words show whole right there (no page of its own)
    await proTo(t, find.byKey(const ValueKey('pbody-107')));
    await t.tap(find.byKey(const ValueKey('pbody-107')));
    await settle(t);
    expect(find.byType(CommentsPanel), findsNothing);
    expect(find.byType(PersonScreen), findsOneWidget);

    // the tabs (back up above the posts): no shared albums; friends, CV
    await t.scrollUntilVisible(find.byKey(const ValueKey('ptab-friends')), -250, scrollable: pro());
    await t.ensureVisible(find.byKey(const ValueKey('ptab-friends')));
    await settle(t);
    expect(find.byKey(const ValueKey('ptab-albums')), findsNothing);
    await t.tap(find.byKey(const ValueKey('ptab-friends')));
    await settle(t);
    expect(find.byKey(const ValueKey('pfriend-u3')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('ptab-cv')));
    await settle(t);
    expect(find.text('ფოტოგრაფი'), findsWidgets);
    expect(find.text('Lightroom'), findsOneWidget);

    // a highlight plays, and one back closes it
    await t.ensureVisible(find.byKey(const ValueKey('hl-1'), skipOffstage: false));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('hl-1')));
    await settle(t);
    expect(find.byType(StoryViewer), findsOneWidget,
        reason: find.byType(SnackBar, skipOffstage: false).evaluate().map((e) => '${((e.widget as SnackBar).content as Text).data}').join(' | '));
    expect(find.text('მთები'), findsWidgets);
    expect(api.calls.where((x) => x.startsWith('seen ')), isEmpty);
    await _back(t);
    expect(find.byType(StoryViewer), findsNothing);

    // more: a complaint, then a gift
    await tapPro(t, 'pro-more');
    await t.tap(find.text('საჩივარი'));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('reason-ყალბი პროფილი')));
    await settle(t);
    expect(api.calls, contains('report user u2 ყალბი პროფილი'));
    await t.pump(const Duration(seconds: 5));
    await settle(t);
    await tapPro(t, 'pro-more');
    await t.tap(find.text('საჩუქრის გაგზავნა'));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('gift-🌹')));
    await settle(t);
    expect(api.calls, contains('gift u2 🌹'));
    await t.pump(const Duration(seconds: 5));
    await settle(t);

    // a sheet closes with one back, the page stays
    await tapPro(t, 'pro-more');
    expect(find.text('დაბლოკვა'), findsOneWidget);
    await _back(t);
    expect(find.text('დაბლოკვა'), findsNothing);
    expect(find.byType(PersonScreen), findsOneWidget);

    // block: asked first, then only "unblock" and "more" are left
    await tapPro(t, 'pro-more');
    await t.tap(find.text('დაბლოკვა'));
    await settle(t);
    await t.tap(find.widgetWithText(TextButton, 'დაბლოკვა'));
    await settle(t);
    expect(api.calls, contains('block u2'));
    expect(find.byKey(const ValueKey('pro-unblock')), findsOneWidget);
    expect(find.byKey(const ValueKey('pro-message')), findsNothing);
    await t.pump(const Duration(seconds: 5));
    await settle(t);
    await tapPro(t, 'pro-unblock');
    expect(api.calls, contains('unblock u2'));
    expect(find.byKey(const ValueKey('pro-message')), findsOneWidget);
  });

  testWidgets('my profile: coins, my space (guests, badges, archive, close friends, drafts, angel days), saved', (t) async {
    phone(t);
    final api = await shell(t);
    await _tab(t, 'me');
    expect(api.calls, contains('check badges'));
    expect(api.calls.where((x) => x.startsWith('visit')), isEmpty);
    expect(find.text('12 450'), findsOneWidget);
    // the information: the calendar knows ნინო's day; the school is still to add
    await tapPro(t, 'pro-info');
    expect(find.text(mdText(daysOfName('ნინო').map((d) => (d.$1, daysUntil(d.$1))).reduce((a, b) => a.$2 <= b.$2 ? a : b).$1)), findsOneWidget);
    expect(find.text('სკოლა ან უნივერსიტეტი'), findsOneWidget);
    await tapPro(t, 'pro-info');

    // guests: who came by; one back closes the sheet
    await spaceTo(t, 'guests');
    await t.tap(find.byKey(const ValueKey('space-guests')));
    await settle(t);
    expect(find.byKey(const ValueKey('guest-u2')), findsOneWidget);
    await _back(t);
    expect(find.byKey(const ValueKey('guest-u2')), findsNothing);

    // badges: 3 of all, the best one first
    await spaceTo(t, 'badges');
    await t.tap(find.byKey(const ValueKey('space-badges')));
    await settle(t);
    expect(find.text('ჩემი ნიშნები'), findsOneWidget);
    expect(find.text('ვარსკვლავი'), findsWidgets);
    await _back(t);

    // the archive: stories, then the highlights tab (a tab, not a step back)
    await spaceTo(t, 'stories');
    await t.tap(find.byKey(const ValueKey('space-stories')));
    await settle(t);
    expect(find.byType(StoryArchiveScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('arch-450')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('arch-450')));
    await settle(t);
    await t.tap(find.text('რჩეულებში დამატება'));
    await settle(t);
    await t.tap(find.text('ქუთაისი').last);
    await settle(t);
    expect(api.calls, contains('keep 450 in 3'));
    await t.pump(const Duration(seconds: 5));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('archtab-hl')));
    await settle(t);
    expect(find.byKey(const ValueKey('archhl-3')), findsOneWidget);
    await _back(t);
    expect(find.byType(StoryArchiveScreen), findsNothing);

    // close friends: one more
    await spaceTo(t, 'close');
    await t.tap(find.byKey(const ValueKey('space-close')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('close-u3')));
    await settle(t);
    expect(api.calls, contains('close u3 true'));
    await _back(t);
    await t.pump(const Duration(seconds: 5));
    await settle(t);

    // drafts: published now
    await spaceTo(t, 'drafts');
    await t.tap(find.byKey(const ValueKey('space-drafts')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('dpub-150')));
    await settle(t);
    expect(api.calls, contains('publish 150'));
    await _back(t);
    await t.pump(const Duration(seconds: 5));
    await settle(t);

    // angel's days
    await spaceTo(t, 'namedays');
    await t.tap(find.byKey(const ValueKey('space-namedays')));
    await settle(t);
    expect(find.byType(NamedaysScreen), findsOneWidget);
    expect(find.textContaining('ნინოობა'), findsWidgets);
    await _back(t);
    expect(find.byType(NamedaysScreen), findsNothing);

    // saved: a grid, and a folder
    await proTo(t, find.byKey(const ValueKey('ptab-saved')));
    await t.tap(find.byKey(const ValueKey('ptab-saved')));
    await settle(t);
    await proTo(t, find.byKey(const ValueKey('grid-101')));
    expect(find.byKey(const ValueKey('grid-103')), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('savf-1'), skipOffstage: false));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('savf-1')));
    await settle(t);
    expect(api.calls, contains('saved 1'));
    expect(find.text('ეს კოლექცია ცარიელია'), findsOneWidget);
    expect(t.state<HomeShellState>(find.byType(HomeShell)).index, 6);
  });

  /// my profile tab, at the top
  Future<FakeApi> meTab(WidgetTester t) async {
    phone(t);
    final api = await shell(t);
    await _tab(t, 'me');
    return api;
  }

  /// the button with this key, brought on screen and tapped
  Future<void> tapKey(WidgetTester t, String key) async {
    await t.ensureVisible(find.byKey(ValueKey(key), skipOffstage: false));
    await settle(t);
    await t.tap(find.byKey(ValueKey(key)));
    await settle(t);
  }

  Future<void> calm(WidgetTester t) async {
    await t.pump(const Duration(seconds: 5));
    await settle(t);
  }

  testWidgets('photo grades: 1 to 5 free, 5+ tells its price once, then it is sent', (t) async {
    phone(t);
    final api = await shell(t);
    await tapKey(t, 'grade-101-4');
    expect(api.calls, contains('grade 101 4'));
    await calm(t);
    await tapKey(t, 'grade-101-5+');
    expect(find.byKey(const ValueKey('plus-go')), findsOneWidget);
    // one back closes the price, nothing is sent
    await _back(t);
    expect(find.byKey(const ValueKey('plus-go')), findsNothing);
    expect(api.calls, isNot(contains('grade 101 5+')));
    await tapKey(t, 'grade-101-5+');
    await t.tap(find.byKey(const ValueKey('plus-go')));
    await settle(t);
    expect(api.calls, contains('grade 101 5+'));
    await calm(t);
    // the second time it is not asked again
    await tapKey(t, 'grade-101-3');
    await calm(t);
    await tapKey(t, 'grade-101-5+');
    expect(find.byKey(const ValueKey('plus-go')), findsNothing);
    expect(api.calls.where((x) => x == 'grade 101 5+').length, 2);
  });

  testWidgets("the games card: someone's ratings with their leagues and Joker; one back closes it", (t) async {
    phone(t);
    await shell(t);
    await _tab(t, 'friends');
    await t.tap(find.byKey(const ValueKey('seg-0')));
    await settle(t);
    await t.tap(find.text('გიორგი კაპანაძე').first);
    await settle(t);
    await tapPro(t, 'pro-info');
    await tapPro(t, 'chip-joker');
    expect(find.text('სათამაშო ბარათი'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('gc-nardi')), matching: find.text('1620')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('gc-nardi')), matching: find.text('ქალაქის ჩემპიონი')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('gc-nardi')), matching: find.text('40 პარტია, 25 მოგება')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('gc-shashi')), matching: find.text('უბნის ოსტატი')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('gc-shashi')), matching: find.text('ჯერ არ უთამაშია')), findsOneWidget);
    expect(find.byKey(const ValueKey('gc-joker')), findsOneWidget);
    expect(find.byKey(const ValueKey('gc-play')), findsNothing);
    await _back(t);
    expect(find.text('სათამაშო ბარათი'), findsNothing);
    expect(find.byType(PersonScreen), findsOneWidget);
  });

  testWidgets('my games card leads to Joker', (t) async {
    await meTab(t);
    await tapPro(t, 'pro-info');
    await tapPro(t, 'chip-joker');
    expect(find.descendant(of: find.byKey(const ValueKey('gc-chess')), matching: find.text('1500')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('gc-play')));
    await settle(t);
    expect(find.text('სათამაშო ბარათი'), findsNothing);
    // the games, where Joker is
    expect(find.byType(GamesTab), findsOneWidget);
  });

  testWidgets('staff: someone restricted from the more menu, after asking; others do not see it', (t) async {
    phone(t);
    final api = FakeApi();
    final mod = Profile(id: nino.id, name: nino.name, surname: nino.surname, username: nino.username, city: nino.city, hue: nino.hue, coins: nino.coins, onboarded: true, role: 'moderator');
    await t.pumpWidget(PeeraApp(mode: ThemeMode.light, home: HomeShell(me: mod, api: api, onSignOut: () async {})));
    await settle(t);
    await _tab(t, 'friends');
    await t.tap(find.byKey(const ValueKey('seg-0')));
    await settle(t);
    await t.tap(find.text('გიორგი კაპანაძე').first);
    await settle(t);
    await tapPro(t, 'pro-more');
    await t.tap(find.text('მოდერაცია: შეზღუდვა'));
    await settle(t);
    expect(find.text('შეზღუდული მომხმარებელი ვეღარ დაწერს პოსტებს, კომენტარებს და შეტყობინებებს.'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'შეზღუდვა'));
    await settle(t);
    expect(api.calls, contains('ban u2'));
    expect(find.text('შეიზღუდა'), findsOneWidget);
  });

  testWidgets('without a staff role the more menu has no restricting', (t) async {
    phone(t);
    await shell(t);
    await _tab(t, 'friends');
    await t.tap(find.byKey(const ValueKey('seg-0')));
    await settle(t);
    await t.tap(find.text('გიორგი კაპანაძე').first);
    await settle(t);
    await tapPro(t, 'pro-more');
    expect(find.text('მოდერაცია: შეზღუდვა'), findsNothing);
    expect(find.text('ოჯახის ხე'), findsOneWidget);
  });

  testWidgets('coins: the bonus waits on the wallet, is taken on the coins page; back returns to the profile', (t) async {
    final api = await meTab(t);
    // four numbers: posts, friends, the likes my posts got, my coins (a gold "+" while today's bonus waits); no rating
    expect(find.byKey(const ValueKey('stat-rating')), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('stat-likes')), matching: find.text('312')), findsOneWidget);
    expect(find.byKey(const ValueKey('stat-coins-bonus')), findsOneWidget);
    expect(find.byKey(const ValueKey('pro-wallet')), findsNothing);
    await tapPro(t, 'stat-coins');
    expect(find.byType(CoinsScreen), findsOneWidget);
    expect(find.text('12 450'), findsWidgets);
    expect(find.text('ლარად გატანა'), findsNothing);
    await tapKey(t, 'coins-bonus');
    expect(api.calls, contains('bonus'));
    expect(find.text('დღევანდელი ბონუსი აღებულია'), findsOneWidget);
    await calm(t);
    // how to earn: today's pages paid green, every page a card; one opens its ways to earn above the cards
    final list = find.descendant(of: find.byType(CoinsScreen), matching: find.byType(Scrollable)).first;
    Future<void> to(String key, double dy) async {
      await t.scrollUntilVisible(find.byKey(ValueKey(key)), dy, scrollable: list);
      await settle(t);
      await t.tap(find.byKey(ValueKey(key)));
      await settle(t);
    }

    await t.scrollUntilVisible(find.byKey(const ValueKey('coins-paid-home')), 200, scrollable: list);
    expect(find.descendant(of: find.byKey(const ValueKey('coins-paid-home')), matching: find.text('+35 დღეს')), findsOneWidget);
    await to('crgrp-me', 200);
    expect(find.byKey(const ValueKey('coins-open-me')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('coins-open-me')), matching: find.text('ერთჯერადი')), findsOneWidget);
    // the photo is done already: no button, a tick
    expect(find.byKey(const ValueKey('coins-go-avatar')), findsNothing);
    // by kind: the study kind has no feed card
    await to('coins-kind-study', -200);
    expect(find.byKey(const ValueKey('crgrp-home')), findsNothing);
    expect(find.byKey(const ValueKey('crgrp-me')), findsOneWidget);
    // the rules behind their button
    await tapKey(t, 'coins-rules');
    expect(find.text('დღის ლიმიტი: 150'), findsOneWidget);
    await _back(t);
    // the history
    await to('coins-part-1', -200);
    expect(find.byKey(const ValueKey('coins-log-0')), findsOneWidget);
    expect(find.text('−300'), findsOneWidget);
    expect(find.byKey(const ValueKey('crgrp-me')), findsNothing);
    await _back(t);
    expect(find.byType(CoinsScreen), findsNothing);
    expect(find.byType(PersonScreen), findsOneWidget);
  });

  testWidgets('shared albums: not on the profile; in the services mine opens, photos added, a friend invited, a photo viewed; no new one without a staff role', (t) async {
    final api = await meTab(t);
    expect(find.byKey(const ValueKey('ptab-albums'), skipOffstage: false), findsNothing);
    expect(find.byKey(const ValueKey('space-albums'), skipOffstage: false), findsNothing);
    openService(t.element(find.byType(PersonScreen).first), 'albums');
    await settle(t);
    expect(find.byType(AlbumsScreen), findsOneWidget);
    expect(find.text('მეგობრების ალბომები'), findsNothing);
    expect(find.text('სადაც მონაწილე ვარ'), findsOneWidget);
    // the staff make them; nobody else sees the button
    expect(find.byKey(const ValueKey('albums-new')), findsNothing);
    await tapKey(t, 'album-2');
    expect(find.byType(AlbumScreen), findsOneWidget);
    expect(find.text('ნინოს დაბადების დღე'), findsWidgets);
    expect(find.textContaining('მხოლოდ მონაწილეები'), findsOneWidget);
    // two photos from the gallery
    await tapKey(t, 'alb-add');
    expect(api.calls.where((x) => x == 'album photo 2').length, 2);
    expect(find.text('დაემატა 2 ფოტო'), findsOneWidget);
    await calm(t);
    // a friend invited
    await tapKey(t, 'alb-invite');
    expect(find.byKey(const ValueKey('pick-u4')), findsNothing);
    await t.tap(find.byKey(const ValueKey('pick-u3')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('pick-ok')));
    await settle(t);
    expect(api.calls, contains('album invite 2 u3'));
    await calm(t);
    // a photo opens; back closes only the photo
    await tapKey(t, 'albp-21');
    expect(find.byType(AlbumViewer), findsOneWidget);
    await _back(t);
    expect(find.byType(AlbumViewer), findsNothing);
    expect(find.byType(AlbumScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(AlbumScreen), findsNothing);
    expect(find.byType(AlbumsScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(AlbumsScreen), findsNothing);
    expect(find.byType(PersonScreen), findsOneWidget);
  });

  testWidgets('a new shared album, made by an admin: it opens, and back goes to the albums', (t) async {
    phone(t);
    final api = await shell(t, me: Profile(id: 'u1', name: 'ნინო ბერიძე', surname: 'ბერიძე', username: 'nino.beridze', city: 'ქუთაისი', hue: 312, onboarded: true, role: 'admin'));
    await _tab(t, 'me');
    openService(t.element(find.byType(PersonScreen).first), 'albums');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('albums-new')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('al-ok')));
    await settle(t);
    expect(find.text('ჩაწერე ალბომის სახელი'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('al-title')), 'ლაშქრობა თუშეთში');
    await t.tap(find.byKey(const ValueKey('al-ok')));
    await settle(t);
    expect(api.calls, contains('album new ლაშქრობა თუშეთში friends'));
    expect(find.byType(AlbumScreen), findsOneWidget);
    expect(find.text('ალბომი ცარიელია'), findsOneWidget);
    await _back(t);
    expect(find.byType(AlbumScreen), findsNothing);
    expect(find.byType(AlbumsScreen), findsOneWidget);
    expect(find.text('ლაშქრობა თუშეთში'), findsOneWidget);
    await _back(t);
    expect(find.byType(PersonScreen), findsOneWidget);
  });

  testWidgets('CV: written from the empty tab; leaving with changes asks first; saved, it shows', (t) async {
    final api = await meTab(t);
    await proTo(t, find.byKey(const ValueKey('ptab-cv')));
    await t.tap(find.byKey(const ValueKey('ptab-cv')));
    await settle(t);
    await t.ensureVisible(find.text('CV-ის შექმნა'));
    await settle(t);
    await t.tap(find.text('CV-ის შექმნა'));
    await settle(t);
    expect(find.byType(CvEditScreen), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('cv-head')), 'ბარისტა და ფოტოგრაფი');
    await settle(t);
    await _back(t);
    expect(find.text('ცვლილებები არ შეინახება'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'არა'));
    await settle(t);
    expect(find.byType(CvEditScreen), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('cv-add-experience')));
    await settle(t);
    expect(find.byKey(const ValueKey('cv-experience-1')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('cv-save')));
    await settle(t);
    expect(api.calls, contains('cv ბარისტა და ფოტოგრაფი'));
    expect(api.savedCv!['languages'], ['ქართული']);
    expect(find.byType(CvEditScreen), findsNothing);
    expect(find.text('ბარისტა და ფოტოგრაფი'), findsOneWidget);
  });

  testWidgets('school: added from the chip, then classmates of my year and class first', (t) async {
    final api = await meTab(t);
    await tapKey(t, 'pro-info');
    await tapKey(t, 'chip-edu');
    expect(find.byType(EduScreen), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('edu-add')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('edu-n')), '41-ე საჯარო სკოლა');
    await t.enterText(find.byKey(const ValueKey('edu-დამთავრების წელი')), '17');
    await t.tap(find.byKey(const ValueKey('edu-ok')));
    await settle(t);
    expect(find.text('წელი ოთხი ციფრით ჩაწერე'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('edu-დამთავრების წელი')), '2017');
    await t.enterText(find.byKey(const ValueKey('edu-cls')), 'ა');
    await t.tap(find.byKey(const ValueKey('edu-ok')));
    await settle(t);
    expect(api.calls, contains('me edu'));
    // no group is made or joined by itself: a person makes one when they want it
    expect(api.calls, isNot(contains('edu groups')));
    expect((api.me['edu'] as List).single['key'], 'ქუთაისი-41');
    expect(find.text('ქუთაისი · 2017 წლის გამოშვება · კლასი „ა“'), findsOneWidget);
    await calm(t);
    await t.tap(find.byKey(const ValueKey('edu-mates')));
    await settle(t);
    expect(api.calls, contains('mates school ქუთაისი-41'));
    expect(find.text('კლასელები · 2017 · 1'), findsOneWidget);
    expect(find.text('იგივე სკოლა, სხვა წელი · 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('mate-u7')), findsOneWidget);
    await _back(t);
    expect(find.byType(ClassmatesScreen), findsNothing);
    await _back(t);
    expect(find.byType(EduScreen), findsNothing);
    expect(find.byType(PersonScreen), findsOneWidget);
  });

  testWidgets('family tree: generations with the Georgian words, a request answered, an aunt added by name, a friend asked', (t) async {
    final api = await meTab(t);
    await spaceTo(t, 'tree');
    await t.tap(find.byKey(const ValueKey('space-tree')));
    await settle(t);
    expect(find.byType(TreeScreen), findsOneWidget);
    expect(find.text('ბებია-ბაბუები'), findsOneWidget);
    expect(find.text('მე და ჩემი თაობა'), findsOneWidget);
    expect(find.text('დედა · 1968'), findsOneWidget);
    expect(find.text('ბაბუა · 1940–2015'), findsOneWidget);
    expect(find.text('ძმა · ელოდება'), findsOneWidget);
    // someone asked to be in their tree
    expect(find.text('მის ოჯახის ხეში: და ან ძმა'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('kreq-ok-50')));
    await settle(t);
    expect(api.calls, contains('kin answer 50 true'));
    await calm(t);
    // mother's sister, by name
    await tapKey(t, 'knode-k1');
    await t.tap(find.byKey(const ValueKey('kn-add-sibling')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('kn-name')), 'ნანა ბერიძე');
    await t.tap(find.byKey(const ValueKey('ksex-f')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('kn-ok')));
    await settle(t);
    expect(api.calls, contains('kin sibling ნანა ბერიძე'));
    expect(find.text('დეიდა'), findsOneWidget);
    await calm(t);
    // a friend as my husband: a request goes to him
    await t.tap(find.byKey(const ValueKey('tree-add')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('krel-spouse')));
    await t.tap(find.byKey(const ValueKey('kwho-user')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('kfr-u2')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('kn-ok')));
    await settle(t);
    expect(api.calls, contains('kin spouse u2'));
    expect(find.text('მოთხოვნა გაიგზავნა'), findsOneWidget);
    await calm(t);
    // a sheet closes with one back, then the tree with another
    await tapKey(t, 'knode-k2');
    expect(find.byKey(const ValueKey('kn-del')), findsOneWidget);
    await _back(t);
    expect(find.byKey(const ValueKey('kn-del')), findsNothing);
    expect(find.byType(TreeScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(TreeScreen), findsNothing);
    expect(find.byType(PersonScreen), findsOneWidget);
  });

  testWidgets('surname: the chip opens its people; its group is made after asking', (t) async {
    final api = await meTab(t);
    await tapKey(t, 'pro-info');
    await tapKey(t, 'chip-surname');
    expect(find.byType(SurnameScreen), findsOneWidget);
    expect(find.text('1 ადამიანი Peera-ზე'), findsOneWidget);
    expect(find.byKey(const ValueKey('snp-u1')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('sn-group')));
    await settle(t);
    expect(find.text('გვარის ჯგუფის შექმნა'), findsWidgets);
    await t.tap(find.widgetWithText(TextButton, 'შექმნა'));
    await settle(t);
    expect(api.calls, contains('surname group'));
    expect(find.text('გვარის ჯგუფი'), findsOneWidget);
    await calm(t);
    await _back(t);
    expect(find.byType(SurnameScreen), findsNothing);
  });

  testWidgets('a draft gets its time; a saved folder is renamed, then removed', (t) async {
    final api = await meTab(t);
    await spaceTo(t, 'drafts');
    await t.tap(find.byKey(const ValueKey('space-drafts')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('dplan-150')));
    await settle(t);
    expect(find.text('გამოქვეყნების დრო'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('dp-ok')));
    await settle(t);
    expect(api.calls, contains('plan 150'));
    expect(find.textContaining('დაიგეგმა: '), findsOneWidget);
    await calm(t);
    await _back(t);

    await proTo(t, find.byKey(const ValueKey('ptab-saved')));
    await t.tap(find.byKey(const ValueKey('ptab-saved')));
    await settle(t);
    await tapKey(t, 'savf-1');
    await tapKey(t, 'savf-menu');
    await t.enterText(find.byKey(const ValueKey('fold-name')), 'სასწავლო');
    await t.tap(find.byKey(const ValueKey('fold-save')));
    await settle(t);
    expect(api.calls, contains('rename folder 1 სასწავლო'));
    expect(find.text('სასწავლო'), findsOneWidget);
    await tapKey(t, 'savf-menu');
    await t.tap(find.byKey(const ValueKey('fold-del')));
    await settle(t);
    expect(api.calls, contains('delete folder 1'));
    expect(find.byKey(const ValueKey('savf-1')), findsNothing);
    expect(find.byKey(const ValueKey('savf-menu')), findsNothing);
  });

  testWidgets('a greeting card: chosen and sent; the conversation takes its place, so one back leaves both', (t) async {
    final api = await meTab(t);
    openCardPicker(t.element(find.byType(PersonScreen)), uid: giorgi.id, toName: giorgi.name);
    await settle(t);
    expect(find.byType(CardPicker), findsOneWidget);
    await tapKey(t, 'card-send');
    expect(api.calls.where((x) => x.startsWith('card u2 ')), isNotEmpty);
    expect(find.byType(CardPicker), findsNothing);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byType(GreetingCard), findsWidgets);
    await calm(t);
    await _back(t);
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.byType(CardPicker), findsNothing);
    expect(find.byType(PersonScreen), findsOneWidget);
  });

  testWidgets('verification: a selfie taken and sent, then it waits', (t) async {
    final api = await meTab(t);
    await spaceTo(t, 'verify');
    await t.tap(find.byKey(const ValueKey('space-verify')));
    await settle(t);
    expect(find.byType(VerifyScreen), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('verify-take')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('verify-send')));
    await settle(t);
    expect(api.calls.where((x) => x.startsWith('verify ')), isNotEmpty);
    expect(find.text('განაცხადი განხილვაშია'), findsOneWidget);
    await calm(t);
    await _back(t);
    expect(find.byType(VerifyScreen), findsNothing);
  });

  testWidgets("my own photos: uploaded straight, a new album, who sees them; someone else's closed to a stranger", (t) async {
    phone(t);
    final api = await shell(t);
    await _tab(t, 'me');
    await proTo(t, find.byKey(const ValueKey('ptab-photos')));
    await t.tap(find.byKey(const ValueKey('ptab-photos')));
    await settle(t);
    expect(api.calls, contains('photos u1'));
    expect(find.byKey(const ValueKey('ph-who')), findsOneWidget);
    // two chosen on the phone go up one after the other
    await proTo(t, find.byKey(const ValueKey('ph-up')));
    await t.tap(find.byKey(const ValueKey('ph-up')));
    await settle(t);
    expect(api.calls.where((c) => c == 'addphoto').length, 2);
    await proTo(t, find.byKey(const ValueKey('ph-900')));
    expect(find.byKey(const ValueKey('ph-901')), findsOneWidget);
    // a new album opens, and back shows it among the albums
    await proTo(t, find.byKey(const ValueKey('ph-newalb')));
    await t.tap(find.byKey(const ValueKey('ph-newalb')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('phalb-title')), 'ზაფხული');
    await t.tap(find.byKey(const ValueKey('phalb-ok')));
    await settle(t);
    expect(api.calls, contains('newphalbum ზაფხული'));
    expect(find.byType(PhotoAlbumScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(PhotoAlbumScreen), findsNothing);
    await proTo(t, find.byKey(const ValueKey('pal-902')));
    // a photo held moves into it
    await proTo(t, find.byKey(const ValueKey('ph-900')));
    await t.longPress(find.byKey(const ValueKey('ph-900')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('ph-move')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('ph-to-902')));
    await settle(t);
    expect(api.calls, contains('movephoto 900 902'));

    // someone who shows their photos to friends only, to someone who is not their friend
    api.photoAccessOf[tamar.id] = 'friends';
    await t.tap(find.byKey(const ValueKey('tab-friends')));
    await settle(t);
    final ctx = t.element(find.byType(FriendsTab));
    openPage(ctx, PersonScreen(uid: tamar.id));
    await settle(t);
    await proTo(t, find.byKey(const ValueKey('ptab-photos')));
    await t.tap(find.byKey(const ValueKey('ptab-photos')));
    await settle(t);
    expect(find.byKey(const ValueKey('ph-locked')), findsOneWidget);
    expect(find.text('ფოტოებს მხოლოდ მეგობრები ხედავენ'), findsOneWidget);
    expect(api.calls, isNot(contains('photos ${tamar.id}')));
  });

}

String jsonOf(JokerGame g) => g.toJson().toString();
