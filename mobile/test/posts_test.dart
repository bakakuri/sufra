// Posts in full: sharing, the menu, editing, saving into a folder, comments (likes, stickers, photos, translation,
// deleting), @mentions and the composer's extras, search and a topic's page.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/feed/compose_screen.dart';
import 'package:peera/feed/post_actions.dart';
import 'package:peera/feed/post_screen.dart';
import 'package:peera/feed/tag_screen.dart';
import 'package:peera/people/search_screen.dart';
import 'package:peera/ui/stickers.dart';

import 'helpers.dart';

Future<void> _back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await settle(t);
}

final _feed = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

Future<void> _tap(WidgetTester t, String key) async {
  await t.scrollUntilVisible(find.byKey(ValueKey(key)), 300, scrollable: _feed);
  await settle(t);
  await t.tap(find.byKey(ValueKey(key)));
  await settle(t);
}

/// a button in a row that scrolls sideways, brought into view first
Future<void> _side(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(ValueKey(key), skipOffstage: false));
  await settle(t);
  await t.tap(find.byKey(ValueKey(key)));
  await settle(t);
}

Future<void> _to(WidgetTester t, String key) async {
  await t.scrollUntilVisible(find.byKey(ValueKey(key)), 300, scrollable: _feed);
  await settle(t);
  await t.tap(find.byKey(ValueKey(key)));
  await settle(t);
}

void main() {
  setUpAll(useTestImages);

  testWidgets('sharing a post: a repost, with my own words, in a message, to my story', (t) async {
    phone(t);
    final api = await shell(t);
    await _tap(t, 'share-101');
    expect(find.text('3 ადამიანმა გააზიარა'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('sh-repost')));
    await settle(t);
    expect(api.calls, contains('repost 101'));
    expect(find.text('გაზიარდა შენს მეგობრებთან'), findsOneWidget);

    await _tap(t, 'share-101');
    await t.tap(find.byKey(const ValueKey('sh-quote')));
    await settle(t);
    expect(find.byType(QuoteScreen), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('q-text')), 'ნახეთ რა ლამაზია');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('q-go')));
    await settle(t);
    expect(api.calls, contains('post ნახეთ რა ლამაზია 0 quote 101'));
    expect(find.byType(QuoteScreen), findsNothing);

    await _tap(t, 'share-101');
    await t.tap(find.byKey(const ValueKey('sh-send')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('sp-1')));
    await settle(t);
    expect(api.calls.any((c) => c.startsWith('send 1 text') && c.contains('#post-101')), isTrue);
    expect(find.text('გაიგზავნა'), findsOneWidget);
    await _back(t);
    expect(find.text('მესიჯით გაგზავნა'), findsNothing);

    await _tap(t, 'share-101');
    await t.tap(find.byKey(const ValueKey('sh-story')));
    await settle(t);
    expect(api.calls, containsAll(['story photo', 'story https://t/hills.jpg post 101']));
  });

  testWidgets("a post's menu: hidden from my feed, a complaint; my own post edited", (t) async {
    phone(t);
    final api = await shell(t);
    await _tap(t, 'more-102');
    await t.tap(find.text('დამალვა ჩემს ფიდში'));
    await settle(t);
    expect(find.byKey(const ValueKey('react-102')), findsNothing);
    expect(postOverrides.hidden, contains(102));

    await _tap(t, 'more-103');
    await t.tap(find.text('საჩივარი პოსტზე'));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('reason-სპამი ან რეკლამა')));
    await settle(t);
    expect(api.calls, contains('report post 103 სპამი ან რეკლამა'));

    await t.scrollUntilVisible(find.byKey(const ValueKey('more-106')), 300, scrollable: _feed);
    await settle(t);
    await t.tap(find.byKey(const ValueKey('more-106')));
    await settle(t);
    expect(find.text('დამალვა ჩემს ფიდში'), findsNothing);
    await t.tap(find.text('რედაქტირება'));
    await settle(t);
    expect(find.byType(EditPostScreen), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('ep-text')), 'ახალი აპი ვცადე! ძალიან სწრაფია 🚀');
    await t.tap(find.byKey(const ValueKey('ep-rm-0')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('ep-place-pick')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('pp-9')));
    await settle(t);
    expect(find.text('📍 ჯვრის მონასტერი'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('ep-save')));
    await settle(t);
    expect(api.calls, contains('edit 106 ახალი აპი ვცადე! ძალიან სწრაფია 🚀 0 place 9'));
    expect(find.byType(EditPostScreen), findsNothing);
    expect(find.text('ახალი აპი ვცადე! ძალიან სწრაფია 🚀'), findsOneWidget);
  });

  testWidgets('leaving an edit asks first; back stays on the post', (t) async {
    phone(t);
    await shell(t);
    await t.scrollUntilVisible(find.byKey(const ValueKey('more-106')), 300, scrollable: _feed);
    await settle(t);
    await t.tap(find.byKey(const ValueKey('more-106')));
    await settle(t);
    await t.tap(find.text('რედაქტირება'));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('ep-text')), 'სხვა ტექსტი');
    await t.pump();
    await _back(t);
    expect(find.text('ცვლილებები არ შეინახება'), findsOneWidget);
    await t.tap(find.text('არა'));
    await settle(t);
    expect(find.byType(EditPostScreen), findsOneWidget);
  });

  testWidgets('saved, then put into a new folder', (t) async {
    phone(t);
    final api = await shell(t);
    await _tap(t, 'save-102');
    expect(api.calls, contains('save 102 true'));
    expect(find.text('საქაღალდეში'), findsOneWidget);
    await t.tap(find.text('საქაღალდეში'));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('fold-name')), 'რეცეპტები');
    await t.tap(find.byKey(const ValueKey('fold-new')));
    await settle(t);
    expect(api.calls, containsAll(['newfolder რეცეპტები', 'folder 102 77']));
    expect(find.text('ჩაიდო საქაღალდეში „რეცეპტები“'), findsOneWidget);
  });

  testWidgets('comments: translated, liked, a sticker and a photo sent, one deleted', (t) async {
    phone(t);
    final api = await shell(t);
    await _to(t, 'comments-106');
    expect(find.byType(PostScreen), findsOneWidget);
    final list = find.descendant(of: find.byType(PostScreen), matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)).first;
    await t.scrollUntilVisible(find.byKey(const ValueKey('cm-22')), 200, scrollable: list);
    await settle(t);
    expect(find.byType(StickerView, skipOffstage: false), findsOneWidget);
    // the sticker's placeholder words are not shown
    expect(find.text('🥟 ხინკალი'), findsNothing);
    // English: "თარგმნა"; Georgian in Latin letters: "ქართული ასოებით"
    expect(find.text('თარგმნა'), findsOneWidget);
    expect(find.text('ქართული ასოებით'), findsOneWidget);
    await t.tap(find.text('თარგმნა'));
    await settle(t);
    expect(api.calls, contains('translate en'));
    expect(find.text('ნათარგმნი: Looks amazing! Which app is this?'), findsOneWidget);
    expect(find.text('ორიგინალი'), findsOneWidget);
    await t.tap(find.text('ორიგინალი'));
    await settle(t);
    expect(find.text('Looks amazing! Which app is this?'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('clike-20')));
    await settle(t);
    expect(api.calls, contains('clike 20 true'));
    expect(find.text('მოგწონს'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('c-stk')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('stk-khinkali')));
    await settle(t);
    expect(api.calls, contains('comment 106 🥟 ხინკალი khinkali'));
    expect(find.byType(StickerView, skipOffstage: false), findsNWidgets(2));

    await t.tap(find.byKey(const ValueKey('c-img')));
    await settle(t);
    expect(api.calls, contains('comment 106 📷 photo'));

    final before = api.calls.length;
    await t.ensureVisible(find.text('წაშლა').last);
    await t.tap(find.text('წაშლა').last);
    await settle(t);
    await t.tap(find.text('წაშლა').last);
    await settle(t);
    expect(api.calls.skip(before).any((c) => c.startsWith('cdel')), isTrue);
  });

  testWidgets('@mentions, a place, a video and a draft in the composer', (t) async {
    phone(t);
    final api = await shell(t);
    await t.tap(find.byKey(const ValueKey('compose')));
    await settle(t);
    expect(find.byType(ComposeScreen), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'გამარჯობა @mar');
    await t.pump(const Duration(milliseconds: 400));
    await settle(t);
    expect(find.byKey(const ValueKey('ment-u3')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('ment-u3')));
    await settle(t);
    expect(find.text('გამარჯობა @mariami '), findsOneWidget);
    expect(find.byKey(const ValueKey('mentions')), findsNothing);

    await _side(t, 'c-place');
    await t.tap(find.byKey(const ValueKey('pp-9')));
    await settle(t);
    expect(find.byKey(const ValueKey('c-place-chip')), findsOneWidget);

    await _side(t, 'c-vid');
    expect(find.byKey(const ValueKey('c-video')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('c-later')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('c-draft')));
    await settle(t);
    expect(api.calls, contains('video 720x1280'));
    expect(api.calls, contains('post გამარჯობა @mariami 1 place 9 draft'));
    expect(find.byType(ComposeScreen), findsNothing);
    expect(find.text('დრაფტი შენახულია'), findsOneWidget);
  });

  testWidgets('search: topics in fashion, people, pages, groups and posts; a topic followed; back one step at a time', (t) async {
    phone(t);
    final api = await shell(t);
    await t.tap(find.byTooltip('ძებნა'));
    await settle(t);
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('trend-მთა')), findsOneWidget);
    expect(find.text('შეიძლება იცნობდე'), findsOneWidget);

    await t.enterText(find.byKey(const ValueKey('s-q')), 'მთ');
    await t.pump(const Duration(milliseconds: 400));
    await settle(t);
    expect(find.text('მთის ამბები'), findsOneWidget);
    expect(find.text('მთის მოყვარულები'), findsOneWidget);
    expect(find.text('პოსტები'), findsWidgets);
    await _side(t, 'stab-groups');
    expect(find.text('მთის ამბები'), findsNothing);
    expect(find.text('მთის მოყვარულები'), findsOneWidget);

    await t.enterText(find.byKey(const ValueKey('s-q')), '#მთა');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('s-tag')));
    await settle(t);
    expect(find.byType(TagScreen), findsOneWidget);
    expect(find.text('1 პოსტი'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('tag-follow')));
    await settle(t);
    expect(api.calls, contains('tags +მთა'));
    expect(find.text('გამოწერილია'), findsOneWidget);

    await _back(t);
    expect(find.byType(TagScreen), findsNothing);
    expect(find.byType(SearchScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(SearchScreen), findsNothing);
  });
}
