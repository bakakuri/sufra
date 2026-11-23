// Short backgammon (ნარდი, the kind where checkers are hit and re-enter from the bar): the board, the rules, a whole
// game's state machine and a computer player. Pure Dart, no Flutter: the same rules run on the server (nds_*).
//
// Player 0 moves from point 24 down to 1 and bears off from 1–6; player 1 moves from 1 up to 24 and bears off from
// 19–24. A point holds + checkers of player 0 or − checkers of player 1. A checker on the bar must enter first: player 0
// enters at 25 − die, player 1 at die.
import 'dart:math' as math;

/// the bar, as a "from" point
const bar = 0;

/// a single checker step: from a point (0: the bar) with one die, to a point (0: off the board for player 0, 25 for 1)
class Step {
  const Step(this.from, this.to, this.die, {this.hit = false});
  final int from, to, die;

  /// the step sent a lone enemy checker to the bar
  final bool hit;

  Map<String, dynamic> toJson() => {'f': from, 't': to, 'd': die, if (hit) 'h': true};
  factory Step.fromJson(Map j) => Step(_i(j['f']), _i(j['t']), _i(j['d']), hit: j['h'] == true);

  @override
  bool operator ==(Object o) => o is Step && o.from == from && o.to == to && o.die == die;
  @override
  int get hashCode => Object.hash(from, to, die);
  @override
  String toString() => '$from→$to($die)${hit ? '*' : ''}';
}

int _i(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;

/// where a checker goes when it leaves the board
int offPoint(int pl) => pl == 0 ? 0 : 25;

/// how far a point is from home (the pip count of one checker there)
int pipsOf(int pl, int p) => p == bar ? 25 : (pl == 0 ? p : 25 - p);

class Board {
  Board(this.pts, this.bars, this.offs);

  /// index 1..24 (0 unused); + player 0, − player 1
  final List<int> pts;
  final List<int> bars, offs;

  factory Board.start() {
    final p = List<int>.filled(25, 0);
    p[24] = 2;
    p[13] = 5;
    p[8] = 3;
    p[6] = 5;
    p[1] = -2;
    p[12] = -5;
    p[17] = -3;
    p[19] = -5;
    return Board(p, [0, 0], [0, 0]);
  }

  factory Board.empty() => Board(List<int>.filled(25, 0), [0, 0], [0, 0]);

  Board copy() => Board(List<int>.of(pts), List<int>.of(bars), List<int>.of(offs));

  Map<String, dynamic> toJson() => {'p': pts.sublist(1), 'b': bars, 'o': offs};
  factory Board.fromJson(Map j) => Board(
        [0, ...(j['p'] as List).map(_i)],
        [for (final x in j['b'] as List) _i(x)],
        [for (final x in j['o'] as List) _i(x)],
      );

  /// how many of [pl]'s checkers stand on [p]
  int cnt(int p, int pl) {
    final v = pts[p];
    return pl == 0 ? (v > 0 ? v : 0) : (v < 0 ? -v : 0);
  }

  /// which player owns the point (null: empty)
  int? owner(int p) => pts[p] == 0 ? null : (pts[p] > 0 ? 0 : 1);

  bool get over => offs[0] == 15 || offs[1] == 15;
  int? get winner => offs[0] == 15 ? 0 : (offs[1] == 15 ? 1 : null);

  /// the home board: 1–6 for player 0, 19–24 for player 1
  bool inHome(int pl, int p) => pl == 0 ? p >= 1 && p <= 6 : p >= 19 && p <= 24;

  /// every checker home (none on the bar): bearing off may begin
  bool allHome(int pl) {
    if (bars[pl] > 0) return false;
    for (var p = 1; p <= 24; p++) {
      if (!inHome(pl, p) && cnt(p, pl) > 0) return false;
    }
    return true;
  }

  int pips(int pl) {
    var n = bars[pl] * 25;
    for (var p = 1; p <= 24; p++) {
      n += cnt(p, pl) * pipsOf(pl, p);
    }
    return n;
  }

  /// the step from [from] with [die] for [pl], when the rules allow it
  Step? step(int pl, int from, int die) {
    if (die < 1 || die > 6) return null;
    final dir = pl == 0 ? -1 : 1;
    if (bars[pl] > 0 && from != bar) return null;
    final int to;
    if (from == bar) {
      if (bars[pl] == 0) return null;
      to = pl == 0 ? 25 - die : die;
    } else {
      if (from < 1 || from > 24 || cnt(from, pl) == 0) return null;
      to = from + dir * die;
    }
    if (to >= 1 && to <= 24) {
      final enemy = cnt(to, 1 - pl);
      if (enemy >= 2) return null;
      return Step(from, to, die, hit: enemy == 1);
    }
    // off the board: only from a full home, exactly or from the farthest checker
    if (!allHome(pl)) return null;
    final exact = pl == 0 ? to == 0 : to == 25;
    if (!exact) {
      for (var p = 1; p <= 24; p++) {
        if (cnt(p, pl) > 0 && pipsOf(pl, p) > pipsOf(pl, from)) return null;
      }
    }
    return Step(from, offPoint(pl), die);
  }

  /// the board after [s], played by [pl]
  Board after(int pl, Step s) {
    final b = copy();
    final sign = pl == 0 ? 1 : -1;
    if (s.from == bar) {
      b.bars[pl]--;
    } else {
      b.pts[s.from] -= sign;
    }
    if (s.to == offPoint(pl)) {
      b.offs[pl]++;
    } else {
      if (s.hit) {
        b.pts[s.to] = 0;
        b.bars[1 - pl]++;
      }
      b.pts[s.to] += sign;
    }
    return b;
  }

  /// the points (and the bar) with a checker of [pl] that can move with [die]
  List<int> froms(int pl, int die) => [for (var p = 0; p <= 24; p++) if (step(pl, p, die) != null) p];

  /// 1, 2 or 3: a plain win, a gammon (the loser bore nothing off), a backgammon (and still has a checker on the bar
  /// or in the winner's home)
  int points(int winner) {
    final l = 1 - winner;
    if (offs[l] > 0) return 1;
    if (bars[l] > 0) return 3;
    for (var p = 1; p <= 24; p++) {
      if (cnt(p, l) > 0 && inHome(winner, p)) return 3;
    }
    return 2;
  }
}

/// the dice of a turn as the steps they allow: two, or four for a double
List<int> turnDice(int a, int b) => a == b ? [a, a, a, a] : [a, b];

/// Every complete turn [pl] may play with [dice] on [board]: as many dice as can be used, and when only one of two
/// different dice can be played, the larger if it can.
List<List<Step>> legalTurns(Board board, int pl, List<int> dice) {
  final out = <List<Step>>[];
  var best = 0;
  void go(Board b, List<int> left, List<Step> done) {
    if (done.length > best) {
      best = done.length;
      out.clear();
    }
    if (done.length == best) out.add(List.of(done));
    if (left.isEmpty || b.over) return;
    final tried = <int>{};
    for (var i = 0; i < left.length; i++) {
      final d = left[i];
      if (!tried.add(d)) continue;
      final rest = List.of(left)..removeAt(i);
      for (final f in b.froms(pl, d)) {
        final s = b.step(pl, f, d)!;
        done.add(s);
        go(b.after(pl, s), rest, done);
        done.removeLast();
      }
    }
  }

  go(board, dice, []);
  if (best == 0) return const [];
  if (best == 1 && dice.length == 2 && dice[0] != dice[1]) {
    final hi = math.max(dice[0], dice[1]);
    final withHi = out.where((t) => t.first.die == hi).toList();
    if (withHi.isNotEmpty) return _dedupe(withHi);
  }
  return _dedupe(out);
}

List<List<Step>> _dedupe(List<List<Step>> ts) {
  final seen = <String>{};
  return [for (final t in ts) if (seen.add(t.join(' '))) t];
}

/// the turns that begin with [done]
List<List<Step>> turnsAfter(List<List<Step>> turns, List<Step> done) =>
    [for (final t in turns) if (t.length >= done.length && _prefix(t, done)) t];

bool _prefix(List<Step> t, List<Step> done) {
  for (var i = 0; i < done.length; i++) {
    if (t[i] != done[i]) return false;
  }
  return true;
}

/// what the game waits for
enum Phase { opening, roll, move, over }

/// A whole game. The dice come from [rng] (the server's, online).
class NardiGame {
  NardiGame({math.Random? rng, Board? board}) : rng = rng ?? math.Random(), board = board ?? Board.start();
  final math.Random rng;
  Board board;
  Phase phase = Phase.opening;

  /// whose move: 0 or 1
  int turn = 0;

  /// the two dice of this turn (the opening roll: each player's one die)
  List<int> dice = const [];

  /// the dice still to play
  List<int> left = const [];

  /// the steps played so far this turn
  final List<Step> done = [];

  /// the turn before this one, for the other player to see (whose, and its steps)
  int lastBy = -1;
  List<Step> last = const [];

  /// every complete turn open now (empty: nothing can be played)
  List<List<Step>> turns = const [];
  int? winner;
  int pts = 0;

  /// the opening rolls that came out equal, for the story
  int ties = 0;

  int _d() => rng.nextInt(6) + 1;

  /// the opening roll: one die each, the higher starts with both; equal dice are rolled again
  void open() {
    var a = _d(), b = _d();
    while (a == b) {
      ties++;
      a = _d();
      b = _d();
    }
    dice = [a, b];
    turn = a > b ? 0 : 1;
    _begin();
  }

  /// the player on turn rolls
  void roll() {
    if (phase != Phase.roll) return;
    dice = [_d(), _d()];
    _begin();
  }

  void _begin() {
    phase = Phase.move;
    left = turnDice(dice[0], dice[1]);
    done.clear();
    turns = legalTurns(board, turn, left);
    if (turns.isEmpty) {
      // nothing to play: the turn passes
      lastBy = turn;
      last = const [];
      left = const [];
      turn = 1 - turn;
      phase = Phase.roll;
    }
  }

  /// the steps open now, as the next step of some legal turn
  List<Step> get options {
    final seen = <Step>{};
    return [for (final t in turnsAfter(turns, done)) if (t.length > done.length && seen.add(t[done.length])) t[done.length]];
  }

  /// the turn is complete: every die that can be played is
  bool get turnDone => phase == Phase.move && turnsAfter(turns, done).every((t) => t.length == done.length);

  /// play one step (one of [options])
  bool play(Step s) {
    if (phase != Phase.move || !options.contains(s)) return false;
    board = board.after(turn, s);
    done.add(s);
    left = List.of(left)..remove(s.die);
    if (board.over) {
      _finish(turn);
    } else if (turnDone) {
      end();
    }
    return true;
  }

  /// take back the steps of this turn (before it ends)
  void undo() {
    if (phase != Phase.move || done.isEmpty) return;
    var b = board;
    for (final s in done.reversed) {
      b = _before(b, turn, s);
    }
    board = b;
    done.clear();
    left = turnDice(dice[0], dice[1]);
  }

  /// the turn is handed over
  void end() {
    if (phase != Phase.move || !turnDone) return;
    lastBy = turn;
    last = List.of(done);
    done.clear();
    left = const [];
    turn = 1 - turn;
    phase = Phase.roll;
  }

  void _finish(int w) {
    winner = w;
    pts = board.points(w);
    phase = Phase.over;
    lastBy = w;
    last = List.of(done);
  }

  /// the player gives up: the other wins one point
  void resign(int pl) {
    if (phase == Phase.over) return;
    done.clear();
    _finish(1 - pl);
    pts = 1;
  }

  /// a whole turn in one go (the computer, the server)
  void playTurn(List<Step> t) {
    for (final s in t) {
      if (!play(s)) return;
    }
    if (phase == Phase.move && turnDone) end();
  }

  Map<String, dynamic> toJson() => {
        'b': board.toJson(),
        'ph': phase.index,
        'turn': turn,
        'dice': dice,
        'left': left,
        'done': [for (final s in done) s.toJson()],
        'lastBy': lastBy,
        'last': [for (final s in last) s.toJson()],
        'winner': winner,
        'pts': pts,
        'ties': ties,
      };

  factory NardiGame.fromJson(Map j, {math.Random? rng}) {
    final g = NardiGame(rng: rng, board: Board.fromJson(j['b'] as Map));
    g.phase = Phase.values[_i(j['ph'])];
    g.turn = _i(j['turn']);
    g.dice = [for (final x in j['dice'] as List? ?? const []) _i(x)];
    g.left = [for (final x in j['left'] as List? ?? const []) _i(x)];
    g.done.addAll([for (final x in j['done'] as List? ?? const []) Step.fromJson(x as Map)]);
    g.lastBy = _i(j['lastBy'] ?? -1);
    g.last = [for (final x in j['last'] as List? ?? const []) Step.fromJson(x as Map)];
    g.winner = j['winner'] == null ? null : _i(j['winner']);
    g.pts = _i(j['pts']);
    g.ties = _i(j['ties']);
    if (g.phase == Phase.move) {
      // the turns as they stood when the dice fell: the board before this turn's steps
      var b = g.board;
      for (final s in g.done.reversed) {
        b = _before(b, g.turn, s);
      }
      g.turns = legalTurns(b, g.turn, turnDice(g.dice[0], g.dice[1]));
    }
    return g;
  }
}

/// the board before [pl] played [s]
Board _before(Board b, int pl, Step s) {
  final r = b.copy();
  final sign = pl == 0 ? 1 : -1;
  if (s.to == offPoint(pl)) {
    r.offs[pl]--;
  } else {
    r.pts[s.to] -= sign;
    if (s.hit) {
      r.bars[1 - pl]--;
      r.pts[s.to] = -sign;
    }
  }
  if (s.from == bar) {
    r.bars[pl]++;
  } else {
    r.pts[s.from] += sign;
  }
  return r;
}

// ---------- the computer player ----------

/// How good [b] looks for [pl]: pips, safety, made points, the bar, checkers off.
double evaluate(Board b, int pl) {
  final op = 1 - pl;
  var v = (b.pips(op) - b.pips(pl)).toDouble();
  v += 14.0 * b.bars[op] - 12.0 * b.bars[pl];
  v += 10.0 * b.offs[pl] - 10.0 * b.offs[op];
  // the enemy's reach: a blot within 12 pips in front of an enemy checker (or its bar) is in danger
  bool threatened(int p) {
    if (b.bars[op] > 0 && pipsOf(pl, p) >= 13) return true;
    for (var q = 1; q <= 24; q++) {
      if (b.cnt(q, op) == 0) continue;
      final d = op == 0 ? q - p : p - q;
      if (d >= 1 && d <= 12) return true;
    }
    return false;
  }

  var prev = false;
  for (var p = 1; p <= 24; p++) {
    final n = b.cnt(p, pl);
    if (n == 1) {
      v -= threatened(p) ? (b.inHome(op, p) ? 9 : 7) : 2;
    } else if (n >= 2) {
      v += b.inHome(pl, p) ? 4.5 : 3;
      if (prev) v += 2.5;
      if (n > 4) v -= (n - 4) * 1.2;
    }
    prev = n >= 2;
  }
  return v;
}

/// the computer's whole turn: the legal turn whose board looks best; a weaker player ([level] 1–4) sees less clearly
List<Step> botTurn(NardiGame g, {math.Random? rng, int level = 4}) {
  final r = rng ?? g.rng;
  final noise = const {1: 14.0, 2: 7.0, 3: 2.5, 4: .8}[level] ?? .8;
  List<Step>? best;
  var bestV = double.negativeInfinity;
  for (final t in turnsAfter(g.turns, g.done)) {
    var b = g.board;
    for (var i = g.done.length; i < t.length; i++) {
      b = b.after(g.turn, t[i]);
    }
    final v = evaluate(b, g.turn) + r.nextDouble() * noise;
    if (v > bestV) {
      bestV = v;
      best = t;
    }
  }
  if (best == null) return const [];
  return best.sublist(g.done.length);
}

const nardiRules = '''
მოკლე ნარდი ორი კაცით თამაშდება, თითოს 15 ქვა აქვს. შენი ქვები ზედა მარჯვენა კუთხიდან საათის ისრის საწინააღმდეგოდ მოძრაობს და ქვედა მარჯვენა მეოთხედში, შენს „სახლში“ იყრის თავს.

დასაწყისში თითო კამათელს აგორებთ: ვისაც მეტი მოუვა, ის იწყებს და ამ ორი კამათლით დადის.

თითო სვლაზე ორი კამათელი გორდება. თითოეული კამათელი ცალკე სვლაა: ერთი ქვა ორივეთი შეიძლება წაიყვანო, ან ორი სხვადასხვა ქვა. წყვილი (მაგალითად 4-4) ოთხჯერ დადის.

ქვა ვერ დადგება იქ, სადაც მოწინააღმდეგის ორი ან მეტი ქვაა. სადაც მარტო ერთია, შეგიძლია „მოკლა“: ის ქვა ბარზე გადადის და მისმა პატრონმა ჯერ ის უნდა შემოიყვანოს მოწინააღმდეგის სახლში (კამათლის რიცხვი კუთხიდან ითვლება), სანამ სხვა ქვას გაანძრევს.

თუ შეიძლება, ორივე კამათელი უნდა ითამაშო. თუ მხოლოდ ერთი გამოდის, უფრო დიდი ითამაშე, როცა ისიც შესაძლებელია.

როცა 15-ივე ქვა სახლშია, იწყებ „გამოყვანას“: კამათლის ზუსტი რიცხვით ქვა გადის. უფრო დიდი რიცხვით ყველაზე შორეული ქვა გადის.

ვინც პირველი გამოიყვანს ყველა ქვას, იგებს 1 ქულას. თუ წაგებულს არცერთი ქვა არ გამოუყვანია, 2 ქულა („მარსი“); თუ ამასთან ქვა ბარზე ან შენს სახლში ჰყავს, 3 ქულა.
''';
