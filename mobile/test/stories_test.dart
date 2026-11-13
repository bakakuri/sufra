// Stories in full: who sees them, a text with a poll, stickers put on with a finger, and a friend's story answered
// through its poll and its question box.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/stories/stories.dart';
import 'package:peera/stories/story_make.dart';

import 'helpers.dart';

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(ValueKey(key)));
  await settle(t);
}

void main() {
  setUpAll(useTestImages);

  testWidgets('a text story with a poll, a place and a question', (t) async {
    phone(t);
    final api = await shell(t);
    await _tap(t, 'story-me');
    await _tap(t, 'as-text');
    expect(find.byType(TextStoryScreen), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('ts-text')), 'შაბათს სად ვიკრიბებით?');
    await _tap(t, 'ts-poll');
    await _tap(t, 'ts-g3');
    await _tap(t, 'ts-next');
    expect(find.byType(StoryComposeScreen), findsOneWidget);
    await _tap(t, 'sc-place');
    await t.enterText(find.byKey(const ValueKey('stk-text')), 'თბილისი');
    await _tap(t, 'stk-ok');
    expect(find.text('თბილისი'), findsOneWidget);
    await _tap(t, 'sc-ask');
    await _tap(t, 'stk-ok');
    expect(find.text('მკითხე რამე'), findsOneWidget);
    // a sticker taken away and put back
    await _tap(t, 'sst-x-1');
    expect(find.text('მკითხე რამე'), findsNothing);
    await _tap(t, 'sc-ask');
    await _tap(t, 'stk-ok');
    await _tap(t, 'sc-ok');
    expect(api.calls, contains('story https://t/hills.jpg poll კი/არა stickers place,ask'));
    expect(find.byType(StoryComposeScreen), findsNothing);
    expect(find.byType(TextStoryScreen), findsNothing);
  });

  testWidgets('a photo story for close friends only', (t) async {
    phone(t);
    final api = await shell(t);
    await _tap(t, 'story-me');
    await t.tap(find.text('ახლო მეგობრები'));
    await settle(t);
    await _tap(t, 'as-photo');
    await _tap(t, 'sc-ok');
    expect(api.calls, contains('story https://t/hills.jpg close'));
  });

  testWidgets("a friend's story: a vote in its poll, an answer to its question", (t) async {
    phone(t);
    final api = await shell(t);
    await _tap(t, 'story-u3');
    expect(find.byType(StoryViewer), findsOneWidget);
    // on to the one with the poll
    await t.tapAt(const Offset(360, 700));
    await settle(t);
    expect(find.text('ზღვა თუ მთა?'), findsOneWidget);
    expect(find.text('ბათუმი'), findsOneWidget);
    await _tap(t, 'svvote-1');
    expect(api.calls, contains('svote 405 1'));
    expect(find.text('50%'), findsNWidgets(2));
    await t.enterText(find.byKey(const ValueKey('ask-answer')), 'ბაკურიანში!');
    await _tap(t, 'ask-send');
    expect(api.calls, contains('story reply 405 ბაკურიანში!'));
  });
}
