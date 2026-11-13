// The Joker rules, scores and bots, without the screen: the same answers as the site's engine.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:peera/joker/engine.dart';

JCard c(String k) => JCard.parse(k);

/// plays the game on with the bots in every seat until [stop] says so (or the game ends)
void run(JokerGame g, int lv, {bool Function(JokerGame)? stop, void Function(JokerGame, int p, Move m)? onPlay}) {
  var guard = 0;
  while (g.phase != 'over' && (stop == null || !stop(g))) {
    if (++guard > 5000) fail('the game does not move');
    switch (g.phase) {
      case 'trump':
        g.setTrump(g.botTrump(g.cur));
      case 'bid':
        g.bid(g.cur, g.botBid(g.cur, lv));
      case 'play':
        if (g.win != null) {
          g.collect();
        } else {
          final p = g.cur, m = g.botPlay(p, lv);
          onPlay?.call(g, p, m);
          g.play(p, m.c, jm: m.jm, js: m.js);
        }
      case 'handover':
        g.nextHand();
    }
  }
}

void main() {
  test('the deck: 36 cards, no black sixes, two jokers', () {
    final d = jDeck();
    expect(d.length, 36);
    expect(d.toSet().length, 36);
    expect(d.contains(c('s6')), isFalse);
    expect(d.contains(c('c6')), isFalse);
    expect(d.contains(c('h6')), isTrue);
    expect(d.where((x) => x.joker).length, 2);
    expect(c('h14').name, 'A გული');
    expect(c('j2').name, 'ჯოკერი');
  });

  test('points for a hand', () {
    expect(jPts(2, 2, 5, 200), 150); // bid and made: 50 a trick and 50
    expect(jPts(0, 0, 5, 200), 50); // a pass kept
    expect(jPts(3, 3, 3, 200), 300); // all the tricks
    expect(jPts(2, 3, 5, 200), 30); // more than said: 10 a trick
    expect(jPts(2, 1, 5, 200), 10);
    expect(jPts(2, 0, 5, 200), -200); // ხიშტი
    expect(jPts(1, 0, 9, 500), -500);
    expect(jPts(0, 2, 5, 200), 20);
  });

  test('the sections of the full game and their ends', () {
    expect([for (var h = 0; h < 24; h++) jSec('full', h)], [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3]);
    expect([for (var h = 0; h < 24; h++) if (jSecEnd('full', h)) h], [7, 11, 19, 23]);
    expect([for (var h = 0; h < 16; h++) if (jSecEnd('nines', h)) h], [3, 7, 11, 15]);
    expect(jSecEnd('quick', 7), isTrue);
  });

  test('the premium: whoever made every bid of the section doubles their best hand, the others lose theirs', () {
    final hist = [
      HandRow(n: 1, b: [1, 0, 0, 0], t: [1, 0, 0, 0], p: [100, 50, 50, 50], s: 0),
      HandRow(n: 2, b: [1, 1, 0, 1], t: [1, 0, 1, 0], p: [100, -200, 10, -200], s: 0),
    ];
    expect(jPremium(hist, 0), [100, -50, -50, -50]);
    // nobody made every bid: nothing
    expect(jPremium([HandRow(n: 2, b: [2, 1, 0, 1], t: [1, 0, 1, 0], p: [10, -200, 10, -200], s: 0)], 0), [0, 0, 0, 0]);
  });

  JokerGame table(String? trump, List<Play> plays) {
    final g = JokerGame.start('quick', rng: Random(1));
    g.trump = trump;
    g.trick = plays;
    return g;
  }

  test('who takes a trick', () {
    // the highest of the suit led
    expect(table('s', [Play(0, c('h9')), Play(1, c('h14')), Play(2, c('d14')), Play(3, c('h10'))]).winner(), 1);
    // a trump beats it
    expect(table('s', [Play(0, c('h9')), Play(1, c('h14')), Play(2, c('s7')), Play(3, c('h10'))]).winner(), 2);
    // a high joker takes, a later high joker beats an earlier one
    expect(table('s', [Play(0, c('h9')), Play(1, c('j1'), jm: 'hi'), Play(2, c('s14')), Play(3, c('j2'), jm: 'hi')]).winner(), 3);
    // a low joker never takes when it does not lead
    expect(table('s', [Play(0, c('h9')), Play(1, c('j1'), jm: 'lo'), Play(2, c('h7')), Play(3, c('h8'))]).winner(), 0);
    // a high joker that led a plain suit loses to a trump
    expect(table('s', [Play(0, c('j1'), jm: 'hi', js: 'h'), Play(1, c('h14')), Play(2, c('s7')), Play(3, c('h10'))]).winner(), 2);
    // ... but not when it named the trump
    expect(table('s', [Play(0, c('j1'), jm: 'hi', js: 's'), Play(1, c('s14')), Play(2, c('s7')), Play(3, c('h10'))]).winner(), 0);
    // a low joker that led: the highest of its suit takes; if nobody followed, it takes itself
    expect(table(null, [Play(0, c('j1'), jm: 'lo', js: 'h'), Play(1, c('h7')), Play(2, c('h12')), Play(3, c('d14'))]).winner(), 2);
    expect(table(null, [Play(0, c('j1'), jm: 'lo', js: 'h'), Play(1, c('c7')), Play(2, c('d12')), Play(3, c('d14'))]).winner(), 0);
  });

  test('what may be played', () {
    final g = JokerGame.start('quick', rng: Random(1));
    g.trump = 's';
    g.hands[1] = [c('h7'), c('h12'), c('s9'), c('d8'), c('j1')];
    g.trick = [Play(0, c('h9'))];
    expect(g.legal(1).toSet(), {c('h7'), c('h12'), c('j1')}); // follow the suit (a joker any time)
    g.trick = [Play(0, c('c9'))];
    expect(g.legal(1).toSet(), {c('s9'), c('j1')}); // no clubs: a trump
    g.trick = [Play(0, c('j2'), jm: 'hi', js: 'h')];
    expect(g.legal(1).toSet(), {c('h12'), c('j1')}); // a high joker asks for the highest of hearts
    g.hands[1] = [c('d8'), c('d9')];
    g.trick = [Play(0, c('c9'))];
    expect(g.legal(1).toSet(), {c('d8'), c('d9')}); // neither suit nor trump: anything
  });

  test('the dealer may not make the bids add up to the cards', () {
    final g = JokerGame.start('quick', rng: Random(3));
    while (g.n < 3 || g.phase != 'bid') {
      run(g, 2, stop: (x) => x.phase == 'handover');
      g.nextHand();
    }
    final first = g.cur;
    g.bid(first, 1);
    g.bid((first + 1) % 4, 0);
    g.bid((first + 2) % 4, 1);
    expect(g.cur, g.dealer);
    expect(g.forbidden(g.dealer), g.n - 2);
    expect(g.forbidden(first), -1);
    expect(g.botBid(g.dealer, 3), isNot(g.n - 2));
  });

  for (final len in ['quick', 'full', 'nines']) {
    for (var lv = 1; lv <= 5; lv++) {
      test('a whole $len game with bots of level $lv keeps the rules', () {
        for (var seed = 0; seed < 6; seed++) {
          final g = JokerGame.start(len, rng: Random(seed * 31 + lv));
          var hands = 0;
          run(g, lv, onPlay: (g, p, m) {
            expect(g.legal(p), contains(m.c), reason: 'a card that may not be played');
          }, stop: (g) {
            if (g.phase == 'handover' || (g.phase == 'over' && g.hist.isNotEmpty)) {
              final l = jLast(g.hist).hand!;
              expect(l.t.reduce((a, b) => a + b), l.n, reason: 'every trick is taken by someone');
              expect(l.b.reduce((a, b) => a + b), isNot(l.n), reason: 'the dealer rule');
              hands++;
            }
            return false;
          });
          expect(g.phase, 'over');
          expect(g.h, jSeq[len]!.length);
          expect(g.hist.where((r) => !r.pr).length, jSeq[len]!.length);
          for (var p = 0; p < 4; p++) {
            expect(g.score[p], g.hist.fold<int>(0, (a, r) => a + r.p[p]));
          }
          expect(hands, greaterThan(0));
        }
      });
    }
  }

  test('a game in the middle is saved and comes back the same', () {
    final g = JokerGame.start('full', rng: Random(9));
    run(g, 4, stop: (g) => g.h == 9 && g.phase == 'play' && g.trick.length == 2);
    final back = JokerGame.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map, rng: Random(1))!;
    expect(jsonEncode(back.toJson()), jsonEncode(g.toJson()));
    expect(back.legal(back.cur), g.legal(g.cur));
    run(back, 4);
    expect(back.phase, 'over');
  });

  test('the stronger bots do better than the weakest', () {
    var strong = 0, weak = 0;
    for (var seed = 0; seed < 40; seed++) {
      // seats 0 and 2 play at level 5, 1 and 3 at level 1
      final g = JokerGame.start('quick', rng: Random(seed));
      var guard = 0;
      while (g.phase != 'over' && guard++ < 3000) {
        final lv = g.cur.isEven ? 5 : 1;
        switch (g.phase) {
          case 'bid':
            g.bid(g.cur, g.botBid(g.cur, lv));
          case 'play':
            if (g.win != null) {
              g.collect();
            } else {
              final m = g.botPlay(g.cur, lv);
              g.play(g.cur, m.c, jm: m.jm, js: m.js);
            }
          case 'handover':
            g.nextHand();
        }
      }
      strong += g.score[0] + g.score[2];
      weak += g.score[1] + g.score[3];
    }
    expect(strong, greaterThan(weak));
  });

  test('the bid hint never says what the dealer may not', () {
    final hand = [c('h14'), c('h13'), c('s9'), c('j1')];
    final f = jHint(hand, 'h', 4, -1);
    expect(jHint(hand, 'h', 4, f), isNot(f));
  });
}
