// The Joker tab: a game against the computer (quick, full or nines), the game in progress to continue,
// the bots' level, the hint and the four-colour deck, and the rules.
import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'cards.dart';
import 'engine.dart';
import 'session.dart';
import 'table_screen.dart';

const jokerRules =
    'ფერი უნდა აჰყვე. თუ ფერი არ გაქვს, კოზირი უნდა დადო. ჯოკერი ნებისმიერ დროს შეგიძლია დადო: „მაღალი“ წაიღებს ხელს, „დაბალი“ არ წაიღებს. '
    'მოგვიანებით დადებული მაღალი ჯოკერი უფრო ძლიერია. ჯოკერით დაწყებისას ითხოვ ფერს: „მაღალი“ ნიშნავს, რომ ყველამ ამ ფრის უმაღლესი კარტი უნდა დადოს და ხელი შენია, '
    'თუმცა თუ ფერი კოზირი არ არის და ვინმემ კოზირი დადო, უმაღლესი კოზირი წაიღებს. „წაიღოს“ ნიშნავს, რომ ამ ფრის უმაღლესი კარტი წაიღებს.\n\n'
    'ქულები: ზუსტად ნათქვამი 50 თითო ხელზე და 50 ბონუსი, ყველა ხელის წაღება 100 თითოზე, პასი და ნული 50. მეტის ან ნაკლების წაღებისას 10 თითოზე. '
    'თუ თქვი და ვერცერთი ვერ წაიღე, ხიშტი: −200, ცხრიან სექციებში −500. ვინც სექციის ყველა ხელში ზუსტად ნათქვამს წაიღებს, პრემიას იღებს: '
    'მისი საუკეთესო ხელი ორმაგდება, დანარჩენებს კი საუკეთესო ხელი ეშლებათ.\n\n'
    'დამრიგებელი ბოლოს ამბობს და ისეთ რიცხვს ვერ იტყვის, რომ ნათქვამების ჯამი კარტების რაოდენობას გაუტოლდეს. ცხრაკარტიან ხელში კოზირს პირველი მთქმელი ირჩევს, პირველი სამი კარტის ნახვით.';

const _modes = [
  ('quick', 'სწრაფი', '8 ხელი · 1-დან 8 კარტამდე'),
  ('full', 'სრული', '24 ხელი · ოთხი სექცია, პრემიით'),
  ('nines', 'ცხრიანები', '16 ხელი · ყოველთვის 9 კარტი, ხიშტი −500'),
];

class JokerTab extends StatefulWidget {
  const JokerTab({super.key});
  @override
  State<JokerTab> createState() => _JokerTabState();
}

class _JokerTabState extends State<JokerTab> {
  JokerSession? _s;

  JokerSession get s => _s!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_s != null) return;
    final api = context.app.api;
    _s = JokerSession(onOver: (won) async => won ? (await api.gameResult('joker', true)).reward : 0)..load();
  }

  @override
  void dispose() {
    _s?.dispose();
    super.dispose();
  }

  Future<void> _open() => openPage(context, JokerTableScreen(session: s), full: true);

  Future<void> _new(String len) async {
    if (s.playing &&
        !await confirm(context, title: 'ახალი თამაში დავიწყოთ?', text: 'დაწყებული თამაში დასრულდება და აღარ გაგრძელდება.', yes: 'დაწყება')) {
      return;
    }
    s.start(len);
    if (mounted) await _open();
  }

  Future<void> _quit() async {
    if (s.playing && !await confirm(context, title: 'თამაში დავასრულოთ?', text: 'ეს თამაში აღარ გაგრძელდება.', yes: 'დასრულება', danger: true)) return;
    s.quit();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      appBar: peeraBar(context, title: 'ჯოკერი'),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 32), children: [
          _hero(c),
          if (s.g != null) ...[const SizedBox(height: 14), _current(c)],
          const SizedBox(height: 22),
          Text(s.g == null ? 'ითამაშე ბოტებთან' : 'ახალი თამაში', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final m in _modes) ...[_mode(c, m), const SizedBox(height: 10)],
          const SizedBox(height: 12),
          _level(c),
          const SizedBox(height: 14),
          PCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              SwitchListTile(
                key: const ValueKey('joker-hint'),
                value: s.hint,
                onChanged: s.setHint,
                title: const Text('რჩევა', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('რამდენის თქმა და რომელი კოზირი ჯობია, მონიშნული იქნება', style: TextStyle(color: c.muted, fontSize: 13)),
              ),
              Divider(height: 1, color: c.line, indent: 16, endIndent: 16),
              SwitchListTile(
                key: const ValueKey('joker-c4'),
                value: s.c4,
                onChanged: s.setC4,
                title: const Text('ოთხფეროვანი დასტა', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('ჯვარი მწვანეა, აგური ლურჯი: ფერები ერთმანეთში არ აგერევა', style: TextStyle(color: c.muted, fontSize: 13)),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          PCard(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const ValueKey('joker-rules'),
                shape: const Border(),
                leading: PIcon('cards', size: 22, color: c.accent),
                title: const Text('წესები', style: TextStyle(fontWeight: FontWeight.w700)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [Text(jokerRules, style: TextStyle(color: c.muted, fontSize: 14, height: 1.5))],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _hero(PeeraColors c) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/joker/table.jpg', fit: BoxFit.cover, alignment: const Alignment(0, -.1)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [.4, 1],
                  colors: [Color(0x00000000), Color(0xE6081020)],
                ),
              ),
            ),
            const Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ჯოკერი ოთხ კაცზე', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                SizedBox(height: 3),
                Text('36 კარტი, ორი ჯოკერი. ყოველ ხელში თქვი, რამდენ ხელს წაიღებ: ზუსტად იმდენი თუ წაიღე, ქულებს მიიღებ.',
                    style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 13, height: 1.35)),
              ]),
            ),
          ]),
        ),
      );

  /// the game in progress (or just finished): who is at the table, which hand, my points
  Widget _current(PeeraColors c) {
    final g = s.g!, over = g.phase == 'over';
    Widget face(String id) => Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.line),
          child: ClipOval(child: Image.asset(castOf(id).asset, width: 30, height: 30, fit: BoxFit.cover)),
        );
    return Container(
      key: const ValueKey('joker-current'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.accent.withValues(alpha: .5), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (final id in s.seats) face(id),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(over ? 'თამაში დასრულდა' : 'დაწყებული თამაში', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              Text(
                over
                    ? '${jLenName[g.len]} · ${g.iWon ? 'მოიგე' : '${g.order.indexOf(0) + 1} ადგილი'} · ${g.score[0]} ქულა'
                    : '${jLenName[g.len]} · ხელი ${g.h + 1}/${g.seq.length} · ${g.score[0]} ქულა',
                style: TextStyle(color: c.muted, fontSize: 13.5),
              ),
            ]),
          ),
          if (!over && g.trump != null) TrumpTile(trump: g.trump, size: 30, c4: s.c4),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('joker-quit'),
              onPressed: _quit,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              child: Text(over ? 'დახურვა' : 'დასრულება'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton(
              key: const ValueKey('joker-continue'),
              onPressed: _open,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              child: Text(over ? 'შედეგის ნახვა' : 'გაგრძელება'),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _mode(PeeraColors c, (String, String, String) m) {
    final first = m.$1 == 'quick';
    return Material(
      color: first ? c.accent : c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: first ? BorderSide.none : BorderSide(color: c.line)),
      child: InkWell(
        key: ValueKey('joker-new-${m.$1}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _new(m.$1),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: first ? Colors.white.withValues(alpha: .18) : c.accentSoft, borderRadius: BorderRadius.circular(12)),
              child: PIcon('cards', size: 24, color: first ? c.onAccent : c.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.$2, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: first ? c.onAccent : c.ink)),
                const SizedBox(height: 1),
                Text(m.$3, style: TextStyle(fontSize: 13, color: first ? c.onAccent.withValues(alpha: .85) : c.muted)),
              ]),
            ),
            PIcon('chev', size: 20, color: first ? c.onAccent : c.muted),
          ]),
        ),
      ),
    );
  }

  Widget _level(PeeraColors c) {
    final lv = botLevels[s.level - 1];
    return PCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ბოტების დონე', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 1; i <= 5; i++)
            ChoiceChip(
              key: ValueKey('joker-level-$i'),
              label: Text(botLevels[i - 1].n),
              selected: s.level == i,
              onSelected: (_) => s.setLevel(i),
              showCheckmark: false,
              labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: s.level == i ? c.onAccent : c.ink),
              selectedColor: c.accent,
              backgroundColor: c.sunk,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
        ]),
        const SizedBox(height: 8),
        Text(lv.d, style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.4)),
      ]),
    );
  }
}
