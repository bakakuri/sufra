// The Joker table: a fixed stage (the room, the table, the people at it — the camera never moves) and over it, as a
// separate layer, everything the game shows: the cards thrown into the trick and swept to whoever took it, the trump
// lying on the felt, each player's plate (what they said, what they took, their points), what has been said in all
// against the cards dealt (შეტენვა / წაგლეჯა), the little score notebook that opens up, my hand fanned at the bottom.
// The back button leaves the table (the game is kept and goes on from the Joker tab); the notebook or a sheet over it
// closes first.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/stores.dart';
import '../ui/icons.dart';
import '../ui/widgets.dart';
import 'cards.dart';
import 'engine.dart';
import 'scene.dart';
import 'sheets.dart';
import 'table_fx.dart';
import 'table_model.dart';

class JokerTableScreen extends StatefulWidget {
  const JokerTableScreen({super.key, required this.session, this.title});
  final JokerTable session;

  /// over the trump in the bar for a table with people (its number)
  final String? title;
  @override
  State<JokerTableScreen> createState() => _JokerTableScreenState();
}

class _JokerTableScreenState extends State<JokerTableScreen> {
  JokerTable get s => widget.session;
  bool _busy = false;

  /// the score notebook is open over the table
  bool _note = false;
  final _noteKey = GlobalKey(), _layerKey = GlobalKey();

  /// where my card was in my hand when I played it (it flies from there)
  final _myFrom = <String, Offset>{};

  /// what each said this hand, popped over their heads: the words and when (to start the bubble again)
  final _said = <int, (String, int)>{};
  List<int?> _bids = [null, null, null, null];
  int _stamp = 0, _h = -1;

  /// the hand whose deal is being shown
  int _dealt = -1;

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
  String _short(int p) => p == 0 ? 'მე' : s.nameOf(p);

  Future<void> _sheetWhile(Future<void> Function() f) async {
    s.hold = true;
    try {
      await f();
    } finally {
      if (mounted) s.hold = false;
    }
  }

  void _openNote() {
    s.hold = true;
    setState(() => _note = true);
  }

  void _closeNote() {
    if (!_note) return;
    setState(() => _note = false);
    s.hold = false;
  }

  /// what has changed since the last look: a new hand (its deal), a word said
  void _watch(JokerGame g) {
    if (g.h != _h) {
      final first = _h < 0;
      _h = g.h;
      _said.clear();
      _bids = [...g.bids];
      // a table opened in the middle of a hand shows it as it is; a new hand is dealt in front of us
      if (!first && const ['trump', 'bid'].contains(g.phase)) _dealt = g.h;
      return;
    }
    for (var p = 1; p < 4; p++) {
      final b = g.bids[p];
      if (_bids[p] == null && b != null) _said[p] = (b == 0 ? 'პასი' : '$b', ++_stamp);
    }
    _bids = [...g.bids];
  }

  Future<void> _tapCard(JCard c, BuildContext cardContext) async {
    final g = s.g;
    if (g == null || _busy || !s.myTurn || g.phase != 'play' || !g.legal(0).contains(c)) return;
    // the card leaves from where it is in my hand
    final box = cardContext.findRenderObject() as RenderBox?, layer = _layerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && layer != null && box.hasSize) _myFrom[c.key] = layer.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
    if (!c.joker) {
      HapticFeedback.selectionClick();
      s.myPlay(c);
      return;
    }
    _busy = true;
    final m = await pickJokerCall(context, c, lead: g.trick.isEmpty, c4: s.c4);
    _busy = false;
    if (m != null) s.myPlay(c, jm: m.jm, js: m.js);
  }

  bool _turnOf(JokerGame g, int p) => g.cur == p && g.win == null && const ['bid', 'play', 'trump'].contains(g.phase);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_note,
      onPopInvokedWithResult: (did, _) {
        if (!did) _closeNote();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: const Color(0xFF07090D),
          body: DefaultTextStyle(
            style: tableText,
            child: ListenableBuilder(
              listenable: s,
              builder: (context, _) {
                final g = s.g;
                if (g == null) return const SizedBox.shrink();
                _watch(g);
                final active = [for (var p = 0; p < 4; p++) if (_turnOf(g, p)) p].firstOrNull;
                return JokerStage(active: active, overlay: (context, m) => _layer(g, m));
              },
            ),
          ),
        ),
      ),
    );
  }

  // ---------- the layer over the stage ----------

  /// a widget with its middle (or [anchor]) at a point of the layer
  Widget _at(Offset p, Widget child, {Alignment anchor = Alignment.center}) =>
      Positioned.fill(child: CustomSingleChildLayout(delegate: _AtPoint(p, anchor), child: child));

  Widget _layer(JokerGame g, StageMap m) {
    final over = g.phase == 'over', spec = m.spec;
    final names = [for (var p = 0; p < 4; p++) _short(p)];
    return Stack(key: _layerKey, clipBehavior: Clip.none, children: [
      if (!over) ...[
        // what lies on the table
        _at(m.at(spec.trump), TrumpOnTable(g: g, w: m.cardW * .72, turn: spec.trumpTurn, c4: s.c4)),
        for (var p = 0; p < 4; p++)
          if (g.taken[p] > 0) _at(m.pile(p), PileView(key: ValueKey('pile-$p'), count: g.taken[p], w: m.cardW * .4)),
        Positioned.fill(child: _TrickLayer(g: g, m: m, from: _myFrom, c4: s.c4)),
        if (_dealt == g.h && g.phase != 'play')
          Positioned.fill(
            child: DealFx(
              key: ValueKey('deal-${g.h}'),
              from: m.seatHand(g.dealer),
              to: [for (var p = 0; p < 4; p++) m.seatHand(p)],
              w: m.cardW * .7,
              rounds: math.min(3, g.n),
              first: (g.dealer + 1) % 4,
            ),
          ),
        // who sits where: their plates, and what they have just said
        for (var p = 1; p < 4; p++) _at(m.plate(p), _plate(g, p)),
        for (final e in _said.entries)
          _at(
            m.plate(e.key) + (e.key == 2 ? Offset(m.len(250), 0) : Offset(0, -m.len(150))),
            SaidBubble(key: ValueKey('said-${e.key}-${e.value.$2}'), text: e.value.$1),
          ),
        if (g.phase == 'handover') _at(m.at(spec.felt), _handFx(g)),
      ] else
        Positioned.fill(child: ColoredBox(color: const Color(0xB3060A12), child: _gameOver(g))),
      // the bar at the top and everything at the bottom
      Positioned(left: 0, right: 0, top: 0, child: SafeArea(bottom: false, child: _top(g, names))),
      Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(top: false, child: _bottom(g))),
      if (_note)
        Positioned.fill(
          child: NotebookOpen(from: _noteRect(), g: g, names: [for (var p = 0; p < 4; p++) _name(p)], onClose: _closeNote),
        ),
    ]);
  }

  Rect _noteRect() {
    final box = _noteKey.currentContext?.findRenderObject() as RenderBox?, layer = _layerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || layer == null || !box.hasSize) return const Rect.fromLTWH(300, 60, 84, 90);
    return layer.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
  }

  // ---------- the bar at the top: back, the trump, which hand; what has been said against the cards; the notebook ----------

  Widget _top(JokerGame g, List<String> names) {
    final choosing = g.phase == 'trump';
    final said = const ['bid', 'play'].contains(g.phase) ? g.bids.whereType<int>().toList() : const <int>[];
    final t = said.fold<int>(0, (a, b) => a + b), all = said.length == 4, d = t - g.n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 4), child: IconBtn('back', label: 'უკან', color: light, onTap: () => Navigator.of(context).maybePop())),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              _glass(
                Row(mainAxisSize: MainAxisSize.min, children: [
                  TrumpTile(trump: g.trump, choosing: choosing, size: 26, c4: s.c4),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text('${widget.title != null ? '${widget.title} · ' : ''}ხელი ${math.min(g.h + 1, g.seq.length)}/${g.seq.length} · ${g.n} კარტი',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: light, fontSize: 13.5, fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
              const SizedBox(height: 5),
              if (said.isNotEmpty)
                _glass(
                  Text.rich(
                    key: const ValueKey('joker-said'),
                    TextSpan(children: [
                      const TextSpan(text: 'ნაძახები ', style: TextStyle(color: lightMuted, fontWeight: FontWeight.w600)),
                      TextSpan(text: '$t/${g.n}', style: numFont.copyWith(color: light, fontWeight: FontWeight.w800)),
                      if (all && d != 0)
                        TextSpan(
                          text: d < 0 ? '  შეტენვა ${-d}' : '  წაგლეჯა $d',
                          style: TextStyle(color: d < 0 ? const Color(0xFF8DB0FF) : badRed, fontWeight: FontWeight.w800),
                        )
                      else if (!all)
                        TextSpan(text: '  ${4 - said.length} ამბობს', style: const TextStyle(color: lightMuted, fontWeight: FontWeight.w600)),
                    ]),
                    style: const TextStyle(fontSize: 13),
                  ),
                  border: all && d != 0 ? (d < 0 ? const Color(0xFF8DB0FF) : badRed) : null,
                ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: KeyedSubtree(key: _noteKey, child: MiniNotebook(g: g, names: names, onTap: _openNote)),
        ),
      ]),
    );
  }

  Widget _glass(Widget child, {Color? border, EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5)}) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: const Color(0xB30A0F1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border ?? Colors.white.withValues(alpha: .1), width: border != null ? 1.4 : 1),
        ),
        child: child,
      );

  // ---------- a player's plate: the face, the name, what they said and took, their points ----------

  Widget _face(int p, double size, {bool turn = false}) {
    final ring = turn ? goldTable : Colors.white24;
    final f = p == 0 ? SeatFace(person: context.me) : s.faceOf(p);
    final Widget pic = f.person != null
        ? Avatar(p: f.person!, size: size)
        : f.asset != null
            ? ClipOval(child: Image.asset(f.asset!, width: size, height: size, fit: BoxFit.cover))
            : Container(
                width: size,
                height: size,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .08), border: Border.all(color: Colors.white24)),
                child: Center(child: PIcon('plus', size: size * .4, color: lightMuted)),
              );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring,
        boxShadow: turn ? const [BoxShadow(color: Color(0x99F5B544), blurRadius: 16, spreadRadius: 2)] : null,
      ),
      child: pic,
    );
  }

  Widget _dealer() => Tooltip(
        message: 'დამრიგებელი',
        child: Container(
          width: 19,
          height: 19,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: goldTable, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0A0F1A), width: 1.5)),
          child: const Text('დ', style: TextStyle(color: Color(0xFF1A1205), fontSize: 10, fontWeight: FontWeight.w800, height: 1)),
        ),
      );

  /// said and taken, side by side and named: green when made, red when more was taken; a pass says so
  Widget _pips(JokerGame g, int p) {
    final b = g.bids[p], t = g.taken[p];
    final col = b == null ? lightMuted : (t > b ? badRed : (t == b ? okGreen : light));
    Widget num(String label, String v, Color c) => Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(color: lightMuted, fontSize: 9, fontWeight: FontWeight.w600, height: 1.1)),
          Text(v, style: numFont.copyWith(color: c, fontSize: 15, fontWeight: FontWeight.w900, height: 1.15)),
        ]);
    return Container(
      key: ValueKey('pips-$p'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: col.withValues(alpha: b == null ? .06 : .13),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: col.withValues(alpha: .5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        num('ნათქვამი', b == null ? '–' : (b == 0 ? 'პასი' : '$b'), b == null ? lightMuted : light),
        Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 7), color: Colors.white24),
        num('წაიღო', '$t', col),
      ]),
    );
  }

  Widget _plate(JokerGame g, int p) {
    final turn = _turnOf(g, p);
    return AnimatedContainer(
      key: ValueKey('plate-$p'),
      duration: const Duration(milliseconds: 300),
      width: 104,
      padding: const EdgeInsets.fromLTRB(6, 7, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xC70A0F1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: turn ? goldTable : Colors.white.withValues(alpha: .1), width: turn ? 1.6 : 1),
        boxShadow: [BoxShadow(color: turn ? const Color(0x66F5B544) : const Color(0x66000000), blurRadius: turn ? 18 : 10)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          _face(p, 40, turn: turn),
          if (p == g.dealer) Positioned(right: -4, bottom: -3, child: _dealer()),
          if (turn && g.phase != 'play') const Positioned(top: -6, left: -12, child: _Thinking()),
        ]),
        const SizedBox(height: 3),
        Text(s.nameOf(p), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: light, fontSize: 12.5, fontWeight: FontWeight.w800)),
        if (s.awayOf(p))
          const Text('გავიდა · ბოტი', style: TextStyle(color: goldTable, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        FittedBox(fit: BoxFit.scaleDown, child: _pips(g, p)),
        const SizedBox(height: 2),
        Text('${g.score[p]} ქულა', style: numFont.copyWith(color: g.score[p] < 0 ? badRed : lightMuted, fontSize: 11, fontWeight: FontWeight.w700)),
        _result(g, p),
      ]),
    );
  }

  /// after a hand: what it brought
  Widget _result(JokerGame g, int p) {
    if (g.phase != 'handover' || g.hist.isEmpty) return const SizedBox.shrink();
    final l = jLast(g.hist);
    final hand = l.hand;
    if (hand == null) return const SizedBox.shrink();
    final x = hand.p[p] + (l.prem?.p[p] ?? 0), ok = hand.b[p] == hand.t[p], kh = hand.b[p] > 0 && hand.t[p] == 0;
    final col = ok ? okGreen : (kh ? badRed : lightMuted);
    return Padding(
      padding: const EdgeInsets.only(top: 3),
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
        padding: const EdgeInsets.fromLTRB(24, 110, 24, 150),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: math.max(200, math.min(380, box.maxWidth - 48)),
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
      ),
    );
  }

  // ---------- the bottom: the line that says what happens now, what I choose, my plate, my hand ----------

  Widget _bottom(JokerGame g) {
    final over = g.phase == 'over';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const SizedBox(width: 12),
        if (g.lastT != null && g.phase == 'play')
          Material(
            color: const Color(0xB30A0F1A),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              key: const ValueKey('joker-last'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => _sheetWhile(() => showLastTrick(context, g.lastT!, _who, c4: s.c4)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  PIcon('cards', size: 15, color: lightMuted),
                  SizedBox(width: 5),
                  Text('ბოლო ხელი', style: TextStyle(color: lightMuted, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        Expanded(child: _status(g)),
        const SizedBox(width: 12),
      ]),
      _panel(g),
      if (!over) _meRow(g),
      if (!over) _hand(g) else const SizedBox(height: 8),
    ]);
  }

  String _statusText(JokerGame g) {
    switch (g.phase) {
      case 'trump':
        return s.myTurn ? 'პირველი სამი კარტით აირჩიე კოზირი${_left()}' : '${s.nameOf(g.cur)} ირჩევს კოზირს…';
      case 'bid':
        if (!s.myTurn) return '${s.nameOf(g.cur)} ამბობს…';
        final f = g.forbidden(0);
        return 'რამდენს წაიღებ?${f >= 0 ? ' დამრიგებელი ხარ, $f-ს ვერ იტყვი' : ''}${_left()}';
      case 'play':
        if (g.win != null) return g.win == 0 ? 'ეს ხელი შენ წაიღე' : s.tookText(g.win!);
        return s.myTurn ? 'შენი სვლაა${_left()}' : '${s.nameOf(g.cur)} ფიქრობს…';
      case 'handover':
        final l = jLast(g.hist);
        final mine = (l.hand?.p[0] ?? 0) + (l.prem?.p[0] ?? 0);
        return 'ხელი დასრულდა. შენ: ${mine > 0 ? '+' : ''}$mine${l.prem != null ? ' · სექციის პრემია' : ''}';
      default:
        return '';
    }
  }

  /// the seconds left for my move at a table with people
  String _left() {
    final l = s.secondsLeft;
    return l == null || l > 30 ? '' : ' · $l წმ';
  }

  Widget _status(JokerGame g) {
    final text = _statusText(g);
    if (text.isEmpty) return const SizedBox(height: 30);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text,
          key: const ValueKey('joker-status'),
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            color: s.myTurn ? goldTable : light,
            fontSize: 14.5,
            fontWeight: s.myTurn ? FontWeight.w800 : FontWeight.w600,
            shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 8)],
          )),
    );
  }

  Widget _meRow(JokerGame g) {
    final turn = _turnOf(g, 0), b = g.bids[0], need = b == null ? null : b - g.taken[0];
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 2, 10, 0),
      padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
      decoration: BoxDecoration(
        color: Color.fromRGBO(10, 15, 26, turn ? .86 : .74),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: turn ? goldTable : Colors.white.withValues(alpha: .08), width: 1.5),
      ),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          _face(0, 32, turn: turn),
          if (g.dealer == 0) Positioned(right: -5, bottom: -4, child: _dealer()),
        ]),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(context.me.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: light, fontSize: 14, fontWeight: FontWeight.w800)),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${g.score[0]}', style: numFont.copyWith(color: g.score[0] < 0 ? badRed : light, fontWeight: FontWeight.w800)),
                const TextSpan(text: ' ქულა'),
                if (g.phase == 'play' && need != null && (need > 0 || b! > 0))
                  TextSpan(
                    text: need > 0 ? ' · კიდევ $need' : (need == 0 ? ' · შესრულდა' : ' · მეტი წაიღე'),
                    style: TextStyle(color: need == 0 ? okGreen : (need > 0 ? goldTable : badRed), fontWeight: FontWeight.w800),
                  ),
              ]),
              style: const TextStyle(color: lightMuted, fontSize: 12),
            ),
          ]),
        ),
        _pips(g, 0),
        if (g.phase == 'handover') ...[const SizedBox(width: 6), _result(g, 0)],
      ]),
    );
  }

  // ---------- what I choose now: the trump, my bid; after a hand and at the end, what comes next ----------

  Widget _panel(JokerGame g) {
    Widget glass(Widget child) => Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          decoration: BoxDecoration(
            color: const Color(0xD90A0F1A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
            boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 18)],
          ),
          child: child,
        );
    if (g.phase == 'trump' && s.myTurn) return glass(_trumpPad(g));
    if (g.phase == 'bid' && s.myTurn) return glass(_bidPad(g));
    if (g.phase == 'handover' && s.canNext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('joker-review'),
              style: OutlinedButton.styleFrom(foregroundColor: light, backgroundColor: const Color(0xB30A0F1A), side: const BorderSide(color: Colors.white30), minimumSize: const Size.fromHeight(44)),
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
              onPressed: _openNote,
              child: const Text('ქულები'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: s.canAgain
                ? FilledButton(
                    key: const ValueKey('joker-again'),
                    style: FilledButton.styleFrom(backgroundColor: goldTable, foregroundColor: const Color(0xFF1A1205), minimumSize: const Size.fromHeight(48)),
                    onPressed: s.again,
                    child: const Text('ახალი თამაში'),
                  )
                : Text(s.againNote, textAlign: TextAlign.center, style: const TextStyle(color: lightMuted, fontSize: 13.5, height: 1.3)),
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

    return Row(children: [
      for (final su in suits) tile(su, SuitMark(su, size: 28, color: suitInk(su, c4: s.c4)), suitName[su]!),
      tile(null, const PIcon('x', size: 24, color: light, stroke: 2.6), 'უკოზირო'),
    ]);
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
                  height: 48,
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

    return Column(children: [
      for (final r in rows)
        Row(children: [
          for (final v in r) btn(v),
          for (var k = r.length; k < cols; k++) const Expanded(child: SizedBox()),
        ]),
    ]);
  }

  // ---------- my cards: a fan held at the bottom; the ones I may play stand up ----------

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
        final w = box.maxWidth;
        final cw = (w / 5.4).clamp(54.0, 78.0), ch = cw * cardRatio;
        final choosing = g.phase == 'trump' && s.myTurn;
        final cards = choosing ? g.first3[0] : _shown(g.hands[0], g.trump);
        final total = choosing ? g.n : cards.length;
        final playing = g.phase == 'play' && s.myTurn;
        final legal = playing ? g.legal(0).toSet() : const <JCard>{};
        // spread along an arc, as held in two hands: the middle highest, the ends turned out and a little lower
        final step = total <= 1 ? 0.0 : math.min(cw * .8, (w - cw - 24) / (total - 1));
        final turn = total <= 1 ? 0.0 : math.min(.07, .5 / (total - 1));
        return SizedBox(
          height: ch + 30,
          child: Stack(clipBehavior: Clip.none, children: [
            for (var i = 0; i < total; i++)
              () {
                final k = i - (total - 1) / 2;
                final up = i < cards.length && playing && legal.contains(cards[i]);
                return AnimatedPositioned(
                  key: ValueKey(i < cards.length ? 'jcard-${cards[i].key}' : 'jback-$i'),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: w / 2 + k * step - cw / 2,
                  top: 12 + k * k * 1.6 + (up ? -12 : 0),
                  child: _InHand(
                    key: ValueKey('in-${g.h}'),
                    order: i,
                    child: Transform.rotate(
                      angle: k * turn,
                      child: i < cards.length
                          ? Builder(
                              builder: (cardContext) => GestureDetector(
                                onTap: () => _tapCard(cards[i], cardContext),
                                child: Semantics(
                                  button: true,
                                  label: cards[i].name,
                                  child: CardFace(cards[i], w: cw, dim: playing && !legal.contains(cards[i]), c4: s.c4),
                                ),
                              ),
                            )
                          : Opacity(opacity: .35, child: CardBack(w: cw)),
                    ),
                  ),
                );
              }(),
          ]),
        );
      });
}

/// A card coming into my hand when a hand is dealt: up from below, one after another.
class _InHand extends StatelessWidget {
  const _InHand({super.key, required this.order, required this.child});
  final int order;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final ms = 300 + order * 70, start = order * 70 / ms;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 60), child: c)),
      child: child,
    );
  }
}

/// lays its child with [anchor] at [p]
class _AtPoint extends SingleChildLayoutDelegate {
  const _AtPoint(this.p, this.anchor);
  final Offset p;
  final Alignment anchor;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();
  @override
  Offset getPositionForChild(Size size, Size childSize) => p - anchor.alongSize(childSize);
  @override
  bool shouldRelayout(_AtPoint o) => o.p != p || o.anchor != anchor;
}

/// The cards of the trick: each thrown in from its player's hands to its place; once taken, the trick waits a moment
/// and is swept to the taker's pile, turning face down on the way.
class _TrickLayer extends StatefulWidget {
  const _TrickLayer({required this.g, required this.m, required this.from, this.c4 = false});
  final JokerGame g;
  final StageMap m;
  final Map<String, Offset> from;
  final bool c4;
  @override
  State<_TrickLayer> createState() => _TrickLayerState();
}

class _TrickLayerState extends State<_TrickLayer> {
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
      _t = Timer(const Duration(milliseconds: 820), () {
        if (mounted) setState(() => _sweep = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _watch();
    final g = widget.g, m = widget.m, cw = m.cardW, spec = m.spec;
    return IgnorePointer(
      child: Stack(clipBehavior: Clip.none, children: [
        for (final (i, e) in g.trick.indexed)
          () {
            final seat = spec.seats[e.p];
            final to = m.slot(e.p) + Offset(cardJitter(e.card, m.len(10)), cardJitter(e.card, m.len(8)));
            final turn = seat.turn + cardJitter(e.card);
            final won = g.win != null && e.p == g.win;
            Widget? call;
            if (e.card.joker) {
              call = Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xE60A1322), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(jokerCall(e), style: const TextStyle(color: light, fontSize: 10.5, fontWeight: FontWeight.w700)),
                  if (e.js != null) ...[const SizedBox(width: 3), SuitMark(e.js!, size: 10, color: suitInkOnDark(e.js!, c4: widget.c4))],
                ]),
              );
            }
            if (_sweep && g.win != null) {
              return CardFlight(
                key: ValueKey('sw-${e.card.key}'),
                card: e.card,
                from: to,
                to: m.pile(g.win!),
                w: cw,
                turn0: turn,
                turn1: (i.isEven ? .06 : -.06),
                scale1: .4,
                lift: .1,
                toBack: true,
                delay: Duration(milliseconds: i * 45),
                duration: const Duration(milliseconds: 460),
                c4: widget.c4,
              );
            }
            return CardFlight(
              key: ValueKey('t-${e.card.key}'),
              card: e.card,
              from: e.p == 0 ? (widget.from[e.card.key] ?? m.seatHand(0)) : m.seatHand(e.p),
              to: to,
              w: cw,
              turn0: e.p == 0 ? 0 : (e.p == 1 ? -.6 : (e.p == 3 ? .6 : .3)),
              turn1: turn,
              scale0: e.p == 0 ? 1.05 : .55,
              flip: e.p != 0,
              lift: e.p == 0 ? .16 : .26,
              duration: Duration(milliseconds: e.p == 0 ? 360 : 520),
              glow: won,
              c4: widget.c4,
              below: call,
            );
          }(),
      ]),
    );
  }
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
