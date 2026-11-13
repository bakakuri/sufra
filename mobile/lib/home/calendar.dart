// Friends' days (home.js upcoming, remStory, PG.calendar): their birthdays and angel's days coming up. The near ones
// (two weeks) stand first in the row of stories, and a touch opens them with a greeting card and a gift at hand; the
// calendar shows the next four months.
import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../people/cards.dart';
import '../people/my_space.dart';
import '../people/namedays.dart';
import '../people/profile_parts.dart';
import '../profile/profile.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// one friend's day: who, in how many days, the date, a birthday ('b') or an angel's day ('n') and its saint
typedef FriendDay = ({Profile p, int n, DateTime dt, String kind, String label});

/// friends' days within [days], the nearest first
Future<List<FriendDay>> upcomingDays(BuildContext context, int days) async {
  final app = context.app;
  final now = DateTime.now(), today = DateTime(now.year, now.month, now.day);
  final out = <FriendDay>[];
  void add(Profile p, int m, int d, String kind, String label) {
    var dt = DateTime(today.year, m, d);
    if (dt.isBefore(today)) dt = DateTime(today.year + 1, m, d);
    final n = dt.difference(today).inDays;
    if (n <= days) out.add((p: p, n: n, dt: dt, kind: kind, label: label));
  }

  try {
    for (final r in await app.api.friendBirthdays()) {
      final id = '${r['id']}';
      final known = app.people[id];
      final p = known ?? Profile(id: id, name: '${r['name'] ?? ''}', hue: r['hue'] is num ? (r['hue'] as num).toInt() : 210, avatarUrl: r['avatar_url'] as String?);
      if (known == null) app.people.put(p);
      add(p, (r['month'] as num?)?.toInt() ?? 1, (r['day'] as num?)?.toInt() ?? 1, 'b', 'დაბადების დღე');
    }
  } catch (_) {}
  if (!app.friends.loaded) await app.friends.load().catchError((_) {});
  await app.people.ensure(app.friends.friends);
  for (final id in app.friends.friends) {
    final p = app.people[id];
    if (p == null) continue;
    for (final (md, f) in nameDaysOf(p.name, p.nameday, p.namedayLabel)) {
      final x = md.split('-');
      add(p, int.tryParse(x.first) ?? 1, int.tryParse(x.length > 1 ? x[1] : '') ?? 1, 'n', f);
    }
  }
  out.sort((a, b) => a.n.compareTo(b.n));
  return out;
}

/// One friend's day: when, whose, and the greeting and the gift.
class FriendDayRow extends StatelessWidget {
  const FriendDayRow({super.key, required this.e});
  final FriendDay e;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        Avatar(p: e.p, size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${whenText(e.n)} · ${e.dt.day} ${monthNames[e.dt.month - 1]}', style: TextStyle(color: e.n == 0 ? c.accent : c.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
            Text(e.p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(e.kind == 'b' ? '🎂 დაბადების დღე' : '🕯 ანგელოზის დღე, ${e.label}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(width: 6),
        OutlinedButton(
          key: ValueKey('greet-${e.p.id}-${e.kind}'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
          onPressed: () => openCardPicker(context, uid: e.p.id, toName: e.p.name, kind: e.kind == 'b' ? 'b' : 'n'),
          child: const Text('მილოცვა'),
        ),
        IconBtn('gift', key: ValueKey('rgift-${e.p.id}'), label: 'საჩუქრის გაგზავნა', size: 20, onTap: () => giftSheet(context, e.p)),
      ]),
    );
  }
}

/// The reminders' ring in the row of stories: the nearest friend, "დღეს / ხვალ / N დღეში", and how many more.
class ReminderRing extends StatelessWidget {
  const ReminderRing({super.key, required this.days, required this.onTap});
  final List<FriendDay> days;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, e = days.first, today = days.any((x) => x.n == 0);
    final tag = today ? 'დღეს' : (e.n == 1 ? 'ხვალ' : '${e.n} დღეში');
    return Semantics(
      button: true,
      label: 'არ დაგავიწყდეს: ${days.length} მილოცვა, ${e.p.name} ${whenText(e.n)}',
      child: GestureDetector(
        key: const ValueKey('story-remind'),
        onTap: onTap,
        child: SizedBox(
          width: 76,
          child: Column(children: [
            SizedBox.square(
              dimension: 66,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 66,
                  height: 66,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: today ? [const Color(0xFFF59E0B), const Color(0xFFE11D48)] : [const Color(0xFFFBBF24), const Color(0xFFF59E0B)]),
                  ),
                  child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle), child: Avatar(p: e.p, size: 54)),
                ),
                Positioned(
                  left: -12,
                  right: -12,
                  bottom: -6,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: today ? const Color(0xFFE11D48) : const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(999), border: Border.all(color: c.bg, width: 2)),
                      child: Text(tag, maxLines: 1, softWrap: false, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                if (days.length > 1)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(999), border: Border.all(color: c.bg, width: 2)),
                      child: Text('+${days.length - 1}', style: TextStyle(color: c.bg, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 5),
            Text('${e.kind == 'b' ? '🎂' : '🕯'} ${e.p.name.split(' ').first}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

/// "არ დაგავიწყდეს": the near days, each with its greeting and gift; the whole calendar a tap further.
Future<void> remindersSheet(BuildContext context, List<FriendDay> days) => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) {
        final c = s.pc;
        return AppScope(app: context.app, me: context.me, child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(s).height * .8),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: [
              const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('არ დაგავიწყდეს', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              if (days.isEmpty)
                const Empty(icon: 'gift', title: 'ახლო დღეებში არაფერია', text: 'მეგობრების დაბადების და ანგელოზის დღეები აქ გამოჩნდება.')
              else
                for (final e in days) FriendDayRow(e: e),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: OutlinedButton.icon(
                  key: const ValueKey('rem-calendar'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  onPressed: () {
                    Navigator.of(s).pop();
                    openPage(context, const CalendarScreen(), full: true);
                  },
                  icon: PIcon('cal', size: 18, color: c.ink),
                  label: const Text('მთელი კალენდარი'),
                ),
              ),
            ]),
          ),
        ));
      },
    );

/// Friends' birthdays and angel's days in the next four months, by month.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<FriendDay>? days;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    upcomingDays(context, 120).then((d) {
      if (mounted) setState(() => days = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, d = days;
    final rows = <Widget>[];
    var m = -1;
    for (final e in d ?? const <FriendDay>[]) {
      if (e.dt.month != m) {
        m = e.dt.month;
        rows.add(Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text(monthNames[m - 1], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))));
      }
      rows.add(FriendDayRow(e: e));
    }
    return Scaffold(
      appBar: peeraBar(context, title: 'კალენდარი', actions: [
        TextButton.icon(
          onPressed: () => openPage(context, const NamedaysScreen()),
          icon: PIcon('cal', size: 18, color: c.accent),
          label: const Text('სახელის დღეები'),
        ),
      ]),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text('მეგობრების დაბადების დღეები და ანგელოზის დღეები მომდევნო 4 თვეში.', style: TextStyle(color: c.muted, fontSize: 13.5)),
              ),
              if (rows.isEmpty)
                Empty(icon: 'gift', title: 'ჯერ ცარიელია', text: 'დაამატე მეგობრები და მათი თარიღები აქ გამოჩნდება.', action: 'მეგობრების პოვნა', onAction: () {
                  Navigator.of(context).maybePop();
                  context.app.goTab?.call('friends');
                })
              else
                ...rows,
            ]),
    );
  }
}
