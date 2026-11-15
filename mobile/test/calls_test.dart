// Calls with one person and the rooms (study room, discussion, live), with a pretend WebRTC: the signals sent are the
// site's, and the other side is played by the test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/calls/call.dart';
import 'package:peera/calls/rooms.dart';
import 'package:peera/chat/chat_screen.dart';
import 'package:peera/home/services.dart';
import 'package:peera/people/person_screen.dart';

import 'fake_api.dart';
import 'helpers.dart';

Future<void> _back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await settle(t);
}

Future<void> _tap(WidgetTester t, String key) async {
  await reveal(t, find.byKey(ValueKey(key), skipOffstage: false));
  await t.ensureVisible(find.byKey(ValueKey(key), skipOffstage: false));
  await settle(t);
  await t.tap(find.byKey(ValueKey(key)));
  await settle(t);
}

Future<void> _chat(WidgetTester t, String name) async {
  await t.tap(find.byKey(const ValueKey('tab-chats')));
  await settle(t);
  await t.tap(find.text(name).first);
  await settle(t);
}

Future<void> _service(WidgetTester t, String k, {String? arg}) async {
  await t.tap(find.byKey(const ValueKey('tab-me')));
  await settle(t);
  openService(t.element(find.byType(PersonScreen).first), k, arg: arg);
  await settle(t);
}

/// a moment passes (the call's screen goes after the last word stays a little)
Future<void> _wait(WidgetTester t, [int ms = 400]) async {
  await t.pump(Duration(milliseconds: ms));
  await settle(t);
}

Future<void> _in(WidgetTester t, FakeApi api, Map<String, dynamic> sig) async {
  api.callIn.add(sig);
  await t.pump();
  await t.pump();
  await settle(t);
}

void main() {
  setUpAll(useTestImages);

  testWidgets('a voice call from a conversation: the offer, the answer, connected, the microphone off, ended with back', (t) async {
    phone(t);
    final api = await shell(t);
    await _chat(t, 'გიორგი კაპანაძე');
    await _tap(t, 'chat-call');
    expect(find.byType(CallScreen), findsOneWidget);
    expect(find.text('ხმოვანი ზარი'), findsOneWidget);
    expect(find.text('ირეკება…'), findsOneWidget);
    final (to, offer) = api.signals.last;
    expect(to, 'u2');
    expect(offer['t'], 'offer');
    expect(offer['sdp'], 'fake-offer');
    expect(offer['video'], false);
    await _in(t, api, {'from': 'u2', 't': 'answer', 'sdp': 'their-answer'});
    expect(find.text('უკავშირდება…'), findsOneWidget);
    expect(fakeRtc.peers.single.log, contains('remote answer'));
    fakeRtc.peers.single.connect();
    await t.pump();
    expect(find.text('00:00'), findsOneWidget);
    await _tap(t, 'call-mic');
    expect(fakeRtc.made.single.audioOn, isFalse);
    // back asks first; the call ends with "დასრულება"
    await _back(t);
    expect(find.text('ზარის დასრულება'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'დასრულება'));
    await settle(t);
    expect(api.signals.last.$2['t'], 'end');
    await _wait(t);
    expect(find.byType(CallScreen), findsNothing);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(fakeRtc.made.single.stopped, isTrue);
    expect(fakeRtc.peers.single.closed, isTrue);
  });

  testWidgets('a video call coming in: ICE before the answer, answered, my camera off, another caller told I am busy, ended by them', (t) async {
    phone(t);
    final api = await shell(t);
    await _in(t, api, {'from': 'u3', 't': 'offer', 'sdp': 'their-offer', 'video': true, 'name': ''});
    expect(find.byType(CallScreen), findsOneWidget);
    expect(find.text('ვიდეოზარი'), findsWidgets);
    await _in(t, api, {
      'from': 'u3',
      't': 'ice',
      'c': {'candidate': 'candidate:1', 'sdpMid': '0', 'sdpMLineIndex': 0},
    });
    await _tap(t, 'call-accept');
    final p = fakeRtc.peers.single;
    expect(p.log, containsAllInOrder(['tracks', 'remote offer']));
    expect(p.ice, hasLength(1));
    expect(api.signals.last.$1, 'u3');
    expect(api.signals.last.$2, containsPair('t', 'answer'));
    expect(api.signals.last.$2, containsPair('sdp', 'fake-answer'));
    p.connect();
    await t.pump();
    expect(find.byKey(const ValueKey('call-remote')), findsOneWidget);
    expect(find.byKey(const ValueKey('call-local')), findsOneWidget);
    await _tap(t, 'call-cam');
    expect(fakeRtc.made.single.videoOn, isFalse);
    expect(find.byKey(const ValueKey('call-local')), findsNothing);
    await _in(t, api, {'from': 'u4', 't': 'offer', 'sdp': 'another', 'video': false});
    expect(api.signals.last.$1, 'u4');
    expect(api.signals.last.$2, {'t': 'busy', 'from': 'u1'});
    await _in(t, api, {'from': 'u3', 't': 'end'});
    await _wait(t);
    expect(find.byType(CallScreen), findsNothing);
  });

  testWidgets('a call declined; one without a microphone does not start', (t) async {
    phone(t);
    final api = await shell(t);
    await _in(t, api, {'from': 'u2', 't': 'offer', 'sdp': 'o', 'video': false});
    await _tap(t, 'call-decline');
    expect(api.signals.last.$1, 'u2');
    expect(api.signals.last.$2, {'t': 'decline', 'from': 'u1'});
    await _wait(t);
    expect(find.byType(CallScreen), findsNothing);

    fakeRtc.deny = true;
    await _chat(t, 'გიორგი კაპანაძე');
    await _tap(t, 'chat-video');
    expect(find.byType(CallScreen), findsNothing);
    expect(find.text('მიკროფონზე ან კამერაზე წვდომა არ არის'), findsOneWidget);
  });

  testWidgets("a study room joined: everyone offered to, answers and ICE, the host's topic, a clap, my microphone, someone leaving, back out", (t) async {
    phone(t);
    final api = await shell(t);
    await _service(t, 'rooms');
    expect(api.calls, contains('rooms supra'));
    expect(find.byKey(const ValueKey('room-30')), findsOneWidget);
    await t.tap(find.text('დისკუსია'));
    await settle(t);
    expect(find.byKey(const ValueKey('room-31')), findsOneWidget);
    await t.tap(find.text('სასწავლო'));
    await settle(t);
    await _tap(t, 'room-30');
    expect(find.byType(RoomScreen), findsOneWidget);
    final link = api.links[30]!;
    expect(link.tracked.first, containsPair('mic', true));
    expect(link.tracked.first, containsPair('host', false));
    expect(link.sent.first.$1, 'hello');

    link.presenceIn.add({
      'u1': {'n': 'ნინო', 'mic': true, 'cam': true},
      'u2': {'n': 'გიორგი', 'mic': true, 'cam': true, 'host': true},
      'u3': {'n': 'მარიამ', 'mic': false, 'cam': true},
    });
    await t.pump();
    await settle(t);
    expect(fakeRtc.peers, hasLength(2));
    final offers = [for (final s in link.sent) if (s.$1 == 'sig' && s.$2['sdp'] is Map) s.$2['to']];
    expect(offers, containsAll(['u2', 'u3']));
    expect(fakeRtc.peers.first.log, contains('sendrecv true true'));
    // ICE that comes before the answer waits for it
    link.eventsIn.add(('sig', {'from': 'u3', 'to': 'u1', 'ice': {'candidate': 'c', 'sdpMid': '0', 'sdpMLineIndex': 0}}));
    await t.pump();
    await t.pump();
    final p3 = fakeRtc.peers[1];
    expect(p3.ice, isEmpty);
    link.eventsIn.add(('sig', {'from': 'u3', 'to': 'u1', 'sdp': {'type': 'answer', 'sdp': 'a3'}}));
    await t.pump();
    await t.pump();
    await settle(t);
    expect(p3.log, contains('remote answer'));
    expect(p3.ice, hasLength(1));
    p3.connect();
    await t.pump();
    expect(find.byKey(const ValueKey('vid-u3'), skipOffstage: false), findsOneWidget);

    link.eventsIn.add(('state', {'from': 'u2', 'st': {'toast': 2, 'custom': '', 'book': '', 'floor': null, 'speakers': ['u2'], 'hands': []}}));
    await t.pump();
    await settle(t);
    expect(find.text('ახალი თემის ახსნა'), findsOneWidget);

    await _tap(t, 'rb-clink');
    expect(link.sent.last.$1, 'clink');
    await _tap(t, 'rb-mic');
    expect(fakeRtc.made.single.audioOn, isFalse);
    expect(link.tracked.last, containsPair('mic', false));

    link.presenceIn.add({
      'u1': {'n': 'ნინო'},
      'u2': {'n': 'გიორგი', 'host': true},
    });
    await t.pump();
    await settle(t);
    expect(p3.closed, isTrue);
    expect(find.byKey(const ValueKey('tile-u3'), skipOffstage: false), findsNothing);
    await _wait(t, 2000);

    await _back(t);
    expect(link.left, isTrue);
    expect(find.byType(RoomScreen), findsNothing);
    expect(find.byType(RoomsScreen), findsOneWidget);
    expect(fakeRtc.made.single.stopped, isTrue);
  });

  testWidgets('my discussion: opened, a raised hand given the word, closed for everyone', (t) async {
    phone(t);
    final api = await shell(t);
    await _service(t, 'rooms', arg: 'birja');
    await _tap(t, 'rooms-new');
    await t.enterText(find.byKey(const ValueKey('nr-title')), 'რა ვისწავლოთ ზაფხულში?');
    await _tap(t, 'nr-tp-career');
    await _tap(t, 'nr-ok');
    expect(api.calls, contains('room birja რა ვისწავლოთ ზაფხულში? career false'));
    final link = api.links[33]!;
    expect(link.tracked.first, containsPair('host', true));
    expect(link.tracked.first, containsPair('mic', true));
    link.presenceIn.add({
      'u1': {'n': 'ნინო', 'host': true, 'mic': true},
      'u4': {'n': 'ლუკა', 'mic': false},
    });
    await t.pump();
    await settle(t);
    expect(fakeRtc.peers.single.log, contains('sendrecv true false'));
    link.eventsIn.add(('hand', {'from': 'u4', 'up': true}));
    await t.pump();
    await settle(t);
    expect(link.sent.last.$1, 'state');
    expect((link.sent.last.$2['st'] as Map)['hands'], ['u4']);
    await _tap(t, 'rsp-u4');
    expect((link.sent.last.$2['st'] as Map)['speakers'], ['u1', 'u4']);
    expect(find.byKey(const ValueKey('rsp-u4')), findsNothing);
    await _back(t);
    expect(find.text('ოთახის დახურვა'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'დასრულება'));
    await settle(t);
    expect(link.sent.last.$1, 'end');
    expect(api.calls, contains('roomend 33'));
    expect(find.byType(RoomScreen), findsNothing);
  });

  testWidgets('a live broadcast watched: the host offers, I only receive; a comment, a heart, a gift; it ends', (t) async {
    phone(t);
    final api = await shell(t);
    await _service(t, 'room', arg: '32');
    expect(find.byType(RoomScreen), findsOneWidget);
    expect(fakeRtc.made, isEmpty);
    final link = api.links[32]!;
    link.presenceIn.add({
      'u1': {'n': 'ნინო'},
      'u4': {'n': 'ლუკა', 'host': true},
    });
    await t.pump();
    await settle(t);
    expect(fakeRtc.peers, isEmpty);
    expect(find.text('ეთერს ვუკავშირდები…'), findsOneWidget);
    link.eventsIn.add(('sig', {'from': 'u4', 'to': 'u1', 'sdp': {'type': 'offer', 'sdp': 'live'}}));
    await t.pump();
    await t.pump();
    await settle(t);
    final p = fakeRtc.peers.single;
    expect(p.log, containsAllInOrder(['remote offer', 'recvonly']));
    expect(link.sent.last.$2, containsPair('to', 'u4'));
    expect(link.sent.last.$2['sdp'], {'type': 'answer', 'sdp': 'fake-answer'});
    p.connect();
    await t.pump();
    expect(find.byKey(const ValueKey('live-video')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await t.enterText(find.byKey(const ValueKey('lv-in')), 'გამარჯობა!');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await settle(t);
    expect(link.sent.last.$1, 'cmt');
    expect(find.textContaining('გამარჯობა!', findRichText: true), findsOneWidget);
    await _tap(t, 'lv-heart');
    expect(link.sent.last.$1, 'heart');
    await _tap(t, 'lv-gift');
    await _tap(t, 'lg-🌹');
    expect(api.calls, contains('livegift 32 🌹'));
    expect(link.sent.last.$1, 'gift');
    expect(link.sent.last.$2, {'e': '🌹', 'n': 'ნინო', 'from': 'u1'});
    link.eventsIn.add(('cmt', {'from': 'u4', 'n': 'ლუკა', 't': 'მადლობა ყველას', 'host': true}));
    await t.pump();
    await settle(t);
    expect(find.textContaining('მადლობა ყველას', findRichText: true), findsOneWidget);
    await _wait(t, 2000);

    link.eventsIn.add(('end', {'from': 'u4'}));
    await t.pump();
    await settle(t);
    expect(find.text('ოთახი დაიხურა'), findsOneWidget);
    expect(link.left, isTrue);
    await _wait(t, 2000);
    await _back(t);
    expect(find.byType(RoomScreen), findsNothing);
  });

  testWidgets("a group conversation's video call: a study room of mine, ended when I leave", (t) async {
    phone(t);
    final api = await shell(t);
    await _chat(t, 'კლასელები');
    await _tap(t, 'chat-gcall');
    expect(api.calls, contains('groupcall 3'));
    expect(find.byType(RoomScreen), findsOneWidget);
    await _back(t);
    await t.tap(find.widgetWithText(TextButton, 'დასრულება'));
    await settle(t);
    expect(api.calls, contains('roomend 34'));
    expect(find.byType(RoomScreen), findsNothing);
    expect(find.byType(ChatScreen), findsOneWidget);
  });
}
