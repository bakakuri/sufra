// The backgammon table on screen: the other player at the top with their character, the board, me at the bottom
// with mine, the dice and the words of the moment. A checker is picked up with a tap and put down with another (one
// with a single way to go moves at once).
import 'dart:async';

import 'package:flutter/material.dart' hide Step;

import '../data/stores.dart';
import '../ui/icons.dart';
import '../ui/look.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'board.dart';
import 'character.dart';
import 'engine.dart';
import 'table_model.dart';

/// the clocks count down on screen (off in the tests, where a screen that changes every second never settles)
bool clocksTick = true;

String _mmss(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

class NardiScreen extends StatefulWidget {
  const NardiScreen({super.key, required this.table, this.title});
  final NardiTable table;
  final String? title;
  @override
  State<NardiScreen> createState() => _NardiScreenState();
}

class _NardiScreenState extends State<NardiScreen> {
  int? selected;
  bool rolling = false;
  Timer? _rollT, _clockT;
  String _rollKey = '';

  NardiTable get t => widget.table;

  @override
  void initState() {
    super.initState();
    t.addListener(_changed);
    _rollKey = _keyOf();
    // on screen: the computer may go on (after this first frame, so what it does is drawn)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) t.live = true;
    });
    if (clocksTick) {
      _clockT = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && t.clockOf(t.me) != null && t.g?.phase != Phase.over) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    t.removeListener(_changed);
    t.live = false;
    _rollT?.cancel();
    _clockT?.cancel();
    super.dispose();
  }

  String _keyOf() {
    final g = t.g;
    return g == null ? '' : '${g.turn}:${g.dice.join()}:${g.phase == Phase.move || g.phase == Phase.over}';
  }

  void _changed() {
    if (!mounted) return;
    final k = _keyOf();
    final g = t.g;
    // new dice fell: they tumble for a moment
    if (k != _rollKey && g != null && g.dice.isNotEmpty && (g.phase == Phase.move || (g.phase == Phase.roll && g.last.isEmpty && g.lastBy >= 0))) {
      rolling = true;
      _rollT?.cancel();
      _rollT = Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => rolling = false);
      });
    }
    _rollKey = k;
    if (!t.canMove) selected = null;
    setState(() {});
  }

  /// the real points I may move from now
  Set<int> get _movable => t.canMove ? {for (final s in t.g!.options) s.from} : const {};

  List<Step> get _options => selected == null ? const [] : [for (final s in t.g!.options) if (s.from == selected) s];

  Future<void> _tap(int p) async {
    if (!t.canMove) return;
    final g = t.g!;
    if (selected == null) {
      final from = [for (final s in g.options) if (s.from == p) s];
      if (from.isEmpty) return;
      final dests = {for (final s in from) s.to};
      if (dests.length == 1) {
        // one way to go: at once, with the larger die when both lead there
        from.sort((a, b) => b.die.compareTo(a.die));
        await t.play(from.first);
      } else {
        setState(() => selected = p);
      }
      return;
    }
    if (p == selected) {
      setState(() => selected = null);
      return;
    }
    final to = [for (final s in _options) if (s.to == p) s]..sort((a, b) => b.die.compareTo(a.die));
    if (to.isNotEmpty) {
      selected = null;
      await t.play(to.first);
      return;
    }
    setState(() => selected = g.options.any((s) => s.from == p) ? p : null);
  }

  String _words() {
    final g = t.g;
    if (g == null) return '';
    final seat = t.seatOf(t.other);
    // a person by their first name, a computer player by all of it
    final other = seat.person != null ? seat.name.split(' ').first : seat.name;
    switch (g.phase) {
      case Phase.opening:
        return 'კამათელი წყვეტს, ვინ იწყებს';
      case Phase.roll:
        if (g.lastBy >= 0 && g.last.isEmpty && g.lastBy != g.turn) {
          return g.lastBy == t.me ? 'სვლა არ გქონდა. ${g.turn == t.me ? 'ისევ შენ აგორებ' : '$other აგორებს'}' : '$other-ს სვლა არ ჰქონდა. შენ აგორებ';
        }
        return g.turn == t.me ? 'შენი სვლაა: გააგორე კამათელი' : '$other აგორებს…';
      case Phase.move:
        final first = g.firstRoll;
        if (g.turn != t.me) return first != null ? '$other იწყებს: ${first[t.other]} და ${first[t.me]}' : '$other დადის…';
        if (selected != null) return 'სად დავდგა?';
        if (g.board.bars[t.me] > 0) return 'ჯერ ბარიდან შემოიყვანე';
        if (first != null && g.done.isEmpty) return 'შენ იწყებ: ${first[t.me]} და ${first[t.other]}';
        if (g.dice[0] == g.dice[1]) return 'წყვილი! ${g.left.length} სვლა დარჩა';
        return 'შენი სვლაა: ${g.left.join(' და ')}';
      case Phase.over:
        return g.winner == t.me ? 'მოიგე!' : '$other-მ მოიგო';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, g = t.g;
    final still = MediaQuery.disableAnimationsOf(context) || ecoMode.value;
    return Scaffold(
      appBar: peeraBar(context, title: widget.title ?? 'ნარდი', actions: [
        if (g != null && g.phase != Phase.over)
          IconBtn('flag', key: const ValueKey('nd-resign'), label: 'დანებება', onTap: () async {
            if (await confirm(context, title: 'დანებდები?', text: 'თამაში წაგებულად ჩაითვლება.', yes: 'დანებება', danger: true)) await t.resign();
          }),
      ]),
      body: g == null
          ? Center(child: Text(t.pause ?? '', key: const ValueKey('nd-pause'), style: TextStyle(color: c.muted, fontSize: 15)))
          : Column(children: [
              _player(context, t.other, top: true, still: still),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1 / 1.08,
                      child: Stack(fit: StackFit.expand, children: [
                        NardiBoardView(
                        key: const ValueKey('nd-board'),
                        board: g.board,
                        me: t.me,
                        selected: selected,
                        options: _options,
                        movable: _movable,
                        onTap: _tap,
                        onTray: () => _tap(offPoint(t.me)),
                        dice: g.dice,
                        left: g.left,
                        diceOf: g.phase == Phase.opening ? -1 : (g.phase == Phase.roll ? g.lastBy : g.turn),
                        rolling: rolling,
                        stepTick: t.stepTick,
                        lastStep: t.lastStep,
                        still: still,
                      ),
                        if (t.pause != null)
                          Center(
                            child: Container(
                              key: const ValueKey('nd-pause'),
                              margin: const EdgeInsets.all(24),
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              decoration: BoxDecoration(color: c.surface.withValues(alpha: .94), borderRadius: BorderRadius.circular(16)),
                              child: Text(t.pause!, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
              _player(context, t.me, top: false, still: still),
              _bottom(context, c, g),
            ]),
    );
  }

  Widget _player(BuildContext context, int pl, {required bool top, required bool still}) {
    final c = context.pc, g = t.g!, seat = t.seatOf(pl), mine = pl == t.me;
    final on = g.phase != Phase.over && g.turn == pl;
    final mood = t.moodOf(pl);
    final who = CharacterView(key: ValueKey('nd-char-$pl'), look: seat.look, mood: mood, size: top ? 92 : 104, facingDown: top, still: still);
    final clk = t.clockOf(pl);
    final short = on && clk != null && clk.inSeconds < 30;
    final words = Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        if (seat.person != null) ...[Avatar(p: seat.person!, size: 28, ring: false), const SizedBox(width: 6)],
        Flexible(child: Text(seat.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: on ? c.accent : c.ink))),
        if (t.otherAway && !mine) ...[const SizedBox(width: 6), Text('გასულია', style: TextStyle(color: c.muted, fontSize: 12))],
      ]),
      const SizedBox(height: 2),
      Text.rich(
        TextSpan(children: [
          TextSpan(text: '${g.board.pips(pl)} პიპი'),
          if (clk != null) TextSpan(text: ' · ${_mmss(clk)}', style: TextStyle(fontWeight: on ? FontWeight.w800 : FontWeight.w500, color: short ? c.nope : (on ? c.ink : c.muted))),
        ]),
        key: ValueKey('nd-clock-$pl'),
        style: TextStyle(color: c.muted, fontSize: 12.5),
      ),
      if (top) ...[
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(_words(), key: ValueKey(_words()), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.ink)),
        ),
      ],
    ]);
    return Container(
      height: top ? 104 : 112,
      padding: EdgeInsets.fromLTRB(mine ? 14 : 8, top ? 4 : 0, mine ? 8 : 14, 0),
      child: Row(children: [
        if (!mine) ...[who, const SizedBox(width: 10), Expanded(child: words)] else ...[Expanded(child: Align(alignment: Alignment.centerRight, child: words)), const SizedBox(width: 10), who],
      ]),
    );
  }

  Widget _bottom(BuildContext context, PeeraColors c, NardiGame g) {
    if (g.phase == Phase.over) {
      final won = g.winner == t.me;
      final kind = g.pts == 3 ? 'კოქსი' : (g.pts == 2 ? 'მარსი' : '');
      return Container(
        key: const ValueKey('nd-over'),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: won ? const Color(0xFFF5B300) : c.line, width: won ? 1.5 : 1),
        ),
        child: Column(children: [
          Text(won ? 'მოიგე! 🎉' : 'წააგე', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text('${g.pts} ქულა${kind.isNotEmpty ? ' · $kind' : ''}${t.reward != null && t.reward! > 0 ? ' · +${t.reward} მონეტა' : ''}', style: TextStyle(color: c.muted)),
          if (t.againNote.isNotEmpty) ...[const SizedBox(height: 4), Text(t.againNote, style: TextStyle(color: c.muted, fontSize: 12.5))],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(key: const ValueKey('nd-close'), onPressed: () => Navigator.of(context).maybePop(), child: const Text('დახურვა'))),
            if (t.canAgain) ...[
              const SizedBox(width: 10),
              Expanded(child: FilledButton(key: const ValueKey('nd-again'), onPressed: () => t.again(), child: Text(t.againLabel))),
            ],
          ]),
        ]),
      );
    }
    return SafeArea(
      top: false,
      child: Container(
        height: 60,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: Row(children: [
          if (t.canMove && t.canUndo && g.done.isNotEmpty)
            OutlinedButton.icon(
              key: const ValueKey('nd-undo'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 16)),
              onPressed: () {
                selected = null;
                t.undo();
              },
              icon: const PIcon('rotate', size: 18),
              label: const Text('უკან'),
            ),
          const Spacer(),
          if (t.canRoll)
            FilledButton.icon(
              key: const ValueKey('nd-roll'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 22), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () => t.roll(),
              icon: const PIcon('dice', size: 20, color: Colors.white),
              label: const Text('კამათელი', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
        ]),
      ),
    );
  }
}

/// A table opened over everything: the screen with its back
Future<void> openNardi(BuildContext context, NardiTable table, {String? title}) => openPage(context, NardiScreen(table: table, title: title), full: true);
