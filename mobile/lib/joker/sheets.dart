// The sheets over the Joker table: the joker's call, the score sheet, the last trick, the review of a hand.
// Each is one step: the back button closes it and nothing else.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'cards.dart';
import 'engine.dart';

const felt = Color(0xFF0A1322), feltHi = Color(0xFF15305A), light = Color(0xFFF2EEE6), lightMuted = Color(0xB3F2EEE6);
const goldTable = Color(0xFFF5B544), okGreen = Color(0xFF3CCB9A), badRed = Color(0xFFFF6B6B);

Future<T?> _sheet<T>(BuildContext context, Widget child, {bool tall = false}) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: tall,
      showDragHandle: true,
      backgroundColor: const Color(0xFF121D33),
      builder: (_) => SafeArea(child: child),
    );

/// What a joker is played as. Leading: high (everyone must give their highest of the named suit, the joker takes) or
/// "let it take" (the highest of the named suit takes). Later: high takes the trick, low gives it away.
Future<Move?> pickJokerCall(BuildContext context, JCard joker, {required bool lead, bool c4 = false}) => _sheet<Move>(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('ჯოკერი', textAlign: TextAlign.center, style: TextStyle(color: light, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          if (lead) ...[
            _callRow(context, joker, 'hi', 'მაღალი', 'ვითხოვ უმაღლესს, ვიღებ', c4),
            const SizedBox(height: 12),
            _callRow(context, joker, 'lo', 'წაიღოს', 'ამ ფრის უმაღლესმა', c4),
          ] else
            Row(children: [
              Expanded(child: _callBig(context, joker, 'hi', 'მაღალი', 'წაიღებს ხელს', goldTable)),
              const SizedBox(width: 12),
              Expanded(child: _callBig(context, joker, 'lo', 'დაბალი', 'არ წაიღებს', const Color(0xFF8DB0FF))),
            ]),
        ]),
      ),
    );

Widget _callRow(BuildContext context, JCard joker, String jm, String title, String sub, bool c4) => Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: light, fontSize: 16, fontWeight: FontWeight.w800)),
          Text(sub, style: const TextStyle(color: lightMuted, fontSize: 12.5)),
        ]),
      ),
      for (final s in suits)
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Material(
            color: cardPaper,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              key: ValueKey('jcall-$jm-$s'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.pop(context, Move(joker, jm: jm, js: s)),
              child: Tooltip(
                message: '$title, ${suitName[s]}',
                child: SizedBox(width: 44, height: 48, child: Center(child: SuitMark(s, size: 26, color: suitInk(s, c4: c4)))),
              ),
            ),
          ),
        ),
    ]);

Widget _callBig(BuildContext context, JCard joker, String jm, String title, String sub, Color col) => Material(
      color: col.withValues(alpha: .14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: col.withValues(alpha: .7), width: 1.5)),
      child: InkWell(
        key: ValueKey('jcall-$jm'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(context, Move(joker, jm: jm)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(children: [
            Text(title, style: TextStyle(color: col, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(color: lightMuted, fontSize: 13)),
          ]),
        ),
      ),
    );

/// The score sheet as kept at a real table: squared paper, blue ballpoint, minus in red. A column a player, a row a hand
/// (the cards dealt in the margin), the bid small in the corner; a ხიშტი struck through; a double line closes each section
/// with the running totals; the hands still to come wait in pencil, the one being played is marked.
Future<void> showScoreSheet(BuildContext context, JokerGame g, List<String> names) => _sheet<void>(
      context,
      DraggableScrollableSheet(
        expand: false,
        initialChildSize: .78,
        minChildSize: .4,
        maxChildSize: .95,
        builder: (_, sc) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(children: [
            const Text('ქულების ფურცელი', style: TextStyle(color: light, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Expanded(child: ScorePaper(g: g, names: names, controller: sc)),
          ]),
        ),
      ),
      tall: true,
    );

const _ink = Color(0xFF1B3A8C), _red = Color(0xFFC62828), _pencil = Color(0xFF9AA3B5);

class ScorePaper extends StatelessWidget {
  const ScorePaper({super.key, required this.g, required this.names, this.controller});
  final JokerGame g;
  final List<String> names;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    final run = [0, 0, 0, 0];
    final full = g.len != 'quick';
    var ls = -1, k = 0;
    TextStyle st(int x, {double size = 15, bool bold = false}) =>
        TextStyle(color: x < 0 ? _red : _ink, fontSize: size, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontFamily: 'NotoSans', fontFamilyFallback: const ['Roboto']);
    Widget margin(Widget? w) => SizedBox(width: 30, child: Center(child: w));
    Widget secTitle(int s) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
          child: Text((g.len == 'nines' ? jSecName9 : jSecName)[s], style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic)),
        );
    // the running totals under a double line
    Widget sub() => Column(children: [
          Container(height: 1, color: _ink),
          const SizedBox(height: 2),
          Container(height: 1, color: _ink),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [margin(null), for (final x in [...run]) Expanded(child: Center(child: Text('$x', style: st(x, bold: true))))]),
          ),
        ]);
    for (var ix = 0; ix < g.hist.length; ix++) {
      final h = g.hist[ix];
      for (var p = 0; p < 4; p++) {
        run[p] += h.p[p];
      }
      if (full && !h.pr && h.s != ls) {
        rows.add(secTitle(h.s));
        ls = h.s;
      }
      if (h.pr) {
        rows.add(_line(Row(children: [
          margin(Star(size: 14, color: goldTable)),
          for (final x in h.p) Expanded(child: Center(child: Text(x == 0 ? '' : '${x > 0 ? '+' : ''}$x', style: st(x)))),
        ])));
      } else {
        rows.add(_line(Row(children: [
          margin(Text('${h.n}', style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w700))),
          for (var p = 0; p < 4; p++) Expanded(child: _cell(h.b[p], h.t[p], h.p[p], st)),
        ])));
        k++;
      }
      final nx = ix + 1 < g.hist.length ? g.hist[ix + 1] : null;
      if ((nx != null && nx.s != h.s) || (nx == null && k < g.seq.length && jSecEnd(g.len, k - 1))) rows.add(sub());
    }
    for (var i = k; i < g.seq.length; i++) {
      final sc = jSec(g.len, i);
      if (full && sc != ls) {
        rows.add(secTitle(sc));
        ls = sc;
      }
      final cur = i == g.h && g.phase != 'over';
      rows.add(_line(
        Row(children: [
          margin(Text('${g.seq[i]}', style: TextStyle(color: cur ? _ink : _pencil, fontSize: 14, fontWeight: cur ? FontWeight.w800 : FontWeight.w500))),
          const Spacer(),
        ]),
        cur: cur,
      ));
    }
    // a star by a name while that player has made every bid of the section being played
    final cs = jSec(g.len, math.min(g.h, g.seq.length - 1));
    final mine = [for (final r in g.hist) if (!r.pr && r.s == cs) r];
    bool star(int p) => mine.isNotEmpty && mine.every((r) => r.b[p] == r.t[p]);
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFFBFAF4), borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _Squares(),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _ink, width: 1.4))),
            child: Row(children: [
              margin(null),
              for (var p = 0; p < 4; p++)
                Expanded(
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Flexible(child: Text(names[p].split(' ').first, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w800))),
                    if (star(p)) const Padding(padding: EdgeInsets.only(left: 2), child: Star(size: 12, color: goldTable)),
                  ]),
                ),
            ]),
          ),
          Expanded(child: ListView(controller: controller, padding: const EdgeInsets.only(bottom: 8), children: rows)),
          if (g.hist.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(color: Color(0xFFF1EEDF), border: Border(top: BorderSide(color: _ink, width: 1.4))),
              child: Row(children: [
                margin(const Text('სულ', style: TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w800))),
                for (final x in g.score) Expanded(child: Center(child: Text('$x', style: st(x, size: 16, bold: true)))),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _line(Widget child, {bool cur = false}) => Container(
        height: 34,
        decoration: BoxDecoration(color: cur ? const Color(0x1F4F46E5) : null),
        child: child,
      );

  Widget _cell(int b, int t, int x, TextStyle Function(int, {double size, bool bold}) st) {
    final kh = b > 0 && t == 0;
    return Stack(alignment: Alignment.center, children: [
      Positioned(
        left: 4,
        top: 2,
        child: Text(b == 0 ? '—' : '$b', style: const TextStyle(color: _ink, fontSize: 10.5, fontWeight: FontWeight.w700, fontFamily: 'NotoSans', fontFamilyFallback: ['Roboto'])),
      ),
      Text('$x',
          style: st(x).copyWith(
            decoration: kh ? TextDecoration.lineThrough : (b == t ? TextDecoration.underline : null),
            decorationColor: kh ? _red : _ink,
            decorationThickness: kh ? 2 : 1,
          )),
    ]);
  }
}

class _Squares extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x2E4F7BD9)
      ..strokeWidth = .6;
    for (var x = 0.0; x < size.width; x += 17) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += 17) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_Squares o) => false;
}

/// The last trick as it lay: who played what in which order, and who took it.
Future<void> showLastTrick(BuildContext context, Trick t, String Function(int) name, {bool c4 = false}) => _sheet<void>(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('ბოლო ხელი', style: TextStyle(color: light, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TrickRow(t: t, name: name, c4: c4, w: 62),
        ]),
      ),
    );

/// Four cards of a trick in the order played, each with who played it and the one that took it in gold.
class TrickRow extends StatelessWidget {
  const TrickRow({super.key, required this.t, required this.name, this.c4 = false, this.w = 44});
  final Trick t;
  final String Function(int) name;
  final bool c4;
  final double w;
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final e in t.t)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: w * .1),
            child: Column(children: [
              CardFace(e.card, w: w, glow: e.p == t.w, c4: c4),
              const SizedBox(height: 4),
              SizedBox(
                width: w + 14,
                child: Text(name(e.p).split(' ').first,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: e.p == t.w ? goldTable : lightMuted, fontSize: 12, fontWeight: e.p == t.w ? FontWeight.w800 : FontWeight.w600)),
              ),
              if (e.card.joker)
                Text(jokerCall(e) + (e.js != null ? ' ${suitName[e.js]}' : ''), style: const TextStyle(color: lightMuted, fontSize: 10.5)),
            ]),
          ),
      ]);
}

/// The hand just played, trick by trick.
Future<void> showHandReview(BuildContext context, JokerGame g, String Function(int) name) => _sheet<void>(
      context,
      DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        maxChildSize: .95,
        builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), children: [
          const Text('ხელის მიმოხილვა', textAlign: TextAlign.center, style: TextStyle(color: light, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            [for (var p = 0; p < 4; p++) '${name(p).split(' ').first}: ${g.hist.isEmpty ? '' : _said(jLast(g.hist).hand, p)}'].join(' · '),
            textAlign: TextAlign.center,
            style: const TextStyle(color: lightMuted, fontSize: 12.5),
          ),
          for (var i = 0; i < g.tricks.length; i++) ...[
            const SizedBox(height: 14),
            Text('${i + 1}', textAlign: TextAlign.center, style: const TextStyle(color: lightMuted, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            TrickRow(t: g.tricks[i], name: name),
          ],
        ]),
      ),
      tall: true,
    );

String _said(HandRow? h, int p) => h == null ? '' : '${h.b[p] == 0 ? 'პასი' : h.b[p]}, წაიღო ${h.t[p]}';

/// a fixed font for numbers on the table (the Georgian font has no digits of its own on every phone)
const numFont = TextStyle(fontFamily: 'NotoSans', fontFamilyFallback: [fontBody, 'Roboto']);
const tableText = TextStyle(fontFamily: fontBody, fontFamilyFallback: fontFallback, color: light);
