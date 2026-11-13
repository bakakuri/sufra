// Greeting cards (namedays.js): six designs for an angel's day, a birthday or just "გილოცავ", with a name, a few
// words and who sent it. Sent as a chat message (media.card), drawn in the chat as on the site.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../data/stores.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const cardKinds = [('n', 'ანგელოზის დღე'), ('b', 'დაბადების დღე'), ('g', 'გილოცავ')];

/// id, kind, title, ornament, background (from, to, angle), ink, ornament colour
const _designs = [
  ('nd1', 'n', 'გილოცავ ანგელოზის დღეს!', 'cross', Color(0xFFFBF1D9), Color(0xFFEBCB86), 165.0, Color(0xFF47290A), Color(0xFFA6741A)),
  ('nd2', 'n', 'ანგელოზი გფარავდეს!', 'stars', Color(0xFF18264F), Color(0xFF3A2A6E), 170.0, Color(0xFFFFF4D6), Color(0xFFF3D27A)),
  ('bd1', 'b', 'გილოცავ დაბადების დღეს!', 'confetti', Color(0xFF4F46E5), Color(0xFF2E2A8F), 160.0, Color(0xFFFFF0F4), Color(0xFFFFF0F4)),
  ('bd2', 'b', 'ბედნიერ დაბადების დღეს!', 'balloons', Color(0xFFFF9F5A), Color(0xFFE8466E), 170.0, Color(0xFFFFFFFF), Color(0xFFFFFFFF)),
  ('gm1', 'g', 'გაგიმარჯოს!', 'vine', Color(0xFFE7F2DA), Color(0xFFB9D79A), 165.0, Color(0xFF1F3B17), Color(0xFF3F6B2A)),
  ('gm2', 'g', 'მადლობა, რომ ხარ!', 'mtn', Color(0xFFCFE3F2), Color(0xFFF7E6D1), 180.0, Color(0xFF20324A), Color(0xFF41608A)),
];

const cardTexts = {
  'n': 'ბედნიერი და მშვიდი წელი გქონდეს. შენი ანგელოზი ყოველთვის გვერდით გედგას.',
  'b': 'ჯანმრთელობას, სიხარულს და ბევრ კარგ დღეს გისურვებ. ყველა ოცნება აგიხდეს!',
  'g': 'ჭიქა შენთვის! ასეთივე კარგი ადამიანი იყავი.',
};

/// A card: the design's colours and ornament, its title, to whom, the words, from whom ([small]: only the title).
class GreetingCard extends StatelessWidget {
  const GreetingCard({super.key, required this.card, this.width = 240, this.small = false});
  final Map card;
  final double width;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final d = _designs.firstWhere((x) => x.$1 == '${card['d']}', orElse: () => _designs.first);
    final rad = (d.$7 - 90) * math.pi / 180;
    final to = '${card['to'] ?? ''}'.trim(), text = '${card['text'] ?? ''}'.trim(), from = '${card['from'] ?? ''}'.trim();
    return Container(
      width: width,
      height: width * 5 / 4,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(small ? 12 : 18),
        gradient: LinearGradient(begin: Alignment(-math.cos(rad), -math.sin(rad)), end: Alignment(math.cos(rad), math.sin(rad)), colors: [d.$5, d.$6]),
        boxShadow: small ? null : const [BoxShadow(color: Color(0x24000000), blurRadius: 22, offset: Offset(0, 6))],
      ),
      child: Stack(children: [
        Positioned(
          top: width * 1.25 * .07,
          left: width * .06,
          width: width * .88,
          height: width * 1.25 * .4,
          child: CustomPaint(painter: _Ornament(d.$4, d.$9)),
        ),
        Positioned.fill(
          child: Container(
            margin: EdgeInsets.all(small ? 4 : 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(small ? 8 : 12), border: Border.all(color: d.$8.withValues(alpha: .28))),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: small ? 6 : 16, vertical: small ? 6 : 18),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(d.$3, textAlign: TextAlign.center, style: TextStyle(color: d.$8, fontSize: small ? 9.5 : 21, fontWeight: FontWeight.w800, height: 1.15)),
              if (!small) ...[
                if (to.isNotEmpty) ...[const SizedBox(height: 6), Text(to, style: TextStyle(color: d.$8.withValues(alpha: .9), fontSize: 17, fontWeight: FontWeight.w700))],
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(text, textAlign: TextAlign.center, style: TextStyle(color: d.$8.withValues(alpha: .95), fontSize: 12.5, height: 1.45)),
                ],
                if (from.isNotEmpty) ...[const SizedBox(height: 6), Text('— $from', style: TextStyle(color: d.$8.withValues(alpha: .75), fontSize: 12, fontWeight: FontWeight.w700))],
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

/// the ornaments of the site's cards, drawn in their 100×56 box
class _Ornament extends CustomPainter {
  _Ornament(this.kind, this.color);
  final String kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 56);
    final fill = Paint()..color = color;
    Paint a(double o, [Color? c]) => Paint()..color = (c ?? color).withValues(alpha: o);
    switch (kind) {
      case 'cross':
        canvas.drawPath(svgPath('M50 6c4 6 4 10 0 14-4-4-4-8 0-14zM50 54c4-6 4-10 0-14-4 4-4 8 0 14zM26 30c6-4 10-4 14 0-4 4-8 4-14 0zM74 30c-6 4-10 4-14 0 4-4 8-4 14 0z'), a(.9));
        canvas.drawCircle(const Offset(50, 30), 5, a(.9));
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: .45);
        canvas.drawCircle(const Offset(50, 30), 22, ring);
        for (var i = 0; i < 28; i++) {
          final t0 = i / 28 * 2 * math.pi;
          canvas.drawArc(Rect.fromCircle(center: const Offset(50, 30), radius: 27), t0, .07, false, ring);
        }
      case 'stars':
        for (final (x, y, r) in const [(14.0, 14.0, 2.0), (30.0, 8.0, 1.4), (78.0, 12.0, 2.2), (88.0, 30.0, 1.2), (64.0, 6.0, 1.0), (8.0, 40.0, 1.3), (92.0, 52.0, 1.6), (40.0, 18.0, 1.0)]) {
          canvas.drawCircle(Offset(x, y), r, fill);
        }
        canvas.drawPath(svgPath('M50 10l3 8 8 .6-6 5.4 2 8-7-4.4-7 4.4 2-8-6-5.4 8-.6z'), a(.95));
      case 'confetti':
        const cs = [Color(0xFFFFD166), Color(0xFFEF476F), Color(0xFF06D6A0), Color(0xFFFFFFFF)];
        for (var i = 0; i < 22; i++) {
          final x = (i * 37) % 96 + 0.0, y = (i * 23) % 46 + 0.0;
          canvas.save();
          canvas.translate(x + 1.5, y + 3.5);
          canvas.rotate(i * 41 * math.pi / 180);
          canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-1.5, -3.5, 3, 7), const Radius.circular(1)), Paint()..color = cs[i % 4].withValues(alpha: .9));
          canvas.restore();
        }
      case 'balloons':
        for (final (x, y, c) in const [(22.0, 24.0, Color(0xFFFFD166)), (40.0, 16.0, Color(0xFFFF8FA3)), (60.0, 22.0, Color(0xFFFFFFFF)), (78.0, 14.0, Color(0xFF9BF6FF))]) {
          canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 16, height: 20), Paint()..color = c);
          canvas.drawPath(
            Path()
              ..moveTo(x, y + 10)
              ..quadraticBezierTo(x - 3, y + 20, x + 2, y + 32),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = c.withValues(alpha: .8),
          );
        }
      case 'vine':
        canvas.drawPath(
          svgPath('M4 40c20-18 40-18 60-8s26 4 32-6'),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
        for (final (x, y) in const [(18, 30), (36, 24), (56, 28), (76, 34)]) {
          canvas.drawPath(svgPath('M$x ${y}c-6-2-8-8-4-12 2 4 6 4 8 0 2 6-1 10-4 12z'), a(.8));
        }
        for (final (x, y) in const [(44.0, 36.0), (47.0, 40.0), (41.0, 40.0), (44.0, 44.0), (64.0, 40.0), (67.0, 44.0), (61.0, 44.0)]) {
          canvas.drawCircle(Offset(x, y), 2.6, a(.95));
        }
      case 'mtn':
        canvas.drawPath(svgPath('M0 56l18-22 10 10 16-26 18 24 10-12 28 26z'), a(.5));
        canvas.drawPath(svgPath('M0 56l26-16 14 8 22-18 16 14 22-6v18z'), a(.85));
        canvas.drawCircle(const Offset(78, 14), 6, a(.9));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Ornament old) => old.kind != kind || old.color != color;
}

/// Choosing and sending a card to someone ([kind]: 'n' angel's day, 'b' birthday, 'g' anything); back closes it.
Future<void> openCardPicker(BuildContext context, {required String uid, required String toName, String kind = 'n'}) =>
    openPage(context, CardPicker(uid: uid, toName: toName, kind: kind), full: true);

class CardPicker extends StatefulWidget {
  const CardPicker({super.key, required this.uid, required this.toName, this.kind = 'n'});
  final String uid, toName;
  final String kind;
  @override
  State<CardPicker> createState() => _CardPickerState();
}

class _CardPickerState extends State<CardPicker> {
  late String k = widget.kind, d = _designs.firstWhere((x) => x.$2 == widget.kind).$1;
  late final to = TextEditingController(text: widget.toName.split(' ').first);
  late final text = TextEditingController(text: cardTexts[widget.kind]);
  bool busy = false;

  @override
  void dispose() {
    to.dispose();
    text.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _card => {'d': d, 'to': to.text.trim(), 'text': text.text.trim(), 'from': context.me.name.split(' ').first};

  Future<void> _send() async {
    if (busy) return;
    setState(() => busy = true);
    final app = context.app;
    try {
      final conv = await app.api.sendCard(widget.uid, _card);
      if (!mounted) return;
      // the card closes and the conversation opens in its place (back from it does not bring the card back)
      final nav = Navigator.of(context), scope = AppScope.of(context);
      toast(context, 'ბარათი გაიგზავნა');
      nav.pushReplacement(MaterialPageRoute(builder: (_) => AppScope(app: scope.app, me: scope.me, child: ChatScreen(convId: conv))));
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      appBar: peeraBar(context, title: 'მისალოცი ბარათი'),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        Row(children: [
          for (final (x, l) in cardKinds) ...[
            Expanded(
              child: Material(
                color: x == k ? c.ink : c.sunk,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: ValueKey('ck-$x'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() {
                    final was = cardTexts[k];
                    k = x;
                    d = _designs.firstWhere((y) => y.$2 == x).$1;
                    if (text.text.trim() == was) text.text = cardTexts[x]!;
                  }),
                  child: SizedBox(
                    height: 40,
                    child: Center(child: FittedBox(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(l, style: TextStyle(color: x == k ? c.bg : c.ink, fontWeight: FontWeight.w700))))),
                  ),
                ),
              ),
            ),
            if (x != cardKinds.last.$1) const SizedBox(width: 6),
          ],
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final x in _designs.where((y) => y.$2 == k))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                key: ValueKey('cd-${x.$1}'),
                onTap: () => setState(() => d = x.$1),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: x.$1 == d ? c.accent : Colors.transparent, width: 2.5)),
                  child: GreetingCard(card: {'d': x.$1}, width: 88, small: true),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        Center(child: ListenableBuilder(listenable: Listenable.merge([to, text]), builder: (context, _) => GreetingCard(card: _card))),
        const SizedBox(height: 16),
        TextField(controller: to, maxLength: 40, decoration: const InputDecoration(labelText: 'ვის', counterText: '')),
        const SizedBox(height: 10),
        TextField(controller: text, maxLength: 300, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'ტექსტი')),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const ValueKey('card-send'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: busy ? null : _send,
          icon: PIcon('send', size: 18, color: c.onAccent),
          label: const Text('გაგზავნა'),
        ),
      ]),
    );
  }
}
