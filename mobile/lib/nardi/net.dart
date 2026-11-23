// The players' lobby, the site's way (js/games-core.js netInit): everyone with the app or the site open is in one
// channel, "lobby", shown by name and whether they play now (unless they hide being online). A challenge goes to one of
// them by name; a "yes" opens the table for both. The app plays backgammon here and says no to the other games.
// Nobody is challenged by someone they blocked, by anyone when they said so in their settings, and an adult and a
// pupil under 18 who do not know each other do not play one to one.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../profile/profile.dart';
import 'online.dart';
import 'table_model.dart';

String _cut(String s) => s.length > 40 ? s.substring(0, 40) : s;

/// someone in the lobby
class NardiPeer {
  const NardiPeer({required this.id, required this.name, this.hue = 200, this.avatar, this.playing = false, this.game, this.vs});
  final String id, name;
  final int hue;
  final String? avatar;
  final bool playing;

  /// what they play and against whom, while they play
  final String? game, vs;

  Profile get person => Profile(id: id, name: name, hue: hue, avatarUrl: avatar);
}

class NardiNet extends ChangeNotifier {
  NardiNet(this.api);
  final PeeraApi api;

  RoomLink? _lobby;
  StreamSubscription<(String, Map<String, dynamic>)>? _ev;
  StreamSubscription<Map<String, Map<String, dynamic>>>? _pr;
  Profile? _me;
  CharacterLook _look = const CharacterLook();
  bool _closed = false;

  /// my friends now (for the order of the list and who may challenge me when I allow only friends)
  List<String> Function() friends = () => const [];
  final _blocked = <String>{};
  Map<String, dynamic> _privacy = const {};

  /// I hide being online: the others do not see me in the lobby
  bool get hidden => _privacy['online'] == false;

  /// the others in the lobby, friends first
  List<NardiPeer> peers = [];
  Set<String> _online = {};

  /// my challenge waiting for an answer
  ({String gid, String to, String name})? pending;
  Timer? _pendT;

  /// a challenge to me, waiting for my answer
  ({String from, String gid, String name, String? tc})? invite;

  /// the game I play now (or just played), if any
  OnlineNardi? game;

  /// a table to open (set by the shell): the game the other said yes to
  void Function(OnlineNardi game)? openTable;

  /// a word for the bottom of the screen
  final note = ValueNotifier<String?>(null);

  void _say(String s) {
    note.value = null;
    note.value = s;
  }

  void _changed() {
    if (!_closed) notifyListeners();
  }

  Future<void> start(Profile me, CharacterLook look) async {
    _me = me;
    _look = look;
    final l = api.gameLink('lobby', const ['chal', 'acc', 'decl']);
    _lobby = l;
    _ev = l.events.listen(_event);
    _pr = l.presence.listen(_presence);
    try {
      final (m, b) = await (api.mySettings(), api.blocked()).wait;
      _privacy = m['privacy'] is Map ? Map<String, dynamic>.from(m['privacy'] as Map) : const {};
      _blocked.addAll(b);
    } catch (_) {}
    if (_closed) return;
    await l.join(_meta);
  }

  /// my privacy changed in the settings
  void privacyChanged(Map<String, dynamic> p) {
    _privacy = Map.of(p);
    _retrack();
    _changed();
  }

  Map<String, dynamic> get _meta {
    final me = _me;
    if (me == null || hidden) return const {};
    final g = game;
    final on = g != null && !g.finished;
    return {'nm': me.name, 'hu': me.hue, 'av': me.avatarUrl, 'st': on ? 'play' : 'idle', 'gt': on ? 'nardi' : null, 'g': on ? g.gid : null, 'vs': on ? g.oppName : null};
  }

  void _retrack() => _lobby?.track(_meta);

  void _presence(Map<String, Map<String, dynamic>> st) {
    if (_closed) return;
    final me = api.myId, fr = friends().toSet();
    _online = st.keys.toSet();
    peers = [
      for (final e in st.entries)
        if (e.key != me && !_blocked.contains(e.key))
          NardiPeer(
            id: e.key,
            name: _cut('${e.value['nm'] ?? 'მოთამაშე'}'),
            hue: asInt(e.value['hu'], 200),
            avatar: e.value['av'] is String ? e.value['av'] as String : null,
            playing: e.value['st'] == 'play',
            game: e.value['gt'] is String ? e.value['gt'] as String : null,
            vs: e.value['vs'] is String ? e.value['vs'] as String : null,
          ),
    ]..sort((a, b) {
        final fa = fr.contains(a.id), fb = fr.contains(b.id);
        if (fa != fb) return fa ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    _changed();
  }

  bool isOnline(String id) => _online.contains(id);

  static String _newGid() {
    final r = math.Random();
    return 'g${List.generate(10, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[r.nextInt(36)]).join()}';
  }

  /// a challenge to a game of backgammon; what went wrong, if anything
  Future<String?> challenge(String to, String name) async {
    if (!isOnline(to)) return 'ახლა ონლაინ არ არის. ითამაშე კომპიუტერთან ან სცადე მოგვიანებით';
    if (game != null && !game!.finished) return 'ჯერ მიმდინარე თამაში დაასრულე';
    if (!friends().contains(to)) {
      final ok = await api.reachable([to]).catchError((_) => {to});
      if (!ok.contains(to)) return 'ამ ადამიანთან ცალკე თამაში არ შეიძლება';
    }
    final gid = _newGid();
    pending = (gid: gid, to: to, name: name);
    _lobby?.send('chal', {'to': to, 'gt': 'nardi', 'gid': gid, 'nm': _me?.name ?? ''});
    _pendT?.cancel();
    _pendT = Timer(const Duration(seconds: 45), () {
      if (pending?.gid == gid) {
        pending = null;
        _say('პასუხი არ მოვიდა');
        _changed();
      }
    });
    _changed();
    return null;
  }

  void cancelChallenge() {
    _pendT?.cancel();
    pending = null;
    _changed();
  }

  void _event((String, Map<String, dynamic>) e) {
    if (_closed) return;
    final (name, d) = e;
    final me = api.myId, from = '${d['from'] ?? ''}';
    if (d['to'] != me || from.isEmpty) return;
    switch (name) {
      case 'chal':
        _challenged(d, from);
      case 'acc':
        final p = pending;
        if (p == null || d['gid'] != p.gid || from != p.to) return;
        _pendT?.cancel();
        pending = null;
        final peer = peers.where((x) => x.id == from).firstOrNull;
        final g = _begin(p.gid, 0, from, peer?.name ?? p.name, peer?.person, null);
        openTable?.call(g);
      case 'decl':
        if (pending?.gid != d['gid']) return;
        _pendT?.cancel();
        pending = null;
        _say('გამოწვევაზე უარი მიიღე');
        _changed();
    }
  }

  Future<void> _challenged(Map<String, dynamic> d, String from) async {
    final gid = '${d['gid'] ?? ''}';
    if (!RegExp(r'^g[a-z0-9]{4,14}$').hasMatch(gid)) return;
    void no() => _lobby?.send('decl', {'to': from, 'gid': gid});
    // only backgammon here; and not while a game goes on
    if (d['gt'] != 'nardi' || (game != null && !game!.finished)) {
      no();
      return;
    }
    final pr = '${_privacy['chal'] ?? 'all'}';
    final friend = friends().contains(from);
    if (_blocked.contains(from) || pr == 'none' || (pr == 'friends' && !friend)) {
      no();
      return;
    }
    if (!friend && d['cup'] == null) {
      final ok = await api.reachable([from]).catchError((_) => <String>{});
      if (_closed) return;
      if (!ok.contains(from)) {
        no();
        return;
      }
    }
    invite = (from: from, gid: gid, name: _cut('${d['nm'] ?? 'მოთამაშე'}'), tc: d['tc'] is String ? d['tc'] as String : null);
    _changed();
  }

  /// yes to the challenge: the table opens
  OnlineNardi? accept() {
    final v = invite;
    if (v == null) return null;
    invite = null;
    _lobby?.send('acc', {'to': v.from, 'gid': v.gid});
    final peer = peers.where((x) => x.id == v.from).firstOrNull;
    return _begin(v.gid, 1, v.from, v.name, peer?.person, v.tc);
  }

  void decline() {
    final v = invite;
    invite = null;
    if (v != null) _lobby?.send('decl', {'to': v.from, 'gid': v.gid});
    _changed();
  }

  OnlineNardi _begin(String gid, int side, String opp, String oppName, Profile? oppPerson, String? tc) {
    game?.leave();
    game?.removeListener(_gameChanged);
    final me = _me!;
    final g = OnlineNardi(
      api: api,
      gid: gid,
      me: side,
      myName: me.name,
      myLook: _look,
      mePerson: me,
      oppId: opp,
      oppName: oppName,
      oppPerson: oppPerson,
      tc: timeControl(tc),
      onRematch: (_) => _retrack(),
    );
    game = g..addListener(_gameChanged);
    g.start();
    _retrack();
    _changed();
    return g;
  }

  bool _wasOn = false;
  void _gameChanged() {
    final on = game != null && !game!.finished;
    if (on != _wasOn) {
      _wasOn = on;
      _retrack();
      _changed();
    }
  }

  /// the finished game's table closed: out of its channel
  Future<void> closeGame({bool force = false}) async {
    final g = game;
    if (g == null || (!g.finished && !force)) return;
    game = null;
    g.removeListener(_gameChanged);
    await g.leave();
    _retrack();
    _changed();
  }

  Future<void> stop() async {
    _closed = true;
    _pendT?.cancel();
    // the game's clocks stop at once (its leaving goes on by itself)
    final g = game;
    game = null;
    final left = g?.leave();
    await _ev?.cancel();
    await _pr?.cancel();
    await left;
    await _lobby?.leave();
    _lobby = null;
    note.dispose();
  }
}
