// Backgammon with another person, the site's way (js/games-core.js): the two phones share one channel, "game-<id>",
// and each sends the whole state after its every step, numbered, in the site's own form (games-engines.js NR.snap),
// so a phone and a browser play together. The one who challenged is the site's side 1 (my player 0) and throws the
// opening roll; the other asks for the state. Each has a clock of 7 minutes and 8 seconds more a turn; a player whose
// time runs out loses, and one who leaves loses after a minute away (at once when they say goodbye). The result goes
// to the server's ratings by both.
import 'dart:async';
import 'dart:math' as math;

import '../data/api.dart';
import '../data/models.dart';
import '../profile/profile.dart';
import 'engine.dart';
import 'session.dart';
import 'table_model.dart';

int _n(Object? v, int lo, int hi) => asInt(v).clamp(lo, hi);
List<int> _dice(Object? a) => a is List ? [for (final x in a) if (x is num && x >= 1 && x <= 6) x.toInt()].take(4).toList() : <int>[];

/// the site's state of a game as this engine's (player 0 is the site's side 1)
NardiGame gameOfSite(Map s, {math.Random? rng}) {
  final p = s['p'];
  if (p is! List || p.length != 24) throw const FormatException('the points');
  final b = Board.empty();
  for (var i = 0; i < 24; i++) {
    b.pts[i + 1] = _n(p[i], -15, 15);
  }
  final bar = s['bar'] is Map ? s['bar'] as Map : const {}, off = s['off'] is Map ? s['off'] as Map : const {};
  b.bars
    ..[0] = _n(bar['1'], 0, 15)
    ..[1] = _n(bar['-1'], 0, 15);
  b.offs
    ..[0] = _n(off['1'], 0, 15)
    ..[1] = _n(off['-1'], 0, 15);
  final g = NardiGame(board: b, rng: rng)..turn = s['turn'] == -1 ? 1 : 0;
  final last = _dice(s['last']), left = _dice(s['dice']), open = _dice(s['open']);
  g.firstRoll = open.length == 2 ? open : null;
  g.dice = last.length >= 2 ? last.sublist(0, 2) : (left.length >= 2 ? left.sublist(0, 2) : (left.length == 1 ? [left[0], left[0]] : const []));
  final over = s['over'];
  if (over == 1 || over == -1) {
    g
      ..phase = Phase.over
      ..winner = over == 1 ? 0 : 1
      ..pts = asInt(s['mult'], 1).clamp(1, 3);
  } else if (s['rolled'] == true) {
    g
      ..phase = Phase.move
      ..left = left
      ..turns = legalTurns(b, g.turn, left);
  } else {
    g.phase = Phase.roll;
  }
  return g;
}

/// this game as the site keeps it
Map<String, dynamic> siteOfGame(NardiGame g, {String why = ''}) {
  final b = g.board, moving = g.phase == Phase.move, over = g.phase == Phase.over;
  return {
    'p': [for (var i = 1; i <= 24; i++) b.pts[i]],
    'bar': {'1': b.bars[0], '-1': b.bars[1]},
    'off': {'1': b.offs[0], '-1': b.offs[1]},
    'dice': moving ? g.left : <int>[],
    'last': g.dice.length == 2 ? g.dice : <int>[],
    'turn': g.turn == 0 ? 1 : -1,
    'rolled': moving,
    'over': over ? (g.winner == 0 ? 1 : -1) : 0,
    'why': over ? why : '',
    'mult': over ? g.pts.clamp(1, 3) : 1,
    'open': g.firstRoll,
    'v': 'short',
    'hd': {'1': 0, '-1': 0},
    'fst': {'1': false, '-1': false},
    'dice0': moving && g.dice.length == 2 ? turnDice(g.dice[0], g.dice[1]) : <int>[],
  };
}

/// a time limit written the site's way, "7+8" (minutes, seconds more a turn); 7+8 when there is none
(int, int) timeControl(Object? tc) {
  final m = RegExp(r'^(\d{1,2})\+(\d{1,2})$').firstMatch('${tc ?? ''}');
  return m == null ? (420, 8) : (int.parse(m.group(1)!) * 60, int.parse(m.group(2)!));
}

class OnlineNardi extends NardiTable {
  OnlineNardi({
    required this.api,
    required this.gid,
    required int me,
    required this.myName,
    required this.myLook,
    required this.oppId,
    required this.oppName,
    this.mePerson,
    this.oppPerson,
    this.tc = (420, 8),
    this.onRematch,
  }) : _me = me;

  final PeeraApi api;
  String gid;
  int _me;
  final String myName;
  final CharacterLook myLook;
  final String oppId;
  final String oppName;
  final Profile? mePerson, oppPerson;
  (int, int) tc;

  /// a rematch begins (a new game id): the lobby shows I play again
  final void Function(String gid)? onRematch;

  @override
  int get me => _me;

  /// the site's side of mine: 1 or −1
  int get _side => _me == 0 ? 1 : -1;
  String get _sideKey => '$_side';
  String get _otherKey => '${-_side}';

  @override
  NardiGame? g;
  int seq = 0;

  /// waiting for the first state from the other
  bool syncing = true;

  /// the other chose long backgammon, which is not here yet
  bool longGame = false;

  /// the other is away (left the channel, or said goodbye)
  bool gone = false, _bye = false, _seenOther = false;
  bool finished = false;
  String why = '';

  /// the rating won or lost, once the server counted it
  int? ratingDelta;
  String? _remSent, _remIn;
  CharacterLook? _oppLook;

  RoomLink? _link;
  StreamSubscription<(String, Map<String, dynamic>)>? _ev;
  StreamSubscription<Map<String, Map<String, dynamic>>>? _pr;
  Timer? _tick, _goneT, _passT;
  bool _closed = false;
  final _rng = nardiRandom();

  // ---- who played last (each state from the other is a new game object; these carry it over) ----
  int _lastBy = -1;
  List<Step> _lastSteps = const [];
  final _theirSteps = <Step>[];

  // ---- the board's movement and the characters ----
  int _tickN = 0;
  (int, Step)? _lastStep;
  final _moods = [Mood.idle, Mood.idle];
  final _moodTs = <Timer?>[null, null];

  @override
  int get stepTick => _tickN;
  @override
  (int, Step)? get lastStep => _lastStep;
  @override
  Mood moodOf(int pl) => _moods[pl];

  void _mood(int pl, Mood m, {Duration back = const Duration(milliseconds: 1600)}) {
    _moods[pl] = m;
    _moodTs[pl]?.cancel();
    if (m == Mood.idle) return;
    _moodTs[pl] = Timer(back, () {
      if (!_closed && _moods[pl] == m) {
        _moods[pl] = Mood.idle;
        _changed();
      }
    });
  }

  void _changed() {
    if (!_closed) notifyListeners();
  }

  // ---- the clock, as the site's: time left for each, whose turn it counts, since when, turns counted ----
  late final List<double> _clk = [tc.$1 * 1000.0, tc.$1 * 1000.0];
  int? _ckTurn;
  int _ckAt = 0, _ckN = 0;
  static int Function() now = () => DateTime.now().millisecondsSinceEpoch;

  int? get _clockTurn => g == null || g!.phase == Phase.over ? null : g!.turn;

  void _clkTurn() {
    final ts = _clockTurn;
    if (ts == _ckTurn) return;
    final t = now();
    if (_ckTurn != null) {
      if (_ckN >= 1) _clk[_ckTurn!] = math.max(0.0, _clk[_ckTurn!] - (t - _ckAt)) + tc.$2 * 1000;
      _ckN++;
    }
    _ckTurn = ts;
    _ckAt = t;
  }

  @override
  Duration? clockOf(int pl) {
    if (g == null || syncing) return null;
    var v = _clk[pl];
    if (_ckTurn == pl && _ckN >= 1 && !finished) v -= now() - _ckAt;
    return Duration(milliseconds: math.max(0, v).round());
  }

  void _clockTick() {
    if (_ckTurn == null || _ckN < 1 || syncing || finished || g == null) return;
    final over = now() - _ckAt - _clk[_ckTurn!];
    if (over >= 0 && _ckTurn == me) {
      _end(other, 'time');
    } else if (over > 2500 && _ckTurn == other) {
      _end(me, 'time');
    }
  }

  // ---- the channel ----

  Future<void> start() async {
    final l = api.gameLink('game-$gid', const ['st', 'need', 'bye', 'rem', 'remok', 'rx', 'cmt']);
    _link = l;
    _ev = l.events.listen(_event);
    _pr = l.presence.listen(_presence);
    await l.join({'w': 0, 'lk': myLook.toJson()});
    if (_closed || _link != l) return;
    api.matchMeet(gid, 'nardi', oppId, _side).catchError((_) {});
    if (me == 0) {
      if (g == null) {
        g = NardiGame(rng: _rng)..open();
        syncing = false;
      }
      _send();
    } else {
      l.send('need', {});
    }
    _tick ??= Timer.periodic(const Duration(milliseconds: 500), (_) => _clockTick());
    _changed();
  }

  void _send({bool clock = true}) {
    final game = g, l = _link;
    if (game == null || l == null) return;
    if (clock) _clkTurn();
    seq++;
    l.send('st', {
      'seq': seq,
      's': siteOfGame(game, why: why),
      'ck': {_sideKey: _clk[me].round(), 'n': _ckN},
    });
  }

  void _event((String, Map<String, dynamic>) e) {
    if (_closed) return;
    final (name, d) = e;
    switch (name) {
      case 'st':
        _state(d);
      case 'need':
        if (me == 0 && g != null) _send(clock: false);
      case 'bye':
        if (d['from'] == oppId && !finished) {
          gone = true;
          _bye = true;
          _goneIn(const Duration(seconds: 4));
          _changed();
        }
      case 'rem':
        final ng = '${d['gid'] ?? ''}';
        if (!finished || !_okGid(ng)) return;
        if (_remSent != null) {
          _rematch(_remSent!.compareTo(ng) < 0 ? _remSent! : ng);
        } else {
          _remIn = ng;
          _changed();
        }
      case 'remok':
        if (d['gid'] == _remSent && _remSent != null) _rematch(_remSent!);
    }
  }

  static bool _okGid(String g) => RegExp(r'^g[a-z0-9]{4,14}$').hasMatch(g);

  void _presence(Map<String, Map<String, dynamic>> st) {
    if (_closed) return;
    final here = st.containsKey(oppId);
    final lk = st[oppId]?['lk'];
    if (lk is Map) _oppLook = CharacterLook.fromJson(lk);
    if (here) {
      _seenOther = true;
      if (gone && !_bye && !finished) {
        gone = false;
        _goneT?.cancel();
      }
    } else if (_seenOther && !finished && !gone) {
      // away: a minute to come back
      gone = true;
      _goneIn(const Duration(minutes: 1));
    }
    _changed();
  }

  void _goneIn(Duration d) {
    _goneT?.cancel();
    _goneT = Timer(d, () {
      if (!_closed && gone && !finished && g != null) _end(me, 'gone');
    });
  }

  /// a state from the other phone
  void _state(Map<String, dynamic> d) {
    final sq = asInt(d['seq']);
    if (sq <= seq || d['s'] is! Map) return;
    final s = d['s'] as Map;
    seq = sq;
    if (s['v'] == 'long') {
      longGame = true;
      syncing = false;
      _changed();
      return;
    }
    final NardiGame n;
    try {
      n = gameOfSite(s, rng: _rng);
    } catch (_) {
      return;
    }
    final old = g;
    syncing = false;
    if (old != null && !finished) {
      // a step of theirs: the board glides it
      if (n.turn == old.turn && old.turn == other) {
        final st = _stepBetween(old.board, n.board, other);
        if (st != null) {
          _theirSteps.add(st);
          _lastStep = (other, st);
          _tickN++;
          _mood(other, Mood.reach, back: const Duration(milliseconds: 700));
        }
      }
      // their roll
      if (old.phase == Phase.roll && n.phase == Phase.move && n.turn == other) _mood(other, Mood.roll, back: const Duration(milliseconds: 900));
      // their turn is over: mine
      if (old.turn == other && n.turn == me) {
        final st = _stepBetween(old.board, n.board, other);
        if (st != null) {
          _theirSteps.add(st);
          _lastStep = (other, st);
          _tickN++;
        }
        _lastBy = other;
        _lastSteps = List.of(_theirSteps);
        _theirSteps.clear();
        _mood(me, Mood.think, back: const Duration(milliseconds: 1400));
      }
    }
    n
      ..lastBy = _lastBy
      ..last = _lastSteps;
    g = n;
    final ck = d['ck'];
    if (ck is Map) {
      if (asInt(ck['n']) > _ckN) _ckN = asInt(ck['n']);
      if (ck[_otherKey] is num) _clk[other] = (ck[_otherKey] as num).toDouble().clamp(0.0, tc.$1 * 3000.0);
    }
    _clkTurn();
    if (ck is Map && ck[_otherKey] is num) _clk[other] = (ck[_otherKey] as num).toDouble().clamp(0.0, tc.$1 * 3000.0);
    if (n.phase == Phase.over) {
      why = '${s['why'] ?? ''}';
      _over();
    } else if (n.turn == me && n.phase == Phase.move && n.turns.isEmpty) {
      // my roll came back with no step to play (say, after the app opened again): the turn passes
      _passOn();
    }
    _changed();
  }

  /// the one step [pl] played between two boards, when it was one
  static Step? _stepBetween(Board a, Board b, int pl) {
    final off = offPoint(pl);
    int? from, to;
    if (b.bars[pl] == a.bars[pl] - 1) from = bar;
    if (b.offs[pl] == a.offs[pl] + 1) to = off;
    for (var p = 1; p <= 24; p++) {
      final d = b.cnt(p, pl) - a.cnt(p, pl);
      if (d == -1 && from == null) {
        from = p;
      } else if (d == 1 && to == null) {
        to = p;
      } else if (d != 0) {
        return null;
      }
    }
    if (from == null || to == null) return null;
    return Step(from, to, 0, hit: b.bars[1 - pl] == a.bars[1 - pl] + 1);
  }

  // ---- my moves ----

  @override
  set live(bool v) {}

  @override
  int? get reward => null;

  @override
  bool get canUndo => false;

  @override
  bool get canRoll => !syncing && !finished && super.canRoll;

  @override
  bool get canMove => !syncing && !finished && super.canMove;

  @override
  String? get pause => longGame
      ? 'მეტოქემ გრძელი ნარდი აირჩია. აპში ჯერ მხოლოდ მოკლე ნარდია'
      : (syncing ? 'ველოდებით მეტოქეს…' : (gone && !finished ? '${oppName.split(' ').first} გავიდა. თუ წუთში არ დაბრუნდება, მოგება შენ ჩაგეთვლება' : null));

  @override
  bool get otherAway => gone && !finished;

  @override
  NardiSeat seatOf(int pl) => pl == me
      ? NardiSeat(name: myName, person: mePerson, look: myLook)
      : NardiSeat(name: oppName, person: oppPerson, look: _oppLook ?? CharacterLook.ofPerson(oppId));

  @override
  Future<void> roll() async {
    if (!canRoll) return;
    final game = g!;
    game.roll();
    _mood(me, Mood.roll, back: const Duration(milliseconds: 900));
    if (game.phase == Phase.move) {
      _send();
    } else if (game.phase == Phase.roll && game.turn == other) {
      // nothing to play: the dice are shown for a moment, then the turn passes
      _lastBy = me;
      _lastSteps = const [];
      _theirSteps.clear();
      final shown = siteOfGame(game)
        ..['turn'] = _side
        ..['rolled'] = true
        ..['dice'] = turnDice(game.dice[0], game.dice[1]);
      seq++;
      _link?.send('st', {'seq': seq, 's': shown, 'ck': {_sideKey: _clk[me].round(), 'n': _ckN}});
      _passT?.cancel();
      _passT = Timer(const Duration(milliseconds: 1200), () {
        if (!_closed && g == game) _send();
      });
    }
    _changed();
  }

  void _passOn() {
    final game = g!;
    game.end();
    _lastBy = me;
    _lastSteps = const [];
    _send();
  }

  @override
  Future<void> play(Step s) async {
    if (!canMove) return;
    final game = g!;
    if (!game.play(s)) return;
    _lastStep = (me, s);
    _tickN++;
    _mood(me, Mood.reach, back: const Duration(milliseconds: 600));
    if (game.phase == Phase.over) {
      _send();
      _over();
    } else {
      if (game.turn != me) {
        _lastBy = me;
        _lastSteps = List.of(game.last);
        _theirSteps.clear();
      }
      _send();
    }
    _changed();
  }

  @override
  Future<void> undo() async {}

  @override
  Future<void> endTurn() async {}

  @override
  Future<void> resign() async {
    if (g == null || finished) return;
    _end(other, 'resign');
  }

  /// [winner] wins now, for [reason] (resign, time, gone)
  void _end(int winner, String reason) {
    final game = g;
    if (game == null || finished) return;
    game.resign(1 - winner);
    why = reason;
    _send();
    _over();
    _changed();
  }

  void _over() {
    if (finished) return;
    finished = true;
    final game = g!;
    _goneT?.cancel();
    final won = game.winner == me;
    _mood(me, won ? Mood.happy : Mood.sad, back: const Duration(seconds: 4));
    _mood(other, won ? Mood.angry : Mood.happy, back: const Duration(seconds: 4));
    api.matchReport(gid, game.winner == 0 ? 1 : -1).then((d) {
      ratingDelta = d;
      _changed();
    }, onError: (_) {});
  }

  // ---- the end ----

  @override
  bool get canAgain => finished && !_bye && !longGame;

  @override
  String get againLabel => _remIn != null ? 'რევანშის მიღება' : 'რევანში';

  @override
  String get againNote {
    final first = oppName.split(' ').first;
    final parts = [
      if (ratingDelta != null && ratingDelta != 0) '${ratingDelta! > 0 ? '+' : ''}$ratingDelta რეიტინგი',
      if (why == 'time') 'დრო ამოიწურა',
      if (why == 'gone') '$first გავიდა',
      if (why == 'resign') (g?.winner == me ? '$first დანებდა' : 'დანებდი'),
      if (_remIn != null) '$first გთავაზობს რევანშს',
      if (_remSent != null && _remIn == null) 'რევანში შესთავაზე. ველოდებით პასუხს…',
    ];
    return parts.join(' · ');
  }

  @override
  Future<void> again() async {
    if (!canAgain) return;
    if (_remIn != null) {
      _link?.send('remok', {'gid': _remIn});
      await _rematch(_remIn!);
      return;
    }
    if (_remSent != null) return;
    _remSent = 'g${List.generate(10, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_rng.nextInt(36)]).join()}';
    _link?.send('rem', {'gid': _remSent});
    _changed();
  }

  /// the next game, in a new channel, the sides changed over
  Future<void> _rematch(String ng) async {
    if (_closed || gid == ng) return;
    await _drop();
    gid = ng;
    _me = 1 - _me;
    g = null;
    seq = 0;
    syncing = true;
    finished = false;
    gone = false;
    _bye = false;
    _seenOther = false;
    why = '';
    ratingDelta = null;
    _remSent = null;
    _remIn = null;
    _lastBy = -1;
    _lastSteps = const [];
    _theirSteps.clear();
    _lastStep = null;
    _clk
      ..[0] = tc.$1 * 1000.0
      ..[1] = tc.$1 * 1000.0;
    _ckTurn = null;
    _ckN = 0;
    onRematch?.call(ng);
    _changed();
    await start();
  }

  Future<void> _drop() async {
    _goneT?.cancel();
    _passT?.cancel();
    await _ev?.cancel();
    await _pr?.cancel();
    final l = _link;
    _link = null;
    if (l != null) {
      l.send('bye', {});
      await l.leave();
    }
  }

  /// out of the game: one not finished after its first moves counts as lost (as on the site)
  Future<void> leave() async {
    if (_closed) return;
    if (!finished && g != null && seq >= 3) api.matchReport(gid, -_side).catchError((_) => null);
    _closed = true;
    _tick?.cancel();
    for (final t in _moodTs) {
      t?.cancel();
    }
    await _drop();
  }

  @override
  void dispose() {
    if (!_closed) leave();
    super.dispose();
  }
}
