// Backgammon on the phone against the computer: its page, the table, a whole game played with taps on the board.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/games/games_tab.dart';
import 'package:peera/nardi/board.dart';
import 'package:peera/nardi/engine.dart';
import 'package:peera/nardi/nardi_screen.dart';
import 'package:peera/nardi/nardi_tab.dart';
import 'package:peera/nardi/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<void> _back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await settle(t);
}

/// backgammon's page, from the games tab
Future<void> _page(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('tab-joker')));
  await settle(t);
  expect(find.byType(GamesTab), findsOneWidget);
  await t.tap(find.byKey(const ValueKey('games-nardi')));
  await settle(t);
  expect(find.byType(NardiTab), findsOneWidget);
}

NardiSession _table(WidgetTester t) => t.widget<NardiScreen>(find.byType(NardiScreen)).table as NardiSession;

/// a tap on view point [v] of the board (0 the bar, -2 the tray); I play the light checkers, so the view is the real one
Future<void> _tapPoint(WidgetTester t, int v) async {
  final r = t.getRect(find.byKey(const ValueKey('nd-board')));
  final geo = BoardGeo(r.size);
  final o = v == -2 ? geo.trayRect.center : (v == bar ? geo.barChecker(true, 0) : geo.checker(v, 0));
  await t.tapAt(r.topLeft + o);
  await t.pump();
}

/// one step of mine with taps: the checker, then where it goes (a checker with one way to go goes at once)
Future<void> _step(WidgetTester t, NardiSession s, Step want) async {
  final tick = s.stepTick;
  await _tapPoint(t, want.from);
  if (s.stepTick != tick) return;
  await _tapPoint(t, want.to == offPoint(0) ? -2 : want.to);
  expect(s.stepTick, tick + 1, reason: 'the step $want was played');
}

/// the game on: I roll and play with taps, the computer plays by itself
Future<void> _playOn(WidgetTester t, NardiSession s, {bool Function()? until, int limit = 5000}) async {
  final pick = Random(1);
  for (var i = 0; i < limit && s.g!.phase != Phase.over && !(until?.call() ?? false); i++) {
    if (s.canRoll) {
      await t.tap(find.byKey(const ValueKey('nd-roll')));
      await t.pump(const Duration(milliseconds: 60));
    } else if (s.canMove) {
      await _step(t, s, botTurn(s.g!, rng: pick, level: 4).first);
    } else {
      await t.pump(const Duration(milliseconds: 400));
    }
  }
}

void main() {
  testWidgets('nardi: a whole game against the computer with taps on the board; the end tells the score', (t) async {
    phone(t);
    SharedPreferences.setMockInitialValues({});
    final api = await shell(t);
    await _page(t);
    expect(find.byKey(const ValueKey('nd-current')), findsNothing);
    expect(find.text('ნიკა'), findsOneWidget);
    expect(find.text('ოსტატი გურამი'), findsOneWidget);
    // the weakest one, then the game
    await t.tap(find.byKey(const ValueKey('nd-bot-1')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('nd-start')));
    await settle(t);
    expect(find.byType(NardiScreen), findsOneWidget);
    final s = _table(t);
    expect(s.level, 1);
    expect(s.bot.name, 'ნიკა');
    await _playOn(t, s);
    expect(s.g!.phase, Phase.over);
    await settle(t);
    expect(find.byKey(const ValueKey('nd-over')), findsOneWidget);
    final won = s.g!.winner == 0;
    expect(find.text(won ? 'მოიგე! 🎉' : 'წააგე'), findsOneWidget);
    expect(s.g!.board.offs[s.g!.winner!], 15);
    expect(api.calls.where((c) => c == 'game nardi won').length, won ? 1 : 0);
    if (won) expect(find.textContaining('+10 მონეტა'), findsOneWidget);
    // closed: the page, with no game going on
    await t.tap(find.byKey(const ValueKey('nd-close')));
    await settle(t);
    expect(find.byType(NardiScreen), findsNothing);
    expect(find.byKey(const ValueKey('nd-current')), findsNothing);
    expect(api.calls.where((c) => c.startsWith('game nardi')).length, won ? 1 : 0, reason: 'told once');
  });

  testWidgets('nardi: back leaves the table and the computer waits; the game goes on from the page and after the app opens again', (t) async {
    phone(t);
    SharedPreferences.setMockInitialValues({});
    await shell(t);
    await _page(t);
    await t.tap(find.byKey(const ValueKey('nd-start')));
    await settle(t);
    final s = _table(t);
    // a few turns, then out on my roll
    var turns = 0;
    await _playOn(t, s, until: () {
      if (s.canRoll) turns++;
      return turns > 3;
    });
    expect(s.canRoll, isTrue);
    await _back(t);
    expect(find.byType(NardiScreen), findsNothing);
    expect(find.byKey(const ValueKey('nd-current')), findsOneWidget);
    expect(find.textContaining('შენი სვლაა'), findsOneWidget);
    final saved = jsonEncode(s.g!.toJson());
    // a new start of the app: the game is read back
    await t.pumpWidget(const SizedBox());
    await shell(t);
    await _page(t);
    expect(find.byKey(const ValueKey('nd-current')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nd-continue')));
    await settle(t);
    final s2 = _table(t);
    expect(jsonEncode(s2.g!.toJson()), saved);
    // the computer's turn goes on only while the table is open
    await t.tap(find.byKey(const ValueKey('nd-roll')));
    await t.pump();
    await _playOn(t, s2, until: () => s2.g!.turn == 1 && s2.g!.phase == Phase.roll);
    if (s2.g!.phase != Phase.over) {
      await _back(t);
      final waiting = jsonEncode(s2.g!.toJson());
      await t.pump(const Duration(seconds: 10));
      expect(jsonEncode(s2.g!.toJson()), waiting, reason: 'the computer waits while the table is closed');
      await t.tap(find.byKey(const ValueKey('nd-continue')));
      await settle(t);
      for (var i = 0; i < 40 && _table(t).g!.turn == 1; i++) {
        await t.pump(const Duration(milliseconds: 400));
      }
      expect(jsonEncode(_table(t).g!.toJson()), isNot(waiting), reason: 'and plays once it is open again');
    }
  });

  testWidgets('nardi: a step taken back before the turn ends; giving up ends the game', (t) async {
    phone(t);
    SharedPreferences.setMockInitialValues({});
    await shell(t);
    await _page(t);
    await t.tap(find.byKey(const ValueKey('nd-start')));
    await settle(t);
    final s = _table(t);
    // on to a turn of mine with two different dice and nothing played yet
    await _playOn(t, s, until: () => s.canMove && s.g!.done.isEmpty && s.g!.left.length == 2 && s.g!.turns.every((x) => x.length == 2));
    expect(find.byKey(const ValueKey('nd-undo')), findsNothing);
    final before = jsonEncode(s.g!.board.toJson());
    await _step(t, s, s.g!.options.first);
    await settle(t);
    expect(s.g!.done.length, 1);
    await t.tap(find.byKey(const ValueKey('nd-undo')));
    await settle(t);
    expect(s.g!.done, isEmpty);
    expect(jsonEncode(s.g!.board.toJson()), before);
    expect(s.g!.left.length, 2);
    // a checker picked up and put back down
    final multi = s.g!.options.map((x) => x.from).firstWhere((f) => s.g!.options.where((x) => x.from == f).map((x) => x.to).toSet().length > 1, orElse: () => -1);
    if (multi >= 0) {
      await _tapPoint(t, multi);
      expect(find.text('სად დავდგა?'), findsOneWidget);
      await _tapPoint(t, multi);
      expect(find.text('სად დავდგა?'), findsNothing);
    }
    // given up
    await t.tap(find.byKey(const ValueKey('nd-resign')));
    await settle(t);
    await t.tap(find.text('დანებება').last);
    await settle(t);
    expect(s.g!.phase, Phase.over);
    expect(s.g!.winner, 1);
    expect(find.text('წააგე'), findsOneWidget);
    expect(find.byKey(const ValueKey('nd-resign')), findsNothing);
    // a new one, from the end card
    await t.tap(find.byKey(const ValueKey('nd-again')));
    await t.pump();
    expect(s.g!.phase, isNot(Phase.over));
    expect(jsonEncode(s.g!.board.toJson()), jsonEncode(Board.start().toJson()));
    await settle(t);
    expect(find.byKey(const ValueKey('nd-over')), findsNothing);
  });
}
