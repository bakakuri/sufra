// A game against the computer as it is being played: the engine, the three drawn people at the table, the bots' pace,
// and the game kept on the phone so it continues where it was left (the app closed, or the back button pressed).
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'engine.dart';

/// The drawn people who sit at the card tables (the site's cast), with the name's ergative for "…მა წაიღო".
class CastMember {
  const CastMember(this.id, this.name, this.erg);
  final String id, name, erg;
  String get asset => 'assets/joker/$id.jpg';
}

const cast = [
  CastMember('m1', 'გურამი', 'გურამმა'),
  CastMember('m3', 'ლუკა', 'ლუკამ'),
  CastMember('m5', 'ნიკა', 'ნიკამ'),
  CastMember('f1', 'თამარი', 'თამარმა'),
  CastMember('f2', 'ნინო', 'ნინომ'),
  CastMember('f3', 'ანა', 'ანამ'),
];
CastMember castOf(String id) => cast.firstWhere((c) => c.id == id, orElse: () => cast.first);

/// the dice of the game (the tests hand out a fixed one)
math.Random Function() jokerRandom = () => math.Random();

/// how long the bots think and how long a taken trick stays on the table (shorter in the tests is not needed: they wait)
const _think = {'trump': 900, 'bid': 750, 'play': 800};
const collectAfter = Duration(milliseconds: 1400);
const nextHandAfter = Duration(milliseconds: 3800);

class JokerSession extends ChangeNotifier {
  JokerSession({this.onOver});

  /// a finished game: the player won or not; answers with the coins it brought, if any
  final Future<int> Function(bool won)? onOver;

  JokerGame? g;

  /// the player's name: nobody drawn at the table has the same first name
  String myName = '';

  /// who sits in seats 1–3 (left, across, right)
  List<String> seats = ['f1', 'm1', 'f2'];
  int level = 2;
  bool hint = true, c4 = false;
  bool loaded = false;

  /// the end of the game was told to the server (once a game)
  bool reported = false;
  int? reward;

  /// the table is on screen: the bots play only then
  bool _live = false;

  /// the score sheet is open: the next hand waits for it to close
  bool _hold = false;
  Timer? _t;
  bool _gone = false;
  SharedPreferences? _prefs;

  static const _kGame = 'joker.game', _kLevel = 'joker.level', _kHint = 'joker.hint', _kC4 = 'joker.c4';

  bool get playing => g != null && g!.phase != 'over';
  String nameOf(int p) => castOf(seats[p - 1]).name;

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      level = math.max(1, math.min(5, p.getInt(_kLevel) ?? 2));
      hint = p.getBool(_kHint) ?? true;
      c4 = p.getBool(_kC4) ?? false;
      final raw = p.getString(_kGame);
      if (raw != null) {
        final m = jsonDecode(raw) as Map;
        final game = JokerGame.fromJson(m['g'] as Map, rng: jokerRandom());
        if (game != null) {
          g = game;
          seats = [for (final s in m['seats'] as List) s as String];
          reported = m['reported'] == true;
          reward = m['reward'] as int?;
          // a trick that was being collected, or a hand that was being scored, goes on
          if (game.phase == 'play' && game.win != null) game.collect();
        }
      }
    } catch (_) {}
    loaded = true;
    _changed();
  }

  void _changed() {
    if (!_gone) notifyListeners();
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    final game = g;
    if (game == null) {
      p.remove(_kGame);
    } else {
      p.setString(_kGame, jsonEncode({'g': game.toJson(), 'seats': seats, 'reported': reported, if (reward != null) 'reward': reward}));
    }
  }

  void setLevel(int v) {
    level = math.max(1, math.min(5, v));
    _prefs?.setInt(_kLevel, level);
    _changed();
  }

  void setHint(bool v) {
    hint = v;
    _prefs?.setBool(_kHint, v);
    _changed();
  }

  void setC4(bool v) {
    c4 = v;
    _prefs?.setBool(_kC4, v);
    _changed();
  }

  /// a new game of [len]; three people at random take the seats
  void start(String len) {
    _t?.cancel();
    final rng = jokerRandom();
    final mine = myName.trim().split(' ').first;
    final free = [for (final c in cast) if (c.name != mine) c.id]..shuffle(rng);
    seats = free.take(3).toList();
    g = JokerGame.start(len, rng: rng);
    reported = false;
    reward = null;
    _after();
  }

  /// the game is put away (finished or given up)
  void quit() {
    _t?.cancel();
    g = null;
    reward = null;
    _save();
    _changed();
  }

  set live(bool v) {
    _live = v;
    if (v) {
      _step();
    } else {
      _t?.cancel();
    }
  }

  set hold(bool v) {
    _hold = v;
    if (!v) _step();
  }

  void _after() {
    _save();
    _changed();
    _step();
  }

  Future<void> _report(bool won) async {
    reported = true;
    _save();
    try {
      final r = await onOver?.call(won);
      if (r != null && r > 0) {
        reward = r;
        _save();
        _changed();
      }
    } catch (_) {}
  }

  /// the next thing that happens by itself: a bot's move, the taken trick leaving the table, the next hand
  void _step() {
    _t?.cancel();
    final game = g;
    if (game == null || !_live || _gone) return;
    if (game.phase == 'over') {
      // the end is told to the server once (a game finished while the app was closed is told when its table opens)
      if (!reported) _report(game.iWon);
      return;
    }
    if (game.phase == 'play' && game.win != null) {
      _t = Timer(collectAfter, () {
        game.collect();
        _after();
      });
      return;
    }
    if (game.phase == 'handover') {
      if (_hold) return;
      _t = Timer(nextHandAfter, () {
        game.nextHand();
        _after();
      });
      return;
    }
    final p = game.cur;
    if (p <= 0 || !_think.containsKey(game.phase)) return;
    _t = Timer(Duration(milliseconds: _think[game.phase]!), () {
      if (game.cur != p) return;
      switch (game.phase) {
        case 'trump':
          game.setTrump(game.botTrump(p));
        case 'bid':
          game.bid(p, game.botBid(p, level));
        case 'play':
          final m = game.botPlay(p, level);
          game.play(p, m.c, jm: m.jm, js: m.js);
      }
      _after();
    });
  }

  // ---------- the player's moves ----------

  bool get myTurn {
    final game = g;
    return game != null && game.cur == 0 && game.win == null && const ['trump', 'bid', 'play'].contains(game.phase);
  }

  void myTrump(String? s) {
    final game = g;
    if (game == null || game.phase != 'trump' || !myTurn) return;
    game.setTrump(s);
    _after();
  }

  void myBid(int b) {
    final game = g;
    if (game == null || game.phase != 'bid' || !myTurn || b < 0 || b > game.n || b == game.forbidden(0)) return;
    game.bid(0, b);
    _after();
  }

  void myPlay(JCard c, {String? jm, String? js}) {
    final game = g;
    if (game == null || game.phase != 'play' || !myTurn || !game.legal(0).contains(c)) return;
    game.play(0, c, jm: jm, js: js);
    _after();
  }

  /// the next hand now, without waiting
  void nextNow() {
    final game = g;
    if (game == null || game.phase != 'handover') return;
    game.nextHand();
    _after();
  }

  @override
  void dispose() {
    _gone = true;
    _t?.cancel();
    super.dispose();
  }
}
