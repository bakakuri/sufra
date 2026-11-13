// School and university (study.js PG.edu, PG.classmates): what I add to my profile, and the people who studied in the
// same place, the same year first. Saving puts me in my class and course groups.
import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'person_screen.dart';
import 'profile_parts.dart';
import 'search_screen.dart';

/// key, full name, short name
const universities = [
  ('tsu', 'ივანე ჯავახიშვილის სახელობის თბილისის სახელმწიფო უნივერსიტეტი', 'თსუ'),
  ('gtu', 'საქართველოს ტექნიკური უნივერსიტეტი', 'სტუ'),
  ('iliauni', 'ილიას სახელმწიფო უნივერსიტეტი', 'ილიაუნი'),
  ('freeuni', 'თავისუფალი უნივერსიტეტი', 'თავისუფალი'),
  ('agruni', 'საქართველოს აგრარული უნივერსიტეტი', 'აგრარული'),
  ('tsmu', 'თბილისის სახელმწიფო სამედიცინო უნივერსიტეტი', 'სამედიცინო'),
  ('cu', 'კავკასიის უნივერსიტეტი', 'კავკასიის'),
  ('ibsu', 'საერთაშორისო შავი ზღვის უნივერსიტეტი', 'IBSU'),
  ('gipa', 'საზოგადოებრივ საქმეთა ინსტიტუტი', 'GIPA'),
  ('btu', 'ბიზნესისა და ტექნოლოგიების უნივერსიტეტი', 'BTU'),
  ('ug', 'საქართველოს უნივერსიტეტი', 'UG'),
  ('gau', 'საქართველოს ამერიკული უნივერსიტეტი', 'GAU'),
  ('eu', 'ევროპის უნივერსიტეტი', 'ევროპის'),
  ('sdasu', 'საქართველოს დავით აღმაშენებლის სახელობის უნივერსიტეტი', 'SDASU'),
  ('alte', 'ალტე უნივერსიტეტი', 'ალტე'),
  ('newvision', 'ნიუ ვიჟენ უნივერსიტეტი', 'ნიუ ვიჟენი'),
  ('eeu', 'აღმოსავლეთ ევროპის უნივერსიტეტი', 'EEU'),
  ('tsaa', 'თბილისის სახელმწიფო სამხატვრო აკადემია', 'სამხატვრო'),
  ('tsc', 'თბილისის სახელმწიფო კონსერვატორია', 'კონსერვატორია'),
  ('atsu', 'აკაკი წერეთლის სახელმწიფო უნივერსიტეტი', 'აწსუ'),
  ('kiu', 'ქუთაისის საერთაშორისო უნივერსიტეტი', 'KIU'),
  ('bsu', 'ბათუმის შოთა რუსთაველის სახელმწიფო უნივერსიტეტი', 'ბსუ'),
  ('gori', 'გორის სახელმწიფო უნივერსიტეტი', 'გორის'),
  ('telavi', 'თელავის სახელმწიფო უნივერსიტეტი', 'თელავის'),
  ('sjsu', 'სამცხე-ჯავახეთის სახელმწიფო უნივერსიტეტი', 'სამცხე-ჯავახეთის'),
  ('zssu', 'ზუგდიდის სახელმწიფო სასწავლო უნივერსიტეტი', 'ზუგდიდის'),
];

const faculties = [
  'ეკონომიკა და ბიზნესი', 'სამართალი', 'მედიცინა', 'ინფორმატიკა', 'მათემატიკა', 'ფიზიკა', 'ქიმია', 'ბიოლოგია', 'ფსიქოლოგია', //
  'ჟურნალისტიკა', 'საერთაშორისო ურთიერთობები', 'ჰუმანიტარული მეცნიერებები', 'ინჟინერია', 'არქიტექტურა', 'განათლება', 'ხელოვნება',
];

/// a name made into a key: small letters, Georgian and digits, the rest a dash
String kuSlug(String s) {
  final t = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9ა-ჿ]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return t.length > 60 ? t.substring(0, 60) : t;
}

/// the key people of one school or university share: a known university's own key, a school's place and number
String eduKey(Map<String, dynamic> e) {
  final n = '${e['n'] ?? ''}';
  if (e['k'] == 'uni') {
    for (final u in universities) {
      if (u.$2 == n || u.$3 == n || u.$1 == e['uk']) return u.$1;
    }
    return 'x-${kuSlug(n)}';
  }
  final num = RegExp(r'\d+').firstMatch(n)?.group(0);
  return '${kuSlug('${e['c'] ?? ''}')}-${num ?? kuSlug(n)}';
}

String uniShort(Map<String, dynamic> e) {
  for (final u in universities) {
    if (u.$1 == e['key']) return u.$3;
  }
  return '${e['n'] ?? ''}';
}

String _s(Map<String, dynamic> e, String k) => '${e[k] ?? ''}'.trim();

/// the grey line under an entry: place, faculty, years, class
String eduSub(Map<String, dynamic> e) {
  final uni = e['k'] == 'uni';
  return [
    _s(e, 'c'),
    _s(e, 'f'),
    uni ? '${_s(e, 'y0')}${_s(e, 'y1').isEmpty ? '' : '–${_s(e, 'y1')}'}' : (_s(e, 'y1').isEmpty ? '' : '${_s(e, 'y1')} წლის გამოშვება'),
    _s(e, 'cls').isEmpty ? '' : 'კლასი „${_s(e, 'cls')}“',
  ].where((x) => x.isNotEmpty).join(' · ');
}

/// What I studied where, with editing and adding.
class EduScreen extends StatefulWidget {
  const EduScreen({super.key});
  @override
  State<EduScreen> createState() => _EduScreenState();
}

class _EduScreenState extends State<EduScreen> {
  List<Map<String, dynamic>>? list;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    list ??= [for (final e in context.me.edu) Map<String, dynamic>.from(e)];
  }

  Future<bool> _save(List<Map<String, dynamic>> l) async {
    final app = context.app;
    final next = l.take(8).toList();
    if (!await attempt(context, () => app.api.updateMe({'edu': next}))) return false;
    if (!mounted) return true;
    setState(() => list = next);
    toast(context, 'შენახულია');
    app.api.joinEduGroups().then((_) {}, onError: (_) {});
    app.refreshMe?.call();
    return true;
  }

  Future<void> _sheet(int i) async {
    final l = [...list!];
    final got = await eduSheet(context, i >= 0 ? l[i] : null, onDelete: i < 0 ? null : () => _save(l..removeAt(i)));
    if (got == null || !mounted) return;
    if (i >= 0) {
      l[i] = got;
    } else {
      l.add(got);
    }
    await _save(l);
  }

  Future<void> _groups() async {
    try {
      final ids = await context.app.api.joinEduGroups();
      if (!mounted) return;
      toast(context, ids.isNotEmpty ? 'ჯგუფები: ${ids.length}' : 'ჯგუფები ვერ შეიქმნა');
      if (ids.isNotEmpty) openSite('#groups');
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, l = list ?? const [];
    return Scaffold(
      appBar: peeraBar(context, title: 'ჩემი განათლება', actions: [IconBtn('plus', key: const ValueKey('edu-add'), label: 'დამატება', onTap: () => _sheet(-1))]),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('სკოლა და უნივერსიტეტი, სადაც სწავლობ ან სწავლობდი. ამით გიპოვით კლასელებსა და კურსელებს და შეგიყვანთ კლასისა და კურსის ჯგუფებში.',
              style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.4)),
        ),
        if (l.isEmpty)
          Empty(icon: 'school', title: 'ჯერ არაფერი დაგიმატებია', text: 'დაამატე სკოლა ან უნივერსიტეტი.', action: 'დამატება', onAction: () => _sheet(-1))
        else ...[
          for (final (i, e) in l.indexed)
            ListTile(
              key: ValueKey('edu-$i'),
              leading: CircleAvatar(backgroundColor: c.sunk, child: PIcon(e['k'] == 'uni' ? 'school' : 'book', size: 20, color: c.accent)),
              title: Text(_s(e, 'n'), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: eduSub(e).isEmpty ? null : Text(eduSub(e), style: TextStyle(color: c.muted)),
              trailing: IconBtn('edit', key: ValueKey('edu-edit-$i'), label: 'რედაქტირება', size: 20, onTap: () => _sheet(i)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                key: const ValueKey('edu-mates'),
                onPressed: () => openPage(context, ClassmatesScreen(edu: list)),
                icon: PIcon('users', size: 18, color: c.onAccent),
                label: const Text('კლასელები და კურსელები'),
              ),
              OutlinedButton.icon(onPressed: _groups, icon: PIcon('users', size: 18, color: c.ink), label: const Text('კლასისა და კურსის ჯგუფები')),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// The school or university form; the entry made ready to keep, or null when closed.
Future<Map<String, dynamic>?> eduSheet(BuildContext context, Map<String, dynamic>? e, {Future<bool> Function()? onDelete}) {
  final me = context.me, yr = DateTime.now().year;
  var kind = '${e?['k'] ?? 'school'}';
  final n = TextEditingController(text: _s(e ?? const {}, 'n')),
      city = TextEditingController(text: e == null ? (me.city ?? '') : _s(e, 'c')),
      fac = TextEditingController(text: _s(e ?? const {}, 'f')),
      y0 = TextEditingController(text: _s(e ?? const {}, 'y0')),
      y1 = TextEditingController(text: _s(e ?? const {}, 'y1')),
      cls = TextEditingController(text: _s(e ?? const {}, 'cls'));
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => StatefulBuilder(builder: (s, set) {
      final c = s.pc, uni = kind == 'uni';
      Widget suggest(TextEditingController ctl, List<(String, String)> all) {
        final q = ctl.text.trim().toLowerCase();
        if (q.isEmpty) return const SizedBox.shrink();
        final hits = all.where((x) => x.$1 != ctl.text && (x.$1.toLowerCase().contains(q) || x.$2.toLowerCase().contains(q))).take(4).toList();
        if (hits.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final h in hits)
              ActionChip(
                key: ValueKey('sug-${h.$1}'),
                label: Text(h.$2 == h.$1 ? h.$1 : '${h.$2} · ${h.$1}', maxLines: 1, overflow: TextOverflow.ellipsis),
                onPressed: () => set(() => ctl.text = h.$1),
              ),
          ]),
        );
      }

      InputDecoration dec(String label, [String? hint]) => InputDecoration(labelText: label, hintText: hint, counterText: '');
      Widget year(TextEditingController ctl, String label, String hint) => Expanded(
            child: TextField(key: ValueKey('edu-$label'), controller: ctl, maxLength: 4, keyboardType: TextInputType.number, decoration: dec(label, hint)),
          );
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(s).bottom),
        child: SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), children: [
            Text(e != null ? 'რედაქტირება' : 'სკოლა ან უნივერსიტეტი', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: 'school', label: Text('სკოლა')), ButtonSegment(value: 'uni', label: Text('უნივერსიტეტი'))],
              selected: {kind},
              onSelectionChanged: (v) => set(() {
                kind = v.first;
                n.clear();
              }),
            ),
            const SizedBox(height: 12),
            if (uni) ...[
              TextField(key: const ValueKey('edu-n'), controller: n, maxLength: 80, onChanged: (_) => set(() {}), decoration: dec('უნივერსიტეტი', 'დაიწყე წერა: თსუ, ილიაუნი…')),
              suggest(n, [for (final u in universities) (u.$2, u.$3)]),
              const SizedBox(height: 10),
              TextField(controller: fac, maxLength: 50, onChanged: (_) => set(() {}), decoration: dec('ფაკულტეტი ან პროგრამა', 'მაგ. ეკონომიკა და ბიზნესი')),
              suggest(fac, [for (final f in faculties) (f, f)]),
              const SizedBox(height: 10),
              Row(children: [year(y0, 'ჩარიცხვის წელი', '${yr - 1}'), const SizedBox(width: 10), year(y1, 'დამთავრება', '${yr + 3}')]),
            ] else ...[
              TextField(key: const ValueKey('edu-n'), controller: n, maxLength: 80, decoration: dec('სკოლა', 'მაგ. 51-ე საჯარო სკოლა')),
              const SizedBox(height: 10),
              TextField(controller: city, maxLength: 40, decoration: dec('ქალაქი ან სოფელი', 'მაგ. თბილისი')),
              const SizedBox(height: 10),
              Row(children: [
                year(y1, 'დამთავრების წელი', '$yr'),
                const SizedBox(width: 10),
                Expanded(child: TextField(key: const ValueKey('edu-cls'), controller: cls, maxLength: 4, decoration: dec('კლასი (ასო)', 'ა, ბ, გ…'))),
              ]),
            ],
            const SizedBox(height: 16),
            Row(children: [
              if (onDelete != null)
                TextButton.icon(
                  key: const ValueKey('edu-del'),
                  onPressed: () async {
                    Navigator.of(s).pop();
                    await onDelete();
                  },
                  icon: PIcon('trash', size: 18, color: c.nope),
                  label: Text('წაშლა', style: TextStyle(color: c.nope)),
                ),
              const Spacer(),
              FilledButton.icon(
                key: const ValueKey('edu-ok'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () {
                  final name = n.text.trim();
                  if (name.length < 2) {
                    toast(s, uni ? 'ჩაწერე უნივერსიტეტი' : 'ჩაწერე სკოლა');
                    return;
                  }
                  final yy = RegExp(r'^\d{4}$');
                  final a = uni ? y0.text.trim() : '', b = y1.text.trim();
                  if ((a.isNotEmpty && !yy.hasMatch(a)) || (b.isNotEmpty && !yy.hasMatch(b))) {
                    toast(s, 'წელი ოთხი ციფრით ჩაწერე');
                    return;
                  }
                  String cut(String v, int m) => v.length > m ? v.substring(0, m) : v;
                  final o = <String, dynamic>{'k': kind, 'n': cut(name, 80)};
                  if (!uni && city.text.trim().isNotEmpty) o['c'] = cut(city.text.trim(), 40);
                  if (uni && fac.text.trim().isNotEmpty) o['f'] = cut(fac.text.trim(), 50);
                  if (a.isNotEmpty) o['y0'] = int.parse(a);
                  if (b.isNotEmpty) o['y1'] = int.parse(b);
                  if (!uni && cls.text.trim().isNotEmpty) o['cls'] = cut(cls.text.trim(), 4);
                  o['key'] = eduKey(o);
                  Navigator.of(s).pop(o);
                },
                icon: PIcon('check', size: 18, color: c.onAccent),
                label: const Text('შენახვა'),
              ),
            ]),
          ]),
        ),
      );
    }),
  );
}

/// The people who share my school or university: my year and class first, then my faculty, then the rest.
class ClassmatesScreen extends StatefulWidget {
  const ClassmatesScreen({super.key, this.edu});

  /// my entries, when they changed after this screen's [AppScope] was made
  final List<Map<String, dynamic>>? edu;
  @override
  State<ClassmatesScreen> createState() => _ClassmatesScreenState();
}

class _ClassmatesScreenState extends State<ClassmatesScreen> {
  List<(Map<String, dynamic>, List<(Profile, Map)>, List<(Profile, Map)>, List<(Profile, Map)>)>? out;
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
    final app = context.app, mine = widget.edu ?? context.me.edu;
    try {
      final res = <(Map<String, dynamic>, List<(Profile, Map)>, List<(Profile, Map)>, List<(Profile, Map)>)>[];
      for (final e in mine) {
        final rows = await app.api.classmates('${e['k']}', '${e['key']}');
        final same = <(Profile, Map)>[], near = <(Profile, Map)>[], rest = <(Profile, Map)>[];
        for (final p in rows) {
          final x = p.edu.firstWhere((y) => y['k'] == e['k'] && y['key'] == e['key'], orElse: () => const {});
          if (e['k'] == 'school') {
            final sameYear = _s(e, 'y1').isNotEmpty && _s(x, 'y1') == _s(e, 'y1');
            final sameCls = _s(e, 'cls').isEmpty || _s(x, 'cls').isEmpty || _s(x, 'cls').toLowerCase() == _s(e, 'cls').toLowerCase();
            (sameYear && sameCls ? same : rest).add((p, x));
          } else {
            final fs = _s(e, 'f').isNotEmpty && _s(x, 'f').isNotEmpty && kuSlug(_s(x, 'f')) == kuSlug(_s(e, 'f'));
            if (fs && _s(e, 'y0').isNotEmpty && _s(x, 'y0') == _s(e, 'y0')) {
              same.add((p, x));
            } else if (fs) {
              near.add((p, x));
            } else {
              rest.add((p, x));
            }
          }
        }
        final y = int.tryParse(_s(e, 'y1')) ?? 0;
        int d((Profile, Map) a) => ((int.tryParse('${a.$2['y1'] ?? ''}') ?? 0) - y).abs();
        rest.sort((a, b) => d(a).compareTo(d(b)));
        res.add((e, same, near, rest));
      }
      if (mounted) setState(() => out = res);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, o = out;
    Widget body;
    if ((widget.edu ?? context.me.edu).isEmpty) {
      body = Center(
        child: Empty(
          icon: 'school',
          title: 'ჯერ სკოლა არ მიგითითებია',
          text: 'დაამატე სკოლა ან უნივერსიტეტი და გიპოვით, ვინ სწავლობდა შენთან ერთად.',
          action: 'განათლების დამატება',
          onAction: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AppScope(app: context.app, me: context.me, child: const EduScreen()))),
        ),
      );
    } else if (o == null) {
      body = error != null ? Center(child: Empty(icon: 'school', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'თავიდან', onAction: _load)) : const Center(child: CircularProgressIndicator());
    } else {
      Widget person((Profile, Map) r) {
        final (p, x) = r;
        final sub = [
          '${x['f'] ?? ''}',
          x['k'] == 'uni' && '${x['y0'] ?? ''}'.isNotEmpty ? '${x['y0']} წლის ჩარიცხვა' : '',
          x['k'] == 'school' && '${x['y1'] ?? ''}'.isNotEmpty ? '${x['y1']} წლის გამოშვება' : '',
          p.city ?? '',
        ].where((s) => s.isNotEmpty).join(' · ');
        return PersonRow(key: ValueKey('mate-${p.id}'), p: p, sub: sub, size: 44, onTap: () => openPage(context, PersonScreen(uid: p.id)));
      }

      List<Widget> block(String t, List<(Profile, Map)> l) => l.isEmpty
          ? const []
          : [
              Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text('$t · ${l.length}', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700))),
              for (final r in l.take(60)) person(r),
            ];
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          for (final (e, same, near, rest) in o) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                PIcon(e['k'] == 'uni' ? 'school' : 'book', size: 20, color: c.accent),
                const SizedBox(width: 8),
                Expanded(child: Text(e['k'] == 'uni' ? uniShort(e) : _s(e, 'n'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              ]),
            ),
            ...block(e['k'] == 'uni' ? 'კურსელები${_s(e, 'f').isEmpty ? '' : ' · ${_s(e, 'f')}'}${_s(e, 'y0').isEmpty ? '' : ' · ${_s(e, 'y0')}'}' : 'კლასელები${_s(e, 'y1').isEmpty ? '' : ' · ${_s(e, 'y1')}'}', same),
            ...block('იგივე ფაკულტეტი, სხვა წელი', near),
            ...block(e['k'] == 'uni' ? 'იგივე უნივერსიტეტი' : 'იგივე სკოლა, სხვა წელი', rest),
            if (same.isEmpty && near.isEmpty && rest.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('აქ ჯერ არავინ მიუთითებია. მოიწვიე შენი კლასელები და კურსელები!', style: TextStyle(color: c.muted)),
              ),
          ],
        ]),
      );
    }
    return Scaffold(appBar: peeraBar(context, title: 'კლასელები და კურსელები'), body: body);
  }
}
