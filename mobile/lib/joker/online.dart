// Joker with people at a table the server runs (public.jks_*, js/joker-online.js): nobody's phone deals or keeps
// the rules. Every move goes to the server; the table's row comes back live; my cards are read when they change.
// Bots sit in the empty seats, and a person who is away (or silent past the time limit) is played for, until back.
import 'dart:async';

import '../data/api.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../profile/profile.dart';
import 'engine.dart';
import 'session.dart';
import 'table_model.dart';

JCard cardOf(Map m) => m['j'] != null ? JCard.joker(asInt(m['j'])) : JCard('${m['s']}', asInt(m['r']));
Map<String, dynamic> cardJson(JCard c) => c.joker ? {'j': c.j} : {'s': c.s, 'r': c.r};

/// the server's clock is close enough to the phone's for a countdown
int _nowMs() => DateTime.now().millisecondsSinceEpoch;

class OnlineJoker extends JokerTable {
  OnlineJoker({required this.api, required this.people, required this.id, this.hint = true, this.c4 = false});
  final PeeraApi api;
  final People people;
  final int id;

  @override
  final bool hint, c4;

  JkTable? t;
  Map<String, dynamic> st = {};
  int seat = -1;
  List<JCard> hand = [];
  int _deal = -1;
  JokerGame? _g;
  final _tricks = <Trick>[];
  String _lastKey = '';

  bool loaded = false, closed = false;

  /// what went wrong with my last move, to say on screen
  String? problem;

  StreamSubscription<JkTable>? _sub;
  Timer? _beat;
  bool _live = false, _busy = false, _ticking = false, _gone = false;
  int _backAt = 0;

  String get me => api.myId;
  bool get isHost => t?.host == me;
  String get status => t?.status ?? 'wait';
  List<String?> get seats => t?.seats ?? const [null, null, null, null];

  /// the seat shown at the bottom (mine; a guest who is not seated sees it from the first seat)
  int get _base => seat >= 0 ? seat : 0;
  int _srv(int p) => (p + _base) % 4;

  void _changed() {
    if (!_gone) notifyListeners();
  }

  Future<void> open() async {
    try {
      final r = await api.jkTable(id);
      if (_gone) return;
      if (r == null || r.status == 'closed' || !r.srv) {
        closed = true;
      } else {
        _take(r);
        await people.ensure([for (final s in r.seats) if (s != null) s]);
        if (seat >= 0 && r.status != 'wait') await _fetchHand();
        _sub = api.liveJkTable(id).listen(_row, onError: (_) {});
        _beat = Timer.periodic(const Duration(seconds: 1), (_) => _pulse());
      }
    } catch (_) {
      closed = true;
    }
    loaded = true;
    _rebuild();
    _changed();
  }

  void _take(JkTable r) {
    t = r;
    st = r.state;
    seat = r.seats.indexOf(me);
    if (r.status == 'closed') closed = true;
  }

  /// a newer row of the table (someone sat down, a move, the next hand); an older answer is left out
  void _row(JkTable r) {
    final old = st, ns = r.state;
    if (old['deal'] != null && old['deal'] == ns['deal'] && asInt(ns['seq']) < asInt(old['seq'])) {
      t = JkTable(id: r.id, host: r.host, len: r.len, seats: r.seats, status: r.status, pub: r.pub, state: old, updatedAt: r.updatedAt);
    } else {
      _take(r);
    }
    people.ensure([for (final s in r.seats) if (s != null) s]);
    _afterState();
  }

  void _state(Map<String, dynamic> ns) {
    final old = st;
    if (ns.isEmpty) return;
    if (old['deal'] != null && old['deal'] == ns['deal'] && asInt(ns['seq']) < asInt(old['seq'])) return;
    st = ns;
    final r = t;
    if (r != null) {
      final s = '${ns['phase']}' == 'over' ? 'over' : (r.status == 'wait' ? 'play' : r.status);
      t = JkTable(id: r.id, host: r.host, len: r.len, seats: r.seats, status: s, pub: r.pub, state: ns, updatedAt: r.updatedAt);
    }
  }

  void _afterState() {
    _rebuild();
    _changed();
    final counts = st['counts'] as List?;
    if (seat >= 0 && status != 'wait' && (asInt(st['deal'], -1) != _deal || (counts != null && counts.length == 4 && asInt(counts[seat]) != hand.length))) {
      _fetchHand();
    }
  }

  Future<void> _fetchHand() async {
    try {
      final h = await api.jkHand(id);
      if (h == null || _gone) return;
      _deal = h.deal;
      hand = sortHand([for (final c in h.cards) cardOf(c)]);
      _rebuild();
      _changed();
    } catch (_) {}
  }

  // ---------- the clock: the server moves the bots and the absent when a seated phone asks ----------

  void _pulse() {
    if (_gone || !_live || status != 'play') return;
    final ph = '${st['phase']}', c = asInt(st['cur'], -1), dl = asInt(st['dl']);
    final away = st['away'] is List ? st['away'] as List : const [];
    final mine = myTurn;
    if (mine && dl > 0) _changed(); // the countdown
    if (seat >= 0 && away.length == 4 && away[seat] == true && _nowMs() - _backAt > 4000) {
      _backAt = _nowMs();
      api.jkBack(id).catchError((_) {});
    }
    if (seat < 0 && !isHost) return;
    final waiting = ph == 'handover' ||
        (ph == 'play' && st['win'] != null) ||
        (c >= 0 &&
            const ['trump', 'bid', 'play'].contains(ph) &&
            (seats[c] == null || (away.length == 4 && away[c] == true) || (dl > 0 && _nowMs() > dl)));
    if (waiting && !_ticking) _tick();
  }

  Future<void> _tick() async {
    _ticking = true;
    try {
      final ns = await api.jkTick(id);
      if (ns != null && !_gone) {
        _state(ns);
        _afterState();
      }
    } catch (_) {}
    _ticking = false;
  }

  Future<void> _act(Map<String, dynamic> move) async {
    if (_busy) return;
    _busy = true;
    problem = null;
    _changed();
    try {
      final r = await api.jkAct(id, move);
      if (_gone) return;
      _state(r.state);
      if (r.hand != null) hand = sortHand([for (final c in r.hand!) cardOf(c)]);
      _busy = false;
      _afterState();
    } catch (e) {
      _busy = false;
      problem = '$e'.contains('not_your_turn') ? 'ახლა შენი სვლა არ არის' : 'სვლა ვერ გაიგზავნა — სცადე ხელახლა';
      _changed();
      _tick();
    }
  }

  // ---------- the game as seen from my seat ----------

  void _rebuild() {
    final r = t;
    if (r == null || r.status == 'wait' || st['phase'] == null) {
      _g = null;
      return;
    }
    final len = '${st['len'] ?? r.len}', b = _base;
    final g = JokerGame.view(len);
    int rot(Object? p) => (asInt(p) - b + 4) % 4;
    List<T> turn<T>(List<T> a) => a.length == 4 ? [for (var d = 0; d < 4; d++) a[(d + b) % 4]] : a;
    List<int> ints(Object? x) => [for (final v in (x as List? ?? const [])) asInt(v)];
    Play play(Map e) => Play(rot(e['p']), cardOf(e['card'] as Map), jm: e['jm'] as String?, js: e['js'] as String?);

    g.h = asInt(st['h']);
    g.n = st['n'] != null ? asInt(st['n']) : g.seq[g.h.clamp(0, g.seq.length - 1).toInt()];
    g.score = turn(ints(st['score']).length == 4 ? ints(st['score']) : [0, 0, 0, 0]);
    g.hist = [
      for (final x in (st['hist'] as List? ?? const []))
        if (x is Map)
          HandRow(
            n: asInt(x['n']),
            b: turn(ints(x['b'])),
            t: turn(ints(x['t'])),
            p: turn(ints(x['p'])),
            s: asInt(x['s']),
            pr: x['pr'] != null && x['pr'] != false && x['pr'] != 0,
          ),
    ];
    g.dealer = rot(st['dealer']);
    final phase = '${st['phase']}';
    g.phase = phase;
    g.hands = [hand, [], [], []];
    g.first3 = [phase == 'trump' ? hand : const [], [], [], []];
    final bids = st['bids'] as List? ?? const [null, null, null, null];
    g.bids = turn([for (final x in bids) x == null ? null : asInt(x)]);
    g.taken = turn(ints(st['taken']).length == 4 ? ints(st['taken']) : [0, 0, 0, 0]);
    g.trick = [for (final e in (st['trick'] as List? ?? const [])) if (e is Map) play(e)];
    g.trump = st['trump'] as String?;
    g.trumpCard = st['trumpCard'] is Map ? cardOf(st['trumpCard'] as Map) : null;
    final c = asInt(st['cur'], -1);
    g.cur = c >= 0 ? rot(c) : -1;
    g.win = st['win'] == null ? null : rot(st['win']);
    final last = st['last'];
    if (last is Map && last['t'] is List) {
      final tr = Trick([for (final e in last['t'] as List) if (e is Map) play(e)], rot(last['w']));
      g.lastT = tr;
      final key = '${st['deal']}:${(last['t'] as List).map((e) => '${(e as Map)['card']}').join()}';
      if (key != _lastKey) {
        _lastKey = key;
        _tricks.add(tr);
      }
    }
    final deal = '${st['deal']}';
    if (_tricks.isNotEmpty && !_lastKey.startsWith('$deal:')) _tricks.clear();
    g.tricks = [..._tricks];
    _g = g;
  }

  @override
  JokerGame? get g => _g;

  @override
  int? get reward => null;

  @override
  bool get myTurn {
    final g = _g;
    return g != null && seat >= 0 && !_busy && g.cur == 0 && g.win == null && const ['trump', 'bid', 'play'].contains(g.phase);
  }

  @override
  set live(bool v) {
    _live = v;
    if (v) _pulse();
  }

  @override
  set hold(bool v) {}

  String? _uid(int p) => seats.length == 4 ? seats[_srv(p)] : null;
  String? _bot(int p) {
    final b = st['bots'];
    if (b is! List || b.length != 4) return null;
    final x = b[_srv(p)];
    return x == null ? null : '$x';
  }

  @override
  String nameOf(int p) {
    final u = _uid(p);
    if (u != null) return (people[u]?.name ?? '…').trim().split(' ').first;
    return _bot(p) ?? 'ცარიელი';
  }

  @override
  SeatFace faceOf(int p) {
    final u = _uid(p);
    if (u != null) return SeatFace(person: people[u] ?? Profile(id: u, name: '?'));
    final b = _bot(p);
    final cm = b == null ? null : castNamed(b);
    return SeatFace(asset: cm?.asset);
  }

  @override
  String tookText(int p) {
    final b = _uid(p) == null ? _bot(p) : null;
    final cm = b == null ? null : castNamed(b);
    return cm != null ? '${cm.erg} წაიღო ხელი' : '${nameOf(p)} იღებს ხელს';
  }

  @override
  bool awayOf(int p) {
    final a = st['away'];
    return _uid(p) != null && a is List && a.length == 4 && a[_srv(p)] == true;
  }

  @override
  int? get secondsLeft {
    final dl = asInt(st['dl']);
    if (dl <= 0 || !myTurn) return null;
    return ((dl - _nowMs()) / 1000).ceil().clamp(0, 999).toInt();
  }

  @override
  void myTrump(String? s) {
    if (myTurn && _g?.phase == 'trump') _act({'k': 'trump', 's': s});
  }

  @override
  void myBid(int b) {
    final g = _g;
    if (g == null || !myTurn || g.phase != 'bid' || b == g.forbidden(0)) return;
    _act({'k': 'bid', 'v': b});
  }

  @override
  void myPlay(JCard c, {String? jm, String? js}) {
    final g = _g;
    if (g == null || !myTurn || g.phase != 'play' || !g.legal(0).contains(c)) return;
    _act({'k': 'card', 'c': cardJson(c), if (jm != null) 'jm': jm, if (js != null) 'js': js});
  }

  @override
  bool get canAgain => isHost && status == 'over';

  @override
  void again() {
    if (!canAgain) return;
    api.jkStart(id).then((ns) {
      if (ns == null || _gone) return;
      _state(ns);
      final r = t;
      if (r != null) t = JkTable(id: r.id, host: r.host, len: r.len, seats: r.seats, status: 'play', pub: r.pub, state: ns, updatedAt: r.updatedAt);
      _tricks.clear();
      _afterState();
    }).catchError((_) {});
  }

  @override
  String get againNote => 'ახალ თამაშს მასპინძელი დაიწყებს';

  // ---------- the waiting room ----------

  Future<void> start() async {
    final ns = await api.jkStart(id);
    if (ns == null || _gone) return;
    final r = t;
    if (r != null) t = JkTable(id: r.id, host: r.host, len: r.len, seats: r.seats, status: 'play', pub: r.pub, state: ns, updatedAt: r.updatedAt);
    st = ns;
    await _fetchHand();
    _afterState();
  }

  Future<void> join() async {
    seat = await api.jkJoin(id);
    final r = t;
    if (r != null && seat >= 0 && seat < 4) {
      final s = [...r.seats]..[seat] = me;
      t = JkTable(id: r.id, host: r.host, len: r.len, seats: s, status: r.status, pub: r.pub, state: r.state, updatedAt: r.updatedAt);
    }
    _changed();
  }

  Future<void> leave() async {
    await api.jkLeave(id);
    final r = t;
    if (r != null && seat >= 0) {
      final s = [...r.seats]..[seat] = null;
      t = JkTable(id: r.id, host: r.host, len: r.len, seats: s, status: r.status, pub: r.pub, state: r.state, updatedAt: r.updatedAt);
    }
    seat = -1;
    _changed();
  }

  Future<void> setLen(String len) async {
    final r = t;
    if (r == null || !isHost || r.status != 'wait') return;
    t = JkTable(id: r.id, host: r.host, len: len, seats: r.seats, status: r.status, pub: r.pub, state: r.state, updatedAt: r.updatedAt);
    _changed();
    await api.jkSet(id, len: len);
  }

  Future<void> setPub(bool pub) async {
    final r = t;
    if (r == null || !isHost || r.status != 'wait') return;
    t = JkTable(id: r.id, host: r.host, len: r.len, seats: r.seats, status: r.status, pub: pub, state: r.state, updatedAt: r.updatedAt);
    _changed();
    await api.jkSet(id, pub: pub);
  }

  Future<void> close() async {
    await api.jkClose(id);
    closed = true;
    _changed();
  }

  @override
  void dispose() {
    _gone = true;
    _beat?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
