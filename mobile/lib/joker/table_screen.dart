// The Joker table against the computer: three drawn people around a dark felt table, my cards at the bottom.
// The back button leaves the table (the game is kept and goes on from the Joker tab); a sheet over it closes first.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/stores.dart';
import '../ui/icons.dart';
import '../ui/widgets.dart';
import 'cards.dart';
import 'engine.dart';
import 'session.dart';
import 'sheets.dart';

class JokerTableScreen extends StatefulWidget {
  const JokerTableScreen({super.key, required this.session});
  final JokerSession session;
  @override
  State<JokerTableScreen> createState() => _JokerTableScreenState();
}

class _JokerTableScreenState extends State<JokerTableScreen> {
  JokerSession get s => widget.session;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    s.live = true;
  }

  @override
  void dispose() {
    s.live = false;
    super.dispose();
  }

  String _name(int p) => p == 0 ? context.me.name : s.nameOf(p);
  String _who(int p) => p == 0 ? 'შენ' : s.nameOf(p);

  Future<void> _sheetWhile(Future<void> Function() f) async {
    s.hold = true;
    try {
      await f();
    } finally {
      if (mounted) s.hold = false;
    }
  }

  Future<void> _tapCard(JCard c) async {
    final g = s.g;
    if (g == null || _busy || !s.myTurn || g.phase != 'play' || !g.legal(0).contains(c)) return;
    if (!c.joker) {
      s.myPlay(c);
      return;
    }
    _busy = true;
    final m = await pickJokerCall(context, c, lead: g.trick.isEmpty, c4: s.c4);
    _busy = false;
    if (m != null) s.myPlay(c, jm: m.jm, js: m.js);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: felt,
        body: SafeArea(
          child: DefaultTextStyle(
            style: tableText,
            child: ListenableBuilder(
              listenable: s,
              builder: (context, _) {
                final g = s.g;
                if (g == null) return const SizedBox.shrink();
                return Column(children: [
                  _top(g),
                  Expanded(child: _table(g)),
                  _meRow(g),
                  _status(g),
                  _panel(g),
                  if (g.phase != 'over') _hand(g),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }

  // ---------- the bar at the top: back, the trump, which hand, what has been said; the score sheet ----------

  Widget _top(JokerGame g) {
    final choosing = g.phase == 'trump';
    final said = const ['bid', 'play'].contains(g.phase) ? g.bids.whereType<int>().toList() : const <int>[];
    final t = said.fold<int>(0, (a, b) => a + b), all = said.length == 4, d = t - g.n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 6, 4),
      child: Row(children: [
        IconBtn('back', label: 'უკან', color: light, onTap: () => Navigator.of(context).maybePop()),
        TrumpTile(trump: g.trump, choosing: choosing, size: 36, c4: s.c4),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(choosing ? 'კოზირი ირჩევა…' : (g.trump == null ? 'უკოზირო' : 'კოზირი: ${suitName[g.trump]}'),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: light, fontSize: 15.5, fontWeight: FontWeight.w800)),
            Text('ხელი ${math.min(g.h + 1, g.seq.length)}/${g.seq.length} · ${g.n} კარტი',
                style: const TextStyle(color: lightMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
        ),
        if (said.isNotEmpty)
          Container(
            key: const ValueKey('joker-said'),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: all && d != 0 ? (d > 0 ? badRed : const Color(0xFF8DB0FF)) : Colors.white24),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('ნათქვამი', style: TextStyle(color: lightMuted, fontSize: 10, fontWeight: FontWeight.w600, height: 1.1)),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$t/${g.n}'),
                  if (all && d != 0) TextSpan(text: ' ${d > 0 ? '+' : '−'}${d.abs()}', style: TextStyle(color: d > 0 ? badRed : const Color(0xFF8DB0FF))),
                ]),
                style: numFont.copyWith(color: light, fontSize: 13.5, fontWeight: FontWeight.w800, height: 1.15),
              ),
            ]),
          ),
        IconBtn('note', label: 'ქულების ფურცელი', color: light, onTap: () => _sheetWhile(() => showScoreSheet(context, g, [for (var p = 0; p < 4; p++) _name(p)]))),
      ]),
    );
  }

  // ---------- the table: three seats, the trick in the middle ----------

  Widget _table(JokerGame g) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final seatAt = <int, Offset>{
          0: Offset(w / 2, h + 40),
          1: Offset(52, h / 2),
          2: Offset(w / 2, 50),
          3: Offset(w - 52, h / 2),
        };
        final over = g.phase == 'over';
        return Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(48),
                gradient: const RadialGradient(colors: [feltHi, Color(0xFF0E1F3C)], radius: .9),
                border: Border.all(color: const Color(0xFFC9A24A), width: 2),
                boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 18, spreadRadius: 2)],
              ),
            ),
          ),
          if (!over) ...[
            Positioned(top: 8, left: 0, right: 0, child: Center(child: _seat(g, 2))),
            Positioned(left: 14, top: h / 2 - 62, child: _seat(g, 1)),
            Positioned(right: 14, top: h / 2 - 62, child: _seat(g, 3)),
            if (const ['bid', 'play'].contains(g.phase)) Positioned.fill(child: Center(child: _TrumpFlash(key: ValueKey('tf${g.h}'), g: g, c4: s.c4))),
            Positioned.fill(child: _TrickView(g: g, seatAt: seatAt, c4: s.c4)),
            if (g.phase == 'handover') Positioned.fill(child: Center(child: _handFx(g))),
            if (g.lastT != null && g.phase == 'play')
              Positioned(
                left: 20,
                bottom: 12,
                child: Material(
                  color: Colors.white.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    key: const ValueKey('joker-last'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _sheetWhile(() => showLastTrick(context, g.lastT!, _who, c4: s.c4)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        PIcon('cards', size: 16, color: lightMuted),
                        SizedBox(width: 5),
                        Text('ბოლო ხელი', style: TextStyle(color: lightMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ),
          ] else
            Positioned.fill(child: _gameOver(g)),
        ]);
      });

  Widget _face(int p, double size, {bool turn = false}) {
    final ring = turn ? goldTable : Colors.white24;
    Widget pic = p == 0
        ? Avatar(p: context.me, size: size)
        : ClipOval(child: Image.asset(castOf(s.seats[p - 1]).asset, width: size, height: size, fit: BoxFit.cover));
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring,
        boxShadow: turn ? const [BoxShadow(color: Color(0x99F5B544), blurRadius: 14, spreadRadius: 1)] : null,
      ),
      child: pic,
    );
  }

  Widget _dealer() => Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: goldTable, shape: BoxShape.circle, border: Border.all(color: felt, width: 1.5)),
        child: const Text('დ', style: TextStyle(color: Color(0xFF1A1205), fontSize: 10, fontWeight: FontWeight.w800, height: 1)),
      );

  bool _turnOf(JokerGame g, int p) => g.cur == p && g.win == null && const ['bid', 'play', 'trump'].contains(g.phase);

  Widget _seat(JokerGame g, int p) {
    final turn = _turnOf(g, p);
    return SizedBox(
      width: 92,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          _face(p, 46, turn: turn),
          if (p == g.dealer) Positioned(right: -2, bottom: -2, child: Tooltip(message: 'დამრიგებელი', child: _dealer())),
          if (turn && g.phase != 'play')
            const Positioned(top: -6, left: -10, child: _Thinking()),
        ]),
        const SizedBox(height: 4),
        Text(s.nameOf(p), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: light, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _pips(g, p),
            const SizedBox(width: 5),
            Text('${g.score[p]}', style: numFont.copyWith(color: g.score[p] < 0 ? badRed : lightMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
        _result(g, p),
      ]),
    );
  }

  /// what a player said and took: taken/said, green when made, red when more; a pass shows the word
  Widget _pips(JokerGame g, int p) {
    final b = g.bids[p], t = g.taken[p];
    final col = b == null ? lightMuted : (t > b ? badRed : (t == b ? okGreen : light));
    final text = b == null ? '–' : (b == 0 ? (t > 0 ? 'პასი +$t' : 'პასი') : '$t/$b');
    return Container(
      key: ValueKey('pips-$p'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: col.withValues(alpha: .14), borderRadius: BorderRadius.circular(8), border: Border.all(color: col.withValues(alpha: .55))),
      child: Text(text, style: numFont.copyWith(color: col, fontSize: 12, fontWeight: FontWeight.w800, height: 1.25)),
    );
  }

  /// after a hand: what it brought, over the player
  Widget _result(JokerGame g, int p) {
    if (g.phase != 'handover' || g.hist.isEmpty) return const SizedBox.shrink();
    final l = jLast(g.hist);
    final hand = l.hand;
    if (hand == null) return const SizedBox.shrink();
    final x = hand.p[p] + (l.prem?.p[p] ?? 0), ok = hand.b[p] == hand.t[p], kh = hand.b[p] > 0 && hand.t[p] == 0;
    final col = ok ? okGreen : (kh ? badRed : lightMuted);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: col.withValues(alpha: .18), borderRadius: BorderRadius.circular(8)),
        child: Text('${ok ? '✓' : '✗'} ${x > 0 ? '+' : (x < 0 ? '−' : '')}${x.abs()}', style: numFont.copyWith(color: col, fontSize: 12.5, fontWeight: FontWeight.w800)),
      ),
    );
  }

  /// a ხიშტი stamped in red, a section premium in gold
  Widget _handFx(JokerGame g) {
    final l = jLast(g.hist), hand = l.hand, prem = l.prem;
    if (hand == null) return const SizedBox.shrink();
    final kh = [for (var p = 0; p < 4; p++) if (hand.b[p] > 0 && hand.t[p] == 0) p];
    final pr = prem == null ? <int>[] : [for (var p = 0; p < 4; p++) if (prem.p[p] != 0) p];
    if (kh.isEmpty && pr.isEmpty) return const SizedBox.shrink();
    String sg(int x) => '${x > 0 ? '+' : (x < 0 ? '−' : '')}${x.abs()}';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .6, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 230),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xEE0A1322),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kh.isNotEmpty ? badRed : goldTable, width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (kh.isNotEmpty) ...[
            const Text('ხიშტი!', style: TextStyle(color: badRed, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(kh.map((p) => '${_who(p)} ${sg(hand.p[p])}').join(' · '), textAlign: TextAlign.center, style: const TextStyle(color: light, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ],
          if (kh.isNotEmpty && pr.isNotEmpty) const SizedBox(height: 8),
          if (pr.isNotEmpty) ...[
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Star(size: 18, color: goldTable),
              SizedBox(width: 5),
              Text('სექციის პრემია', style: TextStyle(color: goldTable, fontSize: 17, fontWeight: FontWeight.w800)),
            ]),
            Text(pr.map((p) => '${_who(p)} ${sg(prem!.p[p])}').join(' · '), textAlign: TextAlign.center, style: const TextStyle(color: light, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ],
        ]),
      ),
    );
  }

  // ---------- the end of the game: the first three on a podium, the fourth beside it ----------

  Widget _gameOver(JokerGame g) {
    final order = g.order, won = g.iWon;
    Widget step(int place) {
      final p = order[place - 1];
      final hs = const {1: 58.0, 2: 40.0, 3: 28.0}[place]!;
      return Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (place == 1) const Padding(padding: EdgeInsets.only(bottom: 2), child: Star(size: 20, color: goldTable)),
          _face(p, place == 1 ? 54 : 44, turn: place == 1),
          const SizedBox(height: 4),
          Text(_who(p), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p == 0 ? goldTable : light, fontSize: 13.5, fontWeight: FontWeight.w800)),
          Text('${g.score[p]}', style: numFont.copyWith(color: g.score[p] < 0 ? badRed : light, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Container(
            height: hs,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: place == 1 ? goldTable.withValues(alpha: .85) : Colors.white.withValues(alpha: .14),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Text('$place', style: numFont.copyWith(color: place == 1 ? const Color(0xFF1A1205) : light, fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ]),
      );
    }

    final four = order[3];
    return LayoutBuilder(
      builder: (context, box) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: math.max(200, box.maxWidth - 48),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(won ? 'მოიგე!' : 'თამაში დასრულდა', key: const ValueKey('joker-over'), style: TextStyle(color: won ? goldTable : light, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(won ? 'ყველაზე მეტი ქულა შენ დააგროვე' : 'გაიმარჯვა: ${_who(order[0])}', style: const TextStyle(color: lightMuted, fontSize: 14)),
        if (s.reward != null && s.reward! > 0) ...[
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const PIcon('coin', size: 18, color: goldTable),
            const SizedBox(width: 5),
            Text('+${s.reward} მონეტა', style: const TextStyle(color: goldTable, fontSize: 14.5, fontWeight: FontWeight.w800)),
          ]),
        ],
        const SizedBox(height: 14),
        SizedBox(height: 196, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [step(2), step(1), step(3)])),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Text('4', style: numFont.copyWith(color: lightMuted, fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            Expanded(child: Text(_who(four), style: TextStyle(color: four == 0 ? goldTable : light, fontWeight: FontWeight.w700))),
            Text('${g.score[four]}', style: numFont.copyWith(color: g.score[four] < 0 ? badRed : light, fontWeight: FontWeight.w800)),
          ]),
        ),
            ]),
          ),
        ),
      ),
    );
  }

  // ---------- me: my name, what I said and took, how many more I need, my points ----------

  Widget _meRow(JokerGame g) {
    final turn = _turnOf(g, 0), b = g.bids[0], need = b == null ? null : b - g.taken[0];
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: turn ? .1 : .05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: turn ? goldTable : Colors.transparent, width: 1.5),
      ),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          _face(0, 34, turn: turn),
          if (g.dealer == 0) Positioned(right: -4, bottom: -3, child: _dealer()),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(context.me.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: light, fontSize: 14.5, fontWeight: FontWeight.w800)),
        ),
        _pips(g, 0),
        if (g.phase == 'play' && need != null && (need > 0 || b! > 0)) ...[
          const SizedBox(width: 6),
          Text(need > 0 ? 'კიდევ $need' : (need == 0 ? 'შესრულდა' : ''),
              style: TextStyle(color: need == 0 ? okGreen : goldTable, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(width: 10),
        Text('${g.score[0]}', style: numFont.copyWith(color: g.score[0] < 0 ? badRed : light, fontSize: 15, fontWeight: FontWeight.w800)),
        const Text(' ქულა', style: TextStyle(color: lightMuted, fontSize: 12.5)),
        if (g.phase == 'handover') ...[const SizedBox(width: 6), _result(g, 0)],
      ]),
    );
  }

  // ---------- the line that says what happens now ----------

  String _statusText(JokerGame g) {
    switch (g.phase) {
      case 'trump':
        return s.myTurn ? 'პირველი სამი კარტით აირჩიე კოზირი' : '${s.nameOf(g.cur)} ირჩევს კოზირს…';
      case 'bid':
        if (!s.myTurn) return '${s.nameOf(g.cur)} ამბობს…';
        final f = g.forbidden(0);
        return 'რამდენს წაიღებ?${f >= 0 ? ' დამრიგებელი ხარ, $f-ს ვერ იტყვი' : ''}';
      case 'play':
        if (g.win != null) return g.win == 0 ? 'ეს ხელი შენ წაიღე' : '${castOf(s.seats[g.win! - 1]).erg} წაიღო ხელი';
        return s.myTurn ? 'შენი სვლაა' : '${s.nameOf(g.cur)} ფიქრობს…';
      case 'handover':
        final l = jLast(g.hist);
        final mine = (l.hand?.p[0] ?? 0) + (l.prem?.p[0] ?? 0);
        return 'ხელი დასრულდა. შენ: ${mine > 0 ? '+' : ''}$mine${l.prem != null ? ' · სექციის პრემია' : ''}';
      default:
        return '';
    }
  }

  Widget _status(JokerGame g) {
    final text = _statusText(g);
    if (text.isEmpty) return const SizedBox(height: 6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Text(text,
          key: const ValueKey('joker-status'),
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(color: s.myTurn ? goldTable : lightMuted, fontSize: 14.5, fontWeight: s.myTurn ? FontWeight.w800 : FontWeight.w600)),
    );
  }

  // ---------- what I choose now: the trump, my bid; after a hand and at the end, what comes next ----------

  Widget _panel(JokerGame g) {
    if (g.phase == 'trump' && s.myTurn) return _trumpPad(g);
    if (g.phase == 'bid' && s.myTurn) return _bidPad(g);
    if (g.phase == 'handover') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('joker-review'),
              style: OutlinedButton.styleFrom(foregroundColor: light, side: const BorderSide(color: Colors.white30), minimumSize: const Size.fromHeight(44)),
              onPressed: () => _sheetWhile(() => showHandReview(context, g, _who)),
              child: const FittedBox(child: Text('მიმოხილვა')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              key: const ValueKey('joker-next'),
              style: FilledButton.styleFrom(backgroundColor: goldTable, foregroundColor: const Color(0xFF1A1205), minimumSize: const Size.fromHeight(44)),
              onPressed: s.nextNow,
              child: const FittedBox(child: Text('შემდეგი ხელი')),
            ),
          ),
        ]),
      );
    }
    if (g.phase == 'over') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: light, side: const BorderSide(color: Colors.white30)),
              onPressed: () => showScoreSheet(context, g, [for (var p = 0; p < 4; p++) _name(p)]),
              child: const Text('ქულები'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton(
              key: const ValueKey('joker-again'),
              style: FilledButton.styleFrom(backgroundColor: goldTable, foregroundColor: const Color(0xFF1A1205), minimumSize: const Size.fromHeight(48)),
              onPressed: () => s.start(g.len),
              child: const Text('ახალი თამაში'),
            ),
          ),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _trumpPad(JokerGame g) {
    final hint = s.hint ? g.botTrump(0) : '?';
    Widget tile(String? su, Widget child, String label) {
      final on = s.hint && hint == su;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Material(
            color: su == null ? Colors.white.withValues(alpha: .1) : cardPaper,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: on ? const BorderSide(color: goldTable, width: 2.5) : BorderSide.none),
            child: InkWell(
              key: ValueKey('jtrump-${su ?? 'none'}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => s.myTrump(su),
              child: SizedBox(
                height: 64,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  child,
                  const SizedBox(height: 3),
                  Text(label, maxLines: 1, style: TextStyle(color: su == null ? light : cardInk, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 2),
      child: Row(children: [
        for (final su in suits) tile(su, SuitMark(su, size: 28, color: suitInk(su, c4: s.c4)), suitName[su]!),
        tile(null, const PIcon('x', size: 24, color: light, stroke: 2.6), 'უკოზირო'),
      ]),
    );
  }

  Widget _bidPad(JokerGame g) {
    final n = g.n, f = g.forbidden(0), hint = s.hint ? jHint(g.hands[0], g.trump, n, f) : -1;
    final count = n + 1, cols = count <= 5 ? count : (count / 2).ceil();
    final rows = <List<int>>[];
    for (var i = 0; i < count; i += cols) {
      rows.add([for (var v = i; v < math.min(count, i + cols); v++) v]);
    }
    Widget btn(int v) {
      final no = v == f, on = v == hint && !no;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Tooltip(
            message: no ? '$v: დამრიგებელს არ შეუძლია' : (on ? '$v: რჩევა' : '$v'),
            child: Material(
              color: no ? Colors.white.withValues(alpha: .03) : (on ? goldTable.withValues(alpha: .2) : Colors.white.withValues(alpha: .1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: on ? goldTable : Colors.white.withValues(alpha: no ? .08 : .2), width: on ? 2 : 1),
              ),
              child: InkWell(
                key: ValueKey('jbid-$v'),
                borderRadius: BorderRadius.circular(12),
                onTap: no ? null : () => s.myBid(v),
                child: SizedBox(
                  height: 50,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$v',
                        style: numFont.copyWith(
                          color: no ? Colors.white24 : (on ? goldTable : light),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          decoration: no ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.white38,
                        )),
                    if (v == 0) Text('პასი', style: TextStyle(color: no ? Colors.white24 : lightMuted, fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.1)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 6, 9, 0),
      child: Column(children: [
        for (final r in rows)
          Row(children: [
            for (final v in r) btn(v),
            for (var k = r.length; k < cols; k++) const Expanded(child: SizedBox()),
          ]),
      ]),
    );
  }

  // ---------- my cards: a fan along the bottom; the ones I may play stand up ----------

  /// jokers first, then the trump, then the suits alternating red and black; high to low in a suit
  List<JCard> _shown(List<JCard> hand, String? trump) {
    final have = suits.where((x) => hand.any((c) => !c.joker && c.s == x)).toList(), ord = <String>[];
    if (trump != null && have.contains(trump)) ord.add(trump);
    var rest = have.where((x) => x != trump).toList();
    while (rest.isNotEmpty) {
      final last = ord.isEmpty ? null : ord.last;
      final k = rest.indexWhere((x) => last == null || isRed(x) != isRed(last));
      final pick = rest[k < 0 ? 0 : k];
      ord.add(pick);
      rest = rest.where((x) => x != pick).toList();
    }
    int key(JCard c) => c.joker ? -10 + c.j : ord.indexOf(c.s) * 20 + (14 - c.r);
    return [...hand]..sort((a, b) => key(a).compareTo(key(b)));
  }

  Widget _hand(JokerGame g) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth - 20;
        final cw = w >= 340 ? 58.0 : 50.0, ch = cw * cardRatio;
        final choosing = g.phase == 'trump' && s.myTurn;
        final cards = choosing ? g.first3[0] : _shown(g.hands[0], g.trump);
        final total = choosing ? g.n : cards.length;
        final playing = g.phase == 'play' && s.myTurn;
        final legal = playing ? g.legal(0).toSet() : const <JCard>{};
        final step = total <= 1 ? 0.0 : math.min(cw + 6, (w - cw) / (total - 1));
        final width = cw + step * math.max(0, total - 1);
        final left0 = (box.maxWidth - width) / 2;
        return SizedBox(
          height: ch + 26,
          child: Stack(clipBehavior: Clip.none, children: [
            for (var i = 0; i < total; i++)
              AnimatedPositioned(
                key: ValueKey(i < cards.length ? 'jcard-${cards[i].key}' : 'jback-$i'),
                duration: const Duration(milliseconds: 160),
                left: left0 + i * step,
                top: i < cards.length && playing && legal.contains(cards[i]) ? 4 : 16,
                child: i < cards.length
                    ? GestureDetector(
                        onTap: () => _tapCard(cards[i]),
                        child: Semantics(
                          button: true,
                          label: cards[i].name,
                          child: CardFace(cards[i], w: cw, dim: playing && !legal.contains(cards[i]), c4: s.c4),
                        ),
                      )
                    : Opacity(opacity: .25, child: CardBack(w: cw)),
              ),
          ]),
        );
      });
}

/// The cards on the table: each comes in from its player's side; a taken trick slides to whoever took it.
class _TrickView extends StatefulWidget {
  const _TrickView({required this.g, required this.seatAt, this.c4 = false});
  final JokerGame g;
  final Map<int, Offset> seatAt;
  final bool c4;
  @override
  State<_TrickView> createState() => _TrickViewState();
}

class _TrickViewState extends State<_TrickView> {
  bool _sweep = false;
  Timer? _t;
  String _key = '';

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _watch() {
    final g = widget.g, k = '${g.h}:${g.tricks.length}:${g.trick.length}:${g.win}';
    if (k == _key) return;
    _key = k;
    _t?.cancel();
    _sweep = false;
    if (g.win != null && g.trick.length == 4) {
      _t = Timer(const Duration(milliseconds: 850), () {
        if (mounted) setState(() => _sweep = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _watch();
    final g = widget.g;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight, cw = 52.0, ch = cw * cardRatio;
      final c = Offset(w / 2, h / 2 + 6);
      const slot = {0: Offset(0, 46), 1: Offset(-50, 0), 2: Offset(0, -46), 3: Offset(50, 0)};
      const turn = {0: 0.0, 1: -.1, 2: .05, 3: .1};
      return Stack(clipBehavior: Clip.none, children: [
        for (final e in g.trick)
          AnimatedPositioned(
            key: ValueKey('t-${e.card.key}'),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInCubic,
            left: (_sweep ? widget.seatAt[g.win]! : c + slot[e.p]!).dx - cw / 2,
            top: (_sweep ? widget.seatAt[g.win]! : c + slot[e.p]!).dy - ch / 2,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 420),
              opacity: _sweep ? 0 : 1,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                builder: (_, v, child) {
                  final from = widget.seatAt[e.p]! - (c + slot[e.p]!);
                  return Transform.translate(offset: from * (1 - v), child: child);
                },
                child: Transform.rotate(
                  angle: turn[e.p]!,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CardFace(e.card, w: cw, glow: g.win != null && e.p == g.win, c4: widget.c4),
                    if (e.card.joker)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xE60A1322), borderRadius: BorderRadius.circular(6)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(jokerCall(e), style: const TextStyle(color: light, fontSize: 10.5, fontWeight: FontWeight.w700)),
                          if (e.js != null) ...[const SizedBox(width: 3), SuitMark(e.js!, size: 10, color: suitInkOnDark(e.js!, c4: widget.c4))],
                        ]),
                      ),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

/// The trump said big in the middle once a hand has it.
class _TrumpFlash extends StatelessWidget {
  const _TrumpFlash({super.key, required this.g, this.c4 = false});
  final JokerGame g;
  final bool c4;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 2200),
        builder: (_, v, child) => Opacity(opacity: v < .1 ? v * 10 : (v < .75 ? 1 : (1 - v) / .25), child: child),
        child: IgnorePointer(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (g.trumpCard != null) CardFace(g.trumpCard!, w: 50, c4: c4) else TrumpTile(trump: g.trump, size: 50, c4: c4),
            const SizedBox(height: 6),
            Text(g.trump == null ? 'უკოზირო' : 'კოზირი: ${suitName[g.trump]}', style: const TextStyle(color: light, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

/// three dots over a player who is choosing
class _Thinking extends StatelessWidget {
  const _Thinking();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: light, borderRadius: BorderRadius.circular(10)),
        child: const Text('…', style: TextStyle(color: felt, fontSize: 12, fontWeight: FontWeight.w800, height: 1)),
      );
}
