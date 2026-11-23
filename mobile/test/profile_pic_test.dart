// My picture and cover, changed straight from my profile.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/settings/frame_photo.dart';
import 'package:peera/ui/theme.dart';

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

  testWidgets('the framing screen itself: its title and the buttons to set the photo are there, and the framed photo comes back', (t) async {
    phone(t);
    final src = File('test/img/sea.jpg').readAsBytesSync();
    Framed? got;
    await t.pumpWidget(MaterialApp(
      theme: peeraTheme(Brightness.light),
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(child: TextButton(onPressed: () async => got = await framePhoto(c, src, aspect: 1, max: 320, title: 'პროფილის ფოტო'), child: const Text('go'))),
        ),
      ),
    ));
    await t.tap(find.text('go'));
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    // the bar is whole (before, the theme's endless button broke it: no title, no button)
    expect(t.takeException(), isNull);
    expect(find.text('პროფილის ფოტო'), findsOneWidget);
    expect(find.byKey(const ValueKey('frame-done')), findsOneWidget);
    expect(find.text('ფოტოს დაყენება'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('frame-set')));
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(got, isNotNull);
    expect(got!.w, 320);
    expect(got!.h, 320);
  });
}
