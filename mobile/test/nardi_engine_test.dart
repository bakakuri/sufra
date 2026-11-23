// Short backgammon's rules and computer player, without the screen.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:peera/nardi/engine.dart';

/// a board with only the checkers given: point → count (+ mine, − theirs)
Board board(Map<int, int> pts, {List<int> bars = const [0, 0], List<int> offs = const [0, 0]}) {
  final b = Board.empty();
  pts.forEach((p, n) => b.pts[p] = n);
  b.bars
    ..[0] = bars[0]
    ..[1] = bars[1];
  b.offs
    ..[0] = offs[0]
    ..[1] = offs[1];
  return b;
}

/// every checker of [pl], wherever it is
int total(Board b, int pl) {
  var n = b.bars[pl] + b.offs[pl];
  for (var p = 1; p <= 24; p++) {
    n += b.cnt(p, pl);
  }
  return n;
}

/// [turn] to move on [b] with the dice given (roll() would throw its own)
NardiGame game(Board b, int turn, int d1, int d2) => NardiGame(board: b)
  ..turn = turn
  ..dice = [d1, d2]
  ..phase = Phase.move
  ..left = turnDice(d1, d2)
  ..turns = legalTurns(b, turn, turnDice(d1, d2));

void main() {
  test('the start: fifteen checkers each, 167 pips each', () {
    final b = Board.start();
    expect(total(b, 0), 15);
    expect(total(b, 1), 15);
    expect(b.pips(0), 167);
    expect(b.pips(1), 167);
    expect(b.over, isFalse);
  });

  test('the opening roll: the dice differ and the higher starts with both', () {
    for (var seed = 0; seed < 40; seed++) {
      final g = NardiGame(rng: Random(seed))..open();
      expect(g.dice[0], isNot(g.dice[1]));
      expect(g.turn, g.dice[0] > g.dice[1] ? 0 : 1);
      expect(g.phase, Phase.move);
      expect(g.left.length, 2);
    }
  });

  test('a point with two of theirs is closed; a lone one is hit and goes to the bar', () {
    final b = board({13: 1, 10: -2, 9: -1, 1: -12});
    expect(b.step(0, 13, 3), isNull);
    final s = b.step(0, 13, 4)!;
    expect(s.hit, isTrue);
    final a = b.after(0, s);
    expect(a.bars[1], 1);
    expect(a.pts[9], 1);
    expect(total(a, 1), 15);
  });

  test('a checker on the bar enters first, in their home (mine at 25 − die, theirs at the die)', () {
    final b = board({13: 14, 22: -2}, bars: [1, 0]);
    // nothing else moves while one is on the bar
    expect(b.step(0, 13, 1), isNull);
    expect(b.step(0, bar, 3), isNull, reason: '22 is closed');
    expect(b.step(0, bar, 4)!.to, 21);
    final c = board({12: -14, 4: 2}, bars: [0, 1]);
    expect(c.step(1, bar, 4), isNull);
    expect(c.step(1, bar, 2)!.to, 2);
  });

  test('bearing off: only with all at home, exactly, or from the farthest with a larger die', () {
    expect(board({7: 1, 3: 14}).step(0, 3, 3), isNull, reason: 'one is not home');
    final b = board({5: 2, 3: 13});
    expect(b.step(0, 3, 3)!.to, offPoint(0));
    expect(b.step(0, 3, 6), isNull, reason: 'a checker stands farther, on 5');
    expect(b.step(0, 5, 6)!.to, offPoint(0));
    final t = board({20: -2, 22: -13});
    expect(t.step(1, 22, 3)!.to, offPoint(1));
    expect(t.step(1, 22, 5), isNull);
    expect(t.step(1, 20, 6)!.to, offPoint(1));
  });

  test('both dice are played when they can be; when only one can, the larger', () {
    // one free checker on 13: 3 then 1, or 1 then 3, both steps every time
    final g = game(board({13: 1, 1: -2, 24: -13}), 0, 3, 1);
    expect(g.turns, isNotEmpty);
    expect(g.turns.every((t) => t.length == 2), isTrue);
    // fourteen are shut in on 24 (18 and 19 are closed); the one on 8 can go 6 or 5, never both: the 6
    final h = game(board({24: 14, 8: 1, 18: -2, 19: -2, 12: -11}), 0, 6, 5);
    expect(h.turns.length, 1);
    expect(h.turns.single, [const Step(8, 2, 6)]);
  });

  test('a double is four steps', () {
    final g = game(Board.start(), 0, 4, 4);
    expect(g.left, [4, 4, 4, 4]);
    expect(g.turns.every((t) => t.length == 4), isTrue);
  });

  test('no step at all: the turn passes', () {
    final b = board({24: 15, 18: -2, 19: -2, 20: -2, 21: -2, 22: -2, 23: -5});
    final g = NardiGame(board: b, rng: Random(1))
      ..phase = Phase.roll
      ..turn = 0;
    g.roll();
    expect(g.phase, Phase.roll);
    expect(g.turn, 1);
    expect(g.lastBy, 0);
    expect(g.last, isEmpty);
  });

  test('a step is played, taken back (a hit one comes back from the bar), and the turn ends by itself', () {
    final b = board({13: 2, 9: -1, 1: -14});
    final g = game(b, 0, 4, 2);
    final hit = g.options.firstWhere((s) => s.to == 9);
    expect(hit.hit, isTrue);
    expect(g.play(hit), isTrue);
    expect(g.board.bars[1], 1);
    expect(g.play(const Step(13, 5, 4)), isFalse, reason: 'the 4 is used');
    g.undo();
    expect(jsonEncode(g.board.toJson()), jsonEncode(b.toJson()));
    expect(g.left, [4, 2]);
    g.play(g.options.first);
    g.play(g.options.first);
    expect(g.phase, Phase.roll);
    expect(g.turn, 1);
    expect(g.last.length, 2);
  });

  test('the points: one, two (none of the loser\'s off), three (and one still on the bar or in my home)', () {
    expect(board({1: -5}, offs: [15, 10]).points(0), 1);
    expect(board({13: -15}, offs: [15, 0]).points(0), 2);
    expect(board({13: -14}, bars: [0, 1], offs: [15, 0]).points(0), 3);
    expect(board({3: -1, 13: -14}, offs: [15, 0]).points(0), 3);
    final g = NardiGame(rng: Random(3))..open();
    g.resign(0);
    expect(g.phase, Phase.over);
    expect(g.winner, 1);
    expect(g.pts, 1);
  });

  test('a game read back from its saved form goes on the same', () {
    final g = NardiGame(rng: Random(5))..open();
    if (g.turn == 0) g.play(g.options.first);
    final r = NardiGame.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map);
    expect(jsonEncode(r.toJson()), jsonEncode(g.toJson()));
    expect(r.options, g.options);
  });

  test('the computer plays whole games to the end, every step allowed, no checker lost', () {
    for (var seed = 0; seed < 12; seed++) {
      final rng = Random(seed);
      final g = NardiGame(rng: rng)..open();
      var guard = 0;
      while (g.phase != Phase.over) {
        if (++guard > 3000) fail('the game does not move (seed $seed)');
        if (g.phase == Phase.roll) {
          g.roll();
          continue;
        }
        final t = botTurn(g, level: seed % 4 + 1);
        expect(t, isNotEmpty);
        for (final s in t) {
          expect(g.options, contains(s));
          expect(g.play(s), isTrue);
          expect(total(g.board, 0), 15);
          expect(total(g.board, 1), 15);
        }
      }
      expect(g.winner, isNotNull);
      expect(g.board.offs[g.winner!], 15);
      expect(g.pts, inInclusiveRange(1, 3));
    }
  });

  test('the strongest computer beats the weakest more often than not', () {
    var strong = 0;
    for (var seed = 0; seed < 30; seed++) {
      final g = NardiGame(rng: Random(100 + seed))..open();
      final rng = Random(seed);
      while (g.phase != Phase.over) {
        if (g.phase == Phase.roll) {
          g.roll();
        } else {
          g.playTurn(botTurn(g, rng: rng, level: g.turn == 0 ? 4 : 1));
        }
      }
      if (g.winner == 0) strong++;
    }
    expect(strong, greaterThan(15));
  });
}
