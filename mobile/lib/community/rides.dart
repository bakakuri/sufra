// "ერთად წავიდეთ" (rides.js): rides between cities found by from, to and day, or mine (as driver or passenger); a ride
// offered (seats, the price per seat, the car); one ride booked, its booking withdrawn; the driver confirms or declines.
import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../config.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/post_card.dart';
import '../people/profile_parts.dart';
import '../profile/profile.dart';
import '../settings/places.dart';
import '../ui/bits.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const rideStates = {'pending': 'მოთხოვნა გაგზავნილია', 'accepted': 'ადგილი დადასტურდა', 'declined': 'უარყოფილია', 'cancelled': 'გაუქმებულია'};

/// "25 ₾", or free
String gel(Object? n) {
  final v = asNum(n) ?? 0;
  if (v == 0) return 'უფასოდ';
  return '${v == v.roundToDouble() ? thousands(v) : v.toStringAsFixed(2)} ₾';
}

/// "დღეს 09:00", "ხვალ 21:00", "14 ნოე 18:30" (sport.js fxWhen)
String atText(DateTime d, [DateTime? now]) {
  final t = now ?? DateTime.now(), dd = DateTime(d.year, d.month, d.day).difference(DateTime(t.year, t.month, t.day)).inDays, hm = hhmm(d);
  if (dd == 0) return 'დღეს $hm';
  if (dd == 1) return 'ხვალ $hm';
  if (dd == -1) return 'გუშინ $hm';
  return '${d.day} ${months[d.month - 1].characters.take(3)} $hm';
}

class _Route extends StatelessWidget {
  const _Route(this.from, this.to, {this.big = false});
  final String from, to;
  final bool big;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, st = TextStyle(fontWeight: FontWeight.w900, fontSize: big ? 22 : 16);
    return Row(children: [
      Flexible(child: Text(from, style: st, overflow: TextOverflow.ellipsis)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
          Container(width: big ? 34 : 22, height: 2, color: c.accent.withValues(alpha: .5)),
          Container(width: 7, height: 7, decoration: BoxDecoration(border: Border.all(color: c.accent, width: 2), shape: BoxShape.circle)),
        ]),
      ),
      Flexible(child: Text(to, style: st, overflow: TextOverflow.ellipsis)),
    ]);
  }
}

/// One ride in a list.
class RideCard extends StatelessWidget {
  const RideCard({super.key, required this.r, required this.onBack});
  final Map<String, dynamic> r;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, d = '${r['driver']}', who = app.people[d] ?? Profile(id: d, name: '…');
    final my = r['my_status'] as String?, pending = asInt(r['pending']);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('rc-${r['id']}'),
          onTap: () async {
            await openPage(context, RideScreen(id: asInt(r['id'])), full: true);
            onBack();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(atText(asTime(r['depart_at'])), style: TextStyle(fontWeight: FontWeight.w800, color: c.accent)),
                const Spacer(),
                if (r['status'] == 'cancelled') const PTag('გაუქმდა', kind: 'warn'),
              ]),
              const SizedBox(height: 6),
              _Route('${r['from_city']}', '${r['to_city']}'),
              const SizedBox(height: 8),
              Row(children: [
                Avatar(p: who, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${who.name.split(' ').first}${'${r['car'] ?? ''}'.isNotEmpty ? ' · ${r['car']}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted)),
                ),
                PIcon('users', size: 15, color: c.muted),
                const SizedBox(width: 3),
                Text('${r['seats_left']}/${r['seats']}', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                Text(gel(r['price']), style: const TextStyle(fontWeight: FontWeight.w900)),
              ]),
              if (my != null || pending > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 6, children: [
                    if (my != null) PTag(rideStates[my] ?? my, kind: my == 'accepted' ? 'ad' : ''),
                    if (pending > 0) PTag('$pending ახალი მოთხოვნა', kind: 'warn'),
                  ]),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Rides: found (from, to, a day) or mine.
class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});
  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> {
  String tab = 'find';
  final from = TextEditingController(), to = TextEditingController();
  DateTime? day;
  List<Map<String, dynamic>>? rows;
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

  @override
  void dispose() {
    from.dispose();
    to.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final g = ++_gen, app = context.app;
    if (rows != null) setState(() => rows = null);
    try {
      final r = await app.api.rides(from: from.text.trim(), to: to.text.trim(), day: day, mine: tab == 'mine');
      await app.people.ensure([for (final x in r) '${x['driver']}']);
      if (mounted && g == _gen) {
        setState(() {
          rows = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && g == _gen) {
        setState(() {
          rows = const [];
          error = e;
        });
      }
    }
  }

  Future<void> _new() async {
    final id = await openPage<int>(context, const RideFormScreen(), full: true);
    if (id != null && mounted) await openPage(context, RideScreen(id: id), full: true);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, r = rows, mine = tab == 'mine';
    Widget cityField(String key, TextEditingController x, String hint) => TextField(
          key: ValueKey(key),
          controller: x,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _load(),
          decoration: InputDecoration(hintText: hint, isDense: true),
        );
    return Scaffold(
      appBar: peeraBar(context, title: 'ერთად წავიდეთ', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: FilledButton.icon(
            key: const ValueKey('rd-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: _new,
            icon: PIcon('plus', size: 17, color: c.onAccent),
            label: const Text('მგზავრობა'),
          ),
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: SegmentedButton<String>(
              key: const ValueKey('rd-tab'),
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: 'find', label: Text('ძებნა')), ButtonSegment(value: 'mine', label: Text('ჩემი'))],
              selected: {tab},
              onSelectionChanged: (v) {
                setState(() => tab = v.first);
                _load();
              },
            ),
          ),
          if (!mine)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Column(children: [
                Row(children: [
                  Expanded(child: cityField('rd-from', from, 'საიდან')),
                  IconBtn('repost', key: const ValueKey('rd-swap'), label: 'მიმართულების შეცვლა', size: 20, onTap: () {
                    final a = from.text;
                    setState(() {
                      from.text = to.text;
                      to.text = a;
                    });
                    _load();
                  }),
                  Expanded(child: cityField('rd-to', to, 'სად')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('rd-day'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                      onPressed: () async {
                        final d = await showDatePicker(context: context, initialDate: day ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)));
                        if (d != null) {
                          setState(() => day = d);
                          _load();
                        }
                      },
                      icon: const PIcon('cal', size: 17),
                      label: Text(day == null ? 'ნებისმიერ დღეს' : '${day!.day} ${months[day!.month - 1]}'),
                    ),
                  ),
                  if (day != null) IconBtn('x', key: const ValueKey('rd-day-x'), label: 'ნებისმიერ დღეს', size: 20, onTap: () {
                    setState(() => day = null);
                    _load();
                  }),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: const ValueKey('rd-go'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                    onPressed: _load,
                    icon: PIcon('search', size: 17, color: c.onAccent),
                    label: const Text('ძებნა'),
                  ),
                ]),
              ]),
            ),
          if (r == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (error != null)
            Empty(icon: 'pin', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
          else if (r.isEmpty)
            Empty(
              icon: 'pin',
              title: mine ? 'მგზავრობები ჯერ არ გაქვს' : 'ვერაფერი მოიძებნა',
              text: mine ? 'შესთავაზე ადგილები მანქანაში ან მოძებნე მგზავრობა.' : 'სცადე სხვა დღე ან დაამატე შენი მგზავრობა.',
              action: 'მგზავრობის დამატება',
              onAction: _new,
            )
          else
            for (final x in r) RideCard(r: x, onBack: _load),
        ]),
      ),
    );
  }
}

/// A ride offered: from, to, when, seats, the price per seat, the car, a note. Pops with its id.
class RideFormScreen extends StatefulWidget {
  const RideFormScreen({super.key});
  @override
  State<RideFormScreen> createState() => _RideFormScreenState();
}

class _RideFormScreenState extends State<RideFormScreen> {
  late final from = TextEditingController(text: context.me.city ?? 'თბილისი');
  final to = TextEditingController(), price = TextEditingController(text: '25'), car = TextEditingController(), note = TextEditingController();
  DateTime at = () {
    final d = DateTime.now().add(const Duration(days: 1));
    return DateTime(d.year, d.month, d.day, 9);
  }();
  int seats = 3;
  bool busy = false;

  @override
  void dispose() {
    for (final x in [from, to, price, car, note]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final f = from.text.trim(), t = to.text.trim();
    if (f.isEmpty || t.isEmpty) {
      toast(context, 'ჩაწერე, საიდან და სად');
      return;
    }
    if (at.isBefore(DateTime.now())) {
      toast(context, 'აირჩიე მომავალი დრო');
      return;
    }
    setState(() => busy = true);
    try {
      final id = await context.app.api.createRide({
        'from_city': f,
        'to_city': t,
        'depart_at': at.toUtc().toIso8601String(),
        'seats': seats,
        'price': (num.tryParse(price.text.trim().replaceAll(',', '.')) ?? 0).clamp(0, 100000),
        'car': car.text.trim(),
        'note': note.text.trim(),
      });
      if (!mounted) return;
      toast(context, 'მგზავრობა გამოქვეყნდა');
      Navigator.of(context).pop(id);
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
      appBar: peeraBar(context, title: 'ახალი მგზავრობა', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(key: const ValueKey('rf-ok'), style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: busy ? null : _save, child: const Text('გამოქვეყნება')),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(child: TextField(key: const ValueKey('rf-from'), controller: from, maxLength: 60, decoration: const InputDecoration(labelText: 'საიდან', counterText: ''))),
          const SizedBox(width: 10),
          Expanded(child: TextField(key: const ValueKey('rf-to'), controller: to, maxLength: 60, decoration: const InputDecoration(labelText: 'სად', hintText: 'ბათუმი', counterText: ''))),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in georgianCities.take(8))
            ActionChip(key: ValueKey('rf-c-$s'), label: Text(s), onPressed: () => setState(() => to.text = s)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('rf-day'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: at, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => at = DateTime(d.year, d.month, d.day, at.hour, at.minute));
              },
              icon: const PIcon('cal', size: 17),
              label: Text('${at.day} ${months[at.month - 1]}'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('rf-time'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(at));
                if (t != null) setState(() => at = DateTime(at.year, at.month, at.day, t.hour, t.minute));
              },
              icon: const PIcon('clock', size: 17),
              label: Text(hhmm(at)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Text('ადგილები', style: TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          IconBtn('minus', key: const ValueKey('rf-less'), label: 'ნაკლები', onTap: seats > 1 ? () => setState(() => seats--) : null),
          SizedBox(width: 34, child: Text('$seats', key: const ValueKey('rf-seats'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          IconBtn('plus', key: const ValueKey('rf-more'), label: 'მეტი', onTap: seats < 8 ? () => setState(() => seats++) : null),
        ]),
        const SizedBox(height: 6),
        TextField(key: const ValueKey('rf-price'), controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ფასი ერთ ადგილზე, ₾', helperText: '0: უფასოდ')),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('rf-car'), controller: car, maxLength: 60, decoration: const InputDecoration(labelText: 'მანქანა', hintText: 'მაგ. თეთრი Prius', counterText: '')),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('rf-note'),
          controller: note,
          maxLength: 500,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'შენიშვნა', hintText: 'სად გავდივარ, ბარგი, შინაური ცხოველი, მოწევა…', counterText: ''),
        ),
        const SizedBox(height: 10),
        Text('მგზავრები მოთხოვნას გამოგიგზავნიან, შენ დაადასტურებ. ფულს ადგილზე იღებ, Peera გადახდაში არ ერევა.', style: TextStyle(color: c.muted, fontSize: 12.5)),
      ]),
    );
  }
}

/// One ride: the route, when, the seats left and the price, the car, the driver; booked (with how many seats) or
/// withdrawn; the driver's passengers confirmed or declined, the ride cancelled.
class RideScreen extends StatefulWidget {
  const RideScreen({super.key, required this.id});
  final int id;
  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  ({Map<String, dynamic> r, int left, Map<String, dynamic>? mine, List<Map<String, dynamic>> books})? d;
  bool loaded = false;
  Object? error;
  int want = 1;
  bool busy = false, _started = false;

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
      final x = await app.api.ride(widget.id);
      if (x != null) await app.people.ensure(['${x.r['driver']}', for (final b in x.books) '${b['user_id']}']);
      if (!mounted) return;
      setState(() {
        d = x;
        loaded = true;
        error = null;
        if (x != null) want = want.clamp(1, x.left < 1 ? 1 : x.left);
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

  Future<void> _do(Future<void> Function() f, [String? done]) async {
    setState(() => busy = true);
    final ok = await attempt(context, f);
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) {
      if (done != null) toast(context, done);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = d, app = context.app;
    if (x == null) {
      return Scaffold(
        appBar: peeraBar(context, title: 'მგზავრობა'),
        body: !loaded
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Empty(icon: 'pin', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
                : const Empty(icon: 'pin', title: 'მგზავრობა ვერ მოიძებნა'),
      );
    }
    final r = x.r, drvId = '${r['driver']}', drv = drvId == app.api.myId, at = asTime(r['depart_at']);
    final open = r['status'] == 'open' && at.isAfter(DateTime.now()), mine = x.mine, who = app.people[drvId] ?? Profile(id: drvId, name: '…');
    final booked = mine != null && (mine['status'] == 'pending' || mine['status'] == 'accepted');
    Widget kv(String icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [PIcon(icon, size: 17, color: c.muted), const SizedBox(width: 8), Expanded(child: Text(text))]),
        );
    return Scaffold(
      appBar: peeraBar(context, title: 'მგზავრობა', actions: [
        IconBtn('share', key: const ValueKey('rd-share'), label: 'გაზიარება', onTap: () => shareText(context, 'ერთად წავიდეთ: ${r['from_city']} → ${r['to_city']}\n$siteUrl/#ride-${r['id']}')),
        if (!drv) IconBtn('flag', key: const ValueKey('rd-report'), label: 'საჩივარი', onTap: () => reportSheet(context, 'ride', '${r['id']}')),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Route('${r['from_city']}', '${r['to_city']}', big: true),
              kv('clock', fullDate(at)),
              kv('users', 'თავისუფალი ${x.left} / ${r['seats']} · ${gel(r['price'])} ერთ ადგილზე'),
              if ('${r['car'] ?? ''}'.isNotEmpty) kv('pin', '${r['car']}'),
              if ('${r['note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${r['note']}')),
              if (r['status'] == 'cancelled') const Padding(padding: EdgeInsets.only(top: 8), child: PTag('მძღოლმა გააუქმა', kind: 'warn')),
            ]),
          ),
          ListTile(
            leading: Avatar(p: who, size: 46),
            title: Text(who.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('მძღოლი'),
            onTap: () => openPerson(context, who),
            trailing: drv
                ? null
                : OutlinedButton.icon(
                    key: const ValueKey('rd-chat'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                    onPressed: () => chatWith(context, drvId),
                    icon: const PIcon('msg', size: 16),
                    label: const Text('მიწერა'),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (drv && open)
                OutlinedButton.icon(
                  key: const ValueKey('rd-cancel'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), foregroundColor: c.nope),
                  onPressed: busy
                      ? null
                      : () async {
                          if (!await confirm(context, title: 'მგზავრობის გაუქმება', text: 'მგზავრებს მიწერე, რომ იცოდნენ.', yes: 'გაუქმება', danger: true) || !context.mounted) return;
                          _do(() => app.api.cancelRide(widget.id));
                        },
                  icon: PIcon('x', size: 17, color: c.nope),
                  label: const Text('მგზავრობის გაუქმება'),
                )
              else if (!drv && mine != null && booked) ...[
                PTag('${rideStates[mine['status']]} · ${mine['seats']} ადგილი', kind: mine['status'] == 'accepted' ? 'ad' : ''),
                OutlinedButton(
                  key: const ValueKey('rd-quit'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: busy
                      ? null
                      : () async {
                          if (!await confirm(context, title: 'ჯავშნის გაუქმება', text: 'მძღოლს ეცნობება.', yes: 'გაუქმება', danger: true) || !context.mounted) return;
                          _do(() => app.api.cancelBooking(widget.id));
                        },
                  child: const Text('ჯავშნის გაუქმება'),
                ),
              ] else if (!drv && open && x.left > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconBtn('minus', key: const ValueKey('rb-less'), label: 'ნაკლები', size: 20, onTap: want > 1 ? () => setState(() => want--) : null),
                    Text('$want ადგილი', key: const ValueKey('rb-n'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    IconBtn('plus', key: const ValueKey('rb-more'), label: 'მეტი', size: 20, onTap: want < x.left && want < 8 ? () => setState(() => want++) : null),
                  ]),
                ),
                FilledButton.icon(
                  key: const ValueKey('rd-book'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: busy ? null : () => _do(() => app.api.bookRide(widget.id, want), 'მოთხოვნა გაეგზავნა მძღოლს'),
                  icon: PIcon('check', size: 17, color: c.onAccent),
                  label: const Text('დაჯავშნა'),
                ),
              ] else if (!drv)
                Text(open ? 'ადგილები აღარ არის' : 'მგზავრობა დაიხურა', style: TextStyle(color: c.muted)),
            ]),
          ),
          if (drv) ...[
            const SecHead('მგზავრები'),
            if (x.books.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('მოთხოვნები ჯერ არ არის', style: TextStyle(color: c.muted))),
            for (final b in x.books)
              if (app.people['${b['user_id']}'] case final p?)
                Padding(
                  key: ValueKey('bk-${p.id}'),
                  padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                  child: Row(children: [
                    GestureDetector(onTap: () => openPerson(context, p), child: Avatar(p: p, size: 42)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${b['seats']} ადგილი · ${rideStates[b['status']] ?? b['status']}', style: TextStyle(color: c.muted, fontSize: 13)),
                      ]),
                    ),
                    if (b['status'] == 'pending') ...[
                      FilledButton(
                        key: ValueKey('bk-ok-${p.id}'),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                        onPressed: busy ? null : () => _do(() => app.api.respondBooking(widget.id, p.id, true), 'დადასტურდა'),
                        child: const Text('დადასტურება'),
                      ),
                      IconBtn('x', key: ValueKey('bk-no-${p.id}'), label: 'უარი', size: 20, onTap: busy ? null : () => _do(() => app.api.respondBooking(widget.id, p.id, false))),
                    ] else if (b['status'] == 'accepted')
                      IconBtn('msg', key: ValueKey('bk-chat-${p.id}'), label: 'მიწერა', size: 20, onTap: () => chatWith(context, p.id)),
                  ]),
                ),
          ],
        ]),
      ),
    );
  }
}
