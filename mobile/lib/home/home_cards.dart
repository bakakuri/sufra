// The parts of the home page between the stories and the feed, and inside it (home.js, firststeps.js, extras.js):
// the first steps for someone new, "on this day", people you may know, inviting friends, the welcome gift, and the
// topics the "for you" feed leans toward.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../data/models.dart';
import '../data/photos.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../feed/post_card.dart';
import '../people/edu.dart';
import '../people/person_screen.dart';
import '../people/profile_parts.dart';
import '../profile/profile.dart';
import '../settings/frame_photo.dart';
import '../settings/places.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

Future<SharedPreferences?> _prefs() async {
  try {
    return await SharedPreferences.getInstance();
  } catch (_) {
    return null;
  }
}

// ---------- first steps ----------

/// how far someone new has come: a photo, school, where from, five people, a first post
class FsProgress {
  FsProgress({required this.photo, required this.edu, required this.place, required this.people, required this.post});
  bool photo, edu, place, post;
  int people;
  int get done => [photo, edu, place, people >= 5, post].where((x) => x).length;
}

Future<FsProgress> fsProgress(BuildContext context) async {
  final api = context.app.api;
  Map<String, dynamic> m = const {};
  try {
    m = await api.mySettings();
  } catch (_) {}
  String t(String k) => '${m[k] ?? ''}'.trim();
  var people = 0, post = false;
  try {
    (people, post) = await api.firstStepsCounts();
  } catch (_) {}
  final edu = m['edu'];
  return FsProgress(
    photo: t('avatar_url').isNotEmpty,
    edu: edu is List && edu.isNotEmpty,
    place: t('city').isNotEmpty && (t('home_region').isNotEmpty || t('home_place').isNotEmpty || t('abroad').isNotEmpty),
    people: people,
    post: post,
  );
}

/// "from Tbilisi" in Georgian: თბილისი → თბილისიდან, მცხეთა → მცხეთიდან
String ablative(String w) {
  w = w.trim();
  if (w.isEmpty) return '';
  if (w.endsWith('ი')) return '$wდან';
  if (w.endsWith('ა')) return '${w.substring(0, w.length - 1)}იდან';
  if (RegExp(r'[ეოუ]$').hasMatch(w)) return '$wდან';
  return '$wიდან';
}

List<String> fsIdeas(String city, String region) => [
      'გამარჯობა, კურსელებო! 👋',
      city.isNotEmpty ? 'მოგესალმებით ${ablative(city)}! 👋' : 'ახალი ვარ აქ, გავიცნოთ ერთმანეთი',
      region.isNotEmpty && region != city ? 'ვინ არის აქ ${ablative(region)}?' : 'რომელი ქართული კერძი გიყვართ ყველაზე მეტად?',
    ];

const _fsItems = [
  ('photo', 'camera', 'პროფილის ფოტო'),
  ('edu', 'school', 'სკოლა ან უნივერსიტეტი'),
  ('place', 'pin', 'ქალაქი და კუთხე'),
  ('people', 'users', 'დაამატე 5 ადამიანი'),
  ('post', 'edit', 'პირველი პოსტი'),
];

/// whether the first steps card may show at all (the tests keep it away unless one asks for it)
bool firstStepsOn = true;

/// The card on the home page until the five steps are done or it is hidden; once done, a "well done" once.
class FirstStepsCard extends StatefulWidget {
  const FirstStepsCard({super.key, required this.onWrite});

  /// a first post with these words (the wizard's last step)
  final void Function(String text) onWrite;
  @override
  State<FirstStepsCard> createState() => FirstStepsCardState();
}

class FirstStepsCardState extends State<FirstStepsCard> {
  FsProgress? p;
  bool hidden = true, cheer = false, _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    reload();
  }

  String _k(String k) => 'fs:${context.me.id}:$k';

  Future<void> reload() async {
    final prefs = await _prefs();
    if (!mounted) return;
    if (!firstStepsOn || (prefs?.getBool(_k('hide')) ?? false)) {
      setState(() => hidden = true);
      return;
    }
    final x = await fsProgress(context);
    if (!mounted) return;
    var ch = false;
    if (x.done >= 5) {
      if (!(prefs?.getBool(_k('cheer')) ?? false) && (prefs?.getBool(_k('seen')) ?? false)) {
        ch = true;
        await prefs?.setBool(_k('cheer'), true);
      }
    } else {
      await prefs?.setBool(_k('seen'), true);
    }
    if (mounted) {
      setState(() {
        p = x;
        cheer = ch;
        hidden = x.done >= 5 && !ch;
      });
    }
  }

  Future<void> _hide() async {
    setState(() => hidden = true);
    await (await _prefs())?.setBool(_k('hide'), true);
  }

  Future<void> _open(int step) async {
    final text = await openPage<String>(context, FirstStepsScreen(start: step), full: true);
    if (!mounted) return;
    await reload();
    if (text != null) widget.onWrite(text);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = p;
    if (hidden || x == null) return const SizedBox.shrink();
    Widget box(Widget child) => Container(
          key: const ValueKey('fsteps'),
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 10),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
          child: child,
        );
    if (cheer) {
      return box(Row(children: [
        CircleAvatar(radius: 18, backgroundColor: c.vine.withValues(alpha: .15), child: PIcon('check', size: 20, color: c.vine)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ყოჩაღ! პირველი ნაბიჯები გადადგმულია', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Peera უკვე შენია.', style: TextStyle(color: c.muted, fontSize: 13)),
          ]),
        ),
        IconBtn('x', key: const ValueKey('fs-hide'), label: 'დახურვა', size: 18, onTap: _hide),
      ]));
    }
    final ok = [x.photo, x.edu, x.place, x.people >= 5, x.post];
    return box(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('პირველი ნაბიჯები', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('${x.done} / 5 შესრულებულია', style: TextStyle(color: c.muted, fontSize: 13)),
          ]),
        ),
        IconBtn('x', key: const ValueKey('fs-hide'), label: 'დამალვა', size: 18, onTap: _hide),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 10, 6),
        child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: x.done / 5, minHeight: 6, backgroundColor: c.sunk, color: c.vine)),
      ),
      for (final (i, (k, icon, label)) in _fsItems.indexed)
        InkWell(
          key: ValueKey('fs-$k'),
          borderRadius: BorderRadius.circular(12),
          onTap: ok[i] ? null : () => _open(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: ok[i] ? c.vine.withValues(alpha: .15) : c.sunk, shape: BoxShape.circle),
                child: PIcon(ok[i] ? 'check' : icon, size: 16, color: ok[i] ? c.vine : c.ink),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: label),
                  if (k == 'people' && !ok[i]) TextSpan(text: '  ${x.people.clamp(0, 5)}/5', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
                ]),
                    style: TextStyle(fontWeight: FontWeight.w600, color: ok[i] ? c.muted : c.ink, decoration: ok[i] ? TextDecoration.lineThrough : null)),
              ),
              if (!ok[i]) Padding(padding: const EdgeInsets.only(right: 8), child: Transform.flip(flipX: true, child: PIcon('back', size: 16, color: c.muted))),
            ]),
          ),
        ),
    ]));
  }
}

/// The wizard: one step a screen, each can be skipped. It closes with the words of a first post when one was chosen.
class FirstStepsScreen extends StatefulWidget {
  const FirstStepsScreen({super.key, this.start = 0});
  final int start;
  @override
  State<FirstStepsScreen> createState() => _FirstStepsScreenState();
}

class _FirstStepsScreenState extends State<FirstStepsScreen> {
  late int step = widget.start;
  FsProgress? p;
  Map<String, dynamic> me = const {};
  bool busy = false, _started = false;
  final city = TextEditingController(), place = TextEditingController();
  String region = '';
  List<Suggestion>? people;
  final asked = <String>{};
  Uint8List? photo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    city.dispose();
    place.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.app.api;
    final x = await fsProgress(context);
    Map<String, dynamic> m = const {};
    try {
      m = await api.mySettings();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      p = x;
      me = m;
      city.text = '${m['city'] ?? ''}';
      place.text = '${m['home_place'] ?? ''}';
      region = homeRegions.contains(m['home_region']) ? '${m['home_region']}' : '';
    });
    if (step == 3) _people();
  }

  Future<void> _people() async {
    final app = context.app;
    try {
      final s = await app.api.suggestions();
      if (mounted) setState(() => people = s.where((x) => x.p.id != app.api.myId).take(15).toList());
    } catch (_) {
      if (mounted) setState(() => people = const []);
    }
  }

  void _next() {
    if (step >= 4) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => step++);
    if (step == 3 && people == null) _people();
  }

  Future<void> _photo() async {
    final app = context.app;
    List<Uint8List> got;
    try {
      got = await photoSource(false);
    } catch (_) {
      return;
    }
    if (got.isEmpty || !mounted) return;
    final f = await photoFrame(context, got.first, aspect: 1, max: 640, title: 'პროფილის ფოტო');
    if (f == null || !mounted) return;
    setState(() {
      busy = true;
      photo = f.bytes;
    });
    try {
      final m = await app.api.uploadPhoto(PreparedPhoto(f.bytes, f.w, f.h));
      await app.api.updateMe({'avatar_url': m.url});
      app.refreshMe?.call();
      p?.photo = true;
      if (mounted) _next();
    } catch (e) {
      if (mounted) {
        toast(context, errText(e));
        setState(() => photo = null);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edu() async {
    final app = context.app;
    final got = await eduSheet(context, null);
    if (got == null || !mounted) return;
    final list = [for (final e in (me['edu'] is List ? me['edu'] as List : const [])) if (e is Map) Map<String, dynamic>.from(e), got];
    if (await attempt(context, () => app.api.updateMe({'edu': list.take(8).toList()}))) {
      app.api.joinEduGroups().then((_) {}, onError: (_) {});
      app.refreshMe?.call();
      p?.edu = true;
      if (mounted) {
        toast(context, 'შეგიყვანეთ კლასისა და კურსის ჯგუფებში');
        _next();
      }
    }
  }

  Future<void> _place() async {
    final c = city.text.trim(), pl = place.text.trim();
    if (c.isEmpty && region.isEmpty && pl.isEmpty) {
      _next();
      return;
    }
    final app = context.app;
    if (await attempt(context, () => app.api.updateMe({'city': c, 'home_region': region, 'home_place': pl}))) {
      app.refreshMe?.call();
      if (mounted) _next();
    }
  }

  Future<void> _add(String uid) async {
    final app = context.app;
    setState(() => asked.add(uid));
    try {
      if (app.friends.incoming.contains(uid)) {
        await app.friends.accept(uid);
      } else {
        await app.friends.add(uid);
      }
      final x = p;
      if (x != null) {
        setState(() => x.people++);
        if (x.people == 5 && mounted) toast(context, 'ყოჩაღ! 5 ადამიანი დაემატა');
      }
    } catch (e) {
      if (mounted) {
        setState(() => asked.remove(uid));
        toast(context, errText(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = p, my = context.me;
    final hasPhoto = photo != null || (my.avatarUrl ?? '').isNotEmpty || '${me['avatar_url'] ?? ''}'.isNotEmpty;
    Widget title(String t, String sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(sub, style: TextStyle(color: c.muted, height: 1.4)),
          const SizedBox(height: 16),
        ]);
    Widget body;
    var mainLabel = '';
    VoidCallback? main;
    switch (step) {
      case 0:
        body = Column(children: [
          const SizedBox(height: 12),
          GestureDetector(
            onTap: busy ? null : _photo,
            child: Stack(clipBehavior: Clip.none, children: [
              photo != null
                  ? ClipOval(child: Image.memory(photo!, width: 120, height: 120, fit: BoxFit.cover))
                  : hasPhoto
                      ? Avatar(p: my, size: 120)
                      : CircleAvatar(radius: 60, backgroundColor: c.sunk, child: PIcon('camera', size: 40, color: c.muted)),
              Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(radius: 18, backgroundColor: c.accent, child: PIcon('camera', size: 18, color: c.onAccent)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Text(hasPhoto ? 'კარგი ფოტოა!' : 'დაამატე პროფილის ფოტო', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('ფოტოთი მეგობრები და ნაცნობები უფრო ადვილად გიცნობენ.', textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
        ]);
        mainLabel = hasPhoto ? 'შემდეგი' : 'ფოტოს არჩევა';
        main = busy ? null : (hasPhoto ? _next : _photo);
      case 1:
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          title('სად სწავლობ ან სწავლობდი?', 'შეგიყვანთ შენი კლასისა და კურსის ჯგუფებში, სადაც კლასელები და კურსელები დაგხვდებიან.'),
          if (x?.edu ?? false)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('უკვე დამატებულია. შეგიძლია კიდევ ერთი დაამატო.', style: TextStyle(color: c.vine, fontWeight: FontWeight.w600))),
        ]);
        mainLabel = 'სკოლის ან უნივერსიტეტის დამატება';
        main = _edu;
      case 2:
        final q = city.text.trim().toLowerCase();
        final hits = q.isEmpty ? const <String>[] : georgianCities.where((x) => x.toLowerCase().startsWith(q) && x != city.text.trim()).take(5).toList();
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          title('საიდან ხარ?', 'ქალაქით და კუთხით მოგძებნიან თანასოფლელები, „ჯგუფებში“ კი შენი კუთხის ჯგუფებს ნახავ.'),
          TextField(key: const ValueKey('fs-city'), controller: city, maxLength: 60, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'სად ცხოვრობ', hintText: 'მაგ. თბილისი', counterText: '')),
          if (hits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 6, children: [for (final h in hits) ActionChip(label: Text(h), onPressed: () => setState(() => city.text = h))]),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('fs-region'),
            isExpanded: true,
            initialValue: region.isEmpty ? null : region,
            decoration: const InputDecoration(labelText: 'მშობლიური კუთხე'),
            items: [for (final r in homeRegions) DropdownMenuItem(value: r, child: Text(r))],
            onChanged: (v) => setState(() => region = v ?? ''),
          ),
          const SizedBox(height: 12),
          TextField(controller: place, maxLength: 60, decoration: const InputDecoration(labelText: 'სოფელი ან ქალაქი (არასავალდებულო)', hintText: 'მაგ. სვირი, ონი, ზესტაფონი', counterText: '')),
        ]);
        mainLabel = 'შენახვა';
        main = _place;
      case 3:
        final l = people;
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: title('დაამატე 5 ადამიანი', 'მეგობრები, ნათესავები, თანასოფლელები. მათი პოსტები შენს ფიდში გამოჩნდება.')),
            const SizedBox(width: 10),
            Text.rich(TextSpan(children: [
              TextSpan(text: '${(x?.people ?? 0).clamp(0, 5)}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: c.accent)),
              TextSpan(text: '/5', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
            ]), key: const ValueKey('fs-n')),
          ]),
          if (l == null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (l.isEmpty)
            Empty(icon: 'users', title: 'ჯერ ვერავინ ვიპოვეთ', text: 'მოგვიანებით სცადე ან მოიწვიე მეგობრები.', action: 'მეგობრის მოწვევა', onAction: () => inviteSheet(context))
          else
            for (final s in l)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Avatar(p: s.p, size: 44),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(s.mutual > 0 ? '${s.mutual} საერთო მეგობარი' : ((s.p.city ?? '').isEmpty ? 'Peera-ზეა' : s.p.city!), style: TextStyle(color: c.muted, fontSize: 13)),
                    ]),
                  ),
                  if (asked.contains(s.p.id) || context.app.friends.outgoing.contains(s.p.id))
                    Text('გაგზავნილია', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700))
                  else
                    FilledButton(
                      key: ValueKey('fs-add-${s.p.id}'),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 14)),
                      onPressed: () => _add(s.p.id),
                      child: const Text('დამატება'),
                    ),
                ]),
              ),
        ]);
        mainLabel = 'შემდეგი';
        main = _next;
      default:
        final ideas = fsIdeas('${me['city'] ?? ''}', '${me['home_region'] ?? ''}');
        body = Column(children: [
          const SizedBox(height: 12),
          CircleAvatar(radius: 34, backgroundColor: c.sunk, child: PIcon('edit', size: 30, color: c.accent)),
          const SizedBox(height: 14),
          const Text('დაწერე პირველი პოსტი', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('მიესალმე კურსელებს ან გაუზიარე ფოტო. აირჩიე იდეა ან დაწერე შენი.', textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
          const SizedBox(height: 14),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            for (final (i, t) in ideas.indexed) ActionChip(key: ValueKey('fs-idea-$i'), label: Text(t), onPressed: () => Navigator.of(context).pop(t)),
          ]),
        ]);
        mainLabel = 'პოსტის დაწერა';
        main = () => Navigator.of(context).pop('');
    }
    return Scaffold(
      appBar: peeraBar(context, title: 'პირველი ნაბიჯები'),
      body: x == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var k = 0; k < 5; k++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: k == step ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(color: k < step ? c.vine : (k == step ? c.accent : c.line), borderRadius: BorderRadius.circular(4)),
                    ),
                ]),
              ),
              Expanded(child: ListView(key: ValueKey('fs-step-$step'), padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), children: [body])),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(children: [
                    TextButton(key: const ValueKey('fs-skip'), onPressed: busy ? null : _next, child: Text(step == 4 ? 'მოგვიანებით' : 'გამოტოვება')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('fs-main'),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                        onPressed: main,
                        child: Text(busy ? 'იტვირთება…' : mainLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }
}

// ---------- on this day ----------

/// "ამ დღეს, N წლის წინ": my post from this day in an earlier year, with the rest a tap further and the way to share it.
class MemoriesCard extends StatefulWidget {
  const MemoriesCard({super.key, required this.onShare});
  final void Function(String text) onShare;
  @override
  State<MemoriesCard> createState() => _MemoriesCardState();
}

String memoryText(Post p) => 'მოგონება ${p.createdAt.year} წლიდან 💭\n$siteUrl/#post-${p.id}';

class _MemoriesCardState extends State<MemoriesCard> {
  List<int> ids = const [];
  Post? post;
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
    if (app.home.off.contains('memories') && context.me.role != 'admin') return;
    try {
      final i = await app.api.myMemories();
      if (i.isEmpty) return;
      final rows = await app.api.postsByIds([i.first]);
      if (rows.isEmpty) return;
      await app.posts.load(rows);
      if (mounted) {
        setState(() {
          ids = i;
          post = rows.first;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, p = post;
    if (p == null) return const SizedBox.shrink();
    final yrs = DateTime.now().year - p.createdAt.year;
    return Container(
      key: const ValueKey('memo'),
      margin: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      color: c.accent.withValues(alpha: .06),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
          child: Row(children: [
            Expanded(child: Text('ამ დღეს, $yrs წლის წინ', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            if (ids.length > 1)
              TextButton(
                key: const ValueKey('memo-all'),
                onPressed: () => openPage(context, const MemoriesScreen(), full: true),
                child: Text('ყველა · ${ids.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
        PostCard(key: ValueKey('memo-post-${p.id}'), post: p),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('memo-share'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => widget.onShare(memoryText(p)),
              icon: PIcon('repost', size: 18, color: c.ink),
              label: const Text('მოგონების გაზიარება'),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Every memory of today, by year.
class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});
  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  List<Post>? posts;
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
      final ids = await app.api.myMemories();
      final rows = await app.api.postsByIds(ids);
      await app.posts.load(rows);
      if (mounted) setState(() => posts = rows);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = posts;
    return Scaffold(
      appBar: peeraBar(context, title: 'მოგონებები'),
      body: p == null
          ? (error != null ? Center(child: Empty(icon: 'clock', title: 'ვერ ჩაიტვირთა', text: errText(error!))) : const Center(child: CircularProgressIndicator()))
          : p.isEmpty
              ? const Center(child: Empty(icon: 'clock', title: 'დღეს მოგონება არ არის'))
              : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                  for (final x in p) ...[
                    Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 6), child: Text('${x.createdAt.year}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                    PostCard(key: ValueKey('post-${x.id}'), post: x),
                  ],
                ]),
    );
  }
}

// ---------- people you may know ----------

/// Inside the feed after the second post: people you may know, sideways, each with "დამატება".
class SuggestRow extends StatefulWidget {
  const SuggestRow({super.key});
  @override
  State<SuggestRow> createState() => _SuggestRowState();
}

class _SuggestRowState extends State<SuggestRow> {
  List<Suggestion>? list;
  final asked = <String>{};
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final app = context.app;
    app.api.suggestions().then((s) {
      for (final x in s) {
        app.people.put(x.p);
      }
      if (mounted) setState(() => list = s.take(10).toList());
    }, onError: (_) {
      if (mounted) setState(() => list = const []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, l = list;
    if (l == null || l.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('suggest'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(children: [
            const Expanded(child: Text('შეიძლება იცნობდე', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            TextButton(onPressed: () => app.goTab?.call('friends'), child: const Text('ყველა', style: TextStyle(fontWeight: FontWeight.w700))),
          ]),
        ),
        SizedBox(
          height: 206,
          child: ListView.separated(
            key: const ValueKey('suggest-row'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: l.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final s = l[i], sent = asked.contains(s.p.id) || app.friends.outgoing.contains(s.p.id);
              return Container(
                key: ValueKey('sug-${s.p.id}'),
                width: 148,
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
                decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
                child: Column(children: [
                  GestureDetector(
                    onTap: () => openPage(context, PersonScreen(uid: s.p.id)),
                    child: Column(children: [
                      Avatar(p: s.p, size: 64),
                      const SizedBox(height: 8),
                      Text(s.p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(s.mutual > 0 ? '${s.mutual} საერთო მეგობარი' : ((s.p.city ?? '').isEmpty ? 'Peera-ზეა' : s.p.city!),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5)),
                    ]),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: sent
                        ? OutlinedButton(onPressed: null, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)), child: const Text('გაგზავნილია'))
                        : FilledButton(
                            key: ValueKey('sug-add-${s.p.id}'),
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                            onPressed: () async {
                              setState(() => asked.add(s.p.id));
                              try {
                                await app.friends.add(s.p.id);
                              } catch (e) {
                                if (!mounted) return;
                                setState(() => asked.remove(s.p.id));
                                toast(this.context, errText(e));
                              }
                            },
                            child: const Text('დამატება'),
                          ),
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ---------- inviting, the welcome gift ----------

String inviteUrl(Profile me) => '$siteUrl/?i=${Uri.encodeComponent((me.username ?? '').isNotEmpty ? me.username! : me.id)}';

/// "მოიწვიე მეგობრები": my link, what it brings (as the coin rules say), and how many came by it.
Future<void> inviteSheet(BuildContext context) async {
  final app = context.app, url = inviteUrl(context.me);
  Map<String, int> r = const {};
  (int, int)? came;
  try {
    r = await app.api.inviteRules();
  } catch (_) {}
  try {
    came = await app.api.referrals();
  } catch (_) {}
  if (!context.mounted) return;
  final w = r['welcome'], inv = r['invite'];
  final text = w != null || inv != null
      ? 'გაუგზავნე ბმული მეგობრებს.${w != null ? ' რეგისტრაციისას თითოეული $w მონეტას მიიღებს საჩუქრად' : ''}${inv != null ? '${w != null ? ',' : ''} შენ კი $inv მონეტას თითოეულზე, ვინც შენი ბმულით მოვა' : ''}.'
      : 'გაუგზავნე ბმული მეგობრებს: კლასელებს, კურსელებს.';
  final share = w != null ? 'შემოდი Peera-ზე: ჩემი ბმულით რეგისტრაციისას $w მონეტა საჩუქრად\n$url' : 'შემოდი Peera-ზე\n$url';
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: context.pc.surface,
    builder: (s) {
      final c = s.pc, n = came;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('მოიწვიე მეგობრები', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Center(child: Text('🎁', style: TextStyle(fontSize: 46))),
            const SizedBox(height: 8),
            Text(text, key: const ValueKey('inv-text'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.45)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Expanded(child: SelectableText(url, maxLines: 1, style: TextStyle(color: c.ink, fontSize: 13.5))),
                IconBtn('copy', key: const ValueKey('inv-copy'), label: 'კოპირება', onTap: () {
                  Clipboard.setData(ClipboardData(text: url));
                  toast(s, 'ბმული დაკოპირდა');
                }),
              ]),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('inv-share'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => shareText(s, share),
              icon: PIcon('share', size: 18, color: c.onAccent),
              label: const Text('ბმულის გაზიარება'),
            ),
            if (n != null && n.$1 > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('შენი ბმულით დარეგისტრირდა ${n.$1}${inv != null && n.$2 > 0 ? ' · +${n.$2 * inv} მონეტა' : ''}',
                    textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 13)),
              ),
          ]),
        ),
      );
    },
  );
}

/// The welcome gift, said once when it has come (within three days of joining).
Future<void> welcomeGift(BuildContext context) async {
  final app = context.app, me = context.me;
  final prefs = await _prefs();
  if (prefs?.getString('welc') == me.id) return;
  int? amount;
  try {
    amount = await app.api.welcomeGift();
  } catch (_) {}
  if (amount == null || !context.mounted) return;
  await prefs?.setString('welc', me.id);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('მოგესალმებით Peera-ზე!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Center(child: Text('🎁', style: TextStyle(fontSize: 46))),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '$amount მონეტა', style: const TextStyle(fontWeight: FontWeight.w800)),
              const TextSpan(text: ' საჩუქრად, რეგისტრაციისთვის. მონეტებით თამაშობ და ჩუქნი.'),
            ]),
            key: const ValueKey('welcome-text'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton(
                key: const ValueKey('welcome-ok'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                onPressed: () => Navigator.of(s).pop(),
                child: const Text('მადლობა!'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                onPressed: () {
                  Navigator.of(s).pop();
                  inviteSheet(context);
                },
                child: const Text('მეგობრების მოწვევა', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
}

// ---------- my topics ----------

/// name, emoji and the hashtags of each topic (extras.js TOPICS)
const topics = [
  ('სწავლა', '📚', ['სწავლა', 'ლექცია', 'კონსპექტი', 'გამოცდა']),
  ('უნივერსიტეტი', '🎓', ['უნივერსიტეტი', 'სტუდენტი', 'ფაკულტეტი']),
  ('სკოლა', '🏫', ['სკოლა', 'კლასი', 'ეროვნულები']),
  ('ტექნოლოგიები', '💻', ['პროგრამირება', 'ტექნოლოგიები', 'ai']),
  ('ფეხბურთი', '⚽', ['ფეხბურთი', 'ეროვნული', 'სპორტი']),
  ('მოგზაურობა', '🧭', ['მოგზაურობა', 'მთა', 'ზღვა', 'ლაშქრობა']),
  ('ოჯახი', '👪', ['ოჯახი', 'ბავშვები']),
  ('მუსიკა', '🎶', ['მუსიკა', 'პოლიფონია', 'სიმღერა']),
  ('ისტორია', '📜', ['ისტორია', 'ძველი']),
  ('თამაშები', '🎲', ['ნარდი', 'ჭადრაკი', 'ჯოკერი']),
  ('ბუნება', '🌿', ['ბუნება', 'ცხოველები']),
  ('ხელოვნება', '🎨', ['ხელოვნება', 'ფოტო']),
  ('ბიზნესი', '💼', ['ბიზნესი', 'სამსახური']),
  ('დღესასწაულები', '🕯️', ['დღესასწაული', 'ეკლესია']),
];

String normTag(String t) => t.trim().replaceFirst(RegExp(r'^#+'), '').toLowerCase();

/// "ჩემი თემები": topics and my own hashtags; true when something changed (the "for you" feed is then read again).
Future<bool> topicsSheet(BuildContext context) async {
  final app = context.app;
  Set<String> mine;
  try {
    mine = await app.api.tagFollows();
  } catch (_) {
    mine = {};
  }
  if (!context.mounted) return false;
  var changed = false;
  final add = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => StatefulBuilder(builder: (s, set) {
      final c = s.pc;
      Future<void> follow(List<String> tags, bool on) async {
        try {
          await app.api.followTags(tags, on);
          set(() {
            if (on) {
              mine.addAll(tags);
            } else {
              mine.removeAll(tags);
            }
            changed = true;
          });
        } catch (e) {
          if (s.mounted) toast(s, errText(e));
        }
      }

      final extra = mine.where((t) => !topics.any((x) => x.$3.contains(t))).toList()..sort();
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(s).bottom),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(s).height * .85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              const Text('ჩემი თემები', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('აირჩიე, რა გაინტერესებს. „შენთვის“ ფიდში ამ თემების პოსტები უფრო ხშირად და უფრო მაღლა გამოჩნდება.', style: TextStyle(color: c.muted, height: 1.4)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (i, (name, emoji, tags)) in topics.indexed)
                  () {
                    final on = tags.every(mine.contains);
                    return FilterChip(
                      key: ValueKey('topic-$i'),
                      avatar: Text(emoji),
                      label: Text(name),
                      selected: on,
                      showCheckmark: false,
                      selectedColor: c.accent.withValues(alpha: .16),
                      side: BorderSide(color: on ? c.accent : c.line),
                      labelStyle: TextStyle(color: on ? c.accent : c.ink, fontWeight: FontWeight.w700),
                      onSelected: (_) => follow(tags, !on),
                    );
                  }(),
              ]),
              const SizedBox(height: 16),
              const Text('ჩემი ჰეშთეგები', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (extra.isEmpty)
                Text('ჯერ არცერთი. ჰეშთეგის გვერდზეც შეგიძლია „გამოწერა“.', style: TextStyle(color: c.muted, fontSize: 13))
              else
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final t in extra)
                    InputChip(key: ValueKey('tag-$t'), label: Text('#$t'), onDeleted: () => follow([t], false), deleteButtonTooltipMessage: 'მოხსნა'),
                ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('tag-new'),
                    controller: add,
                    maxLength: 40,
                    decoration: const InputDecoration(hintText: '#ჰეშთეგი, მაგ. სვანეთი', counterText: ''),
                    onSubmitted: (v) {
                      final t = normTag(v);
                      if (t.isEmpty) return;
                      add.clear();
                      follow([t], true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const ValueKey('tag-add'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  onPressed: () {
                    final t = normTag(add.text);
                    if (t.isEmpty) return;
                    add.clear();
                    follow([t], true);
                  },
                  icon: PIcon('plus', size: 18, color: c.onAccent),
                  label: const Text('დამატება'),
                ),
              ]),
            ]),
            ),
          ),
        ),
      );
    }),
  );
  return changed;
}
