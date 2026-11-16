// The menu of all the services, in groups. Each group is a card that says what is in it — its colour and picture,
// a line on what it is for, and its pages by name — and it opens like an accordion to the pages themselves, each with
// a line on what it does. A search at the top finds a page in any group. Back closes the open group, then the menu.
import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../ui/icons.dart';
import '../ui/mini_svg.dart';
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
  String? opened;
  String q = '';
  final find = TextEditingController();
  final keys = <String, GlobalKey>{};

  @override
  void dispose() {
    find.dispose();
    super.dispose();
  }

  void _toggle(SvcGroup g) {
    setState(() => opened = opened == g.id ? null : g.id);
    if (opened == null) return;
    // the group's card goes up so its pages are in view
    Future.delayed(const Duration(milliseconds: 120), () {
      final ctx = keys[g.id]?.currentContext;
      if (mounted && opened == g.id && ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx, alignment: .02, duration: const Duration(milliseconds: 360), curve: Curves.easeOutCubic);
      }
    });
  }

  void _go(SvcItem i) {
    Navigator.of(context).pop();
    widget.open(i);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, words = q.trim().toLowerCase();
    final found = words.isEmpty
        ? const <(SvcGroup, SvcItem)>[]
        : [
            for (final g in widget.groups)
              for (final i in g.items)
                if (i.title.toLowerCase().contains(words) || i.about.toLowerCase().contains(words) || g.title.toLowerCase().contains(words)) (g, i),
          ];
    final count = widget.groups.fold<int>(0, (n, g) => n + g.items.length);
    return PopScope(
      canPop: opened == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && opened != null) setState(() => opened = null);
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Flexible(child: Text('სერვისები', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -.2))),
            const SizedBox(width: 8),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('${widget.groups.length} ჯგუფი · $count გვერდი', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5)),
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
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                  children: [
                    for (final (n, g) in widget.groups.indexed)
                      _Rise(
                        order: n,
                        child: _GroupBlock(
                          key: keys.putIfAbsent(g.id, GlobalKey.new),
                          group: g,
                          open: opened == g.id,
                          onToggle: () => _toggle(g),
                          onItem: _go,
                        ),
                      ),
                  ],
                ),
        ),
      ]),
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

/// pressed: the card gives a little under the finger
class _Press extends StatefulWidget {
  const _Press({required this.onTap, required this.child, this.radius = 22, super.key});
  final VoidCallback onTap;
  final Widget child;
  final double radius;
  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => down = true),
        onTapUp: (_) => setState(() => down = false),
        onTapCancel: () => setState(() => down = false),
        onTap: widget.onTap,
        child: AnimatedScale(scale: down ? .975 : 1, duration: const Duration(milliseconds: 120), curve: Curves.easeOut, child: widget.child),
      );
}

/// a group: its card, and under it, when open, its pages
class _GroupBlock extends StatefulWidget {
  const _GroupBlock({super.key, required this.group, required this.open, required this.onToggle, required this.onItem});
  final SvcGroup group;
  final bool open;
  final VoidCallback onToggle;
  final void Function(SvcItem) onItem;
  @override
  State<_GroupBlock> createState() => _GroupBlockState();
}

class _GroupBlockState extends State<_GroupBlock> with SingleTickerProviderStateMixin {
  late final _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420), reverseDuration: const Duration(milliseconds: 280), value: widget.open ? 1 : 0);
  late final _ease = CurvedAnimation(parent: _ctl, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);

  @override
  void didUpdateWidget(_GroupBlock old) {
    super.didUpdateWidget(old);
    if (widget.open == old.open) return;
    widget.open
        ? _ctl.forward()
        : _ctl.reverse().then((_) {
            if (mounted) setState(() {});
          });
  }

  @override
  void dispose() {
    _ease.dispose();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group, shown = widget.open || _ctl.value > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Press(key: ValueKey('mg-${g.id}'), onTap: widget.onToggle, child: _GroupCard(group: g, open: widget.open)),
        if (shown)
          SizeTransition(
            sizeFactor: _ease,
            axisAlignment: -1,
            child: FadeTransition(
              opacity: _ease,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final (n, i) in g.items.indexed) _Rise(order: n, child: _ItemRow(item: i, group: g, onTap: () => widget.onItem(i))),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// The group's card: its colour, its picture, its name and what it is for, and its pages by name.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.open});
  final SvcGroup group;
  final bool open;
  @override
  Widget build(BuildContext context) {
    final g = group, a = Color(g.colors.$1), b = Color(g.colors.$2), art = g.art == null ? null : serviceArt[g.art];
    const white = Colors.white;
    final names = [for (final i in g.items) i.title];
    final shownNames = names.length > 4 ? names.take(4).toList() : names;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: a.withValues(alpha: open ? .42 : .24), blurRadius: open ? 26 : 16, offset: Offset(0, open ? 12 : 7))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(children: [
          Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: const Alignment(-1, -1), end: const Alignment(1, 1), colors: [a, b]))),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(-.9, -1.1), radius: 1.3, colors: [Color(0x47FFFFFF), Color(0x00FFFFFF)], stops: [0, .6])),
            ),
          ),
          // the picture of one of its pages, up in the corner
          Positioned(
            right: -6,
            top: -4,
            width: 150,
            height: 96,
            child: IgnorePointer(
              child: art != null
                  ? Opacity(opacity: .92, child: MiniSvg(art.$3))
                  : Align(
                      alignment: const Alignment(.55, .1),
                      child: Transform.rotate(angle: -.18, child: PIcon(g.icon, size: 78, color: white.withValues(alpha: .2))),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: white.withValues(alpha: .22), borderRadius: BorderRadius.circular(11), border: Border.all(color: white.withValues(alpha: .3))),
                  child: PIcon(g.icon, size: 19, color: white),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(99)),
                  child: Text('${g.items.length} გვერდი', style: const TextStyle(color: white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 110),
                child: Text(g.title, style: const TextStyle(color: white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.15, shadows: [Shadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 1))])),
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.only(right: 70),
                child: Text(g.about, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: white.withValues(alpha: .92), fontSize: 13, height: 1.3)),
              ),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Wrap(spacing: 5, runSpacing: 5, children: [
                    for (final n in shownNames) _Pill(n),
                    if (names.length > shownNames.length) _Pill('+${names.length - shownNames.length}', strong: true),
                  ]),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: open ? .75 : .25,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: white.withValues(alpha: open ? .95 : .25), shape: BoxShape.circle),
                    child: PIcon('chev', size: 17, color: open ? a : white),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
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
      child: _Press(
        radius: 16,
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
