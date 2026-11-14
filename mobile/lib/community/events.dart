// Events and the evening's planning (community.js PG.events, PG.event, PG.evnew): what is coming and who goes; one
// event with "მოვდივარ / შეიძლება / ვერ მოვალ", who brings what, the agenda kept by the host and the leader (a ready
// one, from the toast book, done / up / away), the shared costs split between those who come (who owes whom, paid
// and received), friends invited, the album, the link; and a new one (also from a group).
import 'package:flutter/material.dart';

import '../config.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../people/albums.dart';
import '../people/person_screen.dart';
import '../people/profile_parts.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/translate.dart';
import '../ui/widgets.dart';

/// a ready agenda for a meeting (community.js CLASSIC_TOASTS)
const classicAgenda = ['გაცნობა', 'დღის მიზანი', 'მთავარი თემა', 'პრეზენტაცია', 'კითხვები და პასუხები', 'ჯგუფური დავალება', 'შესვენება', 'შეჯამება', 'შემდეგი შეხვედრის დაგეგმვა'];

String lari(num n) {
  final r = (n * 100).round() / 100;
  final s = r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(2);
  return '$s ₾';
}

/// who pays whom so that everyone has paid the same: (from, to, amount)
List<(String, String, double)> settleUp(List<String> people, List<Map<String, dynamic>> costs, List<Map<String, dynamic>> pays) {
  final total = costs.fold<double>(0, (a, c) => a + (asNum(c['amount']) ?? 0));
  final share = people.isEmpty ? 0.0 : total / people.length;
  final bal = {for (final u in people) u: -share};
  for (final c in costs) {
    final u = '${c['paid_by']}';
    bal[u] = (bal[u] ?? 0) + (asNum(c['amount']) ?? 0);
  }
  for (final p in pays) {
    final f = '${p['from_user']}', t = '${p['to_user']}', a = asNum(p['amount']) ?? 0;
    bal[f] = (bal[f] ?? 0) + a;
    bal[t] = (bal[t] ?? 0) - a;
  }
  final deb = [for (final e in bal.entries) if (e.value < -.009) [e.key, -e.value]]..sort((a, b) => (b[1] as double).compareTo(a[1] as double));
  final cred = [for (final e in bal.entries) if (e.value > .009) [e.key, e.value]]..sort((a, b) => (b[1] as double).compareTo(a[1] as double));
  final out = <(String, String, double)>[];
  for (final d in deb) {
    for (final c in cred) {
      if ((d[1] as double) < .01) break;
      if ((c[1] as double) < .01) continue;
      final m = (d[1] as double) < (c[1] as double) ? d[1] as double : c[1] as double;
      out.add((d[0] as String, c[0] as String, m));
      d[1] = (d[1] as double) - m;
      c[1] = (c[1] as double) - m;
    }
  }
  return out;
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.d, required this.hue});
  final DateTime d;
  final int hue;
  @override
  Widget build(BuildContext context) => Container(
        width: 54,
        height: 58,
        decoration: BoxDecoration(color: HSLColor.fromAHSL(1, (hue % 360).toDouble(), .5, .45).toColor(), borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${d.day}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
          Text(months[d.month - 1].characters.take(3).toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)? d;
  Object? error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final app = context.app;
    try {
      final r = await app.api.events();
      await app.people.ensure([...r.$2.map((x) => '${x['user_id']}'), ...r.$1.map((e) => '${e['host']}')]);
      if (mounted) {
        setState(() {
          d = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _new() async {
    final id = await openPage<int>(context, const EventFormScreen(), full: true);
    if (id != null && mounted) {
      _load();
      await openPage(context, EventScreen(id: id), full: true);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = d, app = context.app, me = context.me.id;
    return Scaffold(
      appBar: peeraBar(context, title: 'ღონისძიებები', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: FilledButton.icon(
            key: const ValueKey('events-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: _new,
            icon: PIcon('plus', size: 17, color: c.onAccent),
            label: const Text('ახალი'),
          ),
        ),
      ]),
      body: error != null && x == null
          ? Empty(icon: 'cal', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
          : x == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('შეხვედრები, ლექციები, ექსკურსიები და წვეულებები.', style: TextStyle(color: c.muted)),
                    ),
                    if (x.$1.isEmpty)
                      Empty(icon: 'cal', title: 'მომავალი ღონისძიებები ჯერ არ არის', text: 'შექმენი შეხვედრა და მოიწვიე კურსელები.', action: 'ღონისძიების შექმნა', onAction: _new)
                    else
                      for (final e in x.$1)
                        Builder(builder: (context) {
                          final id = asInt(e['id']), at = asTime(e['starts_at']).toLocal();
                          final going = [for (final r in x.$2) if (asInt(r['event_id']) == id && r['status'] == 'yes') '${r['user_id']}'];
                          final mine = x.$2.any((r) => asInt(r['event_id']) == id && r['user_id'] == me && r['status'] == 'yes');
                          return InkWell(
                            key: ValueKey('ev-$id'),
                            onTap: () async {
                              await openPage(context, EventScreen(id: id), full: true);
                              _load();
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _DateBox(d: at, hue: asInt(e['hue'], 200)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${e['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                                    Text('${fullDate(at)} · ${e['place'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 13)),
                                    const SizedBox(height: 5),
                                    Row(children: [
                                      for (final u in going.take(5))
                                        Padding(padding: const EdgeInsets.only(right: 2), child: Avatar(p: app.people[u] ?? Profile(id: u, name: '…'), size: 24)),
                                      const SizedBox(width: 4),
                                      Text('${going.length} მოდის${mine ? ', შენც' : ''}', style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                    ]),
                                  ]),
                                ),
                              ]),
                            ),
                          );
                        }),
                  ]),
                ),
    );
  }
}

class EventScreen extends StatefulWidget {
  const EventScreen({super.key, required this.id});
  final int id;
  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  (Map<String, dynamic>, List<Map<String, dynamic>>, List<Map<String, dynamic>>)? d;
  List<Map<String, dynamic>>? agenda;
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)? money;
  Object? error;
  bool gone = false, _started = false;
  final item = TextEditingController(), point = TextEditingController(), what = TextEditingController(), amount = TextEditingController();
  String? payer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    item.dispose();
    point.dispose();
    what.dispose();
    amount.dispose();
    super.dispose();
  }

  Map<String, dynamic> get e => d!.$1;
  String get me => context.app.api.myId;
  bool get host => e['host'] == me;
  bool get lead => host || e['tamada'] == me;
  String get my => d!.$2.where((r) => r['user_id'] == me).firstOrNull?['status'] as String? ?? '';
  List<String> get going => [for (final r in d!.$2) if (r['status'] == 'yes') '${r['user_id']}'];

  Future<void> _load() async {
    final app = context.app;
    try {
      final r = await app.api.event(widget.id);
      if (!mounted) return;
      if (r == null) {
        setState(() => gone = true);
        return;
      }
      await app.people.ensure([
        '${r.$1['host']}',
        if (r.$1['tamada'] != null) '${r.$1['tamada']}',
        ...r.$2.map((x) => '${x['user_id']}'),
        ...r.$3.where((i) => i['claimed_by'] != null).map((i) => '${i['claimed_by']}'),
      ]);
      if (!mounted) return;
      setState(() {
        d = r;
        error = null;
      });
      _agenda();
      if (host || my == 'yes' || my == 'maybe') _money();
    } catch (x) {
      if (mounted) setState(() => error = x);
    }
  }

  Future<void> _agenda() async {
    try {
      final a = await context.app.api.eventAgenda(widget.id);
      if (mounted) setState(() => agenda = a);
    } catch (_) {}
  }

  Future<void> _money() async {
    final app = context.app;
    try {
      final m = await app.api.eventCosts(widget.id);
      await app.people.ensure([...m.$1.map((c) => '${c['paid_by']}'), ...m.$2.expand((p) => ['${p['from_user']}', '${p['to_user']}'])]);
      if (mounted) setState(() => money = m);
    } catch (_) {}
  }

  Future<void> _do(Future<void> Function() f, {String? ok, bool all = true}) async {
    if (await attempt(context, f) && mounted) {
      if (ok != null) toast(context, ok);
      if (all) _load();
    }
  }

  String _name(String u) => u == me ? 'შენ' : (context.app.people[u]?.name ?? '…');

  Future<void> _tamada() async {
    final app = context.app;
    final ids = <String>{'${e['host']}', ...going};
    final pick = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('წამყვანის არჩევა', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          for (final u in ids)
            ListTile(
              key: ValueKey('tam-$u'),
              leading: Avatar(p: app.people[u] ?? Profile(id: u, name: '…'), size: 40),
              title: Text(u == me ? 'მე' : (app.people[u]?.name ?? '…'), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: u == e['tamada'] ? const Text('ახლა წამყვანია') : null,
              trailing: u == e['tamada'] ? PIcon('check', color: s.pc.accent) : null,
              onTap: () => Navigator.of(s).pop(u),
            ),
          if (e['tamada'] != null) ListTile(key: const ValueKey('tam-none'), leading: PIcon('x', color: s.pc.muted), title: const Text('წამყვანის მოხსნა'), onTap: () => Navigator.of(s).pop('')),
          if (ids.length < 2) Padding(padding: const EdgeInsets.all(16), child: Text('წამყვანად არჩევა შეგიძლია მათგან, ვინც თქვა „მოვდივარ“.', style: TextStyle(color: s.pc.muted))),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    await _do(() => app.api.setTamada(widget.id, pick.isEmpty ? null : pick), ok: pick.isEmpty ? 'წამყვანი მოიხსნა' : 'წამყვანი არჩეულია');
  }

  Future<void> _book() async {
    final app = context.app;
    final rows = await app.api.toastBook().catchError((_) => <Map<String, dynamic>>[]);
    if (!mounted) return;
    final sel = <int>{};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => StatefulBuilder(
        builder: (s, set) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(s).height * .75),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('რჩევების წიგნი', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  if (rows.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('წიგნი ჯერ ცარიელია.')),
                  for (final r in rows)
                    CheckboxListTile(
                      key: ValueKey('tb-${r['id']}'),
                      value: sel.contains(asInt(r['id'])),
                      onChanged: (v) => set(() => v == true ? sel.add(asInt(r['id'])) : sel.remove(asInt(r['id']))),
                      title: Text('${r['title'] ?? ''}'),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(key: const ValueKey('tb-ok'), onPressed: () => Navigator.of(s).pop(true), child: const Text('დამატება')),
              ),
            ]),
          ),
        ),
      ),
    );
    if (ok != true || sel.isEmpty || !mounted) return;
    final base = (agenda ?? const []).fold<int>(0, (m, r) => asInt(r['pos']) > m ? asInt(r['pos']) : m);
    await _do(() => app.api.addAgenda(widget.id, [for (final r in rows) if (sel.contains(asInt(r['id']))) ('${r['title']}', asInt(r['id']))], base), all: false);
    _agenda();
  }

  Future<void> _read(int tid) async {
    final r = await context.app.api.toastText(tid).catchError((_) => null);
    if (r == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(s).height * .8),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
            Text('${r['title'] ?? ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text('${r['body'] ?? ''}', style: const TextStyle(fontSize: 16, height: 1.55)),
          ]),
        ),
      ),
    );
  }

  Future<void> _addPoints(List<(String, int?)> rows) async {
    final base = (agenda ?? const []).fold<int>(0, (m, r) => asInt(r['pos']) > m ? asInt(r['pos']) : m);
    await _do(() => context.app.api.addAgenda(widget.id, rows, base), all: false);
    _agenda();
  }

  Future<void> _up(int i) async {
    final l = agenda!;
    if (i < 1) return;
    final a = l[i], b = l[i - 1], api = context.app.api;
    await _do(() async {
      await api.agendaPos(asInt(a['id']), i);
      await api.agendaPos(asInt(b['id']), i + 1);
    }, all: false);
    _agenda();
  }

  Future<void> _album() async {
    final app = context.app;
    try {
      final a = await app.api.eventAlbum(widget.id);
      if (!mounted) return;
      if (a != null) {
        await openPage(context, AlbumScreen(id: a), full: true);
        return;
      }
      if (!(host || going.contains(me))) {
        toast(context, 'ალბომი ჯერ არ შექმნილა. შექმნა შეუძლიათ მასპინძელს და სტუმრებს');
        return;
      }
      final n = await app.api.makeEventAlbum(widget.id, '${e['title']}');
      if (!mounted) return;
      toast(context, 'ალბომი შეიქმნა. სტუმრებს შეუძლიათ ფოტოების დამატება');
      await openPage(context, AlbumScreen(id: n), full: true);
    } catch (x) {
      if (mounted) toast(context, errText(x));
    }
  }

  Future<void> _invite() async {
    final sel = await pickFriends(context, title: 'მეგობრების მოწვევა', action: 'მოწვევა', skip: going.toSet());
    if (sel == null || sel.isEmpty || !mounted) return;
    try {
      final n = await context.app.api.inviteToEvent(widget.id, sel);
      if (mounted) toast(context, n > 0 ? 'მოწვევა გაეგზავნა: $n' : 'ყველა უკვე მოწვეულია');
    } catch (x) {
      if (mounted) toast(context, errText(x));
    }
  }

  Widget _sec(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 6), child: Text(t, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)));

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app;
    if (gone) return Scaffold(appBar: peeraBar(context, title: 'ღონისძიება'), body: const Empty(icon: 'cal', title: 'ღონისძიება ვერ მოიძებნა'));
    if (d == null) {
      return Scaffold(
        appBar: peeraBar(context, title: 'ღონისძიება'),
        body: error != null ? Empty(icon: 'cal', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load) : const Center(child: CircularProgressIndicator()),
      );
    }
    final at = asTime(e['starts_at']).toLocal(), hue = asInt(e['hue'], 200), maybe = d!.$2.where((r) => r['status'] == 'maybe').length;
    final hostId = '${e['host']}', tam = e['tamada'] as String?;
    Widget kv(String icon, Widget v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [PIcon(icon, size: 18, color: c.muted), const SizedBox(width: 8), Expanded(child: v)]),
        );
    Widget link(String text, VoidCallback onTap, {Key? key}) => GestureDetector(key: key, onTap: onTap, child: Text(text, style: TextStyle(color: c.accent, fontWeight: FontWeight.w700)));
    final m = money, showMoney = host || my == 'yes' || my == 'maybe';
    final people = {hostId, ...going}.toList();
    if (payer == null || !people.contains(payer)) payer = people.contains(me) ? me : people.first;
    final total = m == null ? 0.0 : m.$1.fold<double>(0, (a, x) => a + (asNum(x['amount']) ?? 0));
    final moves = m == null ? const <(String, String, double)>[] : settleUp(people, m.$1, m.$2);
    final cur = (agenda ?? const []).where((r) => r['done'] != true).firstOrNull;
    return Scaffold(
      appBar: peeraBar(context, title: '${e['title'] ?? 'ღონისძიება'}'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                HSLColor.fromAHSL(1, (hue % 360).toDouble(), .55, .5).toColor(),
                HSLColor.fromAHSL(1, ((hue + 40) % 360).toDouble(), .5, .3).toColor(),
              ]),
            ),
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.all(16),
            child: _DateBox(d: at, hue: (hue + 180) % 360),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${e['title'] ?? ''}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              kv('cal', Text(fullDate(at))),
              kv('pin', Text('${e['place'] ?? ''}'.isEmpty ? 'ადგილი დასაზუსტებელია' : '${e['place']}')),
              kv('user', Wrap(children: [const Text('მასპინძელი: '), link(_name(hostId), () => openPage(context, PersonScreen(uid: hostId, initial: app.people[hostId]), full: true))])),
              if (tam != null)
                kv('star', Wrap(children: [
                  const Text('წამყვანი: '),
                  link(_name(tam), () => openPage(context, PersonScreen(uid: tam, initial: app.people[tam]), full: true)),
                  if (host) ...[const Text('  '), link('შეცვლა', _tamada, key: const ValueKey('ev-tamada'))],
                ]))
              else if (host)
                kv('star', link('წამყვანის არჩევა', _tamada, key: const ValueKey('ev-tamada'))),
              if ('${e['description'] ?? ''}'.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: TranslatableBody('${e['description']}'.trim())),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                key: const ValueKey('ev-rsvp'),
                showSelectedIcon: false,
                emptySelectionAllowed: true,
                segments: const [ButtonSegment(value: 'yes', label: Text('მოვდივარ')), ButtonSegment(value: 'maybe', label: Text('შეიძლება')), ButtonSegment(value: 'no', label: Text('ვერ მოვალ'))],
                selected: {if (my.isNotEmpty) my},
                onSelectionChanged: (v) {
                  if (v.isEmpty) return;
                  _do(() => app.api.rsvp(widget.id, v.first), ok: v.first == 'yes' ? 'შენი პასუხი მასპინძელმა მიიღო' : null);
                },
              ),
              const SizedBox(height: 12),
              Text.rich(TextSpan(children: [
                TextSpan(text: '${going.length} მოდის', style: const TextStyle(fontWeight: FontWeight.w800)),
                if (maybe > 0) TextSpan(text: ' · $maybe შეიძლება', style: TextStyle(color: c.muted)),
              ])),
              const SizedBox(height: 8),
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (final u in going)
                  GestureDetector(onTap: () => openPage(context, PersonScreen(uid: u, initial: app.people[u]), full: true), child: Avatar(p: app.people[u] ?? Profile(id: u, name: '…'), size: 34)),
              ]),
            ]),
          ),
          _sec('ვინ რას მოიტანს'),
          if (d!.$3.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('სია ჯერ ცარიელია.', style: TextStyle(color: c.muted))),
          for (final it in d!.$3)
            Builder(builder: (context) {
              final id = asInt(it['id']), by = it['claimed_by'] as String?;
              return ListTile(
                key: ValueKey('item-$id'),
                leading: by == null ? CircleAvatar(radius: 16, backgroundColor: c.sunk, child: Text('?', style: TextStyle(color: c.muted))) : Avatar(p: app.people[by] ?? Profile(id: by, name: '…'), size: 32),
                title: Text('${it['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(by == null ? 'ჯერ არავინ' : (by == me ? 'შენ მოიტან' : '${_name(by)} მოიტანს'), style: TextStyle(color: c.muted)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (by == null)
                    FilledButton(key: ValueKey('claim-$id'), style: FilledButton.styleFrom(minimumSize: const Size(0, 34)), onPressed: () => _do(() => app.api.claimEventItem(id, true)), child: const Text('მე მოვიტან'))
                  else if (by == me)
                    OutlinedButton(key: ValueKey('unclaim-$id'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34)), onPressed: () => _do(() => app.api.claimEventItem(id, false)), child: const Text('გაუქმება')),
                  if (it['added_by'] == me || host) IconBtn('x', key: ValueKey('itemx-$id'), label: 'წაშლა', size: 18, color: c.muted, onTap: () => _do(() => app.api.deleteEventItem(id))),
                ]),
              );
            }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(children: [
              Expanded(child: TextField(key: const ValueKey('item-new'), controller: item, maxLength: 60, decoration: const InputDecoration(hintText: 'დაამატე, მაგალითად ტყემალი', counterText: ''))),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const ValueKey('item-add'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                onPressed: () {
                  final v = item.text.trim();
                  if (v.isEmpty) return;
                  item.clear();
                  _do(() => app.api.addEventItem(widget.id, v));
                },
                child: const Text('დამატება'),
              ),
            ]),
          ),
          _sec('დღის წესრიგი'),
          if ((agenda ?? const []).isEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(lead ? 'დაამატე პუნქტები ან აირჩიე მზა წესრიგი.' : 'წამყვანს წესრიგი ჯერ არ დაუმატებია.', style: TextStyle(color: c.muted))),
          for (var i = 0; i < (agenda ?? const []).length; i++)
            Builder(builder: (context) {
              final r = agenda![i], id = asInt(r['id']), done = r['done'] == true, now = cur != null && asInt(cur['id']) == id;
              return ListTile(
                key: ValueKey('ag-$id'),
                leading: CircleAvatar(
                  radius: 15,
                  backgroundColor: done ? c.vine : (now ? c.accent : c.sunk),
                  child: done ? const PIcon('check', size: 15, color: Colors.white) : Text('${i + 1}', style: TextStyle(color: now ? Colors.white : c.ink, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                title: Text('${r['title'] ?? ''}', style: TextStyle(decoration: done ? TextDecoration.lineThrough : null, color: done ? c.muted : c.ink, fontWeight: now ? FontWeight.w800 : FontWeight.w500)),
                subtitle: now || r['toast_id'] != null
                    ? Wrap(children: [
                        if (now) Text('ახლა  ', style: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: 12.5)),
                        if (r['toast_id'] != null) link('ტექსტი', () => _read(asInt(r['toast_id']))),
                      ])
                    : null,
                trailing: lead
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        IconBtn(done ? 'back' : 'check', key: ValueKey('agdone-$id'), label: done ? 'დაბრუნება' : 'შესრულდა', size: 18, onTap: () async {
                          await _do(() => app.api.agendaDone(id, !done), all: false);
                          _agenda();
                        }),
                        if (i > 0) IconBtn('chev', key: ValueKey('agup-$id'), label: 'ზემოთ', size: 18, onTap: () => _up(i)),
                        IconBtn('x', key: ValueKey('agx-$id'), label: 'წაშლა', size: 18, color: c.muted, onTap: () async {
                          await _do(() => app.api.agendaDelete(id), all: false);
                          _agenda();
                        }),
                      ])
                    : null,
              );
            }),
          if (lead) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(children: [
                Expanded(child: TextField(key: const ValueKey('ag-new'), controller: point, maxLength: 120, decoration: const InputDecoration(hintText: 'მაგ. პრეზენტაცია: ნინო', counterText: ''))),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: const ValueKey('ag-add'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                  onPressed: () {
                    final v = point.text.trim();
                    if (v.isEmpty) return;
                    point.clear();
                    _addPoints([(v, null)]);
                  },
                  child: const Text('დამატება'),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                if ((agenda ?? const []).isEmpty)
                  OutlinedButton.icon(
                    key: const ValueKey('ag-classic'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                    onPressed: () => _addPoints([for (final t in classicAgenda) (t, null)]),
                    icon: PIcon('note', size: 16, color: c.ink),
                    label: const Text('მზა წესრიგი'),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey('ag-book'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                  onPressed: _book,
                  icon: PIcon('star', size: 16, color: c.ink),
                  label: const Text('რჩევების წიგნიდან'),
                ),
              ]),
            ),
          ],
          if (showMoney) ...[
            _sec('ხარჯები'),
            if (m == null)
              const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
            else ...[
              if (m.$1.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('ჩაწერე, ვინ რა იყიდა და ხარჯი ავტომატურად გაიყოფა მასპინძელსა და „მოვდივარ“-ზე პასუხ გამცემებს შორის.', style: TextStyle(color: c.muted)),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(child: _Stat(value: lari(total), label: 'სულ')),
                    const SizedBox(width: 8),
                    Expanded(child: _Stat(value: lari(people.isEmpty ? 0 : total / people.length), label: 'თითოეულზე · ${people.length} კაცი')),
                  ]),
                ),
                for (final x in m.$1)
                  ListTile(
                    key: ValueKey('cost-${x['id']}'),
                    leading: Avatar(p: app.people['${x['paid_by']}'] ?? Profile(id: '${x['paid_by']}', name: '…'), size: 32),
                    title: Text('${x['what'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${_name('${x['paid_by']}')} გადაიხადა', style: TextStyle(color: c.muted)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(lari(asNum(x['amount']) ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (x['added_by'] == me || host)
                        IconBtn('x', label: 'წაშლა', size: 18, color: c.muted, onTap: () async {
                          await _do(() => app.api.deleteEventCost(asInt(x['id'])), all: false);
                          _money();
                        }),
                    ]),
                  ),
                const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 2), child: Text('ვინ ვის', style: TextStyle(fontWeight: FontWeight.w800))),
                if (moves.isEmpty)
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('ყველა ანგარიში გასწორებულია ✓', style: TextStyle(color: c.muted)))
                else
                  for (final (f, to, amt) in moves)
                    ListTile(
                      key: ValueKey('move-$f-$to'),
                      title: Text('${_name(f)} → ${_name(to)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(lari(amt), style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(width: 6),
                        if (f == me)
                          FilledButton(
                            key: const ValueKey('ev-paid'),
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 34)),
                            onPressed: () async {
                              await _do(() => app.api.addEventPayment(widget.id, me, to, double.parse(amt.toStringAsFixed(2))), ok: 'ჩაიწერა', all: false);
                              _money();
                            },
                            child: const Text('გადავუხადე'),
                          )
                        else if (to == me)
                          OutlinedButton(
                            key: const ValueKey('ev-got'),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34)),
                            onPressed: () async {
                              await _do(() => app.api.addEventPayment(widget.id, f, me, double.parse(amt.toStringAsFixed(2))), ok: 'ჩაიწერა', all: false);
                              _money();
                            },
                            child: const Text('მივიღე'),
                          ),
                      ]),
                    ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(children: [
                  Row(children: [
                    Expanded(flex: 3, child: TextField(key: const ValueKey('cost-what'), controller: what, maxLength: 80, decoration: const InputDecoration(hintText: 'რა? მაგ. პიცა', counterText: ''))),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        key: const ValueKey('cost-amount'),
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: '₾'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const ValueKey('cost-payer'),
                        isExpanded: true,
                        initialValue: payer,
                        items: [for (final u in people) DropdownMenuItem(value: u, child: Text(u == me ? 'მე' : (app.people[u]?.name ?? '…'), overflow: TextOverflow.ellipsis))],
                        onChanged: (v) => setState(() => payer = v),
                        decoration: const InputDecoration(labelText: 'ვინ გადაიხადა'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      key: const ValueKey('cost-add'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                      onPressed: () async {
                        final w = what.text.trim(), a = double.tryParse(amount.text.replaceAll(',', '.').trim());
                        if (w.isEmpty || a == null || a <= 0) {
                          toast(context, 'ჩაწერე რა და რამდენი');
                          return;
                        }
                        what.clear();
                        amount.clear();
                        await _do(() => app.api.addEventCost(widget.id, payer ?? me, a, w), all: false);
                        _money();
                      },
                      child: const Text('დამატება'),
                    ),
                  ]),
                ]),
              ),
              if (m.$2.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Material(
                    type: MaterialType.transparency,
                    child: ExpansionTile(
                      title: Text('გადახდები · ${m.$2.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      children: [
                        for (final p in m.$2)
                          ListTile(
                            title: Text('${_name('${p['from_user']}')} → ${_name('${p['to_user']}')}'),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(lari(asNum(p['amount']) ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
                              if (p['added_by'] == me)
                                IconBtn('x', label: 'გაუქმება', size: 18, color: c.muted, onTap: () async {
                                  await _do(() => app.api.deleteEventPayment(asInt(p['id'])), all: false);
                                  _money();
                                }),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              if (host || my == 'yes' || my == 'maybe')
                OutlinedButton.icon(key: const ValueKey('ev-invite'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)), onPressed: _invite, icon: PIcon('users', size: 17, color: c.ink), label: const Text('მეგობრების მოწვევა')),
              OutlinedButton.icon(key: const ValueKey('ev-album'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)), onPressed: _album, icon: PIcon('image', size: 17, color: c.ink), label: const Text('ალბომი')),
              OutlinedButton.icon(
                key: const ValueKey('ev-share'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: () => shareText(context, 'შემოგვიერთდი: ${e['title']}\n$siteUrl/#event-${widget.id}'),
                icon: PIcon('send', size: 17, color: c.ink),
                label: const Text('ბმული'),
              ),
              if (host)
                OutlinedButton.icon(
                  key: const ValueKey('ev-cancel'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), foregroundColor: c.nope),
                  onPressed: () async {
                    if (!await confirm(context, title: 'ღონისძიების გაუქმება', text: 'ღონისძიება წაიშლება ყველასთვის.', yes: 'გაუქმება', danger: true) || !context.mounted) return;
                    if (await attempt(context, () => app.api.deleteEvent(widget.id)) && context.mounted) Navigator.of(context).maybePop();
                  },
                  icon: PIcon('trash', size: 17, color: c.nope),
                  label: const Text('გაუქმება'),
                )
              else
                OutlinedButton.icon(
                  key: const ValueKey('ev-report'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                  onPressed: () => reportSheet(context, 'event', '${widget.id}'),
                  icon: PIcon('flag', size: 17, color: c.ink),
                  label: const Text('საჩივარი'),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        Text(label, style: TextStyle(color: c.muted, fontSize: 12.5)),
      ]),
    );
  }
}

/// A new event: name, day and hour, place, plan, a leader, and what to bring (separated by commas). From a group it
/// belongs to the group.
class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.groupId});
  final int? groupId;
  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final title = TextEditingController(), place = TextEditingController(), desc = TextEditingController(), items = TextEditingController();
  late DateTime day = DateTime.now().add(const Duration(days: 7));
  TimeOfDay time = const TimeOfDay(hour: 20, minute: 0);
  String tamada = '';
  bool busy = false;

  @override
  void dispose() {
    title.dispose();
    place.dispose();
    desc.dispose();
    items.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = title.text.trim(), p = place.text.trim();
    if (t.isEmpty || p.isEmpty) {
      toast(context, 'ჩაწერე სახელი და ადგილი');
      return;
    }
    setState(() => busy = true);
    try {
      final id = await context.app.api.createEvent(
        title: t,
        startsAt: DateTime(day.year, day.month, day.day, time.hour, time.minute),
        place: p,
        description: desc.text.trim(),
        tamada: tamada.isEmpty ? null : tamada,
        groupId: widget.groupId,
        items: [for (final x in items.text.split(',')) if (x.trim().isNotEmpty) x.trim()],
      );
      if (!mounted) return;
      toast(context, 'ღონისძიება შეიქმნა');
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app, me = context.me;
    return Scaffold(
      appBar: peeraBar(context, title: 'ახალი ღონისძიება', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(key: const ValueKey('ef-ok'), style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: busy ? null : _save, child: const Text('შექმნა')),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          key: const ValueKey('ef-title'),
          controller: title,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'სახელი', hintText: 'მაგალითად: შაბათის სასწავლო შეხვედრა ბიბლიოთეკაში', counterText: ''),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('ef-day'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(context: context, initialDate: day, firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 730)));
                if (d != null) setState(() => day = d);
              },
              icon: const PIcon('cal', size: 17),
              label: Text('${day.day} ${months[day.month - 1]}'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('ef-time'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: time);
                if (t != null) setState(() => time = t);
              },
              icon: const PIcon('clock', size: 17),
              label: Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('ef-place'), controller: place, maxLength: 160, decoration: const InputDecoration(labelText: 'ადგილი', hintText: 'ქალაქი, მისამართი', counterText: '')),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('ef-desc'),
          controller: desc,
          maxLength: 1000,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'აღწერა', hintText: 'რა გეგმაა, როგორ მოვიდნენ', counterText: ''),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const ValueKey('ef-tamada'),
          isExpanded: true,
          initialValue: tamada,
          decoration: const InputDecoration(labelText: 'წამყვანი'),
          items: [
            const DropdownMenuItem(value: '', child: Text('ჯერ არ ვიცი')),
            DropdownMenuItem(value: me.id, child: const Text('მე')),
            for (final id in app.friends.friends) DropdownMenuItem(value: id, child: Text(app.people[id]?.name ?? '…', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => tamada = v ?? ''),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('ef-items'),
          controller: items,
          decoration: const InputDecoration(labelText: 'ვინ რას მოიტანს (მძიმით გამოყავი)', hintText: 'ლეპტოპი, კონსპექტები, ყავა, ნამცხვარი'),
        ),
      ]),
    );
  }
}
