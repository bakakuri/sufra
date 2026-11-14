// The Georgian kitchen (kitchen.js): recipes by category and name; one recipe whose amounts follow the portions, cooked
// a step at a time (with a timer when a step names minutes), its ingredients put on an event's "who brings what" list,
// "I made it too" with a photo; a recipe written or changed.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../community/events.dart';
import '../config.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../feed/photo_viewer.dart';
import '../feed/post_actions.dart';
import '../feed/post_card.dart';
import '../people/profile_parts.dart';
import '../profile/profile.dart';
import '../settings/frame_photo.dart';
import '../ui/bits.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/look.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// the categories, their sign and colour (kitchen.js RCAT)
const recipeCats = [('ცომეული', '🥟', 30), ('ხორციანი', '🍖', 8), ('ბოსტნეული', '🥗', 110), ('წვნიანი', '🍲', 22), ('სალათი', '🥙', 140), ('ტკბილეული', '🍯', 40), ('სოუსი', '🫙', 350), ('სხვა', '🍽️', 260)];

(String, String, int) recipeCat(Object? c) => recipeCats.firstWhere((x) => x.$1 == c, orElse: () => recipeCats.last);

String cookTime(int m) => m >= 60 ? '${m ~/ 60} სთ${m % 60 != 0 ? ' ${m % 60} წთ' : ''}' : '$m წთ';

const _fr = {'½': .5, '¼': .25, '¾': .75, '⅓': 1 / 3, '⅔': 2 / 3};

/// an amount in kitchen words: 3, 1½, 250
String fmtAmount(double x) {
  if (x >= 10) return '${x >= 100 ? (x / 5).round() * 5 : x.round()}';
  final whole = x.floor(), fr = x - whole;
  final f = fr < .13 ? '' : (fr < .38 ? '¼' : (fr < .63 ? '½' : (fr < .88 ? '¾' : '')));
  final n = fr >= .88 ? whole + 1 : whole;
  if (n == 0 && f.isEmpty) return x > 0 ? '⅛' : '0';
  return '${n != 0 || f.isEmpty ? '$n' : ''}$f';
}

double _num(String? a, [String? b]) => (a == null || a.isEmpty ? 0 : double.tryParse(a.replaceAll(',', '.')) ?? 0) + (b == null || b.isEmpty ? 0 : _fr[b] ?? 0);

/// "500 გ" for twice as many: "1000 გ"; "2–3 კბილი" and "½ კონა" scale too; words alone stay
String scaleAmount(String q, double k) {
  if (k == 1) return q;
  var m = RegExp(r'^(\d+(?:[.,]\d+)?)\s*[–-]\s*(\d+(?:[.,]\d+)?)(\s*)(.*)$').firstMatch(q);
  if (m != null) {
    final rest = m.group(4) ?? '';
    return '${fmtAmount(_num(m.group(1)) * k)}–${fmtAmount(_num(m.group(2)) * k)}${rest.isNotEmpty ? ((m.group(3) ?? '').isEmpty ? ' ' : m.group(3)) : ''}$rest';
  }
  m = RegExp(r'^(\d+(?:[.,]\d+)?)?\s*([½¼¾⅓⅔])?(\s*)(.*)$').firstMatch(q);
  if (m == null || (m.group(1) == null && m.group(2) == null)) return q;
  final rest = m.group(4) ?? '';
  return '${fmtAmount(_num(m.group(1), m.group(2)) * k)}${rest.isNotEmpty ? ((m.group(3) ?? '').isEmpty ? ' ' : m.group(3)) : ''}$rest';
}

/// the minutes a step names ("12–15 წუთი", "1 საათი"), or 0
int stepMinutes(String s) {
  final m = RegExp(r'(\d+)(?:\s*[–-]\s*(\d+))?\s*(წუთ|საათ)').firstMatch(s);
  if (m == null) return 0;
  final n = int.tryParse(m.group(2) ?? '') ?? int.tryParse(m.group(1)!) ?? 0;
  return m.group(3) == 'საათ' ? n * 60 : n;
}

List<({String n, String q})> _ings(Object? v) => [
      for (final x in (v is List ? v : const []))
        if (x is Map && '${x['n'] ?? ''}'.trim().isNotEmpty) (n: '${x['n']}', q: '${x['q'] ?? ''}'),
    ];
List<String> _steps(Object? v) => [for (final x in (v is List ? v : const [])) if ('$x'.trim().isNotEmpty) '$x'];

/// the dish's photo, or its category's sign on its colour
class RecipeHero extends StatelessWidget {
  const RecipeHero({super.key, required this.r, this.size = 30});
  final Map<String, dynamic> r;
  final double size;
  @override
  Widget build(BuildContext context) {
    final u = r['photo_url'] as String?, k = recipeCat(r['category']);
    if (u != null && u.startsWith('http') && !ecoMode.value) return PImage(u);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HSLColor.fromAHSL(1, k.$3.toDouble(), .55, .62).toColor(), HSLColor.fromAHSL(1, (k.$3 + 30) % 360.toDouble(), .5, .45).toColor()],
        ),
      ),
      child: Center(child: Text(k.$2, style: TextStyle(fontSize: size))),
    );
  }
}

/// The recipes.
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});
  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  String cat = '';
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
    final g = ++_gen;
    try {
      final r = await context.app.api.recipes(cat: cat, q: q.text.trim());
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
    final id = await openPage<int>(context, const RecipeFormScreen(), full: true);
    if (id != null && mounted) await openPage(context, RecipeScreen(id: id), full: true);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, r = rows;
    return Scaffold(
      appBar: peeraBar(context, title: 'ქართული სამზარეულო', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: FilledButton.icon(
            key: const ValueKey('rc-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: _new,
            icon: PIcon('plus', size: 17, color: c.onAccent),
            label: const Text('რეცეპტი'),
          ),
        ),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: TextField(
            key: const ValueKey('rc-q'),
            controller: q,
            textInputAction: TextInputAction.search,
            onChanged: (_) {
              _wait?.cancel();
              _wait = Timer(const Duration(milliseconds: 350), _load);
            },
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(hintText: 'ძებნა: ხინკალი, ლობიო, ხაჭაპური…', prefixIcon: Padding(padding: const EdgeInsets.all(12), child: PIcon('search', size: 20, color: c.muted))),
          ),
        ),
        ChipsBar(prefix: 'rcc', items: [('', 'ყველა'), for (final (k, e, _) in recipeCats) (k, '$e $k')], value: cat, onPick: (k) {
          setState(() => cat = k);
          _load();
        }),
        Expanded(
          child: r == null && error == null
              ? const Center(child: CircularProgressIndicator())
              : r == null
                  ? Empty(icon: 'book', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
                  : r.isEmpty
                      ? Empty(icon: 'book', title: 'რეცეპტი ვერ მოიძებნა', text: 'დაამატე შენი და სხვებიც ნახავენ.', action: 'რეცეპტის დამატება', onAction: _new)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: GridView.count(
                            crossAxisCount: 2,
                            padding: const EdgeInsets.all(12),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: .72,
                            children: [
                              for (final x in r)
                                Material(
                                  color: c.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    key: ValueKey('rcp-${x['id']}'),
                                    onTap: () async {
                                      await openPage(context, RecipeScreen(id: asInt(x['id'])), full: true);
                                      _load();
                                    },
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Expanded(
                                        child: Stack(fit: StackFit.expand, children: [
                                          RecipeHero(r: x),
                                          Positioned(
                                            left: 8,
                                            bottom: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(999)),
                                              child: Text('⏱ ${cookTime(asInt(x['minutes'], 60))}', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                                            ),
                                          ),
                                        ]),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                                        child: Text('${x['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Text(
                                          '${x['category'] ?? ''}${'${x['region'] ?? ''}'.isNotEmpty ? ' · ${x['region']}' : ''}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: c.muted, fontSize: 12),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                                        child: Row(children: [
                                          PIcon('heart', size: 14, color: c.nope),
                                          const SizedBox(width: 3),
                                          Text('${asInt(x['likes'])}', style: TextStyle(color: c.muted, fontSize: 12)),
                                          const Spacer(),
                                          if (asInt(x['cooks']) > 0) ...[
                                            PIcon('camera', size: 14, color: c.muted),
                                            const SizedBox(width: 3),
                                            Text('${asInt(x['cooks'])}', style: TextStyle(color: c.muted, fontSize: 12)),
                                          ],
                                        ]),
                                      ),
                                    ]),
                                  ),
                                ),
                            ],
                          ),
                        ),
        ),
      ]),
    );
  }
}

/// One recipe.
class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key, required this.id});
  final int id;
  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  Map<String, dynamic>? r;
  bool liked = false, loaded = false;
  List<Map<String, dynamic>> cooks = const [];
  int serv = 4;
  Object? error;
  final ticked = <int>{};
  bool _started = false;

  double get k => serv / asInt(r?['servings'], 4).clamp(1, 40);

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
      final x = await app.api.recipe(widget.id);
      if (x != null) await app.people.ensure([if (x.r['author'] != null) '${x.r['author']}', for (final c in x.cooks) '${c['user_id']}']);
      if (!mounted) return;
      setState(() {
        if (r == null && x != null) serv = asInt(x.r['servings'], 4).clamp(1, 40);
        r = x?.r;
        liked = x?.liked ?? false;
        cooks = x?.cooks ?? const [];
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

  Future<void> _like() async {
    final x = r!, on = !liked;
    setState(() {
      liked = on;
      x['likes'] = (asInt(x['likes']) + (on ? 1 : -1)).clamp(0, 1 << 30);
    });
    try {
      await context.app.api.likeRecipe(widget.id, on);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        liked = !on;
        x['likes'] = (asInt(x['likes']) + (on ? -1 : 1)).clamp(0, 1 << 30);
      });
      toast(context, errText(e));
    }
  }

  Future<void> _toEvent() async {
    final app = context.app, me = context.me, c = context.pc, x = r!, ings = _ings(x['ingredients']);
    List<Map<String, dynamic>> evs = const [];
    try {
      evs = await app.api.myComingEvents();
    } catch (_) {}
    if (!mounted) return;
    if (evs.isEmpty) {
      final go = await showModalBottomSheet<bool>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        backgroundColor: c.surface,
        builder: (s) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('სუფრაზე წაღება', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('მომავალი ღონისძიება არ გაქვს. შექმენი სუფრა და ინგრედიენტები „ვინ რა მოიტანს“ სიაში ჩაჯდება.'),
              const SizedBox(height: 12),
              FilledButton(key: const ValueKey('rce-new'), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.of(s).pop(true), child: const Text('ღონისძიების შექმნა')),
            ]),
          ),
        ),
      );
      if (go == true && mounted) await openPage(context, const EventFormScreen(), full: true);
      return;
    }
    var ev = asInt(evs.first['id']);
    final pick = {for (var i = 0; i < ings.length; i++) i};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (s) => AppScope(
        app: app,
        me: me,
        child: StatefulBuilder(
          builder: (s, set) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('სუფრაზე წაღება', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  key: const ValueKey('rce-ev'),
                  isExpanded: true,
                  initialValue: ev,
                  decoration: const InputDecoration(labelText: 'ღონისძიება'),
                  items: [for (final e in evs) DropdownMenuItem(value: asInt(e['id']), child: Text('${e['title']} · ${fullDate(asTime(e['starts_at']))}', overflow: TextOverflow.ellipsis))],
                  onChanged: (v) => set(() => ev = v ?? ev),
                ),
                const SizedBox(height: 6),
                Text('მონიშნული ინგრედიენტები ჩაჯდება „ვინ რა მოიტანს“ სიაში. სტუმრები თავად აიღებენ, ვინ რას მოიტანს.', style: TextStyle(color: s.pc.muted, fontSize: 12.5)),
                for (var i = 0; i < ings.length; i++)
                  CheckboxListTile(
                    key: ValueKey('rce-i-$i'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: pick.contains(i),
                    onChanged: (v) => set(() => v == true ? pick.add(i) : pick.remove(i)),
                    title: Text('${ings[i].n}${ings[i].q.isNotEmpty ? ' · ${scaleAmount(ings[i].q, k)}' : ''}'),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const ValueKey('rce-ok'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () {
                    if (pick.isEmpty) {
                      toast(s, 'მონიშნე ერთი მაინც');
                      return;
                    }
                    Navigator.of(s).pop(true);
                  },
                  icon: PIcon('check', size: 17, color: s.pc.onAccent),
                  label: const Text('დამატება'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final names = [for (final i in pick.toList()..sort()) '${ings[i].n}${ings[i].q.isNotEmpty ? ' (${scaleAmount(ings[i].q, k)})' : ''}'];
    if (await attempt(context, () => app.api.addEventItems(ev, names)) && mounted) {
      toast(context, '${names.length} ინგრედიენტი დაემატა სიაში');
      await openPage(context, EventScreen(id: ev), full: true);
    }
  }

  Future<void> _made() async {
    final app = context.app, me = context.me;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => AppScope(app: app, me: me, child: _MadeSheet(id: widget.id)),
    );
    if (ok == true && mounted) {
      toast(context, 'გაზიარდა. ყოჩაღ! 👏');
      _load();
    }
  }

  Future<void> _more() async {
    final c = context.pc, x = r!;
    final k = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(key: const ValueKey('rcm-edit'), leading: const PIcon('edit'), title: const Text('რედაქტირება'), onTap: () => Navigator.of(s).pop('edit')),
          ListTile(key: const ValueKey('rcm-del'), leading: PIcon('trash', color: c.nope), title: Text('წაშლა', style: TextStyle(color: c.nope)), onTap: () => Navigator.of(s).pop('del')),
        ]),
      ),
    );
    if (!mounted) return;
    if (k == 'edit') {
      final id = await openPage<int>(context, RecipeFormScreen(edit: x), full: true);
      if (id != null) _load();
    } else if (k == 'del') {
      if (!await confirm(context, title: 'რეცეპტის წაშლა', text: 'რეცეპტი და მისი ფოტოები წაიშლება.', yes: 'წაშლა', danger: true) || !mounted) return;
      if (await attempt(context, () => context.app.api.deleteRecipe(widget.id)) && mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = r, app = context.app;
    if (x == null) {
      return Scaffold(
        appBar: peeraBar(context, title: 'რეცეპტი'),
        body: !loaded
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Empty(icon: 'book', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
                : const Empty(icon: 'book', title: 'რეცეპტი ვერ მოიძებნა', text: 'შეიძლება წაშლილია.'),
      );
    }
    final author = x['author'] == null ? null : '${x['author']}', mine = author == app.api.myId, cat = recipeCat(x['category']);
    final ings = _ings(x['ingredients']), steps = _steps(x['steps']), who = author == null ? null : app.people[author] ?? Profile(id: author, name: '…');
    return Scaffold(
      appBar: peeraBar(context, title: '${x['title']}', actions: [
        IconBtn('share', key: const ValueKey('rc-share'), label: 'გაზიარება', onTap: () => shareText(context, '${x['title']}\n$siteUrl/#recipe-${x['id']}')),
        if (mine || isStaff(context)) IconBtn('more', key: const ValueKey('rc-more'), label: 'მეტი', onTap: _more),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          SizedBox(height: 210, child: RecipeHero(r: x, size: 64)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${x['title']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              if (who != null)
                InkWell(
                  onTap: () => openPerson(context, who),
                  child: Row(children: [Avatar(p: who, size: 22), const SizedBox(width: 6), Text(who.name, style: const TextStyle(fontWeight: FontWeight.w700))]),
                )
              else
                Row(children: [PIcon('book', size: 16, color: c.accent), const SizedBox(width: 6), Text('სუფრის რეცეპტები', style: TextStyle(color: c.accent, fontWeight: FontWeight.w700))]),
              const SizedBox(height: 8),
              Wrap(spacing: 12, runSpacing: 4, children: [
                Text('⏱ ${cookTime(asInt(x['minutes'], 60))}', style: TextStyle(color: c.muted)),
                Text('${cat.$2} ${x['category']}', style: TextStyle(color: c.muted)),
                if ('${x['region'] ?? ''}'.isNotEmpty) Text('📍 ${x['region']}', style: TextStyle(color: c.muted)),
              ]),
              if ('${x['about'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('${x['about']}', style: const TextStyle(fontSize: 15))),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                liked
                    ? FilledButton.icon(
                        key: const ValueKey('rc-like'),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                        onPressed: _like,
                        icon: PIcon('heart', size: 17, color: c.onAccent),
                        label: Text('გემრიელია · ${asInt(x['likes'])}'),
                      )
                    : OutlinedButton.icon(
                        key: const ValueKey('rc-like'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                        onPressed: _like,
                        icon: const PIcon('heart', size: 17),
                        label: Text('გემრიელია · ${asInt(x['likes'])}'),
                      ),
                OutlinedButton.icon(
                  key: const ValueKey('rc-cook'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                  onPressed: steps.isEmpty ? null : () => openPage(context, CookScreen(title: '${x['title']}', steps: steps), full: true),
                  icon: const PIcon('clips', size: 17),
                  label: const Text('მზადება ნაბიჯ-ნაბიჯ'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('rc-event'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                  onPressed: _toEvent,
                  icon: const PIcon('cal', size: 17),
                  label: const Text('სუფრაზე წაღება'),
                ),
              ]),
            ]),
          ),
          SecHead(
            'ინგრედიენტები',
            trailing: Container(
              decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconBtn('minus', key: const ValueKey('rc-less'), label: 'ნაკლები', size: 18, onTap: serv > 1 ? () => setState(() => serv--) : null),
                Text('$serv პორცია', key: const ValueKey('rc-serv'), style: const TextStyle(fontWeight: FontWeight.w800)),
                IconBtn('plus', key: const ValueKey('rc-more-serv'), label: 'მეტი', size: 18, onTap: serv < 40 ? () => setState(() => serv++) : null),
              ]),
            ),
          ),
          for (var i = 0; i < ings.length; i++)
            CheckboxListTile(
              key: ValueKey('rci-$i'),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: ticked.contains(i),
              onChanged: (v) => setState(() => v == true ? ticked.add(i) : ticked.remove(i)),
              title: Row(children: [
                Expanded(
                  child: Text(ings[i].n, style: TextStyle(fontWeight: FontWeight.w700, decoration: ticked.contains(i) ? TextDecoration.lineThrough : null)),
                ),
                if (ings[i].q.isNotEmpty) Text(scaleAmount(ings[i].q, k), key: ValueKey('rcq-$i'), style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
              ]),
            ),
          const SecHead('მომზადება'),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
                  child: Center(child: Text('${i + 1}', style: TextStyle(color: c.accent, fontWeight: FontWeight.w900))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(steps[i], style: const TextStyle(fontSize: 15))),
              ]),
            ),
          SecHead(
            'გააკეთეს${cooks.isNotEmpty ? ' · ${cooks.length}' : ''}',
            trailing: FilledButton.icon(
              key: const ValueKey('rc-made'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
              onPressed: _made,
              icon: PIcon('camera', size: 16, color: c.onAccent),
              label: const Text('მეც გავაკეთე'),
            ),
          ),
          if (cooks.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('ჯერ არავის უჩვენებია. იყავი პირველი და ატვირთე შენი კერძის ფოტო.', style: TextStyle(color: c.muted)))
          else
            for (final ck in cooks)
              Builder(builder: (context) {
                final uid = '${ck['user_id']}', p = app.people[uid] ?? Profile(id: uid, name: '…'), ph = ck['photo_url'] as String?;
                return Padding(
                  key: ValueKey('rck-${ck['id']}'),
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (ph != null && ph.startsWith('http') && !ecoMode.value)
                      GestureDetector(
                        onTap: () => openPhotos(context, [Media(url: ph)]),
                        child: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 72, height: 72, child: PImage(ph))),
                      ),
                    if (ph != null && !ecoMode.value) const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        InkWell(
                          onTap: () => openPerson(context, p),
                          child: Row(children: [Avatar(p: p, size: 24), const SizedBox(width: 6), Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800))]),
                        ),
                        if ('${ck['note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${ck['note']}')),
                        Text(ago(asTime(ck['created_at'])), style: TextStyle(color: c.muted, fontSize: 12)),
                      ]),
                    ),
                  ]),
                );
              }),
        ]),
      ),
    );
  }
}

class _MadeSheet extends StatefulWidget {
  const _MadeSheet({required this.id});
  final int id;
  @override
  State<_MadeSheet> createState() => _MadeSheetState();
}

class _MadeSheetState extends State<_MadeSheet> {
  final note = TextEditingController();
  String? photo;
  bool busy = false;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _photo() async {
    final app = context.app;
    final got = await photoSource(false);
    if (got.isEmpty || !mounted) return;
    setState(() => busy = true);
    try {
      final m = await app.api.uploadPhoto(await photoPrep(got.first));
      if (mounted) setState(() => photo = m.url);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      await context.app.api.cookedRecipe(widget.id, photo, note.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('მეც გავაკეთე', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: photo != null ? PImage(photo!) : Container(color: c.sunk, child: Center(child: PIcon('camera', color: c.muted))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('შენი კერძის ფოტო', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('არასავალდებულო, მაგრამ ყველას აინტერესებს', style: TextStyle(color: c.muted, fontSize: 12.5)),
                  TextButton(key: const ValueKey('rcm-photo'), onPressed: busy ? null : _photo, child: Text(photo != null ? 'შეცვლა' : 'ფოტოს არჩევა')),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('rcm-note'),
              controller: note,
              maxLength: 300,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'რამდენიმე სიტყვა', hintText: 'მაგ. ცოტა მეტი ნიორი ჩავამატე და ძალიან კარგი გამოვიდა', counterText: ''),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('rcm-ok'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: busy ? null : _save,
              icon: PIcon('check', size: 17, color: c.onAccent),
              label: const Text('გაზიარება'),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Cooking: one step at a time in big letters, a timer when the step names minutes; back leaves it.
class CookScreen extends StatefulWidget {
  const CookScreen({super.key, required this.title, required this.steps});
  final String title;
  final List<String> steps;
  @override
  State<CookScreen> createState() => _CookScreenState();
}

class _CookScreenState extends State<CookScreen> {
  int i = 0, left = 0;
  Timer? tm;

  @override
  void dispose() {
    tm?.cancel();
    super.dispose();
  }

  void _timer(int mins) {
    if (tm != null) {
      tm!.cancel();
      setState(() => tm = null);
      return;
    }
    setState(() {
      left = mins * 60;
      tm = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => left--);
        if (left <= 0) {
          t.cancel();
          setState(() => tm = null);
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.alert);
          toast(context, '⏰ დრო ამოიწურა!');
        }
      });
    });
  }

  void _go(int d) {
    if (d > 0 && i == widget.steps.length - 1) {
      toast(context, 'გემრიელად მიირთვით! 🍽️');
      Navigator.of(context).pop();
      return;
    }
    tm?.cancel();
    setState(() {
      tm = null;
      i = (i + d).clamp(0, widget.steps.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, s = widget.steps[i], mins = stepMinutes(s);
    final last = i == widget.steps.length - 1;
    return Scaffold(
      appBar: peeraBar(context, title: widget.title),
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LinearProgressIndicator(value: (i + 1) / widget.steps.length, color: c.accent, backgroundColor: c.sunk),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ნაბიჯი ${i + 1} / ${widget.steps.length}', key: const ValueKey('ck-n'), style: TextStyle(color: c.accent, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(s, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.35)),
                if (mins > 0) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    key: const ValueKey('ck-timer'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: () => _timer(mins),
                    icon: const PIcon('timer', size: 20),
                    label: Text(tm != null ? 'ტაიმერი: ${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}' : 'ტაიმერი · ${cookTime(mins)}'),
                  ),
                ],
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(children: [
              OutlinedButton(key: const ValueKey('ck-prev'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)), onPressed: i == 0 ? null : () => _go(-1), child: const Text('წინა')),
              const Spacer(),
              FilledButton(key: const ValueKey('ck-next'), style: FilledButton.styleFrom(minimumSize: const Size(0, 50)), onPressed: () => _go(1), child: Text(last ? 'დასრულება' : 'შემდეგი')),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A recipe written or changed: the photo, the name, category and region, the time and portions, a few words, the
/// ingredients with amounts and the steps. Pops with its id.
class RecipeFormScreen extends StatefulWidget {
  const RecipeFormScreen({super.key, this.edit});
  final Map<String, dynamic>? edit;
  @override
  State<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends State<RecipeFormScreen> {
  late final e = widget.edit ?? const <String, dynamic>{};
  late final title = TextEditingController(text: '${e['title'] ?? ''}');
  late final region = TextEditingController(text: '${e['region'] ?? ''}');
  late final minutes = TextEditingController(text: '${e['minutes'] ?? 60}');
  late final servings = TextEditingController(text: '${e['servings'] ?? 4}');
  late final about = TextEditingController(text: '${e['about'] ?? ''}');
  late String cat = '${e['category'] ?? 'ხორციანი'}';
  late String? photo = e['photo_url'] as String?;
  late final ings = [
    for (final x in widget.edit == null ? [(n: '', q: ''), (n: '', q: ''), (n: '', q: '')] : _ings(e['ingredients'])) (TextEditingController(text: x.n), TextEditingController(text: x.q)),
  ];
  late final steps = [for (final s in widget.edit == null ? ['', ''] : _steps(e['steps'])) TextEditingController(text: s)];
  bool busy = false;

  @override
  void dispose() {
    for (final x in [title, region, minutes, servings, about, ...steps]) {
      x.dispose();
    }
    for (final (a, b) in ings) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  Future<void> _photo() async {
    final app = context.app;
    final got = await photoSource(false);
    if (got.isEmpty || !mounted) return;
    final f = await photoFrame(context, got.first, aspect: 4 / 3, max: ecoMode.value ? 1080 : 1400, title: 'კერძის ფოტო');
    if (f == null || !mounted) return;
    toast(context, 'იტვირთება…');
    try {
      final m = await app.api.uploadPhoto(await photoPrep(f.bytes));
      if (mounted) setState(() => photo = m.url);
    } catch (x) {
      if (mounted) toast(context, errText(x));
    }
  }

  Future<void> _save() async {
    final t = title.text.trim();
    final ing = [for (final (a, b) in ings) if (a.text.trim().isNotEmpty) {'n': a.text.trim(), 'q': b.text.trim()}];
    final st = [for (final s in steps) if (s.text.trim().isNotEmpty) s.text.trim()];
    if (t.length < 2) {
      toast(context, 'ჩაწერე კერძის სახელი');
      return;
    }
    if (ing.isEmpty) {
      toast(context, 'დაამატე ერთი ინგრედიენტი მაინც');
      return;
    }
    if (st.isEmpty) {
      toast(context, 'დაწერე ერთი ნაბიჯი მაინც');
      return;
    }
    final row = <String, dynamic>{
      'title': t,
      'category': cat,
      'region': region.text.trim(),
      'minutes': (int.tryParse(minutes.text.trim()) ?? 60).clamp(1, 2880),
      'servings': (int.tryParse(servings.text.trim()) ?? 4).clamp(1, 40),
      'about': about.text.trim(),
      'photo_url': photo,
      'ingredients': ing,
      'steps': st,
    };
    setState(() => busy = true);
    try {
      final id = await context.app.api.saveRecipe(row, id: widget.edit == null ? null : asInt(e['id']));
      if (!mounted) return;
      toast(context, widget.edit != null ? 'შენახულია' : 'რეცეპტი გამოქვეყნდა');
      Navigator.of(context).pop(id);
    } catch (x) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(x));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      appBar: peeraBar(context, title: widget.edit != null ? 'რეცეპტის რედაქტირება' : 'ახალი რეცეპტი', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(
            key: const ValueKey('rcf-ok'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: busy ? null : _save,
            child: Text(widget.edit != null ? 'შენახვა' : 'გამოქვეყნება'),
          ),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 96, height: 72, child: photo != null ? PImage(photo!) : Container(color: c.sunk, child: Center(child: PIcon('camera', color: c.muted)))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('კერძის ფოტო', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('ლამაზი ფოტო რეცეპტს უფრო მისაწვდომს ხდის', style: TextStyle(color: c.muted, fontSize: 12.5)),
              TextButton(key: const ValueKey('rcf-photo'), onPressed: _photo, child: Text(photo != null ? 'შეცვლა' : 'არჩევა')),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('rcf-title'), controller: title, maxLength: 80, decoration: const InputDecoration(labelText: 'სახელი', hintText: 'მაგ. მეგრული ხაჭაპური', counterText: '')),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (k, em, _) in recipeCats)
            ChoiceChip(
              key: ValueKey('rcf-c-$k'),
              label: Text('$em $k'),
              selected: cat == k,
              showCheckmark: false,
              selectedColor: c.accentSoft,
              side: BorderSide(color: cat == k ? c.accent : c.line),
              onSelected: (_) => setState(() => cat = k),
            ),
        ]),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('rcf-region'), controller: region, maxLength: 40, decoration: const InputDecoration(labelText: 'კუთხე', hintText: 'მაგ. სამეგრელო', counterText: '')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(key: const ValueKey('rcf-min'), controller: minutes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'დრო (წუთი)'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(key: const ValueKey('rcf-serv'), controller: servings, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'პორცია'))),
        ]),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('rcf-about'), controller: about, maxLength: 500, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'მოკლედ კერძზე', counterText: '')),
        const Padding(padding: EdgeInsets.fromLTRB(0, 14, 0, 6), child: Text('ინგრედიენტები', style: TextStyle(fontWeight: FontWeight.w800))),
        for (var i = 0; i < ings.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(flex: 3, child: TextField(key: ValueKey('rcf-in-$i'), controller: ings[i].$1, maxLength: 60, decoration: const InputDecoration(hintText: 'ინგრედიენტი', counterText: '', isDense: true))),
              const SizedBox(width: 6),
              Expanded(flex: 2, child: TextField(key: ValueKey('rcf-iq-$i'), controller: ings[i].$2, maxLength: 30, decoration: const InputDecoration(hintText: 'რაოდენობა', counterText: '', isDense: true))),
              IconBtn('x', key: ValueKey('rcf-ix-$i'), label: 'წაშლა', size: 18, color: c.muted, onTap: () {
                final (a, b) = ings.removeAt(i);
                setState(() {});
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  a.dispose();
                  b.dispose();
                });
              }),
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('rcf-iadd'),
            onPressed: () => setState(() => ings.add((TextEditingController(), TextEditingController()))),
            icon: const PIcon('plus', size: 16),
            label: const Text('ინგრედიენტი'),
          ),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(0, 14, 0, 6), child: Text('მომზადება', style: TextStyle(fontWeight: FontWeight.w800))),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 12, right: 8), child: Text('${i + 1}', style: TextStyle(color: c.accent, fontWeight: FontWeight.w900))),
              Expanded(
                child: TextField(key: ValueKey('rcf-st-$i'), controller: steps[i], maxLength: 600, minLines: 2, maxLines: 5, decoration: const InputDecoration(hintText: 'რა უნდა გაკეთდეს', counterText: '', isDense: true)),
              ),
              IconBtn('x', key: ValueKey('rcf-sx-$i'), label: 'წაშლა', size: 18, color: c.muted, onTap: () {
                final a = steps.removeAt(i);
                setState(() {});
                WidgetsBinding.instance.addPostFrameCallback((_) => a.dispose());
              }),
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('rcf-sadd'),
            onPressed: () => setState(() => steps.add(TextEditingController())),
            icon: const PIcon('plus', size: 16),
            label: const Text('ნაბიჯი'),
          ),
        ),
      ]),
    );
  }
}
