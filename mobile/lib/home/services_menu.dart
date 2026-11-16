// The menu of all the services, in groups. Each group is a card that says what is in it — its colour and picture,
// a line on what it is for, and its pages by name — in a row like a cover flow: the one in the middle straight, two
// on each side turned toward it; under it the middle group's pages, each with a line on what it does, changing as the
// row turns. A search at the top finds a page in any group. Back closes the menu.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../ui/icons.dart';
import '../ui/mini_svg.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import 'service_art.dart';
import 'services.dart';

/// a page in the menu: what opens, its icon, its name and what it is for ([kind]: which kind of room)
class SvcItem {
  const SvcItem(this.page, this.icon, this.title, this.about, {this.kind});
  final String page, icon, title, about;
  final String? kind;
  String get key => 'menu-$page${kind != null ? '-$kind' : ''}';
}

/// a group of pages: its card's colours, the picture it borrows from one of its pages, what it is about
class SvcGroup {
  const SvcGroup(this.id, this.icon, this.title, this.about, this.colors, this.items, {this.art});
  final String id, icon, title, about;
  final (int, int) colors;
  final List<SvcItem> items;
  final String? art;
}

const serviceGroups = <SvcGroup>[
  SvcGroup('study', 'school', 'სწავლა', 'სკოლა და უნივერსიტეტი ერთ ადგილას', (0xFF5B5BF0, 0xFF9B5CF6), art: 'schedule', [
    SvcItem('study', 'school', 'სწავლის გვერდი', 'დღევანდელი ლექციები, ვადები და შენი ჯგუფი ერთად'),
    SvcItem('schedule', 'cal', 'ლექციების ცხრილი', 'კვირის ლექციები, აუდიტორია და დრო'),
    SvcItem('exams', 'clock', 'გამოცდები და დავალებები', 'ვადები და შეხსენებები, რომ არაფერი გამოგრჩეს'),
    SvcItem('notes', 'book', 'კონსპექტები', 'ჩანაწერები და ფოტოები საგნების მიხედვით'),
    SvcItem('classmates', 'users', 'კლასელები და კურსელები', 'შენი სკოლის და უნივერსიტეტის ხალხი'),
    SvcItem('tips', 'help', 'სასწავლო რჩევები', 'გამოცდილება, კითხვები და პასუხები'),
    SvcItem('rooms', 'video', 'სასწავლო ოთახი', 'ვიდეო-შეხვედრა კურსელებთან'),
    SvcItem('rooms', 'mic', 'დისკუსია', 'ხმოვანი საუბარი ერთ თემაზე', kind: 'birja'),
  ]),
  SvcGroup('people', 'users', 'ხალხი და თემები', 'მეგობრები, საზოგადოებები და შეხვედრები', (0xFF0EA5E9, 0xFF6366F1), art: 'groups', [
    SvcItem('friends', 'user', 'მეგობრები', 'მოთხოვნები, ნაცნობები და შემოთავაზებები'),
    SvcItem('groups', 'users', 'ჯგუფები', 'კლასი, კურსი და ინტერესები'),
    SvcItem('pages', 'mega', 'არხები და გვერდები', 'სიახლეები, ბიზნესი და ბრენდები'),
    SvcItem('events', 'cal', 'შეხვედრები', 'ლექციები, ექსკურსიები, წვეულებები'),
    SvcItem('map', 'globe', 'ლაივ რუკა', 'სად არიან მეგობრები ახლა'),
    SvcItem('albums', 'image', 'ალბომები', 'საერთო ფოტოები ერთად'),
  ]),
  SvcGroup('daily', 'store', 'ყოველდღიური', 'ყიდვა-გაყიდვა, სამსახური, ადგილები და გზა', (0xFFEAB308, 0xFFF97316), art: 'market', [
    SvcItem('market', 'store', 'ბაზრობა', 'იყიდე, გაყიდე, გააჩუქე'),
    SvcItem('jobs', 'work', 'ვაკანსიები და CV', 'სამსახური, სტაჟირება და შენი რეზიუმე'),
    SvcItem('places', 'map', 'ადგილები', 'კაფეები, ბიბლიოთეკები, სივრცეები'),
    SvcItem('rides', 'pin', 'ერთად წავიდეთ', 'მგზავრობა ერთ მანქანაში'),
    SvcItem('help', 'help', 'დახმარება', 'დონორები, ცხოველები, მოხალისეები'),
  ]),
  SvcGroup('fun', 'live', 'გართობა და ლაივი', 'პირდაპირი ეთერი, მატჩები და შეჯიბრებები', (0xFF15A34A, 0xFF065F46), art: 'sport', [
    SvcItem('rooms', 'live', 'ლაივი', 'პირდაპირი ეთერი და მაყურებლები', kind: 'live'),
    SvcItem('sport', 'trophy', 'მატჩის ოთახი', 'მატჩები და პროგნოზები მეგობრებთან'),
    SvcItem('tour', 'trophy', 'ტურნირი', 'შეჯიბრებები და ცხრილები'),
  ]),
  SvcGroup('roots', 'tree', 'ტრადიცია და ოჯახი', 'სუფრა, დღესასწაულები და შენი გვარი', (0xFFEF4444, 0xFFF472B6), art: 'calendar', [
    SvcItem('recipes', 'book', 'ქართული სამზარეულო', 'კერძების რეცეპტები ნაბიჯ-ნაბიჯ'),
    SvcItem('toasts', 'wine', 'სადღეგრძელოები', 'თამადის სიტყვა ყველა შემთხვევისთვის'),
    SvcItem('calendar', 'gift', 'კალენდარი', 'დაბადების და სახელის დღეები'),
    SvcItem('namedays', 'cal', 'სახელის დღეები', 'ვისი სახელობის დღეა დღეს და მალე'),
    SvcItem('tree', 'tree', 'ოჯახის ხე', 'შენი გვარი და ნათესავები'),
  ]),
  SvcGroup('mine', 'gear', 'ჩემი სივრცე', 'რაც შეინახე, დაიწყე და შენი პარამეტრები', (0xFF334155, 0xFF64748B), [
    SvcItem('saved', 'bookmark', 'შენახული', 'შენახული პოსტები საქაღალდეებში'),
    SvcItem('storyarch', 'archive', 'ისტორიების არქივი', 'შენი ძველი ისტორიები'),
    SvcItem('drafts', 'clock', 'დრაფტები', 'დაწყებული და დაუსრულებელი პოსტები'),
    SvcItem('coins', 'coin', 'მონეტები', 'ბალანსი და მისი ისტორია'),
    SvcItem('verify', 'shield', 'ვერიფიკაცია', 'დადასტურებული პროფილის ნიშანი'),
    SvcItem('settings', 'gear', 'პარამეტრები', 'პროფილი, კონფიდენციალურობა, შეტყობინებები'),
  ]),
];

const _admin = SvcItem('admin', 'shield', 'ადმინ პანელი', 'საიტის მართვა: საჩივრები, მომხმარებლები, კონტენტი');

/// the groups as this person sees them: the switched-off pages left out, the admin's panel for the staff
List<SvcGroup> menuGroups(BuildContext context) {
  final staff = context.me.role == 'admin' || context.me.role == 'moderator';
  return [
    for (final g in serviceGroups)
      if ([for (final i in g.items) if (pageOk(context, i.page)) i] case final items when items.isNotEmpty || (g.id == 'mine' && staff))
        SvcGroup(g.id, g.icon, g.title, g.about, g.colors, [...items, if (g.id == 'mine' && staff) _admin], art: g.art),
  ];
}

/// All the services, grouped.
Future<void> servicesMenu(BuildContext context) {
  final groups = menuGroups(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => SizedBox(
      height: MediaQuery.sizeOf(s).height * .88,
      child: _Menu(groups: groups, open: (i) => openService(context, i.page, arg: i.kind)),
    ),
  );
}

class _Menu extends StatefulWidget {
  const _Menu({required this.groups, required this.open});
  final List<SvcGroup> groups;
  final void Function(SvcItem) open;
  @override
  State<_Menu> createState() => _MenuState();
}

class _MenuState extends State<_Menu> {
  /// the group in the middle of the carousel
  int at = 0;
  String q = '';
  final find = TextEditingController();

  @override
  void dispose() {
    find.dispose();
    super.dispose();
  }

  void _go(SvcItem i) {
    Navigator.of(context).pop();
    widget.open(i);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, words = q.trim().toLowerCase(), groups = widget.groups;
    final found = words.isEmpty
        ? const <(SvcGroup, SvcItem)>[]
        : [
            for (final g in groups)
              for (final i in g.items)
                if (i.title.toLowerCase().contains(words) || i.about.toLowerCase().contains(words) || g.title.toLowerCase().contains(words)) (g, i),
          ];
    final count = groups.fold<int>(0, (n, g) => n + g.items.length);
    final g = groups.isEmpty ? null : groups[at % groups.length];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Flexible(child: Text('სერვისები', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -.2))),
          const SizedBox(width: 8),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('${groups.length} ჯგუფი · $count გვერდი', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5)),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: TextField(
          key: const ValueKey('menu-find'),
          controller: find,
          onChanged: (v) => setState(() => q = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'მოძებნე სერვისი',
            isDense: true,
            prefixIcon: Padding(padding: const EdgeInsets.all(11), child: PIcon('search', size: 19, color: c.muted)),
            prefixIconConstraints: const BoxConstraints(minWidth: 42),
            suffixIcon: q.isEmpty
                ? null
                : IconButton(
                    tooltip: 'გასუფთავება',
                    onPressed: () {
                      find.clear();
                      setState(() => q = '');
                    },
                    icon: PIcon('x', size: 17, color: c.muted),
                  ),
            filled: true,
            fillColor: c.sunk,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.accent, width: 1.5)),
          ),
        ),
      ),
      Expanded(
        child: words.isNotEmpty
            ? (found.isEmpty
                ? Center(child: Text('ასეთი სერვისი ვერ ვიპოვე', style: TextStyle(color: c.muted, fontSize: 14.5)))
                : ListView(
                    key: const ValueKey('menu-found'),
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    children: [
                      for (final (n, (g, i)) in found.indexed) _Rise(order: n, child: _ItemRow(item: i, group: g, showGroup: true, onTap: () => _go(i))),
                    ],
                  ))
            : ListView(
                key: const ValueKey('menu-list'),
                padding: const EdgeInsets.only(bottom: 28),
                children: [
                  if (groups.isNotEmpty)
                    _Flow(
                      key: const ValueKey('menu-flow'),
                      groups: groups,
                      onAt: (i) {
                        if (i != at) setState(() => at = i);
                      },
                    ),
                  // the dots: which of the groups is in the middle
                  if (groups.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (var i = 0; i < groups.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == at % groups.length ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == at % groups.length ? Color(groups[i].colors.$1) : c.line,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                      ]),
                    ),
                  // what is in the middle card, changing with it
                  if (g != null)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (ch, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(a), child: ch),
                      ),
                      layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, if (cur != null) cur]),
                      child: Padding(
                        key: ValueKey('mgc-${g.id}'),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                            child: Row(children: [
                              Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [Color(g.colors.$1), Color(g.colors.$2)]),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: PIcon(g.icon, size: 16, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(g.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                              Text('${g.items.length} გვერდი', style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          for (final (n, i) in g.items.indexed) _Rise(order: n, child: _ItemRow(item: i, group: g, onTap: () => _go(i))),
                        ]),
                      ),
                    ),
                ],
              ),
      ),
    ]);
  }
}

/// The groups in one row like a cover flow: the one in the middle straight, two on each side turned toward it. A
/// swipe turns the row (it goes round), a tap on a side card brings it to the middle.
class _Flow extends StatefulWidget {
  const _Flow({super.key, required this.groups, required this.onAt});
  final List<SvcGroup> groups;
  final void Function(int) onAt;
  @override
  State<_Flow> createState() => _FlowState();
}

class _FlowState extends State<_Flow> with SingleTickerProviderStateMixin {
  double p = 0;
  late final AnimationController anim = AnimationController(vsync: this);
  Animation<double>? _to;
  double _step = 120;

  int get n => widget.groups.length;

  @override
  void initState() {
    super.initState();
    anim.addListener(() {
      final t = _to;
      if (t != null) _set(t.value);
    });
  }

  @override
  void dispose() {
    anim.dispose();
    super.dispose();
  }

  void _set(double v) {
    setState(() => p = v);
    widget.onAt(((v.round() % n) + n) % n);
  }

  void _go(int k) {
    final from = p;
    _to = Tween<double>(begin: from, end: k.toDouble()).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
    anim.duration = Duration(milliseconds: math.min(640, 280 + ((k - from).abs() * 120).round()));
    anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cw = box.maxWidth;
      final w = (cw * .47).clamp(160.0, 230.0).toDouble(), h = w * 1.4;
      final first = w * .62, gap = ((cw / 2 - first - w * .1) / 1.5).clamp(14.0, 64.0).toDouble();
      _step = first;
      double xOf(double a) => a <= 1 ? a * first : first + (a - 1) * gap;
      final kids = <(double, Widget)>[];
      final shown = <int>{};
      // the nearest first, so each group is drawn once even when there are few of them
      final ks = [for (var k = (p - 3).floor(); k <= (p + 3).ceil(); k++) k]..sort((x, y) => (x - p).abs().compareTo((y - p).abs()));
      for (final k in ks) {
        final d = k - p, ad = d.abs();
        if (ad > 2.6) continue;
        final gi = ((k % n) + n) % n;
        if (!shown.add(gi)) continue;
        final g = widget.groups[gi], sg = d.sign, t = math.min(ad, 1.0), on = ad < .5;
        kids.add((
          ad,
          Positioned(
            left: cw / 2 - w / 2,
            top: 14,
            child: Transform(
              alignment: Alignment.center,
              transform: (Matrix4.identity()..setEntry(3, 2, .0012))
                ..multiply(Matrix4.translationValues(sg * xOf(ad), 0, t * 110 + math.max(0.0, ad - 1) * 60))
                ..multiply(Matrix4.rotationY(sg * t * 58 * math.pi / 180))
                ..multiply(Matrix4.diagonal3Values(1 - t * .06, 1 - t * .06, 1)),
              child: Opacity(
                opacity: ad <= 2 ? 1.0 : math.max(0.0, (2.6 - ad) / .6),
                child: Semantics(
                  button: true,
                  label: on ? g.title : '${g.title} (გადახვევა)',
                  child: GestureDetector(
                    key: ValueKey('mg-${g.id}'),
                    onTap: on ? null : () => _go(k),
                    child: SizedBox(width: w, height: h, child: _FlowCard(group: g, front: on, shade: t)),
                  ),
                ),
              ),
            ),
          ),
        ));
      }
      kids.sort((a, b) => b.$1.compareTo(a.$1));
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => anim.stop(),
        onHorizontalDragUpdate: (e) => _set(p - e.delta.dx / _step),
        onHorizontalDragEnd: (e) {
          final v = e.primaryVelocity ?? 0;
          // a slow drag settles on the nearest card, a flick goes on to the next one in its direction
          _go(v.abs() < 300 ? p.round() : (v < 0 ? p.floor() + 1 : p.ceil() - 1));
        },
        child: SizedBox(height: h + 40, child: Stack(clipBehavior: Clip.none, children: [for (final k in kids) k.$2])),
      );
    });
  }
}

/// A group's card standing in the carousel: its colours and picture, how many pages, its name and what it is for, its
/// pages by name. The ones at the sides are shaded, as if turned away from the light.
class _FlowCard extends StatelessWidget {
  const _FlowCard({required this.group, required this.front, required this.shade});
  final SvcGroup group;
  final bool front;
  final double shade;
  @override
  Widget build(BuildContext context) {
    final g = group, a = Color(g.colors.$1), b = Color(g.colors.$2), art = g.art == null ? null : serviceArt[g.art];
    const white = Colors.white;
    final names = [for (final i in g.items) i.title];
    final shownNames = names.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: a.withValues(alpha: front ? .45 : .2), blurRadius: front ? 28 : 14, offset: Offset(0, front ? 14 : 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: const Alignment(-1, -1), end: const Alignment(1, 1), colors: [a, b]))),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(-.9, -1.1), radius: 1.3, colors: [Color(0x47FFFFFF), Color(0x00FFFFFF)], stops: [0, .6])),
          ),
          // the picture of one of its pages, at the top
          Positioned(
            left: 0,
            right: 0,
            top: 8,
            height: 110,
            child: IgnorePointer(
              child: art != null
                  ? Padding(padding: const EdgeInsets.symmetric(horizontal: 22), child: MiniSvg(art.$3))
                  : Center(child: Transform.rotate(angle: -.18, child: PIcon(g.icon, size: 74, color: white.withValues(alpha: .28)))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: white.withValues(alpha: .22), borderRadius: BorderRadius.circular(10), border: Border.all(color: white.withValues(alpha: .3))),
                  child: PIcon(g.icon, size: 16, color: white),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(99)),
                  child: Text('${g.items.length} გვერდი', style: const TextStyle(color: white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ]),
              const Spacer(),
              Text(g.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.15, shadows: [Shadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 1))])),
              const SizedBox(height: 3),
              Text(g.about, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: white.withValues(alpha: .92), fontSize: 12, height: 1.3)),
              const SizedBox(height: 8),
              // the pages by name, as many as fit (the rest cut off, never spilling out of the card)
              Flexible(
                flex: 4,
                child: ClipRect(
                  child: Wrap(spacing: 4, runSpacing: 4, children: [
                    for (final t in shownNames) _Pill(t),
                    if (names.length > shownNames.length) _Pill('+${names.length - shownNames.length}', strong: true),
                  ]),
                ),
              ),
            ]),
          ),
          // the side cards a little darker, as if turned from the light
          IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: .22 * shade))),
        ]),
      ),
    );
  }
}

/// coming in: up a little and into view, a moment after the one before it
class _Rise extends StatelessWidget {
  const _Rise({required this.order, required this.child});
  final int order;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final wait = (order * 55).clamp(0, 400), ms = 420 + wait;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Interval(wait / ms, 1, curve: Curves.easeOutCubic),
      builder: (_, v, ch) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 22), child: Transform.scale(scale: .96 + .04 * v, child: ch))),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.strong = false});
  final String text;
  final bool strong;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: strong ? .32 : .18),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: .22)),
        ),
        child: Text(text, maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2)),
      );
}

/// A page in an open group: its icon in its own colours, its name and what it is for; a page still on the site
/// carries a small arrow.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.group, required this.onTap, this.showGroup = false});
  final SvcItem item;
  final SvcGroup group;
  final VoidCallback onTap;
  final bool showGroup;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, art = serviceArt[item.page];
    final a = Color(art?.$1 ?? group.colors.$1), b = Color(art?.$2 ?? group.colors.$2);
    final site = !nativeServices.contains(item.page);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Pressable(
        onTap: onTap,
        child: Container(
          key: ValueKey(item.key),
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line.withValues(alpha: .7))),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: a.withValues(alpha: .3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: PIcon(item.icon, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (showGroup) Text(group.title, style: TextStyle(color: Color(group.colors.$1), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .2)),
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.25)),
                const SizedBox(height: 1),
                Text(item.about, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.3)),
              ]),
            ),
            const SizedBox(width: 6),
            site
                ? Semantics(label: 'საიტზე იხსნება', child: PIcon('link', size: 15, color: c.muted))
                : PIcon('chev', size: 16, color: c.muted),
          ]),
        ),
      ),
    );
  }
}
