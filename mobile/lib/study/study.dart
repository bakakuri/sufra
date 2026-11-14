// Study (study.js): the study page with what is on today and the near deadlines; the lecture timetable by weekday
// (kind, days, time, room, teacher, odd or even weeks, a colour, for me or a group); exams and assignments with how
// long is left and a tick when done; notes (#კონსპექტი) and study tips (#რჩევა) gathered from posts by subject.
// A class's or a course's timetable is shared with all its members; someone else's row shows who added it and the
// group's admin may remove it.
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../feed/post_card.dart';
import '../people/edu.dart';
import '../people/person_screen.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const kDays = ['ორშ', 'სამ', 'ოთხ', 'ხუთ', 'პარ', 'შაბ', 'კვ'];
const kDayNames = ['ორშაბათი', 'სამშაბათი', 'ოთხშაბათი', 'ხუთშაბათი', 'პარასკევი', 'შაბათი', 'კვირა'];
const lessonKinds = [('lecture', 'ლექცია'), ('seminar', 'სემინარი'), ('lab', 'ლაბორატორია'), ('lesson', 'გაკვეთილი'), ('other', 'სხვა')];
const lessonHues = [250, 200, 160, 20, 330, 45];
const deadlineKinds = [('exam', 'გამოცდა', '🎓'), ('midterm', 'შუალედური', '📝'), ('quiz', 'ქვიზი', '❓'), ('task', 'დავალება', '✏️'), ('project', 'პროექტი', '📁')];

typedef StudyGroup = ({int id, String name, String kind, bool admin, bool share});

String _hm(Object? t) {
  final s = '${t ?? ''}';
  return s.length >= 5 ? s.substring(0, 5) : s;
}

int _mins(Object? t) {
  final p = _hm(t).split(':');
  return (int.tryParse(p.first) ?? 0) * 60 + (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
}

int _isoWeek(DateTime d) {
  final t = DateTime.utc(d.year, d.month, d.day);
  final th = t.add(Duration(days: 4 - (t.weekday)));
  final y = DateTime.utc(th.year, 1, 1);
  return ((th.difference(y).inDays) / 7).floor() + 1;
}

bool weekOk(Map<String, dynamic> l, [DateTime? d]) {
  final w = '${l['weeks'] ?? 'all'}';
  if (w == 'all' || w.isEmpty) return true;
  return (_isoWeek(d ?? DateTime.now()).isOdd) == (w == 'odd');
}

/// "on Monday": ორშაბათს, კვირას
String onDay(int d) {
  final n = kDayNames[(d - 1).clamp(0, 6)];
  return n.endsWith('ი') ? '${n.substring(0, n.length - 1)}ს' : '$nს';
}

String lessonKindName(Object? k) => lessonKinds.firstWhere((x) => x.$1 == k, orElse: () => lessonKinds.first).$2;
(String, String, String) deadlineKind(Object? k) => deadlineKinds.firstWhere((x) => x.$1 == k, orElse: () => deadlineKinds[3]);

/// how long until a deadline: the words and how urgent ('late', 'soon', 'week', '')
(String, String) dueText(DateTime d, [DateTime? at]) {
  final now = at ?? DateTime.now();
  final days = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (d.isBefore(now)) return ('ვადა გავიდა', 'late');
  if (days == 0) return ('დღეს ${hhmm(d)}', 'soon');
  if (days == 1) return ('ხვალ ${hhmm(d)}', 'soon');
  if (days < 7) return ('$days დღეში', 'week');
  return ('${d.day} ${months[d.month - 1].characters.take(3)}', '');
}

Color _hueColor(int h, [double l = .5]) => HSLColor.fromAHSL(1, (h % 360).toDouble(), .55, l).toColor();

/// One lesson in a list: the time, the subject, its kind, room and teacher, the group it came from.
class LessonRow extends StatelessWidget {
  const LessonRow({super.key, required this.l, required this.groups, required this.onTap, this.big = false});
  final Map<String, dynamic> l;
  final List<StudyGroup> groups;
  final VoidCallback onTap;
  final bool big;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, hue = asInt(l['hue'], 250), gid = l['group_id'];
    final sub = [lessonKindName(l['kind']), '${l['place'] ?? ''}', '${l['teacher'] ?? ''}'].where((x) => x.isNotEmpty).join(' · ');
    final w = '${l['weeks'] ?? 'all'}';
    return InkWell(
      key: ValueKey('lesson-${l['id']}'),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: EdgeInsets.all(big ? 14 : 11),
        decoration: BoxDecoration(
          color: _hueColor(hue).withValues(alpha: .1),
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: _hueColor(hue), width: 4)),
        ),
        child: Row(children: [
          SizedBox(
            width: 52,
            child: Column(children: [
              Text(_hm(l['starts']), style: TextStyle(fontWeight: FontWeight.w900, fontSize: big ? 17 : 15)),
              Text(_hm(l['ends']), style: TextStyle(color: c.muted, fontSize: 12.5)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${l['title'] ?? ''}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: big ? 17 : 15)),
              Text('$sub${w != 'all' ? ' · ${w == 'odd' ? 'კენტ კვირებში' : 'ლუწ კვირებში'}' : ''}', style: TextStyle(color: c.muted, fontSize: 13)),
              if (gid != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(children: [
                    PIcon('users', size: 13, color: c.accent),
                    const SizedBox(width: 4),
                    Flexible(child: Text(groups.where((g) => g.id == asInt(gid)).firstOrNull?.name ?? 'ჯგუფი', style: TextStyle(color: c.accent, fontSize: 12.5, fontWeight: FontWeight.w700))),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// One deadline: the tick, what it is, how long is left.
class DeadlineRow extends StatelessWidget {
  const DeadlineRow({super.key, required this.x, required this.done, required this.groups, required this.onTap, required this.onTick});
  final Map<String, dynamic> x;
  final bool done;
  final List<StudyGroup> groups;
  final VoidCallback onTap, onTick;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, k = deadlineKind(x['kind']), at = asTime(x['due_at']).toLocal();
    final (w, cls) = dueText(at);
    final col = done ? c.vine : (cls == 'late' ? c.nope : (cls == 'soon' ? c.gold : (cls == 'week' ? c.accent : c.muted)));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(children: [
        IconButton(
          key: ValueKey('dl-tick-${x['id']}'),
          tooltip: done ? 'შესრულებულია' : 'შესრულებულად მონიშვნა',
          onPressed: onTick,
          icon: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(shape: BoxShape.circle, color: done ? c.vine : Colors.transparent, border: Border.all(color: done ? c.vine : c.line, width: 2)),
            child: done ? const PIcon('check', size: 15, color: Colors.white, stroke: 2.6) : null,
          ),
        ),
        Expanded(
          child: InkWell(
            key: ValueKey('dl-${x['id']}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Text(k.$3, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${x['title'] ?? ''}',
                        style: TextStyle(fontWeight: FontWeight.w800, decoration: done ? TextDecoration.lineThrough : null, color: done ? c.muted : c.ink)),
                    Text('${k.$2}${'${x['subject'] ?? ''}'.isEmpty ? '' : ' · ${x['subject']}'} · ${fullDate(at)}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                    if (x['group_id'] != null)
                      Text('👥 ${groups.where((g) => g.id == asInt(x['group_id'])).firstOrNull?.name ?? 'ჯგუფი'}', style: TextStyle(color: c.accent, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: 6),
                Text(done ? 'შესრულდა' : w, style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The study page.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});
  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  List<Map<String, dynamic>>? lessons, deadlines;
  Set<int> done = {};
  List<StudyGroup> groups = const [];
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final api = context.app.api;
    try {
      final r = await Future.wait([api.lessons(), api.deadlines()]);
      final d = await api.deadlinesDone().catchError((_) => <int>{});
      final g = await api.studyGroups().catchError((_) => <StudyGroup>[]);
      if (mounted) {
        setState(() {
          lessons = r[0];
          deadlines = r[1];
          done = d;
          groups = g;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          lessons ??= [];
          deadlines ??= [];
        });
        toast(context, errText(e));
      }
    }
  }

  Future<void> _add() async {
    final c = context.pc;
    final k = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text('რა დავამატო?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))),
          for (final (key, icon, t, sub) in [
            ('lesson', 'cal', 'ლექცია ცხრილში', 'დღე, დრო, აუდიტორია, ლექტორი'),
            ('deadline', 'clock', 'გამოცდა ან დავალება', 'ვადით და შეხსენებით'),
            ('note', 'book', 'კონსპექტი', 'ფოტო, ტექსტი, საგანი'),
            ('edu', 'school', 'სკოლა ან უნივერსიტეტი', 'კლასელებისა და კურსელების საპოვნელად'),
          ])
            ListTile(
              key: ValueKey('ka-$key'),
              leading: PIcon(icon, color: s.pc.accent),
              title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(sub),
              onTap: () => Navigator.of(s).pop(key),
            ),
        ]),
      ),
    );
    if (k == null || !mounted) return;
    switch (k) {
      case 'lesson':
        await openPage(context, LessonFormScreen(groups: groups), full: true);
      case 'deadline':
        await openPage(context, DeadlineFormScreen(groups: groups, subjects: [for (final l in lessons ?? const []) '${l['title']}']), full: true);
      case 'note':
        await openPage(context, const ComposeScreen(text: '\n\n#კონსპექტი'), full: true);
      case 'edu':
        await openPage(context, const EduScreen(), full: true);
    }
    _load();
  }

  Future<void> _tick(Map<String, dynamic> x) async {
    final id = asInt(x['id']), on = !done.contains(id);
    setState(() => on ? done.add(id) : done.remove(id));
    try {
      await context.app.api.markDeadline(id, on);
      if (on && mounted) toast(context, 'ყოჩაღ! შესრულდა ✓');
    } catch (e) {
      if (!mounted) return;
      setState(() => on ? done.remove(id) : done.add(id));
      toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, now = DateTime.now(), me = context.me;
    final d = now.weekday, m = now.hour * 60 + now.minute;
    final today = [for (final l in lessons ?? const <Map<String, dynamic>>[]) if (asInt(l['day']) == d && weekOk(l, now)) l]..sort((a, b) => _mins(a['starts']).compareTo(_mins(b['starts'])));
    final cur = today.where((l) => _mins(l['starts']) <= m && _mins(l['ends']) > m).firstOrNull;
    final next = today.where((l) => _mins(l['starts']) > m).firstOrNull;
    final up = [
      for (final x in deadlines ?? const <Map<String, dynamic>>[])
        if (!done.contains(asInt(x['id'])) && asTime(x['due_at']).isAfter(now.subtract(const Duration(days: 1)))) x,
    ]..sort((a, b) => asTime(a['due_at']).compareTo(asTime(b['due_at'])));
    Widget card(Widget child) => Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
          child: child,
        );
    Widget head(String t, String? more, VoidCallback? onMore) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
          child: Row(children: [
            Expanded(child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            if (more != null) TextButton(onPressed: onMore, child: Text(more)),
          ]),
        );
    Future<void> openLesson(Map<String, dynamic> l) async {
      await openLessonRow(context, l, groups);
      _load();
    }

    final tiles = [
      ('schedule', 'cal', 'ლექციების ცხრილი', 'კვირის ცხრილი', 250),
      ('exams', 'clock', 'გამოცდები და დავალებები', 'ვადები და შეხსენებები', 20),
      ('notes', 'book', 'კონსპექტები', 'ჩანაწერები და ფოტოები', 160),
      ('classmates', 'school', 'კლასელები და კურსელები', 'სკოლა და უნივერსიტეტი', 200),
      ('tips', 'help', 'სასწავლო რჩევები', 'როგორ ვისწავლოთ', 40),
    ];
    return Scaffold(
      appBar: peeraBar(context, title: 'სწავლა', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: FilledButton.icon(
            key: const ValueKey('study-add'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: _add,
            icon: PIcon('plus', size: 17, color: c.onAccent),
            label: const Text('დამატება'),
          ),
        ),
      ]),
      body: lessons == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text('${kDayNames[d - 1]}, ${now.day} ${months[now.month - 1]}', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
                ),
                card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (lessons!.isEmpty) ...[
                    head('დაამატე ლექციების ცხრილი', null, null),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('ყოველ დილით აქ გამოჩნდება, რა გელოდება დღეს.', style: TextStyle(color: c.muted))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          key: const ValueKey('study-first-lesson'),
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                          onPressed: () async {
                            await openPage(context, LessonFormScreen(groups: groups), full: true);
                            _load();
                          },
                          icon: PIcon('plus', size: 16, color: c.onAccent),
                          label: const Text('ლექციის დამატება'),
                        ),
                      ),
                    ),
                  ] else ...[
                    head('დღეს', 'მთელი ცხრილი', () async {
                      await openPage(context, ScheduleScreen(groups: groups), full: true);
                      _load();
                    }),
                    if (cur != null) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: Row(children: [PIcon('live', size: 15, color: c.nope), const SizedBox(width: 5), Text('ახლა მიმდინარეობს', style: TextStyle(color: c.nope, fontWeight: FontWeight.w800, fontSize: 13))]),
                      ),
                      LessonRow(l: cur, groups: groups, big: true, onTap: () => openLesson(cur)),
                    ],
                    if (next != null) ...[
                      if (cur != null) Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 2), child: Text('შემდეგი', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700))),
                      LessonRow(l: next, groups: groups, big: cur == null, onTap: () => openLesson(next)),
                    ],
                    if (cur == null && next == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(today.isNotEmpty ? 'დღევანდელი ლექციები დასრულდა. დაისვენე! 🎉' : 'დღეს ლექციები არ გაქვს.', style: TextStyle(color: c.muted)),
                      ),
                    for (final l in today.where((l) => l != cur && l != next && _mins(l['starts']) > m).take(3)) LessonRow(l: l, groups: groups, onTap: () => openLesson(l)),
                  ],
                ])),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.7,
                    children: [
                      for (final (k, icon, t, sub, hue) in tiles)
                        Material(
                          color: _hueColor(hue).withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            key: ValueKey('kt-$k'),
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              final Widget page = switch (k) {
                                'schedule' => ScheduleScreen(groups: groups),
                                'exams' => ExamsScreen(groups: groups),
                                'notes' => const LibraryScreen(kind: 'notes'),
                                'tips' => const LibraryScreen(kind: 'tips'),
                                _ => me.edu.isEmpty ? const EduScreen() : const ClassmatesScreen(),
                              };
                              await openPage(context, page, full: true);
                              _load();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                                PIcon(icon, size: 22, color: _hueColor(hue, .42)),
                                const SizedBox(height: 4),
                                Text(t, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 11.5)),
                              ]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  head('ვადები', 'ყველა', () async {
                    await openPage(context, ExamsScreen(groups: groups), full: true);
                    _load();
                  }),
                  if (up.isEmpty)
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('ახლო ვადები არ გაქვს.', style: TextStyle(color: c.muted)))
                  else
                    for (final x in up.take(3))
                      DeadlineRow(
                        x: x,
                        done: false,
                        groups: groups,
                        onTick: () => _tick(x),
                        onTap: () async {
                          await openDeadlineRow(context, x, groups, [for (final l in lessons!) '${l['title']}']);
                          _load();
                        },
                      ),
                ])),
              ]),
            ),
    );
  }
}

/// a lesson touched: mine opens to be changed; someone else's (from a group) says who added it
Future<void> openLessonRow(BuildContext context, Map<String, dynamic> l, List<StudyGroup> groups) async {
  final me = context.me.id;
  if (l['owner'] == null || l['owner'] == me) {
    await openPage(context, LessonFormScreen(l: l, groups: groups), full: true);
  } else {
    await _info(context, 'lessons', l, groups);
  }
}

Future<void> openDeadlineRow(BuildContext context, Map<String, dynamic> x, List<StudyGroup> groups, List<String> subjects) async {
  final me = context.me.id;
  if (x['owner'] == null || x['owner'] == me) {
    await openPage(context, DeadlineFormScreen(x: x, groups: groups, subjects: subjects), full: true);
  } else {
    await _info(context, 'deadlines', x, groups);
  }
}

/// someone else's lesson or deadline on a group's timetable: what it is, who added it; the group's admin may remove it
Future<void> _info(BuildContext context, String kind, Map<String, dynamic> x, List<StudyGroup> groups) async {
  final app = context.app, isL = kind == 'lessons', owner = '${x['owner']}';
  await app.people.ensure([owner]);
  if (!context.mounted) return;
  final g = groups.where((y) => y.id == asInt(x['group_id'])).firstOrNull;
  final k = deadlineKind(x['kind']);
  final sub = isL
      ? '${kDayNames[(asInt(x['day'], 1) - 1).clamp(0, 6)]}, ${_hm(x['starts'])}–${_hm(x['ends'])} · ${lessonKindName(x['kind'])}${'${x['place'] ?? ''}'.isEmpty ? '' : ' · ${x['place']}'}${'${x['teacher'] ?? ''}'.isEmpty ? '' : ' · ${x['teacher']}'}'
      : '${k.$2}${'${x['subject'] ?? ''}'.isEmpty ? '' : ' · ${x['subject']}'} · ${fullDate(asTime(x['due_at']).toLocal())} · ${dueText(asTime(x['due_at']).toLocal()).$1}';
  final del = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) {
      final c = s.pc, p = app.people[owner] ?? Profile(id: owner, name: '…');
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isL ? 'ჯგუფის ლექცია' : 'ჯგუფის ვადა', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${isL ? '' : '${k.$3} '}${x['title'] ?? ''}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(color: c.muted)),
            if (!isL && '${x['notes'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${x['notes']}')),
            const SizedBox(height: 10),
            if (g != null) Text('👥 ${g.name}', style: TextStyle(color: c.accent, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            InkWell(
              onTap: () {
                Navigator.of(s).pop();
                openPage(context, PersonScreen(uid: owner, initial: p), full: true);
              },
              child: Text('დაამატა ${p.name}. შეცვლა მხოლოდ მას შეუძლია${g != null && g.admin ? ', წაშლა კი ჯგუფის ადმინსაც' : ''}.', style: TextStyle(color: c.muted, fontSize: 13)),
            ),
            if (g != null && g.admin) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('ku-del'),
                style: OutlinedButton.styleFrom(foregroundColor: c.nope),
                onPressed: () => Navigator.of(s).pop(true),
                icon: PIcon('trash', size: 17, color: c.nope),
                label: const Text('ჯგუფიდან წაშლა'),
              ),
            ],
          ]),
        ),
      );
    },
  );
  if (del != true || !context.mounted) return;
  if (!await confirm(context, title: 'წაშლა', text: '„${x['title']}“ ჯგუფის ${isL ? 'ცხრილიდან' : 'ვადებიდან'} წაიშლება ყველასთვის.', yes: 'წაშლა', danger: true) || !context.mounted) return;
  if (await attempt(context, () => isL ? app.api.deleteLesson(asInt(x['id'])) : app.api.deleteDeadline(asInt(x['id']))) && context.mounted) toast(context, 'წაიშალა');
}

/// The timetable: the week's days, the chosen day's lessons, and whose (all, mine, a group's).
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, this.groups});

  /// my classes and courses (loaded here when opened on its own)
  final List<StudyGroup>? groups;
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int day = DateTime.now().weekday;
  String whose = '';
  List<Map<String, dynamic>>? rows;
  late List<StudyGroup> groups = widget.groups ?? const [];
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final api = context.app.api;
    try {
      final r = await api.lessons();
      if (widget.groups == null) groups = await api.studyGroups().catchError((_) => <StudyGroup>[]);
      if (mounted) setState(() => rows = r);
    } catch (e) {
      if (mounted) {
        setState(() => rows ??= []);
        toast(context, errText(e));
      }
    }
  }

  bool _fits(Map<String, dynamic> x) => whose.isEmpty || (whose == 'me' ? x['group_id'] == null : asInt(x['group_id']) == int.tryParse(whose));

  @override
  Widget build(BuildContext context) {
    final c = context.pc, all = rows ?? const <Map<String, dynamic>>[];
    final gids = {for (final x in all) if (x['group_id'] != null) asInt(x['group_id'])};
    final list = [for (final x in all) if (asInt(x['day']) == day && _fits(x)) x]..sort((a, b) => _mins(a['starts']).compareTo(_mins(b['starts'])));
    return Scaffold(
      appBar: peeraBar(context, title: 'ლექციების ცხრილი', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: FilledButton.icon(
            key: const ValueKey('sch-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: () async {
              await openPage(context, LessonFormScreen(groups: groups, day: day), full: true);
              _load();
            },
            icon: PIcon('plus', size: 17, color: c.onAccent),
            label: const Text('ახალი'),
          ),
        ),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(children: [
            for (var i = 1; i <= 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Material(
                    color: day == i ? c.accent : (i == DateTime.now().weekday ? c.accentSoft : c.sunk),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      key: ValueKey('sday-$i'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => day = i),
                      child: SizedBox(
                        height: 40,
                        child: Center(child: Text(kDays[i - 1], style: TextStyle(color: day == i ? c.onAccent : c.ink, fontWeight: FontWeight.w800, fontSize: 13))),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        if (gids.isNotEmpty)
          SizedBox(
            height: 46,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 4, 12, 4), children: [
              for (final (v, n) in [('', 'ყველა'), ('me', 'ჩემი'), for (final g in gids) ('$g', groups.where((x) => x.id == g).firstOrNull?.name ?? 'ჯგუფი')])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: ValueKey('sgf-$v'),
                    label: Text(n),
                    selected: whose == v,
                    showCheckmark: false,
                    selectedColor: c.accentSoft,
                    side: BorderSide(color: whose == v ? c.accent : c.line),
                    onSelected: (_) => setState(() => whose = v),
                  ),
                ),
            ]),
          ),
        Expanded(
          child: rows == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.only(top: 6, bottom: 24), children: [
                    if (list.isEmpty)
                      Empty(
                        icon: 'cal',
                        title: '${onDay(day)} ლექცია არ გაქვს',
                        text: all.isNotEmpty ? 'სხვა დღეს აირჩიე ან დაამატე ახალი.' : 'დაამატე პირველი ლექცია: საგანი, დრო, აუდიტორია.',
                      )
                    else
                      for (final l in list)
                        LessonRow(
                          l: l,
                          groups: groups,
                          onTap: () async {
                            await openLessonRow(context, l, groups);
                            _load();
                          },
                        ),
                    if (all.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('სულ ${all.length} ლექცია კვირაში', style: TextStyle(color: c.muted))),
                  ]),
                ),
        ),
      ]),
    );
  }
}

/// A new lesson (on one or more days) or one of mine changed.
class LessonFormScreen extends StatefulWidget {
  const LessonFormScreen({super.key, this.l, required this.groups, this.day});
  final Map<String, dynamic>? l;
  final List<StudyGroup> groups;
  final int? day;
  @override
  State<LessonFormScreen> createState() => _LessonFormScreenState();
}

class _LessonFormScreenState extends State<LessonFormScreen> {
  late final l = widget.l;
  late final title = TextEditingController(text: '${l?['title'] ?? ''}');
  late final place = TextEditingController(text: '${l?['place'] ?? ''}');
  late final teacher = TextEditingController(text: '${l?['teacher'] ?? ''}');
  late String kind = '${l?['kind'] ?? 'lecture'}', weeks = '${l?['weeks'] ?? 'all'}';
  late int hue = asInt(l?['hue'], 250);
  late final days = <int>{asInt(l?['day'], widget.day ?? DateTime.now().weekday)};
  late TimeOfDay starts = _t(l?['starts'], const TimeOfDay(hour: 10, minute: 0)), ends = _t(l?['ends'], const TimeOfDay(hour: 11, minute: 30));
  late int? group = l?['group_id'] == null ? null : asInt(l!['group_id']);
  bool busy = false;

  bool get edit => l != null;

  static TimeOfDay _t(Object? v, TimeOfDay d) {
    final s = _hm(v);
    if (s.length < 5) return d;
    return TimeOfDay(hour: int.tryParse(s.substring(0, 2)) ?? d.hour, minute: int.tryParse(s.substring(3, 5)) ?? d.minute);
  }

  static String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    title.dispose();
    place.dispose();
    teacher.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = title.text.trim();
    if (t.isEmpty) {
      toast(context, 'ჩაწერე საგანი');
      return;
    }
    if (ends.hour * 60 + ends.minute <= starts.hour * 60 + starts.minute) {
      toast(context, 'დასრულების დრო დაწყებაზე გვიან უნდა იყოს');
      return;
    }
    final api = context.app.api;
    final base = <String, dynamic>{'title': t, 'kind': kind, 'starts': _fmt(starts), 'ends': _fmt(ends), 'place': place.text.trim(), 'teacher': teacher.text.trim(), 'weeks': weeks, 'hue': hue, 'group_id': group};
    setState(() => busy = true);
    try {
      if (edit) {
        await api.putLesson({...l!, ...base, 'day': days.first});
      } else {
        for (final d in days.toList()..sort()) {
          await api.putLesson({...base, 'day': d});
        }
      }
      if (!mounted) return;
      toast(context, edit ? 'შენახულია' : (days.length > 1 ? '${group != null ? 'ჯგუფის ცხრილში ' : ''}დაემატა ${days.length} დღეს' : (group != null ? 'დაემატა ჯგუფის ცხრილში' : 'დაემატა ცხრილში')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e));
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, title: 'ლექციის წაშლა', text: '„${l!['title']}“ ცხრილიდან წაიშლება.', yes: 'წაშლა', danger: true) || !mounted) return;
    if (await attempt(context, () => context.app.api.deleteLesson(asInt(l!['id']))) && mounted) {
      toast(context, 'წაიშალა');
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, gs = [for (final g in widget.groups) if (g.share || g.id == group) g];
    Widget label(String t) => Padding(padding: const EdgeInsets.fromLTRB(0, 14, 0, 6), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)));
    Widget chip(String key, String text, bool on, VoidCallback tap) => ChoiceChip(
          key: ValueKey(key),
          label: Text(text),
          selected: on,
          showCheckmark: false,
          selectedColor: c.accentSoft,
          side: BorderSide(color: on ? c.accent : c.line),
          onSelected: (_) => tap(),
        );
    return Scaffold(
      appBar: peeraBar(context, title: edit ? 'ლექციის რედაქტირება' : 'ახალი ლექცია', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(key: const ValueKey('ls-ok'), style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: busy ? null : _save, child: const Text('შენახვა')),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(key: const ValueKey('ls-title'), controller: title, maxLength: 80, decoration: const InputDecoration(labelText: 'საგანი', hintText: 'მაგ. მაკროეკონომიკა', counterText: '')),
        label('ტიპი'),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final (k, n) in lessonKinds) chip('lsk-$k', n, kind == k, () => setState(() => kind = k))]),
        label(edit ? 'დღე' : 'დღეები'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 1; i <= 7; i++)
            chip('lsd-$i', kDays[i - 1], days.contains(i), () {
              setState(() {
                if (edit) {
                  days
                    ..clear()
                    ..add(i);
                } else if (days.contains(i) && days.length > 1) {
                  days.remove(i);
                } else {
                  days.add(i);
                }
              });
            }),
        ]),
        label('დრო'),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('ls-starts'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: starts);
                if (t != null) setState(() => starts = t);
              },
              child: Text('იწყება ${_fmt(starts)}'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('ls-ends'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: ends);
                if (t != null) setState(() => ends = t);
              },
              child: Text('მთავრდება ${_fmt(ends)}'),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(key: const ValueKey('ls-place'), controller: place, maxLength: 60, decoration: const InputDecoration(labelText: 'აუდიტორია ან ოთახი', hintText: 'მაგ. II კორპუსი, 312', counterText: '')),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('ls-teacher'), controller: teacher, maxLength: 60, decoration: const InputDecoration(labelText: 'ლექტორი ან მასწავლებელი', hintText: 'მაგ. ნ. ბერიძე', counterText: '')),
        label('რომელ კვირებში'),
        SegmentedButton<String>(
          key: const ValueKey('ls-weeks'),
          showSelectedIcon: false,
          segments: const [ButtonSegment(value: 'all', label: Text('ყოველ კვირა')), ButtonSegment(value: 'odd', label: Text('კენტში')), ButtonSegment(value: 'even', label: Text('ლუწში'))],
          selected: {weeks},
          onSelectionChanged: (v) => setState(() => weeks = v.first),
        ),
        label('ფერი'),
        Row(children: [
          for (final h in lessonHues)
            GestureDetector(
              key: ValueKey('lsh-$h'),
              onTap: () => setState(() => hue = h),
              child: Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: _hueColor(h), shape: BoxShape.circle, border: Border.all(color: hue == h ? c.ink : Colors.transparent, width: 2.4)),
              ),
            ),
        ]),
        if (gs.isNotEmpty) ...[
          label('ვისთვის'),
          DropdownButtonFormField<int?>(
            key: const ValueKey('ls-for'),
            isExpanded: true,
            initialValue: group,
            items: [const DropdownMenuItem<int?>(value: null, child: Text('მხოლოდ ჩემთვის')), for (final g in gs) DropdownMenuItem<int?>(value: g.id, child: Text(g.name, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => group = v),
          ),
          Padding(padding: const EdgeInsets.only(top: 4), child: Text('ჯგუფს თუ აირჩევ, ყველა წევრი დაინახავს და შეხსენებასაც მიიღებს.', style: TextStyle(color: c.muted, fontSize: 12.5))),
        ],
        if (edit) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            key: const ValueKey('ls-del'),
            style: OutlinedButton.styleFrom(foregroundColor: c.nope),
            onPressed: busy ? null : _delete,
            icon: PIcon('trash', size: 17, color: c.nope),
            label: const Text('წაშლა'),
          ),
        ],
      ]),
    );
  }
}

/// Exams and assignments: the coming ones (late, this week, later) or the done ones; whose.
class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key, this.groups});

  /// my classes and courses (loaded here when opened on its own)
  final List<StudyGroup>? groups;
  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  List<Map<String, dynamic>>? rows;
  late List<StudyGroup> groups = widget.groups ?? const [];
  List<String> subjects = const [];
  Set<int> done = {};
  bool showDone = false;
  String whose = '';
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final api = context.app.api;
    try {
      final r = await api.deadlines();
      final d = await api.deadlinesDone().catchError((_) => <int>{});
      final l = await api.lessons().catchError((_) => <Map<String, dynamic>>[]);
      if (widget.groups == null) groups = await api.studyGroups().catchError((_) => <StudyGroup>[]);
      if (mounted) {
        setState(() {
          rows = r;
          done = d;
          subjects = {for (final x in l) '${x['title']}'}.take(30).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => rows ??= []);
        toast(context, errText(e));
      }
    }
  }

  Future<void> _tick(Map<String, dynamic> x) async {
    final id = asInt(x['id']), on = !done.contains(id);
    setState(() => on ? done.add(id) : done.remove(id));
    try {
      await context.app.api.markDeadline(id, on);
      if (on && mounted) toast(context, 'ყოჩაღ! შესრულდა ✓');
    } catch (e) {
      if (!mounted) return;
      setState(() => on ? done.remove(id) : done.add(id));
      toast(context, errText(e));
    }
  }

  bool _fits(Map<String, dynamic> x) => whose.isEmpty || (whose == 'me' ? x['group_id'] == null : asInt(x['group_id']) == int.tryParse(whose));

  @override
  Widget build(BuildContext context) {
    final c = context.pc, now = DateTime.now(), all = [for (final x in rows ?? const <Map<String, dynamic>>[]) if (_fits(x)) x]
      ..sort((a, b) => asTime(a['due_at']).compareTo(asTime(b['due_at'])));
    final gids = {for (final x in rows ?? const <Map<String, dynamic>>[]) if (x['group_id'] != null) asInt(x['group_id'])};
    Widget row(Map<String, dynamic> x, bool d) => DeadlineRow(
          x: x,
          done: d,
          groups: groups,
          onTick: () => _tick(x),
          onTap: () async {
            await openDeadlineRow(context, x, groups, subjects);
            _load();
          },
        );
    Widget sec(String t, List<Map<String, dynamic>> l) => l.isEmpty
        ? const SizedBox.shrink()
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 2), child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            for (final x in l) row(x, false),
          ]);
    final open = [for (final x in all) if (!done.contains(asInt(x['id']))) x];
    final late = [for (final x in open) if (asTime(x['due_at']).isBefore(now)) x];
    final week = [for (final x in open) if (!asTime(x['due_at']).isBefore(now) && asTime(x['due_at']).isBefore(now.add(const Duration(days: 7)))) x];
    final later = [for (final x in open) if (!asTime(x['due_at']).isBefore(now.add(const Duration(days: 7)))) x];
    final doneL = [for (final x in all.reversed) if (done.contains(asInt(x['id']))) x];
    return Scaffold(
      appBar: peeraBar(context, title: 'გამოცდები და დავალებები', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: FilledButton.icon(
            key: const ValueKey('dl-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: () async {
              await openPage(context, DeadlineFormScreen(groups: groups, subjects: subjects), full: true);
              _load();
            },
            icon: PIcon('plus', size: 17, color: c.onAccent),
            label: const Text('ახალი'),
          ),
        ),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: SegmentedButton<bool>(
            key: const ValueKey('dl-seg'),
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: false, label: Text('მომავალი')), ButtonSegment(value: true, label: Text('შესრულებული'))],
            selected: {showDone},
            onSelectionChanged: (v) => setState(() => showDone = v.first),
          ),
        ),
        if (gids.isNotEmpty)
          SizedBox(
            height: 46,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 4, 12, 4), children: [
              for (final (v, n) in [('', 'ყველა'), ('me', 'ჩემი'), for (final g in gids) ('$g', groups.where((x) => x.id == g).firstOrNull?.name ?? 'ჯგუფი')])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: ValueKey('dgf-$v'),
                    label: Text(n),
                    selected: whose == v,
                    showCheckmark: false,
                    selectedColor: c.accentSoft,
                    side: BorderSide(color: whose == v ? c.accent : c.line),
                    onSelected: (_) => setState(() => whose = v),
                  ),
                ),
            ]),
          ),
        Expanded(
          child: rows == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                    if (showDone) ...[
                      if (doneL.isEmpty) const Empty(icon: 'check', title: 'ჯერ არაფერი შეგისრულებია', text: 'მონიშნე დავალება შესრულებულად და აქ გადმოვა.'),
                      for (final x in doneL) row(x, true),
                    ] else if (open.isEmpty)
                      const Empty(icon: 'clock', title: 'ვადები არ გაქვს', text: 'დაამატე გამოცდა, შუალედური ან დავალება და გეტყვით, რამდენი დღე დარჩა.')
                    else ...[
                      sec('ვადა გავიდა', late),
                      sec('ამ კვირაში', week),
                      sec('მოგვიანებით', later),
                    ],
                  ]),
                ),
        ),
      ]),
    );
  }
}

/// A new exam or assignment, or one of mine changed: the kind, the title, the subject (from the timetable), the day
/// and hour, a note, for me or a group.
class DeadlineFormScreen extends StatefulWidget {
  const DeadlineFormScreen({super.key, this.x, required this.groups, this.subjects = const []});
  final Map<String, dynamic>? x;
  final List<StudyGroup> groups;
  final List<String> subjects;
  @override
  State<DeadlineFormScreen> createState() => _DeadlineFormScreenState();
}

class _DeadlineFormScreenState extends State<DeadlineFormScreen> {
  late final x = widget.x;
  late final title = TextEditingController(text: '${x?['title'] ?? ''}');
  late final subject = TextEditingController(text: '${x?['subject'] ?? ''}');
  late final notes = TextEditingController(text: '${x?['notes'] ?? ''}');
  late String kind = '${x?['kind'] ?? 'exam'}';
  late DateTime due = x == null
      ? () {
          final d = DateTime.now().add(const Duration(days: 3));
          return DateTime(d.year, d.month, d.day, 10);
        }()
      : asTime(x!['due_at']).toLocal();
  late int? group = x?['group_id'] == null ? null : asInt(x!['group_id']);
  bool busy = false;

  bool get edit => x != null;

  @override
  void dispose() {
    title.dispose();
    subject.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = title.text.trim();
    if (t.isEmpty) {
      toast(context, 'ჩაწერე სათაური');
      return;
    }
    setState(() => busy = true);
    try {
      await context.app.api.putDeadline({
        ...?x,
        'kind': kind,
        'title': t,
        'subject': subject.text.trim(),
        'due_at': due.toUtc().toIso8601String(),
        'notes': notes.text.trim(),
        'group_id': group,
      });
      if (!mounted) return;
      toast(context, edit ? 'შენახულია' : (group != null ? 'დაემატა, ჯგუფის წევრებს ეცნობებათ' : 'დაემატა'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e));
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, title: 'წაშლა', text: '„${x!['title']}“ წაიშლება.', yes: 'წაშლა', danger: true) || !mounted) return;
    if (await attempt(context, () => context.app.api.deleteDeadline(asInt(x!['id']))) && mounted) {
      toast(context, 'წაიშალა');
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, gs = [for (final g in widget.groups) if (g.share || g.id == group) g];
    return Scaffold(
      appBar: peeraBar(context, title: edit ? 'რედაქტირება' : 'გამოცდა ან დავალება', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(key: const ValueKey('dl-ok'), style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: busy ? null : _save, child: const Text('შენახვა')),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (k, n, e) in deadlineKinds)
            ChoiceChip(
              key: ValueKey('dlk-$k'),
              label: Text('$e $n'),
              selected: kind == k,
              showCheckmark: false,
              selectedColor: c.accentSoft,
              side: BorderSide(color: kind == k ? c.accent : c.line),
              onSelected: (_) => setState(() => kind = k),
            ),
        ]),
        const SizedBox(height: 12),
        TextField(key: const ValueKey('dl-title'), controller: title, maxLength: 120, decoration: const InputDecoration(labelText: 'სათაური', hintText: 'მაგ. შუალედური: თავები 1–4', counterText: '')),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('dl-subject'), controller: subject, maxLength: 80, decoration: const InputDecoration(labelText: 'საგანი', hintText: 'მაგ. მაკროეკონომიკა', counterText: '')),
        if (widget.subjects.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in widget.subjects.toSet())
                ActionChip(key: ValueKey('dls-$s'), label: Text(s), onPressed: () => setState(() => subject.text = s)),
            ]),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('dl-day'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: due, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 730)));
                if (d != null) setState(() => due = DateTime(d.year, d.month, d.day, due.hour, due.minute));
              },
              icon: const PIcon('cal', size: 17),
              label: Text('${due.day} ${months[due.month - 1]}'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('dl-time'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(due));
                if (t != null) setState(() => due = DateTime(due.year, due.month, due.day, t.hour, t.minute));
              },
              icon: const PIcon('clock', size: 17),
              label: Text(hhmm(due)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('dl-notes'),
          controller: notes,
          maxLength: 1000,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'შენიშვნა', hintText: 'რა უნდა გავიმეორო, რა წავიღო…', counterText: ''),
        ),
        if (gs.isNotEmpty) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<int?>(
            key: const ValueKey('dl-for'),
            isExpanded: true,
            initialValue: group,
            decoration: const InputDecoration(labelText: 'ვისთვის'),
            items: [const DropdownMenuItem<int?>(value: null, child: Text('მხოლოდ ჩემთვის')), for (final g in gs) DropdownMenuItem<int?>(value: g.id, child: Text(g.name, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => group = v),
          ),
        ],
        if (edit) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            key: const ValueKey('dl-del'),
            style: OutlinedButton.styleFrom(foregroundColor: c.nope),
            onPressed: busy ? null : _delete,
            icon: PIcon('trash', size: 17, color: c.nope),
            label: const Text('წაშლა'),
          ),
        ],
      ]),
    );
  }
}

/// the two libraries: notes and study tips (study.js NOTES, TIPS)
const _libs = {
  'notes': (
    tag: 'კონსპექტი',
    title: 'კონსპექტები',
    add: 'კონსპექტი',
    icon: 'book',
    cats: ['მათემატიკა', 'ფიზიკა', 'ქიმია', 'ბიოლოგია', 'ისტორია', 'ქართული', 'ინგლისური', 'ეკონომიკა', 'სამართალი', 'პროგრამირება', 'მედიცინა', 'ფსიქოლოგია'],
    hint: 'ლექციების ჩანაწერები, დაფის ფოტოები და მოკლე კონსპექტები. გააზიარე შენი და ნახე კურსელების.',
    empty: 'კონსპექტები ჯერ არ არის',
    emptySub: 'გადაუღე ფოტო დაფას ან ჩაწერე მთავარი და გაუზიარე სხვებს.',
  ),
  'tips': (
    tag: 'რჩევა',
    title: 'სასწავლო რჩევები',
    add: 'რჩევა',
    icon: 'help',
    cats: ['სწავლის მეთოდები', 'გამოცდები', 'ეროვნულები', 'მოტივაცია', 'კარიერა', 'დროის მართვა'],
    hint: 'როგორ ვისწავლოთ უკეთ: გამოცდებისთვის მზადება, დროის მართვა, მოტივაცია. დაწერე რა გიშველის შენ.',
    empty: 'რჩევები ჯერ არ არის',
    emptySub: 'დაწერე პირველი: რა გეხმარება სწავლაში?',
  ),
};

String _tagOf(String s) => s.trim().replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^\p{L}\p{N}_]', unicode: true), '');

/// Notes or study tips: posts with the tag, by subject or topic and by words; a new one starts with the tags.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.kind});
  final String kind;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final o = _libs[widget.kind]!;
  String sub = '';
  final q = TextEditingController();
  List<Post>? rows;
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
    q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final g = ++_gen, app = context.app;
    try {
      final r = await app.api.postsWithTags([o.tag, if (sub.isNotEmpty) _tagOf(sub)], q: q.text.trim());
      await app.posts.load(r);
      if (mounted && g == _gen) {
        setState(() {
          rows = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && g == _gen) setState(() => error = e);
    }
  }

  Future<void> _new() async {
    final p = await openPage<Post>(context, ComposeScreen(text: '\n\n#${o.tag}${sub.isNotEmpty ? ' #${_tagOf(sub)}' : ''}'), full: true);
    if (p != null && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, r = rows;
    return Scaffold(
      appBar: peeraBar(context, title: o.title, actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: FilledButton.icon(
            key: const ValueKey('lib-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: _new,
            icon: PIcon('plus', size: 17, color: c.onAccent),
            label: Text(o.add),
          ),
        ),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 4), child: Text(o.hint, style: TextStyle(color: c.muted))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: TextField(
            key: const ValueKey('lib-q'),
            controller: q,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(hintText: 'ძიება', prefixIcon: Padding(padding: const EdgeInsets.all(12), child: PIcon('search', size: 20, color: c.muted))),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 4, 12, 4), children: [
            for (final s in ['', ...o.cats])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  key: ValueKey('libc-$s'),
                  label: Text(s.isEmpty ? 'ყველა' : s),
                  selected: sub == s,
                  showCheckmark: false,
                  selectedColor: c.accentSoft,
                  side: BorderSide(color: sub == s ? c.accent : c.line),
                  onSelected: (_) {
                    setState(() => sub = s);
                    _load();
                  },
                ),
              ),
          ]),
        ),
        Expanded(
          child: error != null && r == null
              ? Empty(icon: o.icon, title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
              : r == null
                  ? const Center(child: CircularProgressIndicator())
                  : r.isEmpty
                      ? Empty(icon: o.icon, title: sub.isNotEmpty || q.text.trim().isNotEmpty ? 'ვერაფერი მოიძებნა' : o.empty, text: o.emptySub, action: o.add, onAction: _new)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [for (final p in r) PostCard(key: ValueKey('lib-${p.id}'), post: p)]),
                        ),
        ),
      ]),
    );
  }
}
