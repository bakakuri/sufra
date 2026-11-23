// Backgammon with another person: the lobby, a challenge and its answer, the game with the other phone (the test
// plays it, as the site would, in the site's own form), leaving, a rematch.
import 'dart:math';

import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/nardi/engine.dart';
import 'package:peera/nardi/nardi_screen.dart';
import 'package:peera/nardi/nardi_tab.dart';
import 'package:peera/nardi/online.dart';

import 'fake_api.dart';
import 'helpers.dart';

Future<void> _page(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('tab-joker')));
  await settle(t);
  await t.tap(find.byKey(const ValueKey('games-nardi')));
  await settle(t);
  expect(find.byType(NardiTab), findsOneWidget);
}

/// the last state this phone sent
Map<String, dynamic> _sent(FakeRoomLink room) => room.sent.lastWhere((e) => e.$1 == 'st').$2;

/// the other phone's turn: the state I sent last, their roll, their steps one at a time
Future<void> _theirTurn(WidgetTester t, FakeRoomLink room, OnlineNardi table, int them, Random rng) async {
  final g = gameOfSite(_sent(room)['s'] as Map, rng: rng);
  var sq = table.seq;
  void send() => room.eventsIn.add(('st', {'seq': ++sq, 's': siteOfGame(g), 'ck': {'${them == 0 ? 1 : -1}': 400000, 'n': 1}, 'from': 'u2'}));
  if (g.phase == Phase.roll && g.turn == them) {
    g.roll();
    send();
    await t.pump(const Duration(milliseconds: 50));
  }
  while (g.phase == Phase.move && g.turn == them) {
    final before = table.stepTick;
    g.play(botTurn(g, level: 2, rng: rng).first);
    send();
    await t.pump(const Duration(milliseconds: 50));
    expect(table.stepTick, before + 1, reason: 'their step glides on my board');
  }
}

/// my turn, played on the table
Future<void> _myTurn(WidgetTester t, OnlineNardi table) async {
  if (table.canRoll) {
    await t.tap(find.byKey(const ValueKey('nd-roll')));
    await t.pump(const Duration(milliseconds: 50));
  }
  while (table.canMove) {
    await table.play(botTurn(table.g!, level: 2, rng: Random(3)).first);
    await t.pump(const Duration(milliseconds: 50));
  }
  // a roll with nothing to play shows the dice for a moment, then passes
  await t.pump(const Duration(milliseconds: 1300));
}

void main() {
  testWidgets('nardi online: a friend challenged from the lobby, the game played with their phone, given up, a rematch', (t) async {
    phone(t);
    final api = await shell(t);
    final lobby = api.gameLinks['lobby']!;
    expect(lobby.tracked.last['nm'], nino.name);
    expect(lobby.tracked.last['st'], 'idle');
    lobby.presenceIn.add({
      'u1': {'nm': nino.name},
      'u2': {'nm': giorgi.name, 'hu': 30, 'st': 'idle'},
      'u5': {'nm': ana.name, 'hu': 300, 'st': 'play', 'gt': 'chess'},
    });
    await t.pump();
    await _page(t);
    expect(find.byKey(const ValueKey('nd-peer-u2')), findsOneWidget);
    expect(find.byKey(const ValueKey('nd-peer-u1')), findsNothing, reason: 'not me');
    expect(find.textContaining('· მეგობარი'), findsOneWidget);
    // one who plays now is not challenged
    expect(t.widget<OutlinedButton>(find.byKey(const ValueKey('nd-chal-u5'))).onPressed, isNull);
    await t.tap(find.byKey(const ValueKey('nd-chal-u2')));
    await settle(t);
    final chal = lobby.sent.lastWhere((e) => e.$1 == 'chal').$2;
    expect(chal['to'], 'u2');
    expect(chal['gt'], 'nardi');
    expect(chal['nm'], nino.name);
    final gid = chal['gid'] as String;
    expect(RegExp(r'^g[a-z0-9]{10}$').hasMatch(gid), isTrue);
    expect(find.byKey(const ValueKey('nd-pending')), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('reachable')), isEmpty, reason: 'a friend may be challenged');

    // yes: the table, mine the first side; I throw the opening roll and send the state
    lobby.eventsIn.add(('acc', {'to': 'u1', 'gid': gid, 'from': 'u2'}));
    await settle(t);
    expect(find.byType(NardiScreen), findsOneWidget);
    final room = api.gameLinks['game-$gid']!;
    final table = t.widget<NardiScreen>(find.byType(NardiScreen)).table as OnlineNardi;
    expect(table.me, 0);
    expect(room.tracked.first['lk'], isA<Map>());
    expect(api.calls, contains('meet $gid nardi u2 1'));
    final first = _sent(room);
    expect(first['seq'], 1);
    expect((first['s'] as Map)['p'], hasLength(24));
    expect((first['s'] as Map)['open'], hasLength(2));
    expect(lobby.tracked.last['st'], 'play');
    expect(lobby.tracked.last['vs'], giorgi.name);
    // the other's character, as they chose it
    room.presenceIn.add({
      'u1': {'w': 0},
      'u2': {'w': 0, 'lk': {'style': 'curly', 'hat': 1, 'skin': '#C08261'}},
    });
    await t.pump();
    expect(table.seatOf(1).look.style, 'curly');
    expect(find.byKey(const ValueKey('nd-clock-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('nd-undo')), findsNothing);

    // six turns, each phone its own
    final rng = Random(5);
    for (var i = 0; i < 6 && !table.finished; i++) {
      if (table.myTurn) {
        await _myTurn(t, table);
        expect(table.myTurn, isFalse);
        expect((_sent(room)['s'] as Map)['turn'], -1, reason: 'the turn passed to them');
      } else {
        await _theirTurn(t, room, table, 1, rng);
        expect(table.myTurn || table.finished, isTrue);
      }
    }
    await settle(t);
    // the board is the same on both phones
    final mine = gameOfSite(_sent(room)['s'] as Map);
    expect(table.g!.board.pips(0) + table.g!.board.pips(1), lessThan(334));
    expect(mine.board.offs, table.g!.board.offs);

    // given up: the state says so, the result goes to the ratings
    await t.tap(find.byKey(const ValueKey('nd-resign')));
    await settle(t);
    await t.tap(find.text('დანებება').last);
    await settle(t);
    expect(table.finished, isTrue);
    final over = _sent(room)['s'] as Map;
    expect(over['over'], -1);
    expect(over['why'], 'resign');
    expect(api.calls, contains('report $gid -1'));
    expect(find.text('წააგე'), findsOneWidget);
    expect(find.textContaining('რეიტინგი'), findsOneWidget);
    expect(lobby.tracked.last['st'], 'idle');

    // they offer a rematch; I take it: a new room, the sides changed over, the new first side sends the state
    room.eventsIn.add(('rem', {'gid': 'gabcdef123', 'from': 'u2'}));
    await settle(t);
    expect(find.textContaining('გთავაზობს რევანშს'), findsOneWidget);
    expect(find.text('რევანშის მიღება'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nd-again')));
    await settle(t);
    expect(room.sent.any((e) => e.$1 == 'remok' && e.$2['gid'] == 'gabcdef123'), isTrue);
    expect(room.left, isTrue);
    final room2 = api.gameLinks['game-gabcdef123']!;
    expect(table.me, 1);
    expect(table.gid, 'gabcdef123');
    expect(room2.sent.any((e) => e.$1 == 'need'), isTrue);
    expect(find.byKey(const ValueKey('nd-pause')), findsOneWidget);
    final g2 = NardiGame(rng: Random(8))..open();
    room2.eventsIn.add(('st', {'seq': 1, 's': siteOfGame(g2), 'ck': {'1': 420000, 'n': 0}, 'from': 'u2'}));
    await settle(t);
    expect(find.byKey(const ValueKey('nd-pause')), findsNothing);
    expect(table.g!.firstRoll, g2.firstRoll);
    expect(lobby.tracked.last['st'], 'play');

    // back: the table closes, the game goes on from backgammon's page
    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.byType(NardiScreen), findsNothing);
    expect(find.byKey(const ValueKey('nd-online-current')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nd-online-continue')));
    await settle(t);
    expect(t.widget<NardiScreen>(find.byType(NardiScreen)).table, same(table));
  });

  testWidgets('nardi online: a challenge to me; yes opens the table; the other says goodbye and the game is mine', (t) async {
    phone(t);
    final api = await shell(t);
    final lobby = api.gameLinks['lobby']!;
    lobby.eventsIn.add(('chal', {'to': 'u1', 'gt': 'nardi', 'gid': 'gq1w2e3r4', 'nm': mariam.name, 'from': 'u3'}));
    await settle(t);
    expect(find.byKey(const ValueKey('nd-invite')), findsOneWidget);
    expect(find.textContaining('გიწვევს ნარდის თამაშში'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nd-inv-yes')));
    await settle(t);
    final acc = lobby.sent.lastWhere((e) => e.$1 == 'acc').$2;
    expect(acc['to'], 'u3');
    expect(acc['gid'], 'gq1w2e3r4');
    expect(find.byType(NardiScreen), findsOneWidget);
    final room = api.gameLinks['game-gq1w2e3r4']!;
    final table = t.widget<NardiScreen>(find.byType(NardiScreen)).table as OnlineNardi;
    expect(table.me, 1);
    expect(room.sent.any((e) => e.$1 == 'need'), isTrue);
    expect(find.text('ველოდებით მეტოქეს…'), findsOneWidget);
    // their opening roll
    final g = NardiGame(rng: Random(4))..open();
    room.eventsIn.add(('st', {'seq': 1, 's': siteOfGame(g), 'ck': {'1': 420000, 'n': 0}, 'from': 'u3'}));
    room.presenceIn.add({'u1': {'w': 0}, 'u3': {'w': 0}});
    await settle(t);
    expect(table.g!.turn, g.turn);
    expect(table.g!.board.pips(0), 167);
    // an old state is not taken
    room.eventsIn.add(('st', {'seq': 1, 's': siteOfGame(NardiGame(rng: Random(5))..open()), 'from': 'u3'}));
    await t.pump();
    expect(table.g!.firstRoll, g.firstRoll);
    // goodbye: four seconds, then the win
    room.eventsIn.add(('bye', {'from': 'u3'}));
    // (the event comes a moment later; the screen after it)
    await t.pump();
    await t.pump();
    expect(find.textContaining('გავიდა'), findsWidgets);
    await t.pump(const Duration(seconds: 5));
    await settle(t);
    expect(table.finished, isTrue);
    expect(table.g!.winner, 1);
    expect(table.why, 'gone');
    expect((_sent(room)['s'] as Map)['over'], -1);
    expect(api.calls, contains('report gq1w2e3r4 -1'));
    expect(find.text('მოიგე! 🎉'), findsOneWidget);
    expect(find.byKey(const ValueKey('nd-again')), findsNothing, reason: 'no rematch with one who left');
    // closed: out of the room
    await t.tap(find.byKey(const ValueKey('nd-close')));
    await settle(t);
    expect(find.byType(NardiScreen), findsNothing);
    expect(room.left, isTrue);
  });

  testWidgets('nardi online: challenges that are said no to by themselves; one I say no to; one I may not send', (t) async {
    phone(t);
    final api = await shell(t);
    final lobby = api.gameLinks['lobby']!;
    Future<void> chal(String from, String gid, {String gt = 'nardi'}) async {
      lobby.eventsIn.add(('chal', {'to': 'u1', 'gt': gt, 'gid': gid, 'nm': 'x', 'from': from}));
      await settle(t);
    }

    bool declined(String gid) => lobby.sent.any((e) => e.$1 == 'decl' && e.$2['gid'] == gid);
    // another game than backgammon
    await chal('u2', 'gchess0001', gt: 'chess');
    expect(declined('gchess0001'), isTrue);
    // one I blocked
    await chal('u8', 'gblock0001');
    expect(declined('gblock0001'), isTrue);
    // a stranger I may not play with one to one
    api.unreachable.add('u5');
    await chal('u5', 'gminor0001');
    expect(api.calls, contains('reachable u5'));
    expect(declined('gminor0001'), isTrue);
    expect(find.byKey(const ValueKey('nd-invite')), findsNothing);
    // a stranger I may play with: asked, and I say no
    await chal('u6', 'gnope00001');
    expect(find.byKey(const ValueKey('nd-invite')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nd-inv-no')));
    await settle(t);
    expect(declined('gnope00001'), isTrue);
    expect(api.gameLinks.keys.where((k) => k.startsWith('game-')), isEmpty);
    // I may not challenge a stranger I may not reach
    api.unreachable.add('u7');
    lobby.presenceIn.add({'u7': {'nm': tamar.name, 'st': 'idle'}});
    await t.pump();
    await _page(t);
    await t.tap(find.byKey(const ValueKey('nd-chal-u7')));
    await settle(t);
    expect(find.text('ამ ადამიანთან ცალკე თამაში არ შეიძლება'), findsOneWidget);
    expect(lobby.sent.where((e) => e.$1 == 'chal'), isEmpty);
    // nobody else in the lobby
    lobby.presenceIn.add({});
    await t.pump();
    await t.pump();
    expect(find.byKey(const ValueKey('nd-nobody')), findsOneWidget);
  });
}
