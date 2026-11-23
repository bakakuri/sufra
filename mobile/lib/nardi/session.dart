// Backgammon on the phone against the computer: I am player 0, the computer player 1. The game is kept between
// openings of the app.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'engine.dart';
import 'table_model.dart';

math.Random Function() nardiRandom = () => math.Random();

/// how long the computer waits before it rolls, between its steps, and before it hands the turn back
const botRollAfter = Duration(milliseconds: 1100);
const botStepEvery = Duration(milliseconds: 750);

class NardiSession extends NardiTable {
  NardiSession({this.onOver, this.myName = '', this.myLook = const CharacterLook()});

  /// a finished game: I won or not; answers with the coins it brought, if any
  final Future<int> Function(bool won)? onOver;
  String myName;
  CharacterLook myLook;

  @override
  NardiGame? g;
  @override
  int get me => 0;

  /// the computer's strength, 1–4 (which of [bots] sits across)
  int level = 2;
  bool loaded = false;
  bool reported = false;
  @override
  int? reward;

  bool _live = false, _gone = false;
  Timer? _t;
  SharedPreferences? _prefs;
  final _moods = <Mood>[Mood.idle, Mood.idle];
  final _moodTs = <Timer?>[null, null];
  int _tick = 0;
  (int, Step)? _last;

  static const _kGame = 'nardi.game', _kLevel = 'nardi.level';

  Bot get bot => bots[(level - 1).clamp(0, bots.length - 1)];
  bool get playing => g != null && g!.phase != Phase.over;

  @override
  NardiSeat seatOf(int pl) => pl == 0 ? NardiSeat(name: myName, look: myLook) : NardiSeat(name: bot.name, look: bot.look);
  @override
  bool get canAgain => true;
  @override
  int get stepTick => _tick;
  @override
  (int, Step)? get lastStep => _last;
  @override
  Mood moodOf(int pl) => _moods[pl];

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      level = math.max(1, math.min(bots.length, p.getInt(_kLevel) ?? 2));
      final raw = p.getString(_kGame);
      if (raw != null) {
        final m = jsonDecode(raw) as Map;
        g = NardiGame.fromJson(m['g'] as Map, rng: nardiRandom());
        reported = m['reported'] == true;
        reward = m['reward'] as int?;
      }
    } catch (_) {
      g = null;
    }
    loaded = true;
    _changed();
    _wake();
  }

  void _changed() {
    if (!_gone) notifyListeners();
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    if (g == null) {
      p.remove(_kGame);
    } else {
      p.setString(_kGame, jsonEncode({'g': g!.toJson(), 'reported': reported, 'reward': reward}));
    }
  }

  void setLevel(int v) {
    level = v.clamp(1, bots.length);
    _prefs?.setInt(_kLevel, level);
    _changed();
  }

  @override
  set live(bool v) {
    _live = v;
    if (v) {
      _wake();
    } else {
      // off the screen: the computer waits
      _t?.cancel();
      _t = null;
    }
  }

  /// a new game: the opening roll decides who starts
  void start() {
    _t?.cancel();
    g = NardiGame(rng: nardiRandom())..open();
    reported = false;
    reward = null;
    _last = null;
    _mood(0, Mood.roll);
    _mood(1, Mood.roll);
    _save();
    _changed();
    _wake();
  }

  @override
  Future<void> again() async => start();

  /// a game set up elsewhere goes on here (the screenshots)
  void use(NardiGame game) {
    _t?.cancel();
    g = game;
    reported = false;
    reward = null;
    _last = null;
    _save();
    _changed();
    _wake();
  }

  void _mood(int pl, Mood m, {Duration back = const Duration(milliseconds: 1600)}) {
    _moods[pl] = m;
    _moodTs[pl]?.cancel();
    _changed();
    if (m == Mood.idle) return;
    _moodTs[pl] = Timer(back, () {
      if (!_gone && _moods[pl] == m) {
        _moods[pl] = Mood.idle;
        _changed();
      }
    });
  }

  @override
  Future<void> roll() async {
    final game = g;
    if (game == null || !canRoll) return;
    game.roll();
    _mood(0, Mood.roll);
    _after();
  }

  @override
  Future<void> play(Step s) async {
    final game = g;
    if (game == null || !canMove || !game.play(s)) return;
    _tick++;
    _last = (0, s);
    _mood(0, Mood.reach, back: const Duration(milliseconds: 700));
    if (s.hit) _mood(1, Mood.angry);
    _after();
  }

  @override
  Future<void> undo() async {
    final game = g;
    if (game == null || !canMove) return;
    game.undo();
    _tick++;
    _last = null;
    _save();
    _changed();
  }

  @override
  Future<void> endTurn() async {
    final game = g;
    if (game == null || !canMove) return;
    game.end();
    _after();
  }

  @override
  Future<void> resign() async {
    final game = g;
    if (game == null || game.phase == Phase.over) return;
    game.resign(0);
    _after();
  }

  /// after anything that moved the game: save, tell, and let the computer go on when it is its turn
  void _after() {
    _save();
    _changed();
    if (g?.phase == Phase.over) {
      _over();
    } else {
      _wake();
    }
  }

  void _over() {
    final game = g;
    if (game == null || reported || game.winner == null) return;
    reported = true;
    final won = game.winner == 0;
    _mood(won ? 0 : 1, Mood.happy, back: const Duration(seconds: 4));
    _mood(won ? 1 : 0, Mood.sad, back: const Duration(seconds: 4));
    _save();
    final f = onOver;
    if (f != null) {
      f(won).then((r) {
        if (_gone) return;
        reward = r;
        _save();
        _changed();
      }, onError: (_) {});
    }
  }

  /// the computer plays when it is its turn and the table is on screen
  void _wake() {
    final game = g;
    if (!_live || game == null || game.phase == Phase.over || game.turn != 1 || _t?.isActive == true) return;
    if (game.phase == Phase.roll) {
      _mood(1, Mood.think, back: botRollAfter);
      _t = Timer(botRollAfter, () {
        _t = null;
        if (_gone || !_live || g != game || game.phase != Phase.roll || game.turn != 1) return;
        game.roll();
        _mood(1, Mood.roll);
        _save();
        _changed();
        _wake();
      });
    } else {
      _t = Timer(botStepEvery, () {
        _t = null;
        if (_gone || !_live || g != game || game.phase != Phase.move || game.turn != 1) return;
        final t = botTurn(game, level: level);
        if (t.isEmpty) {
          game.end();
          _after();
          return;
        }
        final s = t.first;
        game.play(s);
        _tick++;
        _last = (1, s);
        _mood(1, Mood.reach, back: const Duration(milliseconds: 600));
        if (s.hit) {
          _mood(1, Mood.happy);
          _mood(0, Mood.angry);
        }
        _after();
      });
    }
  }

  @override
  void dispose() {
    _gone = true;
    _t?.cancel();
    for (final t in _moodTs) {
      t?.cancel();
    }
    super.dispose();
  }
}
