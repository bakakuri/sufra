// Joker (ჯოკერი) for four, Georgian rules: the site's engine (js/games-engines.js), the same rules, scores and bots.
// Pure Dart, no timers: the table drives it.
import 'dart:math' as math;

const suits = ['s', 'c', 'h', 'd'];
const suitName = {'s': 'ყვავი', 'c': 'ჯვარი', 'h': 'გული', 'd': 'აგური'};
bool isRed(String s) => s == 'h' || s == 'd';

/// A card: a suit and a rank 6…14 (J 11, Q 12, K 13, A 14), or one of the two jokers.
class JCard {
  const JCard(this.s, this.r) : j = 0;
  const JCard.joker(this.j)
      : s = '',
        r = 0;
  final String s;
  final int r, j;

  bool get joker => j > 0;
  String get key => joker ? 'j$j' : '$s$r';
  String get rank => const {11: 'J', 12: 'Q', 13: 'K', 14: 'A'}[r] ?? '$r';
  String get name => joker ? 'ჯოკერი' : '$rank ${suitName[s]}';

  static JCard parse(String k) => k.startsWith('j') ? JCard.joker(int.parse(k.substring(1))) : JCard(k[0], int.parse(k.substring(1)));

  @override
  bool operator ==(Object o) => o is JCard && o.key == key;
  @override
  int get hashCode => key.hashCode;
  @override
  String toString() => key;
}

/// 36 cards: six to ace in four suits without the two black sixes, and two jokers.
List<JCard> jDeck() => [
      for (final s in suits)
        for (var r = 6; r <= 14; r++)
          if (!(r == 6 && (s == 's' || s == 'c'))) JCard(s, r),
      const JCard.joker(1),
      const JCard.joker(2),
    ];

int _order(JCard c) => c.joker ? 99 : suits.indexOf(c.s) * 20 + c.r;
List<JCard> sortHand(List<JCard> h) => h..sort((a, b) => _order(a).compareTo(_order(b)));

/// A card on the table. A joker says what it is: high (takes) or low; a joker that leads also names a suit.
class Play {
  const Play(this.p, this.card, {this.jm, this.js});
  final int p;
  final JCard card;
  final String? jm, js;

  Map<String, dynamic> toJson() => {'p': p, 'c': card.key, if (jm != null) 'jm': jm, if (js != null) 'js': js};
  static Play fromJson(Map m) => Play(m['p'] as int, JCard.parse(m['c'] as String), jm: m['jm'] as String?, js: m['js'] as String?);
}

/// How a joker was played, said as at the table.
String jokerCall(Play e) => (e.jm == 'hi' ? 'მაღალი' : (e.js != null ? 'წაიღოს' : 'დაბალი'));

/// A trick that was taken: the four cards in order and who took it.
class Trick {
  const Trick(this.t, this.w);
  final List<Play> t;
  final int w;
  Map<String, dynamic> toJson() => {'t': [for (final e in t) e.toJson()], 'w': w};
  static Trick fromJson(Map m) => Trick([for (final e in m['t'] as List) Play.fromJson(e as Map)], m['w'] as int);
}

/// A row of the score sheet: a hand (cards dealt, what each said and took, the points), or a section premium.
class HandRow {
  const HandRow({required this.n, required this.b, required this.t, required this.p, required this.s, this.pr = false});
  final int n, s;
  final List<int> b, t, p;
  final bool pr;

  Map<String, dynamic> toJson() => {'n': n, 'b': b, 't': t, 'p': p, 's': s, if (pr) 'pr': 1};
  static HandRow fromJson(Map m) => HandRow(
        n: m['n'] as int,
        b: [for (final x in m['b'] as List) x as int],
        t: [for (final x in m['t'] as List) x as int],
        p: [for (final x in m['p'] as List) x as int],
        s: m['s'] as int,
        pr: m['pr'] != null,
      );
}

/// The three games: quick (1 to 8 cards), full (1–8, four nines, 8–1, four nines), nines (sixteen hands of nine).
const jSeq = {
  'quick': [1, 2, 3, 4, 5, 6, 7, 8],
  'full': [1, 2, 3, 4, 5, 6, 7, 8, 9, 9, 9, 9, 8, 7, 6, 5, 4, 3, 2, 1, 9, 9, 9, 9],
  'nines': [9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9],
};
const jLenName = {'quick': 'სწრაფი', 'full': 'სრული', 'nines': 'ცხრიანები'};
const jSecName = ['1-დან 8-მდე', 'ცხრიანები', '8-დან 1-მდე', 'ცხრიანები'];
const jSecName9 = ['პირველი ოთხი', 'მეორე ოთხი', 'მესამე ოთხი', 'მეოთხე ოთხი'];

int jSec(String len, int h) => len == 'full'
    ? (h < 8 ? 0 : h < 12 ? 1 : h < 20 ? 2 : 3)
    : len == 'nines'
        ? math.min(3, h ~/ 4)
        : 0;
bool jSecEnd(String len, int h) => len == 'full' ? const [7, 11, 19, 23].contains(h) : len == 'nines' ? h % 4 == 3 : h == 7;

/// Bid and made: 50 a trick and 50 more; all the tricks bid and taken: 100 a trick; a pass kept: 50;
/// otherwise 10 a trick; bid but took none (ხიშტი): −200, or −500 in the nine-card sections.
int jPts(int b, int t, int n, int kh) {
  if (t == b) return b == n ? 100 * n : (b == 0 ? 50 : 50 * b + 50);
  if (b > 0 && t == 0) return -kh;
  return 10 * t;
}

/// A section premium: whoever made every bid of a section gets their best hand there again, and the others lose theirs.
List<int> jPremium(List<HandRow> hist, int sec) {
  final rows = [for (final r in hist) if (!r.pr && r.s == sec) r];
  if (rows.isEmpty) return [0, 0, 0, 0];
  final all = [for (var p = 0; p < 4; p++) rows.every((r) => r.b[p] == r.t[p])];
  final best = [for (var p = 0; p < 4; p++) rows.fold<int>(0, (a, r) => math.max(a, r.p[p]))];
  final any = all.any((x) => x);
  return [for (var p = 0; p < 4; p++) all[p] ? best[p] : (any ? -best[p] : 0)];
}

/// The last hand of the sheet and the premium that came with it.
({HandRow? hand, HandRow? prem}) jLast(List<HandRow> hist) {
  if (hist.isEmpty) return (hand: null, prem: null);
  final l = hist.last;
  if (l.pr) return (hand: hist.length > 1 ? hist[hist.length - 2] : null, prem: l);
  return (hand: l, prem: null);
}

/// How many tricks a hand should take, counted the way a careful player does (the bid hint and the stronger bots use it).
double jEst(List<JCard> hand, String? tr) {
  var e = 0.0;
  int len(String s) => hand.where((c) => !c.joker && c.s == s).length;
  final nt = tr != null ? len(tr) : 0;
  for (final c in hand) {
    if (c.joker) {
      e += 1;
    } else if (tr != null && c.s == tr) {
      e += c.r == 14 ? .95 : c.r == 13 ? .8 : c.r == 12 ? .55 : c.r == 11 ? .4 : .25;
    } else {
      final l = len(c.s);
      e += c.r == 14 ? (l <= 3 ? .8 : .6) : c.r == 13 ? (l >= 2 && l <= 4 ? .4 : .2) : 0;
    }
  }
  if (tr != null && nt >= 4) e += (nt - 3) * .3;
  if (tr != null && nt > 0) {
    for (final s in suits) {
      if (s != tr && len(s) == 0) e += math.min(nt, 2) * .3;
    }
  }
  return e;
}

int _round(double e) => (e + .5).floor();

/// The bid the hint shows: the estimate, never the one the dealer may not say.
int jHint(List<JCard> hand, String? tr, int n, int f) {
  final e = jEst(hand, tr);
  var b = math.max(0, math.min(n, _round(e)));
  if (b == f) b = e >= b && b < n ? b + 1 : (b > 0 ? b - 1 : b + 1);
  return b;
}

/// The bot levels, as on the site.
const botLevels = [
  (n: 'ახალბედა', d: 'ხშირად ცდება, კარგია სწავლისთვის'),
  (n: 'მოყვარული', d: 'საშუალო სირთულე, მშვიდი პარტიისთვის'),
  (n: 'გამოცდილი', d: 'უფრო შორს ითვლის და იშვიათად ცდება'),
  (n: 'ოსტატი', d: 'ახსოვს გასული კარტები და იცის, რომელი აღარ წავა'),
  (n: 'ექსპერტი', d: 'ითვლის გასულ კარტებს და ჯოკერებს, ახსოვს, ვის რომელი ფერი აღარ აქვს'),
];

/// A move a bot (or the player) makes: the card, and for a joker what it is called.
class Move {
  const Move(this.c, {this.jm, this.js});
  final JCard c;
  final String? jm, js;
}

/// One game: the hands, the bids, the table, the sheet. Seat 0 is the player; 1–3 sit left, across, right.
class JokerGame {
  JokerGame._(this.len, this.rng);

  /// a new game of [len] ('quick', 'full', 'nines'); the first hand is dealt at once
  factory JokerGame.start(String len, {math.Random? rng}) {
    final g = JokerGame._(jSeq.containsKey(len) ? len : 'quick', rng ?? math.Random());
    g.dealer = g.rng.nextInt(4);
    g.newHand();
    return g;
  }

  /// an empty game to fill from elsewhere (a server table, seen from one seat)
  factory JokerGame.view(String len) => JokerGame._(jSeq.containsKey(len) ? len : 'quick', math.Random());

  final String len;
  final math.Random rng;
  int h = 0;
  List<int> score = [0, 0, 0, 0];
  List<HandRow> hist = [];
  int dealer = 0, n = 1;
  List<List<JCard>> hands = [[], [], [], []];
  List<List<JCard>> first3 = [[], [], [], []];
  List<int?> bids = [null, null, null, null];
  List<int> taken = [0, 0, 0, 0];
  List<Play> trick = [];
  String? trump;
  JCard? trumpCard;

  /// 'trump' (a nine-card hand's trump is being chosen), 'bid', 'play', 'handover' (the hand is scored), 'over'
  String phase = 'bid';
  int cur = 0;

  /// who took the trick that is complete on the table (it is collected a moment later)
  int? win;
  Set<String> gone = {};
  List<Set<String>> voids = [{}, {}, {}, {}];
  int jg = 0;
  Trick? lastT;
  List<Trick> tricks = [];

  List<int> get seq => jSeq[len]!;
  int get sec => jSec(len, math.min(h, seq.length - 1));

  void newHand() {
    n = seq[h];
    gone = {};
    voids = [{}, {}, {}, {}];
    jg = 0;
    lastT = null;
    tricks = [];
    dealer = (dealer + 1) % 4;
    final d = jDeck()..shuffle(rng);
    first3 = [for (var i = 0; i < 4; i++) d.sublist(i * n, i * n + math.min(3, n))];
    hands = [for (var i = 0; i < 4; i++) sortHand(d.sublist(i * n, (i + 1) * n))];
    bids = [null, null, null, null];
    taken = [0, 0, 0, 0];
    trick = [];
    win = null;
    cur = (dealer + 1) % 4;
    if (n < 9) {
      final tc = d[4 * n];
      trumpCard = tc;
      trump = tc.joker ? null : tc.s;
      phase = 'bid';
    } else {
      trumpCard = null;
      trump = null;
      phase = 'trump';
    }
  }

  void setTrump(String? s) {
    trump = (s == null || s.isEmpty) ? null : s;
    phase = 'bid';
    cur = (dealer + 1) % 4;
  }

  /// what the dealer may not say (so that the bids never add up to the cards); −1 for anyone else
  int forbidden(int p) {
    if (p != dealer) return -1;
    final f = n - bids.fold<int>(0, (a, x) => a + (x ?? 0));
    return f >= 0 ? f : -1;
  }

  void bid(int p, int b) {
    bids[p] = b;
    if (bids.every((x) => x != null)) {
      phase = 'play';
      cur = (dealer + 1) % 4;
    } else {
      cur = (p + 1) % 4;
    }
  }

  String? _suitOf(Play lead) => lead.card.joker ? lead.js : lead.card.s;

  /// The cards [p] may play: follow the suit (a high joker that led asks for the highest of it); without the suit, a trump;
  /// a joker any time.
  List<JCard> legal(int p) {
    final hand = hands[p], t = trick;
    if (t.isEmpty) return [...hand];
    final lead = t.first, suit = _suitOf(lead), jokers = hand.where((c) => c.joker).toList();
    final of = hand.where((c) => !c.joker && c.s == suit).toList();
    if (of.isNotEmpty) {
      if (lead.card.joker && lead.jm == 'hi') {
        final mx = of.map((c) => c.r).reduce(math.max);
        return [...of.where((c) => c.r == mx), ...jokers];
      }
      return [...of, ...jokers];
    }
    final tr = trump != null ? hand.where((c) => !c.joker && c.s == trump).toList() : <JCard>[];
    return tr.isNotEmpty ? [...tr, ...jokers] : [...hand];
  }

  /// A later high joker beats an earlier one. A high joker that led a plain suit loses to a trump.
  /// A low joker that led wins only if nobody followed the suit, trumped or played a high joker.
  int winner([List<Play>? t]) {
    t ??= trick;
    final lead = t.first, suit = _suitOf(lead);
    final trumped = trump != null && t.any((e) => !e.card.joker && e.card.s == trump);
    var best = 0, bv = -1 << 30;
    for (var i = 0; i < t.length; i++) {
      final e = t[i];
      int v;
      if (e.card.joker) {
        v = e.jm == 'hi' ? (i == 0 && trumped && lead.js != trump ? 99 : 1000 + i) : -1;
      } else if (trump != null && e.card.s == trump) {
        v = 100 + e.card.r;
      } else if (e.card.s == suit) {
        v = e.card.r;
      } else {
        v = 0;
      }
      if (v > bv) {
        bv = v;
        best = i;
      }
    }
    return bv <= 0 ? t.first.p : t[best].p;
  }

  /// [p] plays [c]; true when it completed the trick (then [win] says who took it, and [collect] clears the table)
  bool play(int p, JCard c, {String? jm, String? js}) {
    hands[p].remove(c);
    final lead = trick.isEmpty;
    if (!c.joker) gone.add(c.key);
    if (c.joker) jg++;
    if (!lead && !c.joker) {
      final su = _suitOf(trick.first);
      if (su != null && c.s != su) {
        voids[p].add(su);
        if (trump != null && c.s != trump) voids[p].add(trump!);
      }
    }
    trick.add(Play(p, c, jm: c.joker ? (jm ?? 'hi') : null, js: c.joker && lead ? (js ?? suits[rng.nextInt(4)]) : null));
    if (trick.length < 4) {
      cur = (p + 1) % 4;
      return false;
    }
    final w = winner();
    taken[w]++;
    cur = -1;
    win = w;
    tricks.add(Trick([...trick], w));
    return true;
  }

  /// the taken trick leaves the table; the one who took it leads, or the hand is scored
  void collect() {
    final w = win;
    if (w == null) return;
    lastT = Trick([...trick], w);
    trick = [];
    win = null;
    if (hands[0].isEmpty) {
      endHand();
    } else {
      cur = w;
    }
  }

  void endHand() {
    final s = jSec(len, h);
    final kh = len == 'nines' || s.isOdd ? 500 : 200;
    final pts = [for (var p = 0; p < 4; p++) jPts(bids[p] ?? 0, taken[p], n, kh)];
    for (var p = 0; p < 4; p++) {
      score[p] += pts[p];
    }
    hist.add(HandRow(n: n, b: [for (final b in bids) b ?? 0], t: [...taken], p: pts, s: s));
    if (jSecEnd(len, h)) {
      final pr = jPremium(hist, s);
      if (pr.any((x) => x != 0)) {
        for (var p = 0; p < 4; p++) {
          score[p] += pr[p];
        }
        hist.add(HandRow(n: 0, b: const [], t: const [], p: pr, s: s, pr: true));
      }
    }
    h++;
    cur = -1;
    phase = h >= seq.length ? 'over' : 'handover';
  }

  void nextHand() {
    if (phase == 'handover') newHand();
  }

  /// the places at the end: seats from the most points down
  List<int> get order => [0, 1, 2, 3]..sort((a, b) => score[b].compareTo(score[a]));
  bool get iWon => score[0] == score.reduce(math.max);

  // ---------- the bots ----------

  int _val(JCard c) => c.joker ? 60 : (trump != null && c.s == trump ? 20 + c.r : c.r);
  int _byV(JCard a, JCard b) => _val(a).compareTo(_val(b));

  /// a nine-card hand's trump, from the first three cards: the suit they are strongest in, if strong enough
  String? botTrump(int p) {
    final sc = <String, int>{};
    for (final c in first3[p]) {
      if (!c.joker) sc[c.s] = (sc[c.s] ?? 0) + c.r;
    }
    if (sc.isEmpty) return null;
    final best = sc.entries.reduce((a, b) => b.value > a.value ? b : a);
    return best.value >= 11 ? best.key : null;
  }

  int botBid(int p, int lv) {
    final hand = hands[p], n = hand.length;
    var e = 0.0;
    if (lv >= 3) {
      e = jEst(hand, trump);
    } else {
      for (final c in hand) {
        if (c.joker) {
          e += 1;
        } else if (trump != null && c.s == trump) {
          e += c.r >= 13 ? .9 : c.r >= 11 ? .55 : .3;
        } else {
          e += c.r == 14 ? .7 : c.r == 13 ? .3 : 0;
        }
      }
    }
    if (lv == 1) e += rng.nextDouble() * 2.4 - 1.2;
    if (lv >= 5) {
      final said = bids.whereType<int>().toList(), os = said.fold<int>(0, (a, x) => a + x);
      if (said.isNotEmpty) e += (n - os - e) * .18 * said.length / 3;
    }
    var b = math.max(0, math.min(n, _round(e)));
    if (b == forbidden(p)) {
      final f = b;
      b = lv >= 5 ? (e >= f && f < n ? f + 1 : (f > 0 ? f - 1 : f + 1)) : (b > 0 ? b - 1 : b + 1);
    }
    return math.min(n, b);
  }

  bool _top(JCard c, List<JCard> hand) {
    for (var r = c.r + 1; r <= 14; r++) {
      if (!gone.contains('${c.s}$r') && !hand.any((h) => !h.joker && h.s == c.s && h.r == r)) return false;
    }
    return true;
  }

  bool _wins(int p, JCard c, {String? jm}) => winner([...trick, Play(p, c, jm: jm)]) == p;

  /// the expert: a card is sure when every higher card of its suit is gone or its own, no joker is still out with the others,
  /// and nobody still to play can trump it. It leads sure cards when it needs tricks, wins with the cheapest card that holds,
  /// and throws its dangerous high cards while it wants no more.
  Move? _botPlay5(int p) {
    final l = legal(p), hand = hands[p], need = (bids[p] ?? 0) - taken[p], t = trick;
    final nj = l.where((c) => !c.joker).toList();
    final jk = l.where((c) => c.joker).firstOrNull;
    final jOut = 2 - jg - hand.where((c) => c.joker).length;
    final after = [for (var k = 1; k <= 3; k++) (p + k) % 4].take(3 - t.length).toList();
    bool noRuff(JCard c) => trump == null || c.s == trump || after.every((q) => !voids[q].contains(c.s) || voids[q].contains(trump));
    bool holds(JCard c) {
      if (c.joker) return true;
      if (jOut > 0) return false;
      final tr = trump != null && c.s == trump;
      if (t.isNotEmpty && !_wins(p, c)) return false;
      final su = t.isNotEmpty ? _suitOf(t.first) : c.s;
      if (c.s != su && !tr) return false;
      return _top(c, hand) && (tr || noRuff(c));
    }

    if (t.isEmpty) {
      if (need > 0) {
        final sure = nj.where(holds).toList()..sort(_byV);
        if (sure.isNotEmpty) return Move(sure.last);
        if (jk != null && need >= hand.length) return Move(jk, jm: 'hi', js: trump ?? suits[0]);
        return null;
      }
      final safe = nj.where((c) => !holds(c)).toList()..sort(_byV);
      return safe.isNotEmpty ? Move(safe.first) : null;
    }
    if (need > 0) {
      final w = nj.where((c) => _wins(p, c)).toList()..sort(_byV);
      if (w.isEmpty) return null;
      if (t.length == 3) return Move(w.first);
      final h = w.where(holds).toList();
      return Move((h.isNotEmpty ? h : w).first);
    }
    final lose = nj.where((c) => !_wins(p, c)).toList()..sort(_byV);
    return lose.isNotEmpty ? Move(lose.last) : null;
  }

  Move botPlay(int p, int lv) {
    final l = legal(p), need = (bids[p] ?? 0) - taken[p], t = trick;
    final nj = l.where((c) => !c.joker).toList();
    final jk = l.where((c) => c.joker).firstOrNull;
    if (lv >= 5) {
      final m = _botPlay5(p);
      if (m != null) return m;
    }
    if (lv == 1 && rng.nextDouble() < .45) {
      final c = l[rng.nextInt(l.length)];
      return c.joker ? Move(c, jm: rng.nextDouble() < .5 ? 'hi' : 'lo', js: trump ?? suits[rng.nextInt(4)]) : Move(c);
    }
    // the top levels lead a card nobody can beat any more: every higher card of its suit is already played or its own
    if (lv >= 4 && t.isEmpty) {
      final hand = hands[p];
      bool sure(JCard c) => !c.joker && (trump == null || c.s == trump || gone.length >= 20) && _top(c, hand);
      final ss = nj.where(sure).toList();
      if (need > 0 && ss.isNotEmpty) return Move((ss..sort((a, b) => _val(b).compareTo(_val(a)))).first);
      if (need <= 0) {
        final safe = nj.where((c) => !sure(c)).toList();
        if (safe.isNotEmpty) return Move((safe..sort(_byV)).first);
      }
    }
    final byV = [...nj]..sort(_byV);
    if (t.isEmpty) {
      if (need > 0) {
        final top = byV.lastOrNull;
        if (top != null && (top.r == 14 || (trump != null && top.s == trump && top.r >= 13))) return Move(top);
        if (jk != null) return Move(jk, jm: 'hi', js: trump ?? suits[rng.nextInt(4)]);
        return Move(top ?? l.first);
      }
      final low = byV.firstOrNull;
      return low != null ? Move(low) : Move(l.first, jm: 'lo', js: trump ?? 'h');
    }
    if (need > 0) {
      final w = byV.where((c) => _wins(p, c)).toList();
      if (w.isNotEmpty) return Move(w.first);
      if (jk != null && _wins(p, jk, jm: 'hi')) return Move(jk, jm: 'hi');
      return Move(byV.firstOrNull ?? l.first, jm: 'lo');
    }
    final lose = byV.where((c) => !_wins(p, c)).toList();
    if (lose.isNotEmpty) return Move(lose.last);
    if (jk != null) return Move(jk, jm: 'lo');
    return Move(byV.first);
  }

  // ---------- saving ----------

  Map<String, dynamic> toJson() => {
        'v': 1,
        'len': len,
        'h': h,
        'score': score,
        'hist': [for (final r in hist) r.toJson()],
        'dealer': dealer,
        'n': n,
        'hands': [for (final x in hands) [for (final c in x) c.key]],
        'first3': [for (final x in first3) [for (final c in x) c.key]],
        'bids': bids,
        'taken': taken,
        'trick': [for (final e in trick) e.toJson()],
        'trump': trump,
        'trumpCard': trumpCard?.key,
        'phase': phase,
        'cur': cur,
        'win': win,
        'gone': [...gone],
        'voids': [for (final v in voids) [...v]],
        'jg': jg,
        'lastT': lastT?.toJson(),
        'tricks': [for (final x in tricks) x.toJson()],
      };

  static JokerGame? fromJson(Map m, {math.Random? rng}) {
    try {
      final len = m['len'] as String;
      if (!jSeq.containsKey(len)) return null;
      List<JCard> cards(List x) => [for (final k in x) JCard.parse(k as String)];
      final g = JokerGame._(len, rng ?? math.Random())
        ..h = m['h'] as int
        ..score = [for (final x in m['score'] as List) x as int]
        ..hist = [for (final r in m['hist'] as List) HandRow.fromJson(r as Map)]
        ..dealer = m['dealer'] as int
        ..n = m['n'] as int
        ..hands = [for (final x in m['hands'] as List) cards(x as List)]
        ..first3 = [for (final x in m['first3'] as List) cards(x as List)]
        ..bids = [for (final x in m['bids'] as List) x as int?]
        ..taken = [for (final x in m['taken'] as List) x as int]
        ..trick = [for (final e in m['trick'] as List) Play.fromJson(e as Map)]
        ..trump = m['trump'] as String?
        ..trumpCard = m['trumpCard'] == null ? null : JCard.parse(m['trumpCard'] as String)
        ..phase = m['phase'] as String
        ..cur = m['cur'] as int
        ..win = m['win'] as int?
        ..gone = {for (final x in m['gone'] as List) x as String}
        ..voids = [for (final v in m['voids'] as List) {for (final x in v as List) x as String}]
        ..jg = m['jg'] as int
        ..lastT = m['lastT'] == null ? null : Trick.fromJson(m['lastT'] as Map)
        ..tricks = [for (final x in m['tricks'] as List) Trick.fromJson(x as Map)];
      if (g.hands.length != 4 || g.score.length != 4) return null;
      return g;
    } catch (_) {
      return null;
    }
  }
}
