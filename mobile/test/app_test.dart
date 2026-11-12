import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/auth/auth_screen.dart';
import 'package:peera/chat/chat_screen.dart';
import 'package:peera/feed/compose_screen.dart';
import 'package:peera/feed/post_screen.dart';
import 'package:peera/main.dart';
import 'package:peera/people/person_screen.dart';
import 'package:peera/push/push.dart';
import 'package:peera/shell/home_shell.dart';
import 'package:peera/shell/tab_bar.dart';

import 'helpers.dart';

Future<void> _back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await settle(t);
}

/// the feed's own list (photos inside it scroll sideways)
final _feed = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

Future<void> _tab(WidgetTester t, String id) async {
  await t.tap(find.byKey(ValueKey('tab-$id')));
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

    // a post's comments, then back
    await t.tap(find.byKey(const ValueKey('comments-101')));
    await settle(t);
    expect(find.byType(PostScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(PostScreen), findsNothing);
    expect(exits, 0);

    // on the main tab the first back only asks; a second one within two seconds closes the app
    await _back(t);
    expect(find.text(HomeShellState.exitHint), findsOneWidget);
    expect(exits, 0);
    await _back(t);
    expect(exits, 1);
  });

  testWidgets('the seven tabs of the site, messages raised in the middle, unread on the badges', (t) async {
    phone(t);
    await shell(t);
    for (final tab in tabs) {
      expect(find.descendant(of: find.byKey(ValueKey('tab-${tab.id}')), matching: find.text(tab.label)), findsOneWidget);
    }
    // 2 from გიორგი + 5 in the group; one friend request
    expect(find.descendant(of: find.byKey(const ValueKey('tab-chats')), matching: find.text('7')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('tab-friends')), matching: find.text('1')), findsOneWidget);
    await _tab(t, 'me');
    expect(find.text('@nino.beridze'), findsOneWidget);
    expect(find.text('12 450 ქოინი'), findsOneWidget);
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
    await t.tap(find.text('მთაში'));
    await settle(t);
    expect(api.calls.last, 'vote 103 1');
    expect(find.text('55%'), findsOneWidget);
  });

  testWidgets('comments: read them, answer one', (t) async {
    phone(t);
    final api = await shell(t);
    await t.tap(find.byKey(const ValueKey('comments-101')));
    await settle(t);
    expect(find.text('ჯვრის მონასტერთან ახლოს 🙂'), findsOneWidget);
    await t.tap(find.text('პასუხი').first);
    await settle(t);
    expect(find.text('პასუხი: მარიამ'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'ზაფხულში ისევ წავალთ');
    await t.pump();
    await t.tap(find.byTooltip('გაგზავნა'));
    await settle(t);
    expect(api.calls, contains('comment 101 ზაფხულში ისევ წავალთ ↩1'));
    expect(find.text('ზაფხულში ისევ წავალთ'), findsOneWidget);
    expect(find.text('კომენტარები · 5'), findsOneWidget);
  });

  testWidgets('writing a post with two photos puts it at the top of the feed', (t) async {
    phone(t);
    final api = await shell(t);
    await t.tap(find.byTooltip('ახალი პოსტი'));
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
    await t.tap(find.byTooltip('ახალი პოსტი'));
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
    api.notes.add({'kind': 'message', 'actor': 'u3', 'ref': {'conv': 2, 'text': 'სად ხარ? 🙂'}});
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

  test('a notification knows what it opens', () {
    expect(PushTarget.fromData({'url': '/#chat-12', 'kind': 'message'})!.conv, 12);
    expect(PushTarget.fromData({'url': '/#post-34', 'kind': 'comment'})!.post, 34);
    expect(PushTarget.fromData({'url': '/#notifications', 'kind': 'friend_req'})!.tab, 'friends');
    expect(PushTarget.fromData({'url': '/#date', 'kind': 'match'}), isNull);
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

    push.open!(const PushTarget(post: 101));
    await settle(t);
    expect(find.byType(PostScreen), findsOneWidget);
    await _back(t);

    push.open!(const PushTarget(tab: 'friends'));
    await settle(t);
    expect(t.state<HomeShellState>(find.byType(HomeShell)).index, 1);

    // with the app open: a line at the bottom
    push.whileOpen!('Peera', 'მარიამ · ახალი კომენტარი: სუპერ!', const PushTarget(post: 101));
    await t.pump();
    expect(find.text('მარიამ · ახალი კომენტარი: სუპერ!'), findsOneWidget);

    await _tab(t, 'me');
    await t.tap(find.byTooltip('გასვლა'));
    await settle(t);
    await t.tap(find.widgetWithText(TextButton, 'გასვლა'));
    await settle(t);
    expect(push.calls, contains('stop'));
    expect(api.calls, contains('push- tok'));
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
