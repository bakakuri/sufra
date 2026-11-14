// Jobs (jobs.js): vacancies by category, kind and words; a vacancy posted (its company can be one of my pages); one
// vacancy answered with a letter and the CV, or, for who posted it, the candidates (their CV seen, invited, declined);
// my vacancies and where I applied.
import 'dart:async';

import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../config.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/post_card.dart';
import '../people/cv_edit.dart';
import '../people/person_screen.dart';
import '../people/profile_parts.dart';
import '../profile/profile.dart';
import '../ui/bits.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const jobCats = [
  ('it', 'IT და ტექნოლოგიები'), ('sales', 'გაყიდვები'), ('service', 'მომსახურება'), ('food', 'კვება და რესტორნები'), //
  ('build', 'მშენებლობა და ხელობა'), ('edu', 'განათლება'), ('health', 'მედიცინა'), ('drive', 'მძღოლი და მიწოდება'),
  ('office', 'ოფისი და ადმინისტრაცია'), ('design', 'დიზაინი და მედია'), ('tourism', 'ტურიზმი'), ('other', 'სხვა'),
];
const jobTypes = [('full', 'სრული განაკვეთი'), ('part', 'ნახევარი განაკვეთი'), ('remote', 'დისტანციური'), ('intern', 'სტაჟირება'), ('freelance', 'ფრილანსი')];
const appStates = {'new': 'ახალი', 'seen': 'ნანახი', 'invited': 'მოწვეულია გასაუბრებაზე', 'rejected': 'უარყოფილია'};

String jobCat(Object? k) => jobCats.firstWhere((x) => x.$1 == k, orElse: () => jobCats.last).$2;
String jobType(Object? k) => jobTypes.firstWhere((x) => x.$1 == k, orElse: () => jobTypes.first).$2;

String salaryText(Map<String, dynamic> j) {
  final a = asNum(j['salary_from']), b = asNum(j['salary_to']);
  if (a != null && b != null) return '${thousands(a)}–${thousands(b)} ₾';
  if (a != null) return '${thousands(a)} ₾-დან';
  if (b != null) return '${thousands(b)} ₾-მდე';
  return '';
}

/// the company's letter on its colour
class JobLogo extends StatelessWidget {
  const JobLogo({super.key, required this.j, this.size = 44});
  final Map<String, dynamic> j;
  final double size;
  @override
  Widget build(BuildContext context) {
    final name = '${'${j['company'] ?? ''}'.isNotEmpty ? j['company'] : j['title'] ?? '?'}';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: HSLColor.fromAHSL(1, (asInt(j['id']) * 53 % 360).toDouble(), .5, .5).toColor(), borderRadius: BorderRadius.circular(size * .28)),
      child: Center(child: Text(name.isEmpty ? '?' : name.characters.first, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * .42))),
    );
  }
}

Widget _jobTags(Map<String, dynamic> j, {bool cat = false}) => Wrap(spacing: 5, runSpacing: 5, children: [
      PTag(jobType(j['job_type'])),
      if (cat) PTag(jobCat(j['category'])),
      if (salaryText(j).isNotEmpty) PTag(salaryText(j), kind: 'ad'),
      if (j['status'] == 'closed') const PTag('დახურულია', kind: 'warn'),
    ]);

/// One vacancy in a list.
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.j, required this.onBack});
  final Map<String, dynamic> j;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, company = '${j['company'] ?? ''}';
    return InkWell(
      key: ValueKey('job-${j['id']}'),
      onTap: () async {
        await openPage(context, JobScreen(id: asInt(j['id'])), full: true);
        onBack();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          JobLogo(j: j),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${j['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(
                '${company.isNotEmpty ? company : app.people['${j['poster']}']?.name ?? ''}${'${j['city'] ?? ''}'.isNotEmpty ? ' · ${j['city']}' : ''}',
                style: TextStyle(color: c.muted, fontSize: 13),
              ),
              const SizedBox(height: 4),
              _jobTags(j),
            ]),
          ),
          Text(ago(asTime(j['created_at'])), style: TextStyle(color: c.muted, fontSize: 12)),
        ]),
      ),
    );
  }
}

/// The vacancies.
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});
  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  String cat = '', type = '';
  final q = TextEditingController();
  List<Map<String, dynamic>>? rows;
  Object? error;
  Timer? _wait;
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
    _wait?.cancel();
    q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final g = ++_gen, app = context.app;
    try {
      final r = await app.api.jobs(cat: cat, type: type, q: q.text.trim());
      await app.people.ensure([for (final j in r) '${j['poster']}']);
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
    final id = await openPage<int>(context, const JobFormScreen(), full: true);
    if (id != null && mounted) await openPage(context, JobScreen(id: id), full: true);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, r = rows;
    return Scaffold(
      appBar: peeraBar(context, title: 'ვაკანსიები', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: FilledButton.icon(
            key: const ValueKey('jb-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: _new,
            icon: PIcon('plus', size: 17, color: c.onAccent),
            label: const Text('ვაკანსია'),
          ),
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                key: const ValueKey('jb-cv'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                onPressed: () => openPage(context, const CvEditScreen(), full: true),
                icon: const PIcon('user', size: 16),
                label: const Text('ჩემი CV'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('jb-mine'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                onPressed: () async {
                  await openPage(context, const MyJobsScreen(), full: true);
                  _load();
                },
                icon: const PIcon('work', size: 16),
                label: const Text('ჩემი ვაკანსიები და განაცხადები'),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              key: const ValueKey('jb-q'),
              controller: q,
              textInputAction: TextInputAction.search,
              onChanged: (_) {
                _wait?.cancel();
                _wait = Timer(const Duration(milliseconds: 400), _load);
              },
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(hintText: 'პოზიცია, კომპანია, ქალაქი', prefixIcon: Padding(padding: const EdgeInsets.all(12), child: PIcon('search', size: 20, color: c.muted))),
            ),
          ),
          ChipsBar(prefix: 'jbc', items: [('', 'ყველა'), ...jobCats], value: cat, onPick: (k) {
            setState(() => cat = k);
            _load();
          }),
          ChipsBar(prefix: 'jbt', items: [('', 'ნებისმიერი'), ...jobTypes], value: type, onPick: (k) {
            setState(() => type = k);
            _load();
          }),
          if (r == null && error == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (r == null)
            Empty(icon: 'work', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
          else if (r.isEmpty)
            Empty(icon: 'work', title: 'ვაკანსიები ვერ მოიძებნა', text: 'სცადე სხვა ფილტრი ან გამოაქვეყნე შენი ვაკანსია.', action: 'ვაკანსიის დამატება', onAction: _new)
          else
            for (final j in r) JobCard(j: j, onBack: _load),
        ]),
      ),
    );
  }
}

/// A new vacancy: the position, the company (one of my pages, or any name), the city, category and kind, the salary,
/// a description. Pops with its id.
class JobFormScreen extends StatefulWidget {
  const JobFormScreen({super.key});
  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  final title = TextEditingController(), company = TextEditingController(), s1 = TextEditingController(), s2 = TextEditingController(), desc = TextEditingController();
  late final city = TextEditingController(text: context.me.city ?? '');
  String cat = 'it', type = 'full';
  List<Map<String, dynamic>> pages = const [];
  bool busy = false, _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    context.app.api.myPages().then((p) {
      if (mounted) setState(() => pages = p);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    for (final x in [title, company, s1, s2, desc, city]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final t = title.text.trim();
    if (t.length < 2) {
      toast(context, 'ჩაწერე პოზიცია');
      return;
    }
    int? n(String v) {
      final x = int.tryParse(v.trim());
      return x != null && x >= 0 ? x : null;
    }

    final comp = company.text.trim(), pg = pages.where((p) => p['name'] == comp).firstOrNull;
    setState(() => busy = true);
    try {
      final id = await context.app.api.createJob({
        'page_id': pg?['id'],
        'title': t,
        'company': comp,
        'city': city.text.trim(),
        'category': cat,
        'job_type': type,
        'salary_from': n(s1.text),
        'salary_to': n(s2.text),
        'description': desc.text.trim(),
      });
      if (!mounted) return;
      toast(context, 'ვაკანსია გამოქვეყნდა');
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
      appBar: peeraBar(context, title: 'ახალი ვაკანსია', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(key: const ValueKey('jf-ok'), style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: busy ? null : _save, child: const Text('გამოქვეყნება')),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(key: const ValueKey('jf-title'), controller: title, maxLength: 100, decoration: const InputDecoration(labelText: 'პოზიცია', hintText: 'მაგ. მზარეული, ფრონტენდ დეველოპერი', counterText: '')),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('jf-company'), controller: company, maxLength: 80, decoration: const InputDecoration(labelText: 'კომპანია', hintText: 'კომპანიის სახელი', counterText: '')),
        if (pages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in pages) ActionChip(key: ValueKey('jf-pg-${p['id']}'), label: Text('${p['name']}'), onPressed: () => setState(() => company.text = '${p['name']}')),
            ]),
          ),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('jf-city'), controller: city, maxLength: 60, decoration: const InputDecoration(labelText: 'ქალაქი', counterText: '')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const ValueKey('jf-cat'),
          isExpanded: true,
          initialValue: cat,
          decoration: const InputDecoration(labelText: 'კატეგორია'),
          items: [for (final (k, n) in jobCats) DropdownMenuItem(value: k, child: Text(n, overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => cat = v ?? cat),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(0, 14, 0, 6), child: Text('ტიპი', style: TextStyle(fontWeight: FontWeight.w700))),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (k, n) in jobTypes)
            ChoiceChip(
              key: ValueKey('jf-t-$k'),
              label: Text(n),
              selected: type == k,
              showCheckmark: false,
              selectedColor: c.accentSoft,
              side: BorderSide(color: type == k ? c.accent : c.line),
              onSelected: (_) => setState(() => type = k),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(key: const ValueKey('jf-s1'), controller: s1, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ხელფასი დან, ₾', hintText: '1200'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(key: const ValueKey('jf-s2'), controller: s2, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'მდე, ₾', hintText: '2000'))),
        ]),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('jf-desc'),
          controller: desc,
          maxLength: 4000,
          minLines: 5,
          maxLines: 12,
          decoration: const InputDecoration(labelText: 'აღწერა', hintText: 'მოვალეობები, მოთხოვნები, გრაფიკი, რას სთავაზობ', counterText: ''),
        ),
      ]),
    );
  }
}

/// One vacancy.
class JobScreen extends StatefulWidget {
  const JobScreen({super.key, required this.id});
  final int id;
  @override
  State<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends State<JobScreen> {
  ({Map<String, dynamic> j, Map<String, dynamic>? mine, List<Map<String, dynamic>> apps})? d;
  bool loaded = false;
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
      final x = await app.api.job(widget.id);
      if (x != null) await app.people.ensure(['${x.j['poster']}', for (final a in x.apps) '${a['user_id']}']);
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

  Future<void> _apply() async {
    final app = context.app, me = context.me, c = context.pc;
    Map<String, dynamic>? cv;
    try {
      cv = await app.api.cv(me.id);
    } catch (_) {}
    if (!mounted) return;
    final myCv = cv;
    final cover = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (s) => AppScope(
        app: app,
        me: me,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(s).bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('გამოხმაურება', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('ja-cover'),
                  controller: cover,
                  maxLength: 2000,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'მოკლე წერილი', hintText: 'რატომ ხარ შესაფერისი, როდის შეგიძლია დაწყება', counterText: ''),
                ),
                const SizedBox(height: 6),
                Text(
                  myCv != null
                      ? 'შენი CV („${'${myCv['headline'] ?? ''}'.isEmpty ? 'CV' : myCv['headline']}“) დამსაქმებელს ავტომატურად ეჩვენება.'
                      : 'CV ჯერ არ გაქვს. შეგიძლია ახლავე შექმნა, დამსაქმებელი უფრო მეტად გამოგეხმაურება.',
                  style: TextStyle(color: c.muted, fontSize: 13),
                ),
                if (myCv == null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(key: const ValueKey('ja-cv'), onPressed: () => openPage(s, const CvEditScreen(), full: true), child: const Text('CV-ის შექმნა')),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    key: const ValueKey('ja-send'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => Navigator.of(s).pop(true),
                    icon: PIcon('send', size: 17, color: s.pc.onAccent),
                    label: const Text('გაგზავნა'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    final text = cover.text.trim();
    if (ok != true || !mounted) return;
    if (await attempt(context, () => app.api.applyJob(widget.id, text)) && mounted) {
      toast(context, 'გამოხმაურება გაიგზავნა. წარმატებები!');
      _load();
    }
  }

  /// a candidate's CV (and the application marked seen)
  Future<void> _cv(String uid) async {
    final app = context.app, me = context.me, c = context.pc;
    Map<String, dynamic>? cv;
    try {
      cv = await app.api.cv(uid);
      unawaited(app.api.setApplication(widget.id, uid, 'seen').catchError((_) {}));
    } catch (e) {
      if (mounted) toast(context, errText(e));
      return;
    }
    if (!mounted) return;
    final theCv = cv;
    final who = app.people[uid] ?? Profile(id: uid, name: '…');
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (s) => AppScope(
        app: app,
        me: me,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .8,
          maxChildSize: .95,
          builder: (s, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
            Text('CV · ${who.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (theCv == null) Padding(padding: const EdgeInsets.only(top: 12), child: Text('კანდიდატს CV არ აქვს შევსებული.', style: TextStyle(color: c.muted))) else CvView(cv: theCv, who: who, mine: false),
          ]),
        ),
      ),
    );
    _load();
  }

  Future<void> _status(String uid, String st) async {
    if (await attempt(context, () => context.app.api.setApplication(widget.id, uid, st)) && mounted) {
      toast(context, st == 'invited' ? 'კანდიდატს ეცნობა' : 'შენახულია');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = d, app = context.app;
    if (x == null) {
      return Scaffold(
        appBar: peeraBar(context, title: 'ვაკანსია'),
        body: !loaded
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Empty(icon: 'work', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
                : const Empty(icon: 'work', title: 'ვაკანსია ვერ მოიძებნა', text: 'შეიძლება წაშლილია.'),
      );
    }
    final j = x.j, poster = '${j['poster']}', mine = poster == app.api.myId, my = x.mine, who = app.people[poster] ?? Profile(id: poster, name: '…');
    Widget btn(String key, String icon, String label, VoidCallback onTap, {bool filled = false, Color? color}) => filled
        ? FilledButton.icon(key: ValueKey(key), style: FilledButton.styleFrom(minimumSize: const Size(0, 42)), onPressed: onTap, icon: PIcon(icon, size: 17, color: c.onAccent), label: Text(label))
        : OutlinedButton.icon(
            key: ValueKey(key),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), foregroundColor: color),
            onPressed: onTap,
            icon: PIcon(icon, size: 17, color: color),
            label: Text(label),
          );
    return Scaffold(
      appBar: peeraBar(context, title: 'ვაკანსია', actions: [
        IconBtn('share', key: const ValueKey('jb-share'), label: 'გაზიარება', onTap: () => shareText(context, 'ვაკანსია Peera-ზე: ${j['title']}\n$siteUrl/#job-${j['id']}')),
        if (!mine) IconBtn('flag', key: const ValueKey('jb-report'), label: 'საჩივარი', onTap: () => reportSheet(context, 'job', '${j['id']}')),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              JobLogo(j: j, size: 60),
              const SizedBox(height: 10),
              Text('${j['title'] ?? ''}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
              Text('${j['company'] ?? ''}${'${j['city'] ?? ''}'.isNotEmpty ? ' · ${j['city']}' : ''}', style: TextStyle(color: c.muted)),
              const SizedBox(height: 8),
              _jobTags(j, cat: true),
              const SizedBox(height: 14),
              if ('${j['description'] ?? ''}'.isNotEmpty) Text('${j['description']}', style: const TextStyle(fontSize: 15.5)) else Text('აღწერა არ არის', style: TextStyle(color: c.muted)),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => openPerson(context, who),
                child: Text('გამოქვეყნდა ${ago(asTime(j['created_at']))} · ${who.name}', style: TextStyle(color: c.muted, fontSize: 12.5)),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (mine) ...[
                  btn('jb-toggle', j['status'] == 'open' ? 'lock' : 'check', j['status'] == 'open' ? 'დახურვა' : 'ხელახლა გახსნა', () async {
                    if (await attempt(context, () => app.api.setJobStatus(widget.id, j['status'] == 'open' ? 'closed' : 'open'))) _load();
                  }),
                  btn('jb-del', 'trash', 'წაშლა', () async {
                    if (!await confirm(context, title: 'ვაკანსიის წაშლა', text: 'ვაკანსია და განაცხადები წაიშლება.', yes: 'წაშლა', danger: true) || !context.mounted) return;
                    if (await attempt(context, () => app.api.deleteJob(widget.id)) && context.mounted) Navigator.of(context).pop();
                  }, color: c.nope),
                ] else if (my != null) ...[
                  PTag(appStates[my['status']] ?? '${my['status']}', kind: my['status'] == 'invited' ? 'ad' : my['status'] == 'rejected' ? 'warn' : ''),
                  btn('jb-ask', 'msg', 'დამსაქმებელს მიწერა', () => chatWith(context, poster)),
                ] else if (j['status'] == 'open') ...[
                  btn('jb-apply', 'send', 'გამოხმაურება', _apply, filled: true),
                  btn('jb-ask', 'msg', 'კითხვა', () => chatWith(context, poster)),
                ],
              ]),
            ]),
          ),
          if (mine) ...[
            SecHead('კანდიდატები · ${x.apps.length}'),
            if (x.apps.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('გამოხმაურება ჯერ არ არის', style: TextStyle(color: c.muted))),
            for (final a in x.apps)
              if (app.people['${a['user_id']}'] case final p?)
                Padding(
                  key: ValueKey('app-${p.id}'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GestureDetector(onTap: () => openPerson(context, p), child: Avatar(p: p, size: 44)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${appStates[a['status']] ?? a['status']} · ${ago(asTime(a['created_at']))}', style: TextStyle(color: c.muted, fontSize: 13)),
                        if ('${a['cover'] ?? ''}'.isNotEmpty)
                          Padding(padding: const EdgeInsets.only(top: 4), child: Text('${a['cover']}', maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5))),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          OutlinedButton.icon(
                            key: ValueKey('app-cv-${p.id}'),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34)),
                            onPressed: () => _cv(p.id),
                            icon: const PIcon('user', size: 15),
                            label: const Text('CV'),
                          ),
                          OutlinedButton(
                            key: ValueKey('app-chat-${p.id}'),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34)),
                            onPressed: () => chatWith(context, p.id),
                            child: const PIcon('msg', size: 15),
                          ),
                          if (a['status'] != 'invited')
                            FilledButton(
                              key: ValueKey('app-inv-${p.id}'),
                              style: FilledButton.styleFrom(minimumSize: const Size(0, 34)),
                              onPressed: () => _status(p.id, 'invited'),
                              child: const Text('გასაუბრებაზე'),
                            ),
                          if (a['status'] != 'rejected')
                            OutlinedButton(
                              key: ValueKey('app-no-${p.id}'),
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34)),
                              onPressed: () => _status(p.id, 'rejected'),
                              child: const Text('უარი'),
                            ),
                        ]),
                      ]),
                    ),
                  ]),
                ),
          ],
        ]),
      ),
    );
  }
}

/// The vacancies I posted and where I applied.
class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});
  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  ({List<Map<String, dynamic>> posted, List<Map<String, dynamic>> applied, List<Map<String, dynamic>> jobs})? d;
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
    try {
      final x = await context.app.api.myJobs();
      if (mounted) {
        setState(() {
          d = x;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = d;
    return Scaffold(
      appBar: peeraBar(context, title: 'ჩემი ვაკანსიები'),
      body: x == null
          ? (error != null ? Empty(icon: 'work', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                const SecHead('ჩემი გამოქვეყნებული'),
                if (x.posted.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('ჯერ არცერთი', style: TextStyle(color: c.muted))),
                for (final j in x.posted) JobCard(j: j, onBack: _load),
                const SecHead('სად გამოვეხმაურე'),
                if (x.applied.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('ჯერ არცერთი', style: TextStyle(color: c.muted))),
                for (final a in x.applied)
                  if (x.jobs.where((j) => j['id'] == a['job_id']).firstOrNull case final j?)
                    ListTile(
                      key: ValueKey('myapp-${j['id']}'),
                      leading: JobLogo(j: j, size: 40),
                      title: Text('${j['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${j['company'] ?? ''} · ${appStates[a['status']] ?? a['status']}'),
                      onTap: () async {
                        await openPage(context, JobScreen(id: asInt(j['id'])), full: true);
                        _load();
                      },
                    ),
              ]),
            ),
    );
  }
}
