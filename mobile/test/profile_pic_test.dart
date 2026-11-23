// My picture and cover, changed straight from my profile.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUpAll(useTestImages);

  testWidgets('my picture and cover from my profile: a choice of gallery or camera, uploaded and set; one seen, one taken away', (t) async {
    phone(t);
    final api = await shell(t);
    await toProfile(t);
    // the picture: from the gallery
    await t.tap(find.byKey(const ValueKey('pro-avatar')));
    await settle(t);
    expect(find.text('ფოტოს ატვირთვა გალერეიდან'), findsOneWidget);
    expect(find.text('გადაღება კამერით'), findsOneWidget);
    await t.tap(find.text('ფოტოს ატვირთვა გალერეიდან'));
    await settle(t);
    expect(api.calls, contains('upload 640x640'));
    expect(api.calls, contains('me avatar_url'));
    expect(api.me['avatar_url'], isNotNull);
    // told in the feed too (the switch is on at first): a post whose photo is marked as the new picture
    expect(api.calls, contains('post  1'));
    expect(api.lastPostMedia.single.pic, 'avatar');
    expect(find.text('ფოტო შეიცვალა · ფიდშიც გამოჩნდა'), findsOneWidget);
    // the cover: from the camera
    expect(find.byKey(const ValueKey('pro-cover-edit')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('pro-cover')));
    await settle(t);
    // this time not in the feed
    await t.tap(find.byKey(const ValueKey('pic-feed')));
    await settle(t);
    await t.tap(find.text('გადაღება კამერით'));
    await settle(t);
    expect(api.calls.where((c) => c.startsWith('post ')), hasLength(1));
    expect(api.calls, contains('upload 1400x788'));
    expect(api.calls, contains('me cover_url'));
    expect(find.text('ფონი შეიცვალა'), findsOneWidget);
    // back closes the sheet and changes nothing
    final n = api.calls.length;
    await t.tap(find.byKey(const ValueKey('pro-cover')));
    await settle(t);
    expect(find.text('ფონის წაშლა'), findsOneWidget);
    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.text('ფონის წაშლა'), findsNothing);
    expect(api.calls.length, n);
    // the cover taken away, after asking
    await t.tap(find.byKey(const ValueKey('pro-cover')));
    await settle(t);
    await t.tap(find.text('ფონის წაშლა'));
    await settle(t);
    await t.tap(find.text('წაშლა').last);
    await settle(t);
    expect(api.me['cover_url'], isNull);
    expect(find.text('ფონი წაიშალა'), findsOneWidget);
  });
}
