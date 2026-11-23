// The match room (sport.js): the coming matches, the finished ones and my predictions; one match with a free
// prediction (1, X, 2) and how everyone predicted, a live chat during the game; for the moderators a new match, the
// result and a cancel.
import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../feed/post_actions.dart';
import '../feed/post_card.dart';
import '../profile/profile.dart';
import '../ui/bits.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'rides.dart' show atText;

const pickNames = {'1': 'მასპინძელი', 'X': 'ფრე', '2': 'სტუმარი'};

/// a match that came by itself carries the source's state and score (live_state, live_home/away); staff settle it
bool fixtureLive(Map<String, dynamic> f) =>
    f['status'] == 'upcoming' && !asTime(f['starts_at']).isAfter(DateTime.now()) && !const ['finished', 'postponed', 'cancelled', 'suspended'].contains(f['live_state']);

/// over by the source, its result not yet confirmed
bool fixtureEnded(Map<String, dynamic> f) => f['status'] == 'upcoming' && f['live_state'] == 'finished';

String fixtureScore(Map<String, dynamic> f) => f['status'] == 'finished'
    ? '${f['home_score']}:${f['away_score']}'
    : f['live_home'] != null && f['live_away'] != null
        ? '${f['live_home']}:${f['live_away']}'
        : 'vs';

const _wdays = ['კვირა', 'ორშაბათი', 'სამშაბათი', 'ოთხშაბათი', 'ხუთშაბათი', 'პარასკევი', 'შაბათი'];

/// the day a match is on, over its group
String fixtureDay(DateTime d, [DateTime? now]) {
  final t = now ?? DateTime.now(), dd = DateTime(d.year, d.month, d.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (dd == 0) return 'დღეს';
  if (dd == 1) return 'ხვალ';
  if (dd == -1) return 'გუშინ';
  return '${_wdays[d.weekday % 7]}, ${d.day} ${months[d.month - 1]}';
}

Widget fixtureBadge(BuildContext context, Map<String, dynamic> f, {bool timeOnly = false}) {
  final c = context.pc;
  if (f['status'] == 'finished' || fixtureEnded(f)) return const PTag('დასრულდა');
  if (f['status'] == 'cancelled' || f['live_state'] == 'cancelled') return const PTag('გაუქმდა', kind: 'warn');
  if (f['live_state'] == 'postponed') return const PTag('გადაიდო', kind: 'warn');
  if (f['live_state'] == 'suspended') return const PTag('შეჩერდა', kind: 'warn');
  if (fixtureLive(f)) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: c.nope, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(f['live_state'] == 'paused' ? 'შესვენება' : 'ცოცხლად', style: TextStyle(color: c.nope, fontWeight: FontWeight.w800, fontSize: 12.5)),
    ]);
  }
  final at = asTime(f['starts_at']);
  return PTag(timeOnly ? hhmm(at) : atText(at), kind: 'ad');
}

/// a team's round mark (sport.js fxCrest): its first letter on a colour of its own, the same name the same colour
class TeamCrest extends StatelessWidget {
  const TeamCrest(this.name, {super.key, this.size = 40, this.draw = false});
  final String name;
  final double size;

  /// the draw's mark: "=" on grey
  final bool draw;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    var h = 0;
    for (final r in name.runes) {
      h = (h * 31 + r) % 360;
    }
    final t = name.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: draw ? c.sunk : null,
        gradient: draw
            ? null
            : RadialGradient(center: const Alignment(-.4, -.6), radius: 1.2, colors: [
                HSLColor.fromAHSL(1, h.toDouble(), .72, .62).toColor(),
                HSLColor.fromAHSL(1, (h + 30) % 360.0, .62, .36).toColor(),
              ]),
        boxShadow: draw ? null : [BoxShadow(color: HSLColor.fromAHSL(.45, h.toDouble(), .6, .3).toColor(), blurRadius: 10, spreadRadius: -3, offset: const Offset(0, 4))],
      ),
      child: Text(draw ? '=' : (t.isEmpty ? '?' : t.characters.first), style: TextStyle(color: draw ? c.muted : Colors.white, fontWeight: FontWeight.w900, fontSize: size * .42)),
    );
  }
}

class _Teams extends StatelessWidget {
  const _Teams(this.f, {this.big = false});
  final Map<String, dynamic> f;
  final bool big;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, st = TextStyle(fontWeight: FontWeight.w900, fontSize: big ? 18 : 15, height: 1.2);
    Widget side(String n) => Expanded(
          child: Column(children: [
            TeamCrest(n, size: big ? 56 : 40),
            SizedBox(height: big ? 8 : 6),
            Text(n, style: st, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        );
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      side('${f['home']}'),
      Padding(
        padding: EdgeInsets.fromLTRB(10, big ? 12 : 6, 10, 0),
        child: Text(
          fixtureScore(f),
          key: big ? const ValueKey('fx-score') : null,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: big ? 30 : 22, color: fixtureLive(f) ? c.nope : fixtureScore(f) != 'vs' ? c.ink : c.accent),
        ),
      ),
      side('${f['away']}'),
    ]);
  }
}

/// how people predicted (sport.js fxSplit): three green bars with their shares, the leading one fullest
class FixtureSplit extends StatelessWidget {
  const FixtureSplit({super.key, required this.pool});
  final Map<String, dynamic>? pool;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, n = asInt(pool?['n']);
    int pc(String k) => n == 0 ? 0 : (asInt(pool?['c$k']) / n * 100).round();
    final top = n == 0 ? -1 : [pc('1'), pc('X'), pc('2')].reduce((a, b) => a > b ? a : b);
    return Row(children: [
      for (final (i, k) in ['1', 'X', '2'].indexed) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Text(k == 'X' ? 'ფრე' : k, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              const Spacer(),
              Text('${pc(k)}%',
                  key: ValueKey('fxsp-$k'),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: pc(k) == top ? c.vine : c.muted, fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
            const SizedBox(height: 5),
            _Bar(value: pc(k) / 100, strong: pc(k) == top, height: 7),
          ]),
        ),
      ],
    ]);
  }
}

/// a green bar that grows to its share
class _Bar extends StatelessWidget {
  const _Bar({required this.value, this.strong = true, this.height = 6});
  final double value, height;
  final bool strong;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: height,
        child: Stack(children: [
          Positioned.fill(child: ColoredBox(color: c.sunk)),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0, 1)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(colors: strong ? [c.vine, Color.lerp(c.vine, const Color(0xFF7CF5C9), .4)!] : [c.vine.withValues(alpha: .5), c.vine.withValues(alpha: .5)]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// The matches.
class SportScreen extends StatefulWidget {
  const SportScreen({super.key});
  @override
  State<SportScreen> createState() => _SportScreenState();
}

class _SportScreenState extends State<SportScreen> {
  String tab = 'up';
  (List<Map<String, dynamic>>, Map<int, Map<String, dynamic>>)? d;
  Object? error;
  int _gen = 0;
  bool _started = false;

  /// the league shown ('' for all); for staff the finished ones to confirm and how the automatic matches are doing
  String league = '';
  List<Map<String, dynamic>> pending = const [];
  Map<String, dynamic>? sync;

  /// how people predicted each match in the list
  Map<int, Map<String, dynamic>> pools = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final g = ++_gen;
    if (d != null) setState(() => d = null);
    try {
      final api = context.app.api, staff = tab == 'up' && isStaff(context);
      final r = await api.fixtures(tab);
      final p = staff ? await api.pendingFixtures().catchError((_) => <Map<String, dynamic>>[]) : const <Map<String, dynamic>>[];
      final st = staff ? await api.fixtureSyncState() : null;
      final pl = await api.fixturePools([for (final f in [...r.$1, ...p]) asInt(f['id'])]);
      if (mounted && g == _gen) {
        setState(() {
          d = r;
          pending = p;
          sync = st;
          pools = pl;
          error = null;
          if (league.isNotEmpty && !r.$1.any((f) => _lg(f) == league)) league = '';
        });
      }
    } catch (e) {
      if (mounted && g == _gen) {
        setState(() {
          d = (const <Map<String, dynamic>>[], const <int, Map<String, dynamic>>{});
          error = e;
        });
      }
    }
  }

  static String _lg(Map<String, dynamic> f) => '${f['league'] ?? ''}'.isEmpty ? 'მატჩი' : '${f['league']}';

  /// a finished one's score confirmed as the source gave it: the winners are paid
  Future<void> _confirm(Map<String, dynamic> f) async {
    final a = asInt(f['live_home']), b = asInt(f['live_away']);
    if (!await confirm(context, title: 'შედეგის დადასტურება', text: '${f['home']} $a:$b ${f['away']}. მოგებული მონეტები ავტომატურად დაირიცხება.', yes: 'დადასტურება') || !mounted) return;
    if (await attempt(context, () => context.app.api.settleFixture(asInt(f['id']), a, b)) && mounted) {
      toast(context, 'შედეგი შენახულია');
      _load();
    }
  }

  Future<void> _open(Map<String, dynamic> f) async {
    await openPage(context, FixtureScreen(id: asInt(f['id'])), full: true);
    _load();
  }

  Widget _card(BuildContext context, Map<String, dynamic> f, Map<int, Map<String, dynamic>> mine, {bool timeOnly = false}) {
    final c = context.pc, dark = Theme.of(context).brightness == Brightness.dark, id = asInt(f['id']);
    final pool = pools[id], n = asInt(pool?['n']), m = mine[id];
    final open = f['status'] == 'upcoming' && asTime(f['starts_at']).isAfter(DateTime.now());
    final foot = [
      n > 0 ? '$n პროგნოზი' : (open ? 'პროგნოზი ჯერ არავის გაუკეთებია · იყავი პირველი' : 'პროგნოზი არ ყოფილა'),
      if (m != null)
        'შენი: ${pickNames[m['pick']] ?? m['pick']}${m['payout'] != null ? ' · ${asInt(m['payout']) > asInt(m['stake']) ? 'მოგება +${m['payout']}' : asInt(m['payout']) == asInt(m['stake']) && asInt(m['stake']) > 0 ? 'დაბრუნდა' : 'წაგება'}' : ''}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Pressable(
        onTap: () => _open(f),
        child: Container(
          key: ValueKey('fx-$id'),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.line.withValues(alpha: .6)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: dark ? .4 : .05), blurRadius: 2, offset: const Offset(0, 1)),
              BoxShadow(color: Colors.black.withValues(alpha: dark ? .45 : .10), blurRadius: 20, spreadRadius: -6, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(_lg(f), style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w700))),
              fixtureBadge(context, f, timeOnly: timeOnly),
            ]),
            const SizedBox(height: 10),
            _Teams(f),
            const SizedBox(height: 12),
            FixtureSplit(key: ValueKey('fxsplit-$id'), pool: pool),
            const SizedBox(height: 8),
            Text(foot, style: TextStyle(color: m != null ? c.accent : c.muted, fontSize: 12.5, fontWeight: m != null ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }

  List<Widget> _rows(BuildContext context, (List<Map<String, dynamic>>, Map<int, Map<String, dynamic>>) x) {
    final c = context.pc, rows = [for (final f in x.$1) if (league.isEmpty || _lg(f) == league) f], leagues = {for (final f in x.$1) _lg(f)};
    final out = <Widget>[];
    if (pending.isNotEmpty) {
      out
        ..add(SecHead('შედეგი დასადასტურებელია · ${pending.length}'))
        ..add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('მატჩი დასრულდა, ანგარიში თავისით ჩაიწერა. დადასტურების შემდეგ მოგებული მონეტები დაირიცხება.', style: TextStyle(color: c.muted, fontSize: 13)),
        ));
      for (final f in pending) {
        out.add(Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: Color.alphaBlend(c.gold.withValues(alpha: .12), c.surface),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color.alphaBlend(c.gold.withValues(alpha: .35), c.line)),
          ),
          child: Row(children: [
            Expanded(
              child: InkWell(
                onTap: () => _open(f),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_lg(f), style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                  Text('${f['home']}  ${f['live_home']}:${f['live_away']}  ${f['away']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
            FilledButton(key: ValueKey('fxok-${f['id']}'), style: FilledButton.styleFrom(minimumSize: const Size(0, 38)), onPressed: () => _confirm(f), child: const Text('დადასტურება')),
          ]),
        ));
      }
      out.add(const SizedBox(height: 8));
    }
    if (leagues.length > 1) {
      out.add(SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 4, 12, 6), children: [
          for (final l in ['', ...leagues])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                key: ValueKey('fxlg-${l.isEmpty ? 'all' : l}'),
                label: Text(l.isEmpty ? 'ყველა' : l),
                selected: league == l,
                showCheckmark: false,
                onSelected: (_) => setState(() => league = l),
              ),
            ),
        ]),
      ));
    }
    if (rows.isEmpty) {
      out.add(Padding(padding: const EdgeInsets.all(24), child: Text('ამ ლიგაში მატჩი ჯერ არ არის', textAlign: TextAlign.center, style: TextStyle(color: c.muted))));
    } else if (tab == 'up') {
      String? day;
      for (final f in rows) {
        final dd = fixtureLive(f) ? 'ახლა მიმდინარე' : fixtureDay(asTime(f['starts_at']));
        if (dd != day) {
          day = dd;
          out.add(Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 16, 4),
            child: Text(dd, key: ValueKey('fxday-$dd'), style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 13)),
          ));
        }
        out.add(_card(context, f, x.$2, timeOnly: !fixtureLive(f)));
      }
    } else {
      for (final f in rows) {
        out.add(_card(context, f, x.$2));
      }
    }
    if (sync case final st?) {
      final err = '${st['error'] ?? ''}';
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(
          st['on'] != true
              ? 'ავტომატური მატჩები ჯერ არ არის ჩართული'
              : err.isNotEmpty
                  ? 'ავტომატური მატჩები: შეცდომა — $err'
                  : 'ავტომატური მატჩები ჩართულია${st['took_at'] != null ? ' · განახლდა ${atText(asTime(st['took_at']))}' : ''}',
          key: const ValueKey('fx-sync'),
          style: TextStyle(color: err.isNotEmpty ? c.nope : c.muted, fontSize: 12),
        ),
      ));
    }
    return out;
  }

  Future<void> _new() async {
    final id = await newFixtureSheet(context);
    if (id != null && mounted) await openPage(context, FixtureScreen(id: id), full: true);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = d;
    return Scaffold(
      appBar: peeraBar(context, title: 'მატჩის ოთახი', actions: [
        if (isStaff(context))
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton.icon(
              key: const ValueKey('fx-new'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
              onPressed: _new,
              icon: PIcon('plus', size: 17, color: c.onAccent),
              label: const Text('მატჩი'),
            ),
          ),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: SegmentedButton<String>(
            key: const ValueKey('fx-tab'),
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: 'up', label: Text('მომავალი')), ButtonSegment(value: 'done', label: Text('დასრულებული')), ButtonSegment(value: 'mine', label: Text('ჩემი'))],
            selected: {tab},
            onSelectionChanged: (v) {
              setState(() => tab = v.first);
              _load();
            },
          ),
        ),
        Expanded(
          child: x == null
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Empty(icon: 'trophy', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
                  : x.$1.isEmpty && pending.isEmpty
                      ? Empty(
                          icon: 'trophy',
                          title: tab == 'mine' ? 'პროგნოზები ჯერ არ გაქვს' : 'მატჩები ჯერ არ არის',
                          text: tab == 'up' ? (isStaff(context) ? 'დაამატე მატჩი ზედა ღილაკით.' : 'მალე დაემატება. მატჩის დროს აქ ერთად ვგულშემატკივრობთ.') : null,
                          action: tab == 'mine' ? 'მატჩების ნახვა' : null,
                          onAction: tab == 'mine'
                              ? () {
                                  setState(() => tab = 'up');
                                  _load();
                                }
                              : null,
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: _rows(context, x)),
                        ),
        ),
      ]),
    );
  }
}

/// A new match (for the moderators): the tournament, the teams, the start. Its id.
Future<int?> newFixtureSheet(BuildContext context) async {
  final app = context.app, c = context.pc;
  final league = TextEditingController(), home = TextEditingController(), away = TextEditingController();
  var at = () {
    final d = DateTime.now().add(const Duration(days: 1));
    return DateTime(d.year, d.month, d.day, 21);
  }();
  final id = await showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: c.surface,
    builder: (s) => StatefulBuilder(
      builder: (s, set) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(s).bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('ახალი მატჩი', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              TextField(key: const ValueKey('fxn-league'), controller: league, maxLength: 60, decoration: const InputDecoration(labelText: 'ტურნირი', hintText: 'მაგ. ეროვნული ლიგა', counterText: '')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(key: const ValueKey('fxn-home'), controller: home, maxLength: 60, decoration: const InputDecoration(labelText: 'მასპინძელი', counterText: ''))),
                const SizedBox(width: 8),
                Expanded(child: TextField(key: const ValueKey('fxn-away'), controller: away, maxLength: 60, decoration: const InputDecoration(labelText: 'სტუმარი', counterText: ''))),
              ]),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('fxn-when'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () async {
                  final d = await showDatePicker(context: s, initialDate: at, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 730)));
                  if (d == null || !s.mounted) return;
                  final t = await showTimePicker(context: s, initialTime: TimeOfDay.fromDateTime(at));
                  set(() => at = DateTime(d.year, d.month, d.day, t?.hour ?? at.hour, t?.minute ?? at.minute));
                },
                icon: const PIcon('clock', size: 17),
                label: Text(fullDate(at)),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const ValueKey('fxn-ok'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () async {
                    final h = home.text.trim(), a = away.text.trim();
                    if (h.length < 2 || a.length < 2) {
                      toast(s, 'შეავსე გუნდები და დრო');
                      return;
                    }
                    try {
                      final id = await app.api.createFixture(league: league.text.trim(), home: h, away: a, startsAt: at);
                      if (s.mounted) Navigator.of(s).pop(id);
                    } catch (e) {
                      if (s.mounted) toast(s, errText(e));
                    }
                  },
                  child: const Text('დამატება'),
                ),
              ),
            ]),
          ),
        ),
      ),
    ),
  );
  return id;
}

/// One match: the teams, a free prediction and how everyone predicted, the result (moderators), the chat.
class FixtureScreen extends StatefulWidget {
  const FixtureScreen({super.key, required this.id});
  final int id;
  @override
  State<FixtureScreen> createState() => _FixtureScreenState();
}

class _FixtureScreenState extends State<FixtureScreen> {
  ({Map<String, dynamic> f, Map<String, dynamic>? my, Map<String, dynamic> pool})? d;
  bool loaded = false;
  Object? error;
  String? pick;
  bool busy = false;
  final msgs = <Map<String, dynamic>>[];
  final seen = <Object?>{};
  final say = TextEditingController(), hs = TextEditingController(), aws = TextEditingController();
  final scroll = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _live;
  bool _started = false;

  /// while the match is on its score is looked at every minute
  Timer? _tick;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
    _chat();
  }

  @override
  void dispose() {
    _live?.cancel();
    _tick?.cancel();
    say.dispose();
    hs.dispose();
    aws.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final x = await context.app.api.fixture(widget.id);
      if (!mounted) return;
      setState(() {
        d = x;
        loaded = true;
        error = null;
        // a finished one from the source: its score ready to be confirmed
        if (x != null && fixtureEnded(x.f) && hs.text.isEmpty && aws.text.isEmpty) {
          hs.text = '${x.f['live_home']}';
          aws.text = '${x.f['live_away']}';
        }
      });
      final f = x?.f;
      final soon = f != null && f['ext_id'] != null && f['status'] == 'upcoming' && asTime(f['starts_at']).difference(DateTime.now()) < const Duration(minutes: 15);
      if (f != null && (fixtureLive(f) || (soon && !fixtureEnded(f) && f['live_state'] != 'postponed'))) {
        _tick ??= Timer.periodic(const Duration(minutes: 1), (_) => _load());
      } else {
        _tick?.cancel();
        _tick = null;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loaded = true;
        });
      }
    }
  }

  Future<void> _add(Map<String, dynamic> m) async {
    if (!seen.add(m['id'])) return;
    final app = context.app;
    await app.people.ensure(['${m['user_id']}']);
    if (!mounted) return;
    // mine always, someone else's when I am already near the end: the chat follows to the newest
    final follow = m['user_id'] == app.api.myId || !scroll.hasClients || scroll.position.extentAfter < 320;
    setState(() => msgs.add(m));
    if (follow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
      });
    }
  }

  Future<void> _chat() async {
    final app = context.app;
    try {
      final rows = await app.api.fixtureChat(widget.id);
      await app.people.ensure([for (final m in rows) '${m['user_id']}']);
      if (!mounted) return;
      setState(() {
        for (final m in rows) {
          if (seen.add(m['id'])) msgs.add(m);
        }
      });
    } catch (_) {}
    _live = app.api.liveFixtureChat(widget.id).listen(_add);
  }

  Future<void> _send() async {
    final v = say.text.trim();
    if (v.isEmpty) return;
    say.clear();
    try {
      final m = await context.app.api.sayInFixture(widget.id, v);
      await _add(m);
    } catch (e) {
      if (!mounted) return;
      say.text = v;
      toast(context, errText(e));
    }
  }

  Future<void> _predict() async {
    final p = pick;
    if (p == null) return;
    setState(() => busy = true);
    try {
      await context.app.api.predict(widget.id, p);
      if (!mounted) return;
      toast(context, 'პროგნოზი მიღებულია. წარმატებები!');
      await _load();
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _settle(Map<String, dynamic> f) async {
    final a = int.tryParse(hs.text.trim()), b = int.tryParse(aws.text.trim());
    if (a == null || b == null || a < 0 || b < 0) {
      toast(context, 'ჩაწერე ანგარიში');
      return;
    }
    if (!await confirm(context, title: 'შედეგის დადასტურება', text: '${f['home']} $a:$b ${f['away']}. მოგებული მონეტები ავტომატურად დაირიცხება.', yes: 'დადასტურება') || !mounted) return;
    if (await attempt(context, () => context.app.api.settleFixture(widget.id, a, b)) && mounted) {
      toast(context, 'შედეგი შენახულია');
      _load();
    }
  }

  /// the teams' names set right (a match that came by itself: its teams keep them for their next matches)
  Future<void> _names(Map<String, dynamic> f) async {
    final c = context.pc, h = TextEditingController(text: '${f['home']}'), a = TextEditingController(text: '${f['away']}');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (s) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(s).bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('გუნდების სახელები', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(f['home_en'] != null ? 'ეს სახელი ამ გუნდის შემდეგ მატჩებსაც გადაჰყვება.' : 'მხოლოდ ამ მატჩისთვის.', style: TextStyle(color: c.muted, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(key: const ValueKey('fn-h'), controller: h, maxLength: 60, decoration: const InputDecoration(labelText: 'მასპინძელი', counterText: ''))),
                const SizedBox(width: 8),
                Expanded(child: TextField(key: const ValueKey('fn-a'), controller: a, maxLength: 60, decoration: const InputDecoration(labelText: 'სტუმარი', counterText: ''))),
              ]),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const ValueKey('fn-ok'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () {
                    if (h.text.trim().length < 2 || a.text.trim().length < 2) {
                      toast(s, 'შეავსე ორივე სახელი');
                      return;
                    }
                    Navigator.of(s).pop(true);
                  },
                  child: const Text('შენახვა'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    // (the fields still close with the sheet: their controllers are left to go by themselves)
    final hv = h.text.trim(), av = a.text.trim();
    if (ok != true || !mounted) return;
    if (await attempt(context, () => context.app.api.renameFixtureTeams(widget.id, hv, av)) && mounted) {
      toast(context, 'სახელები შეიცვალა');
      _load();
    }
  }

  Future<void> _cancel() async {
    if (!await confirm(context, title: 'მატჩის გაუქმება', text: 'მატჩი გაუქმდება. ძველი ფსონები, თუ იყო, დაბრუნდება.', yes: 'გაუქმება', danger: true) || !mounted) return;
    if (await attempt(context, () => context.app.api.cancelFixture(widget.id)) && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = d, app = context.app;
    if (x == null) {
      return Scaffold(
        appBar: peeraBar(context, title: 'მატჩი'),
        body: !loaded
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Empty(icon: 'trophy', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
                : const Empty(icon: 'trophy', title: 'მატჩი ვერ მოიძებნა'),
      );
    }
    final f = x.f, my = x.my, n = asInt(x.pool['n']);
    final open = f['status'] == 'upcoming' && asTime(f['starts_at']).isAfter(DateTime.now());
    int pc(String k) => n == 0 ? 0 : (asInt(x.pool['c$k']) / n * 100).round();
    final top = [pc('1'), pc('X'), pc('2')].reduce((a, b) => a > b ? a : b);
    final me = app.api.myId;
    return Scaffold(
      appBar: peeraBar(context, title: '${f['home']} – ${f['away']}'),
      body: Column(children: [
        Expanded(
          child: ListView(controller: scroll, padding: const EdgeInsets.only(bottom: 12), children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                Text('${'${f['league'] ?? ''}'.isEmpty ? 'მატჩი' : f['league']}'.toUpperCase(), style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .4)),
                const SizedBox(height: 10),
                _Teams(f, big: true),
                const SizedBox(height: 10),
                fixtureBadge(context, f),
                if (fixtureEnded(f)) Padding(padding: const EdgeInsets.only(top: 6), child: Text('შედეგი მალე დადასტურდება', style: TextStyle(color: c.muted, fontSize: 12.5))),
              ]),
            ),
            const SecHead('პროგნოზი'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('$n პროგნოზი. პროგნოზი უფასოა: გაკეთებისთვის +1 მონეტა, სწორისთვის +5.', style: TextStyle(color: c.muted, fontSize: 13)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(children: [
                for (final k in ['1', 'X', '2'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Builder(builder: (context) {
                        final on = (my?['pick'] ?? pick) == k, lead = n > 0 && pc(k) == top;
                        return Material(
                          color: on ? Color.alphaBlend(c.vine.withValues(alpha: .08), c.surface) : c.surface,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: on ? c.vine : c.line, width: 2)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: ValueKey('fxp-$k'),
                            onTap: !open || my != null ? null : () => setState(() => pick = k),
                            child: Stack(children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
                                child: Column(children: [
                                  TeamCrest(k == '1' ? '${f['home']}' : k == '2' ? '${f['away']}' : '', size: 34, draw: k == 'X'),
                                  const SizedBox(height: 6),
                                  Text(
                                    k == '1' ? '${f['home']}' : k == '2' ? '${f['away']}' : 'ფრე',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${pc(k)}%',
                                      style: TextStyle(color: lead ? c.vine : c.muted, fontWeight: FontWeight.w900, fontSize: 22, fontFeatures: const [FontFeature.tabularFigures()])),
                                  const SizedBox(height: 8),
                                  _Bar(value: pc(k) / 100, strong: true),
                                ]),
                              ),
                              if (on && my != null)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(color: c.vine, shape: BoxShape.circle),
                                    child: const PIcon('check', size: 14, color: Colors.white),
                                  ),
                                ),
                            ]),
                          ),
                        );
                      }),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: my != null
                  ? Text(
                      'შენი პროგნოზი: ${pickNames[my['pick']] ?? my['pick']} · ${asInt(my['stake']) > 0 ? '${my['stake']} მონეტა' : 'უფასო'}${my['payout'] != null ? ' · ${asInt(my['payout']) > 0 ? 'მიიღე ${my['payout']}' : 'წაგება'}' : ''}',
                      key: const ValueKey('fx-mine'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )
                  : open
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            key: const ValueKey('fx-go'),
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                            onPressed: pick == null || busy ? null : _predict,
                            child: const Text('პროგნოზი'),
                          ),
                        )
                      : Text('პროგნოზი დახურულია.', style: TextStyle(color: c.muted)),
            ),
            if (isStaff(context) && f['status'] == 'upcoming')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  const Text('მოდერატორი:', style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(width: 56, child: TextField(key: const ValueKey('fs-h'), controller: hs, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(hintText: '${f['home']}', isDense: true))),
                  const Text(':'),
                  SizedBox(width: 56, child: TextField(key: const ValueKey('fs-a'), controller: aws, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(hintText: '${f['away']}', isDense: true))),
                  FilledButton(key: const ValueKey('fs-ok'), style: FilledButton.styleFrom(minimumSize: const Size(0, 38)), onPressed: () => _settle(f), child: Text(fixtureEnded(f) ? 'დადასტურება' : 'შედეგი')),
                  OutlinedButton(key: const ValueKey('fs-x'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)), onPressed: _cancel, child: const Text('გაუქმება')),
                  OutlinedButton.icon(
                    key: const ValueKey('fs-names'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                    onPressed: () => _names(f),
                    icon: const PIcon('edit', size: 16),
                    label: const Text('სახელები'),
                  ),
                ]),
              ),
            SecHead(fixtureLive(f) ? 'ცოცხალი ჩატი' : 'ჩატი'),
            if (msgs.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('დაიწყე საუბარი მატჩზე.', style: TextStyle(color: c.muted))),
            for (final m in msgs)
              Builder(builder: (context) {
                final uid = '${m['user_id']}', p = app.people[uid] ?? Profile(id: uid, name: '…'), mine = uid == me;
                return Padding(
                  key: ValueKey('fxm-${m['id']}'),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GestureDetector(onTap: () => openPerson(context, p), child: Avatar(p: p, size: 28)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: mine ? c.accentSoft : c.sunk, borderRadius: BorderRadius.circular(14)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.name.split(' ').first, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: c.accent)),
                          Text('${m['body']}'),
                        ]),
                      ),
                    ),
                  ]),
                );
              }),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('fx-msg'),
                  controller: say,
                  maxLength: 500,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'დაწერე… გოოოლ!', counterText: '', isDense: true),
                ),
              ),
              IconBtn('send', key: const ValueKey('fx-send'), label: 'გაგზავნა', onTap: _send),
            ]),
          ),
        ),
      ]),
    );
  }
}
