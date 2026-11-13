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
import 'package:peera/feed/post_screen.dart';
import 'package:peera/joker/engine.dart';
import 'package:peera/joker/table_screen.dart';
import 'package:peera/main.dart';
import 'package:peera/people/person_screen.dart';
import 'package:peera/push/push.dart';
import 'package:peera/shell/home_shell.dart';
import 'package:peera/shell/tab_bar.dart';

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
    await t.ensureVisible(find.byKey(const ValueKey('comments-101')));
    await settle(t);
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
    await t.ensureVisible(find.byKey(const ValueKey('comments-101')));
    await settle(t);
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
    await t.tap(find.byKey(const ValueKey('clip-comments-301')));
    await settle(t);
    expect(find.text('პოსტი'), findsOneWidget);
    await _back(t);
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
    // notifications switched off on the phone: the profile says so and opens the setting
    expect(find.text('შეტყობინებები გამორთულია'), findsNothing);
    push.on.value = false;
    await t.pump();
    expect(find.text('შეტყობინებები გამორთულია'), findsOneWidget);
    await t.tap(find.text('ჩართვა'));
    expect(push.calls, contains('settings'));
    await t.tap(find.byTooltip('გასვლა'));
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
    await _tab(t, 'joker');
    expect(find.text('ჯოკერი ოთხ კაცზე'), findsOneWidget);
    expect(find.text('თამაშები'), findsNothing);
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
    await _tab(t, 'joker');
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
    await _tab(t, 'joker');
    await settle(t);
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
    await _tab(t, 'joker');
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

String jsonOf(JokerGame g) => g.toJson().toString();
