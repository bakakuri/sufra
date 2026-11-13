// The chat in full: a message's menu (reactions, reply, edit, pin, forward, delete for everyone), stickers and a
// place, the conversation's menu (search, mute, disappearing, archive), typing and "seen", group conversations and
// the list's long press.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/chat/chat_screen.dart';
import 'package:peera/chat/chat_tools.dart';
import 'package:peera/ui/stickers.dart';

import 'helpers.dart';

Future<void> _back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await settle(t);
}

Future<void> _open(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('tab-chats')));
  await settle(t);
  await t.tap(find.text('გიორგი კაპანაძე').first);
  await settle(t);
}

Future<void> _hold(WidgetTester t, Finder f) async {
  await t.longPress(f);
  await settle(t);
}

Future<void> _pick(WidgetTester t, String key) async {
  await t.tap(find.byKey(ValueKey(key)));
  await settle(t);
}

void main() {
  setUpAll(useTestImages);

  testWidgets("a message held: a reaction, a reply, an edit, a pin, forwarded, deleted for everyone", (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t);
    expect(find.byType(ChatScreen), findsOneWidget);
    // the pinned message and a reaction already there
    expect(find.byKey(const ValueKey('pin-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('mreact-509')), findsOneWidget);

    await _hold(t, find.text('ხვალ 7-ზე შევხვდეთ?'));
    await _pick(t, 'mr-😂');
    expect(api.calls, contains('mreact 509 😂'));

    await _hold(t, find.text('ხვალ 7-ზე შევხვდეთ?'));
    await _pick(t, 'ma-reply');
    expect(find.byKey(const ValueKey('reply-bar')), findsOneWidget);
    // back closes the reply first, the conversation stays
    await _back(t);
    expect(find.byKey(const ValueKey('reply-bar')), findsNothing);
    expect(find.byType(ChatScreen), findsOneWidget);
    await _hold(t, find.text('ხვალ 7-ზე შევხვდეთ?'));
    await _pick(t, 'ma-reply');
    await t.enterText(find.byType(TextField), 'კი, 7-ზე');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('chat-send')));
    await settle(t);
    expect(api.calls, contains('send 1 text კი, 7-ზე ↩509'));
    expect(find.byKey(const ValueKey('reply-bar')), findsNothing);

    await _hold(t, find.text('აუცილებლად!').last);
    await _pick(t, 'ma-edit');
    await t.enterText(find.byType(TextField), 'აუცილებლად! 🙂');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('chat-send')));
    await settle(t);
    expect(api.calls, contains('medit 507 აუცილებლად! 🙂'));
    expect(find.text('აუცილებლად! 🙂'), findsWidgets);

    await _hold(t, find.text('ხვალ თავისუფალი ხარ?'));
    await _pick(t, 'ma-pin');
    expect(api.calls, contains('pin 1 508'));
    expect(find.descendant(of: find.byKey(const ValueKey('pin-bar')), matching: find.text('ხვალ თავისუფალი ხარ?')), findsOneWidget);

    await _hold(t, find.text('კი, 7-ზე'));
    await _pick(t, 'ma-fwd');
    await _pick(t, 'fw-2');
    expect(api.calls, contains('send 2 text კი, 7-ზე fwd ნინო ბერიძე'));
    await _back(t);

    await _hold(t, find.text('კი, 7-ზე'));
    await _pick(t, 'ma-unsend');
    expect(api.calls.any((c) => c.startsWith('unsend ')), isTrue);
    expect(find.text('შეტყობინება წაიშალა'), findsOneWidget);

    await t.tap(find.text('ხვალ თავისუფალი ხარ?').last);
    await t.pump(const Duration(milliseconds: 60));
    await t.tap(find.text('ხვალ თავისუფალი ხარ?').last);
    await settle(t);
    expect(api.calls, contains('mreact 508 ❤️'));
  });

  testWidgets('a sticker and my place sent; someone typing; "sent" under my last message', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t);
    api.typingLive.add('u2');
    await t.pump();
    await t.pump();
    expect(find.text('წერს…'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    await settle(t);
    expect(find.text('წერს…'), findsNothing);

    await _pick(t, 'chat-stk');
    await _pick(t, 'stk-khinkali');
    expect(api.calls, contains('send 1 text 🥟 ხინკალი sticker khinkali'));
    expect(find.byType(StickerView), findsOneWidget);
    expect(find.byKey(const ValueKey('seen')), findsOneWidget);

    await _pick(t, 'chat-plus');
    await _pick(t, 'pf-loc');
    expect(api.calls, contains('send 1 text 📍 ლოკაცია loc'));
    expect(find.byType(LocCard), findsOneWidget);
  });

  testWidgets("the conversation's menu: search, mute, disappearing messages, archive", (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t);
    await _pick(t, 'chat-more');
    await _pick(t, 'pf-search');
    expect(find.byType(ChatSearchScreen), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('cs-q')), 'ურეკ');
    await t.pump(const Duration(milliseconds: 400));
    await settle(t);
    await _pick(t, 'csr-505');
    expect(find.byType(ChatSearchScreen), findsNothing);
    expect(find.byType(ChatScreen), findsOneWidget);

    await _pick(t, 'chat-more');
    await _pick(t, 'pf-mute');
    await _pick(t, 'pf-1');
    expect(api.calls, contains('mute 1 on'));

    await _pick(t, 'chat-more');
    await _pick(t, 'pf-ttl');
    await _pick(t, 'pf-86400');
    expect(api.calls, contains('ttl 1 86400'));
    expect(find.textContaining('24 საათი'), findsOneWidget);

    await _pick(t, 'chat-more');
    await _pick(t, 'pf-media');
    expect(find.byType(ChatMediaScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('cmi-0')), findsOneWidget);
    await _back(t);

    await _pick(t, 'chat-more');
    await _pick(t, 'pf-arch');
    expect(api.calls, contains('archive 1 true'));
  });

  testWidgets('a new group conversation; a conversation held in the list goes to the archive', (t) async {
    phone(t);
    final api = await shell(t);
    await t.tap(find.byKey(const ValueKey('tab-chats')));
    await settle(t);
    expect(find.text('🔥12'), findsOneWidget);

    await _hold(t, find.byKey(const ValueKey('chat-2')));
    await _pick(t, 'pf-arch');
    expect(api.calls, contains('archive 2 true'));

    await _pick(t, 'new-group');
    expect(find.byType(NewGroupChatScreen), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('gc-title')), 'ექსკურსია');
    await _pick(t, 'gc-u2');
    await _pick(t, 'gc-u3');
    await _pick(t, 'gc-make');
    expect(api.calls, contains('group ექსკურსია u2,u3'));
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('ექსკურსია'), findsWidgets);
  });
}
