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
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'rides.dart' show atText;

const pickNames = {'1': 'მასპინძელი', 'X': 'ფრე', '2': 'სტუმარი'};

bool fixtureLive(Map<String, dynamic> f) => f['status'] == 'upcoming' && !asTime(f['starts_at']).isAfter(DateTime.now());

Widget fixtureBadge(BuildContext context, Map<String, dynamic> f) {
  final c = context.pc;
  if (f['status'] == 'finished') return const PTag('დასრულდა');
  if (f['status'] == 'cancelled') return const PTag('გაუქმდა', kind: 'warn');
  if (fixtureLive(f)) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: c.nope, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text('ცოცხლად', style: TextStyle(color: c.nope, fontWeight: FontWeight.w800, fontSize: 12.5)),
    ]);
  }
  return PTag(atText(asTime(f['starts_at'])), kind: 'ad');
}

class _Teams extends StatelessWidget {
  const _Teams(this.f, {this.big = false});
  final Map<String, dynamic> f;
  final bool big;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, st = TextStyle(fontWeight: FontWeight.w900, fontSize: big ? 19 : 15.5);
    return Row(children: [
      Expanded(child: Text('${f['home']}', style: st, textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          f['status'] == 'finished' ? '${f['home_score']}:${f['away_score']}' : 'vs',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: big ? 28 : 18, color: f['status'] == 'finished' ? c.ink : c.muted),
        ),
      ),
      Expanded(child: Text('${f['away']}', style: st, maxLines: 2, overflow: TextOverflow.ellipsis)),
    ]);
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
      final r = await context.app.api.fixtures(tab);
      if (mounted && g == _gen) {
        setState(() {
          d = r;
          error = null;
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
                  : x.$1.isEmpty
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
                          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                            for (final f in x.$1)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                child: Material(
                                  color: c.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.line)),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    key: ValueKey('fx-${f['id']}'),
                                    onTap: () async {
                                      await openPage(context, FixtureScreen(id: asInt(f['id'])), full: true);
                                      _load();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(children: [
                                          Expanded(child: Text('${'${f['league'] ?? ''}'.isEmpty ? 'მატჩი' : f['league']}'.toUpperCase(), style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .4))),
                                          fixtureBadge(context, f),
                                        ]),
                                        const SizedBox(height: 10),
                                        _Teams(f),
                                        if (x.$2[asInt(f['id'])] case final m?)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(
                                              'შენი: ${pickNames[m['pick']] ?? m['pick']}${m['payout'] != null ? ' · ${asInt(m['payout']) > asInt(m['stake']) ? 'მოგება +${m['payout']}' : asInt(m['payout']) == asInt(m['stake']) && asInt(m['stake']) > 0 ? 'დაბრუნდა' : 'წაგება'}' : ''}',
                                              style: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: 13),
                                            ),
                                          ),
                                      ]),
                                    ),
                                  ),
                                ),
                              ),
                          ]),
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
      });
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
    await context.app.people.ensure(['${m['user_id']}']);
    if (mounted) setState(() => msgs.add(m));
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
                      child: Material(
                        color: (my?['pick'] ?? pick) == k ? c.accent : c.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: (my?['pick'] ?? pick) == k ? c.accent : c.line)),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: ValueKey('fxp-$k'),
                          onTap: !open || my != null ? null : () => setState(() => pick = k),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                            child: Column(children: [
                              Text(
                                k == '1' ? '${f['home']}' : k == '2' ? '${f['away']}' : 'ფრე',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w800, color: (my?['pick'] ?? pick) == k ? c.onAccent : c.ink),
                              ),
                              const SizedBox(height: 2),
                              Text('${pc(k)}%', style: TextStyle(color: (my?['pick'] ?? pick) == k ? c.onAccent : c.muted, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                      ),
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
                  FilledButton(key: const ValueKey('fs-ok'), style: FilledButton.styleFrom(minimumSize: const Size(0, 38)), onPressed: () => _settle(f), child: const Text('შედეგი')),
                  OutlinedButton(key: const ValueKey('fs-x'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)), onPressed: _cancel, child: const Text('გაუქმება')),
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
