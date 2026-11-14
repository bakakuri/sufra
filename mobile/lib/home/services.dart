// The services (app.js SVC, home.js SHORT): the strip on the home page that turns like a cover flow, each card with
// the site's picture and how much is going on there; the menu of them all; and what can be made ("შექმნა").
// What the app has itself opens here; the rest still opens on the site.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../clips/clip_composer.dart';
import '../community/events.dart';
import '../community/groups.dart';
import '../community/help.dart';
import '../community/jobs.dart';
import '../community/kitchen.dart';
import '../community/market.dart';
import '../community/pages.dart';
import '../community/rides.dart';
import '../community/sport.dart';
import '../community/toasts.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/post_card.dart';
import '../map/live_map.dart';
import '../people/albums.dart';
import '../people/coins.dart';
import '../people/cv_edit.dart';
import '../people/edu.dart';
import '../people/family.dart';
import '../people/my_space.dart';
import '../people/profile_parts.dart';
import '../people/verify.dart';
import '../places/places.dart';
import '../settings/settings_screens.dart';
import '../stories/stories.dart';
import '../study/study.dart';
import '../ui/icons.dart';
import '../ui/mini_svg.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'calendar.dart';
import 'service_art.dart';

/// page, icon, title, under the title, and how its number reads (null: no number)
typedef Service = (String, String, String, String, String Function(int)?);

/// the strip's cards, in the site's order (the coin shop stays out: no paying in the app)
final List<Service> stripServices = [
  ('schedule', 'cal', 'ლექციების ცხრილი', 'კვირის ცხრილი', null),
  ('exams', 'clock', 'გამოცდები', 'და დავალებები', null),
  ('notes', 'book', 'კონსპექტები', 'ჩანაწერები, ფოტოები', null),
  ('classmates', 'school', 'კლასელები', 'და კურსელები', null),
  ('rooms', 'video', 'სასწავლო ოთახები', 'ვიდეო-შეხვედრა კურსელებთან', (n) => '$n ცოცხლად'),
  ('places', 'map', 'ადგილები', 'კაფეები, ბიბლიოთეკები, სივრცეები', (n) => '$n ადგილი'),
  ('sport', 'trophy', 'მატჩები', 'პროგნოზები მეგობრებთან', (n) => '$n მატჩი წინ'),
  ('help', 'help', 'დახმარება', 'დონორები, ცხოველები, მოხალისეები', (n) => '$n აქტიური თხოვნა'),
  ('events', 'cal', 'შეხვედრები', 'ლექციები, ექსკურსიები, წვეულებები', (n) => '$n ამ კვირაში'),
  ('albums', 'image', 'ალბომები', 'საერთო ფოტოები ერთად', (n) => '$n ალბომი'),
  ('groups', 'users', 'ჯგუფები', 'კლასი, კურსი და ინტერესები', (n) => '$n ჯგუფი'),
  ('rides', 'pin', 'ერთად წავიდეთ', 'მგზავრობა ერთ მანქანაში', (n) => '$n მგზავრობა'),
  ('jobs', 'work', 'ვაკანსიები', 'სამსახური და CV', (n) => '$n ვაკანსია'),
  ('market', 'store', 'ბაზრობა', 'იყიდე, გაყიდე, გააჩუქე', (n) => '$n განცხადება'),
  ('pages', 'mega', 'არხები', 'სიახლეები და ბიზნესი', (n) => '$n გვერდი'),
  ('friends', 'user', 'მეგობრები', 'კლასელები, კურსელები, ნაცნობები', (n) => '$n ახალი მოთხოვნა'),
  ('calendar', 'gift', 'კალენდარი', 'დაბადების და სახელის დღეები', null),
];

/// page, icon, title, and the room kind for rooms (the menu of all services, app.js SVC)
const List<(String, String, String, String?)> allServices = [
  ('study', 'school', 'სწავლა', null),
  ('schedule', 'cal', 'ლექციების ცხრილი', null),
  ('exams', 'clock', 'გამოცდები და დავალებები', null),
  ('notes', 'book', 'კონსპექტები', null),
  ('classmates', 'school', 'კლასელები და კურსელები', null),
  ('tips', 'help', 'სასწავლო რჩევები', null),
  ('rooms', 'video', 'სასწავლო ოთახი', null),
  ('rooms', 'mic', 'დისკუსია', 'birja'),
  ('rooms', 'live', 'ლაივი', 'live'),
  ('groups', 'users', 'ჯგუფები', null),
  ('friends', 'users', 'მეგობრები', null),
  ('map', 'globe', 'ლაივ რუკა', null),
  ('events', 'cal', 'შეხვედრები', null),
  ('jobs', 'school', 'ვაკანსიები და CV', null),
  ('pages', 'mega', 'არხები და გვერდები', null),
  ('albums', 'image', 'ალბომები', null),
  ('market', 'store', 'ბაზრობა', null),
  ('places', 'map', 'ადგილები', null),
  ('sport', 'trophy', 'მატჩის ოთახი', null),
  ('help', 'help', 'დახმარება', null),
  ('rides', 'pin', 'ერთად წავიდეთ', null),
  ('recipes', 'book', 'ქართული სამზარეულო', null),
  ('toasts', 'wine', 'სადღეგრძელოები', null),
  ('namedays', 'cal', 'სახელის დღეები', null),
  ('tree', 'tree', 'ოჯახის ხე', null),
  ('calendar', 'gift', 'კალენდარი', null),
  ('tour', 'trophy', 'ტურნირი', null),
  ('saved', 'bookmark', 'შენახული', null),
  ('storyarch', 'archive', 'ისტორიების არქივი', null),
  ('drafts', 'clock', 'დრაფტები', null),
  ('coins', 'coin', 'მონეტები', null),
  ('verify', 'shield', 'ვერიფიკაცია', null),
  ('settings', 'gear', 'პარამეტრები', null),
];

/// the services the app opens itself; the others open on the site
const nativeServices = {
  'classmates', 'albums', 'friends', 'calendar', 'map', 'namedays', 'tree', 'saved', 'storyarch', 'drafts', 'coins', 'verify', 'settings', //
  'groups', 'group', 'pages', 'pagev', 'events', 'event', 'evnew', 'market', //
  'study', 'schedule', 'exams', 'notes', 'tips', //
  'places', 'place', 'placenew', 'help', 'helpnew', 'helpreq', 'rides', 'ride', 'ridenew', 'sport', 'fixture', //
  'jobs', 'job', 'jobnew', 'myjobs', 'cv', 'recipes', 'recipe', 'toasts',
};

/// the sections the admin can switch off (promo.js FEATS) that each page belongs to
const _featOf = {
  'rooms': 'rooms', 'places': 'places', 'sport': 'sport', 'help': 'help', 'rides': 'rides', 'jobs': 'jobs', 'market': 'market', //
  'events': 'events', 'albums': 'albums', 'groups': 'groups', 'pages': 'pages', 'tree': 'tree', 'namedays': 'namedays', 'map': 'map',
  'calendar': 'calendar', 'study': 'study', 'schedule': 'study', 'exams': 'study', 'notes': 'study', 'classmates': 'study', 'tips': 'study',
  'tour': 'tour', 'place': 'places', 'placenew': 'places', 'helpnew': 'help', 'helpreq': 'help', 'ride': 'rides', 'ridenew': 'rides', //
  'fixture': 'sport', 'job': 'jobs', 'jobnew': 'jobs', 'myjobs': 'jobs', 'cv': 'jobs', 'recipes': 'recipes', 'recipe': 'recipes', 'toasts': 'toasts',
};

/// whether a page is on (the admin sees everything, so a switched-off one can be checked)
bool pageOk(BuildContext context, String page) {
  if (context.me.role == 'admin') return true;
  final f = _featOf[page];
  return f == null || !context.app.home.off.contains(f);
}

/// a service opened: here when the app has it, otherwise on the site
Future<void> openService(BuildContext context, String k, {String? arg}) async {
  final app = context.app, me = context.me;
  switch (k) {
    case 'classmates':
      await openPage(context, me.edu.isEmpty ? const EduScreen() : const ClassmatesScreen(), full: true);
    case 'albums':
      await openPage(context, const AlbumsScreen(), full: true);
    case 'friends':
      app.goTab?.call('friends');
    case 'calendar':
      await openPage(context, const CalendarScreen(), full: true);
    case 'map':
      await openLiveMap(context);
    case 'namedays':
      await openPage(context, const NamedaysScreen(), full: true);
    case 'tree':
      await openPage(context, TreeScreen(uid: me.id), full: true);
    case 'saved':
      await openPage(context, const SavedScreen(), full: true);
    case 'storyarch':
      await openPage(context, const StoryArchiveScreen(), full: true);
    case 'drafts':
      await openPage(context, const DraftsScreen(), full: true);
    case 'coins':
      await openPage(context, const CoinsScreen(), full: true);
    case 'verify':
      await openPage(context, const VerifyScreen(), full: true);
    case 'settings':
      await openSettings(context);
    case 'groups':
      await openPage(context, const GroupsScreen(), full: true);
    case 'group':
      await openPage(context, GroupScreen(id: int.tryParse(arg ?? '') ?? 0), full: true);
    case 'pages':
      await openPage(context, const PagesScreen(), full: true);
    case 'pagev':
      await openPage(context, PageScreen(id: int.tryParse(arg ?? '') ?? 0), full: true);
    case 'events':
      await openPage(context, const EventsScreen(), full: true);
    case 'event':
      await openPage(context, EventScreen(id: int.tryParse(arg ?? '') ?? 0), full: true);
    case 'evnew':
      await openPage(context, EventFormScreen(groupId: int.tryParse(arg ?? '')), full: true);
    case 'market':
      await openPage(context, const MarketScreen(), full: true);
    case 'study':
      await openPage(context, const StudyScreen(), full: true);
    case 'schedule':
      await openPage(context, const ScheduleScreen(), full: true);
    case 'exams':
      await openPage(context, const ExamsScreen(), full: true);
    case 'notes':
      await openPage(context, const LibraryScreen(kind: 'notes'), full: true);
    case 'tips':
      await openPage(context, const LibraryScreen(kind: 'tips'), full: true);
    case 'places':
      await openPage(context, const PlacesScreen(), full: true);
    case 'place':
      await openPage(context, PlaceScreen(id: int.tryParse(arg ?? '') ?? 0), full: true);
    case 'placenew':
      {
        final id = await openPage<int>(context, const PlaceFormScreen(), full: true);
        if (id != null && context.mounted) await openPage(context, PlaceScreen(id: id), full: true);
      }
    case 'help':
      await openPage(context, const HelpScreen(), full: true);
    case 'helpnew':
      {
        final id = await openPage<int>(context, const HelpNewScreen(), full: true);
        if (id != null && context.mounted) await openPage(context, HelpRequestScreen(id: id), full: true);
      }
    case 'helpreq':
      await openPage(context, HelpRequestScreen(id: int.tryParse(arg ?? '') ?? 0), full: true);
    case 'rides':
      await openPage(context, const RidesScreen(), full: true);
    case 'ride':
      await openPage(context, RideScreen(id: int.tryParse(arg ?? '') ?? 0), full: true);
    case 'ridenew':
      {
        final id = await openPage<int>(context, const RideFormScreen(), full: true);
        if (id != null && context.mounted) await openPage(context, RideScreen(id: id), full: true);
      }
    case 'sport':
      await openPage(context, const SportScreen(), full: true);
    case 'fixture':
      await openPage(context, FixtureScreen(id: int.tryParse(arg ?? '') ?? 0), full: true);
    case 'jobs':
      await openPage(context, const JobsScreen(), full: true);
    case 'job':
      await openPage(context, JobScreen(id: int.tryParse(arg ?? '') ?? 0), full: true);
    case 'jobnew':
      {
        final id = await openPage<int>(context, const JobFormScreen(), full: true);
        if (id != null && context.mounted) await openPage(context, JobScreen(id: id), full: true);
      }
    case 'myjobs':
      await openPage(context, const MyJobsScreen(), full: true);
    case 'cv':
      await openPage(context, const CvEditScreen(), full: true);
    case 'recipes':
      await openPage(context, const RecipesScreen(), full: true);
    case 'recipe':
      await openPage(context, RecipeScreen(id: int.tryParse(arg ?? '') ?? 0), full: true);
    case 'toasts':
      await openPage(context, const ToastsScreen(), full: true);
    default:
      await openSite('#$k${arg != null ? '-$arg' : ''}');
  }
}

/// One card: the picture on its two colours, the number on top, the name below.
class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.s, required this.width, this.count, this.on = false});
  final Service s;
  final double width;
  final String? count;
  final bool on;
  @override
  Widget build(BuildContext context) {
    final art = serviceArt[s.$1];
    final h = width * .8;
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF141830).withValues(alpha: on ? .18 : .08), blurRadius: on ? 26 : 14, offset: Offset(0, on ? 12 : 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: const Alignment(-.8, -1), end: const Alignment(.8, 1), colors: [Color(art?.$1 ?? 0xFF6366F1), Color(art?.$2 ?? 0xFF8B5CF6)]),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(-.76, -1), radius: 1.1, colors: [Color(0x57FFFFFF), Color(0x00FFFFFF)], stops: [0, .55])),
          ),
          if (art != null) MiniSvg(art.$3) else Center(child: PIcon(s.$2, size: 40, color: Colors.white)),
          if (count != null && count!.isNotEmpty)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(color: s.$1 == 'rooms' ? const Color(0xFFE11D48) : const Color(0x6B000000), borderRadius: BorderRadius.circular(999)),
                  child: Text(count!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, height: 1.75)),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 10),
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00060812), Color(0x6B060812), Color(0xB8060812)], stops: [0, .38, 1])),
              child: Text(s.$3,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, height: 1.2, shadows: [Shadow(color: Color(0x73000000), blurRadius: 6, offset: Offset(0, 1))])),
            ),
          ),
        ]),
      ),
    );
  }
}

/// The strip: a title with "ყველა", then the cards turning round like a cover flow (the middle one straight, the
/// ones beside it turned toward it). A swipe turns it; a tap on a side card brings it to the middle, a tap on the
/// middle one opens it. Until it is touched it turns by itself, slowly.
class ServicesStrip extends StatefulWidget {
  const ServicesStrip({super.key, this.auto = true});
  final bool auto;
  @override
  State<ServicesStrip> createState() => _ServicesStripState();
}

/// whether the strip turns by itself (the tests hold it still)
bool stripTurns = true;

class _ServicesStripState extends State<ServicesStrip> with SingleTickerProviderStateMixin {
  double p = 0;
  late final AnimationController anim = AnimationController(vsync: this);
  Animation<double>? _to;
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    anim.addListener(() {
      final t = _to;
      if (t != null) setState(() => p = t.value);
    });
    if (widget.auto && stripTurns) _auto = Timer.periodic(const Duration(seconds: 4), (_) => _go(p.round() + 1));
  }

  @override
  void dispose() {
    _auto?.cancel();
    anim.dispose();
    super.dispose();
  }

  void _stop() {
    _auto?.cancel();
    _auto = null;
  }

  void _go(int k) {
    final from = p;
    _to = Tween<double>(begin: from, end: k.toDouble()).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
    anim.duration = Duration(milliseconds: math.min(620, 260 + ((k - from).abs() * 110).round()));
    anim.forward(from: 0);
  }

  void _arrow(int d) {
    _stop();
    _go(p.round() + d);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app;
    final items = [for (final s in stripServices) if (pageOk(context, s.$1)) s];
    final n = items.length;
    if (n == 0) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
        child: Row(children: [
          const Text('სერვისები', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const Spacer(),
          IconBtn('back', label: 'წინა', size: 18, color: c.muted, onTap: () => _arrow(-1)),
          Transform.flip(flipX: true, child: IconBtn('back', label: 'შემდეგი', size: 18, color: c.muted, onTap: () => _arrow(1))),
          TextButton(key: const ValueKey('svc-all'), onPressed: () => servicesMenu(context), child: const Text('ყველა', style: TextStyle(fontWeight: FontWeight.w700))),
        ]),
      ),
      LayoutBuilder(builder: (context, box) {
        final cw = box.maxWidth;
        final w = (cw * .38).clamp(128.0, 176.0).toDouble();
        final first = w / 2 + w * .2, gap = ((cw / 2 - first - w * .2) / 2).clamp(16.0, 70.0).toDouble();
        double xOf(double a) => a <= 1 ? a * first : first + (a - 1) * gap;
        return ListenableBuilder(
          listenable: Listenable.merge([app.home.counts, app.friends, app.home]),
          builder: (context, _) {
            final counts = {...app.home.counts.value, 'friends': app.friends.incoming.length};
            final kids = <(double, Widget)>[];
            for (var k = (p - 4).floor(); k <= (p + 4).ceil(); k++) {
              final d = k - p, ad = d.abs();
              if (ad > 4.001) continue;
              final s = items[((k % n) + n) % n], sg = d.sign, t = math.min(ad, 1.0), on = k == p.round();
              final cnt = s.$5 == null ? null : (counts[s.$1] ?? 0);
              final card = ServiceCard(s: s, width: w, count: cnt != null && cnt > 0 ? s.$5!(cnt) : null, on: on);
              kids.add((
                ad,
                Positioned(
                  left: cw / 2 - w / 2,
                  top: 6,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: (Matrix4.identity()..setEntry(3, 2, .001))
                      ..multiply(Matrix4.translationValues(sg * xOf(ad), 0, t * 90 + math.max(0.0, ad - 1) * 40))
                      ..multiply(Matrix4.rotationY(sg * t * 55 * math.pi / 180))
                      ..multiply(Matrix4.diagonal3Values(1 - t * .08, 1 - t * .08, 1)),
                    child: Opacity(
                      opacity: ad <= 3 ? 1.0 : math.max(0.0, 4 - ad),
                      child: Semantics(
                        button: true,
                        label: on ? s.$3 : '${s.$3} (გადახვევა)',
                        child: GestureDetector(
                          key: ValueKey(on ? 'svc-${s.$1}' : 'svc-side-$k'),
                          onTap: () {
                            _stop();
                            if (on) {
                              openService(context, s.$1);
                            } else {
                              _go(k);
                            }
                          },
                          child: card,
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
              onHorizontalDragStart: (_) {
                _stop();
                anim.stop();
              },
              onHorizontalDragUpdate: (e) => setState(() => p -= e.delta.dx / (first * .85)),
              onHorizontalDragEnd: (e) {
                final v = -(e.primaryVelocity ?? 0) / (first * .85);
                _go((p + v * .18).round());
              },
              child: SizedBox(height: w * .8 + 24, child: ClipRect(child: Stack(clipBehavior: Clip.none, children: [for (final k in kids) k.$2]))),
            );
          },
        );
      }),
    ]);
  }
}

/// All the services, in a grid; the ones the app does not have yet carry a small arrow (they open on the site).
Future<void> servicesMenu(BuildContext context) {
  final staff = context.me.role == 'admin' || context.me.role == 'moderator';
  final list = <(String, String, String, String?)>[for (final s in allServices) if (pageOk(context, s.$1)) s, if (staff) ('admin', 'shield', 'ადმინ პანელი', null)];
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) {
      final c = s.pc;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(s).height * .85),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('სერვისები', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            Flexible(
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: .98,
                children: [
                  for (final x in list)
                    Material(
                      color: c.sunk,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: ValueKey('menu-${x.$1}${x.$4 != null ? '-${x.$4}' : ''}'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(s).pop();
                          openService(context, x.$1, arg: x.$4);
                        },
                        child: Stack(children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: c.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
                                child: PIcon(x.$2, size: 22, color: c.accent),
                              ),
                              const SizedBox(height: 8),
                              Text(x.$3, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.2)),
                            ]),
                          ),
                          if (!nativeServices.contains(x.$1))
                            Positioned(top: 6, right: 6, child: Semantics(label: 'საიტზე იხსნება', child: PIcon('link', size: 13, color: c.muted))),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          ]),
        ),
      );
    },
  );
}

/// What I can make from here (app.js CREATE, the parts the app has).
Future<void> createMenu(BuildContext context, {required Future<void> Function({bool photos, bool poll}) write}) {
  final items = <(String, String, String, String, Future<void> Function())>[
    ('cpost', 'edit', 'პოსტი', 'ტექსტი, ფოტო, ჰეშთეგი', () => write()),
    ('cphoto', 'image', 'ფოტო', 'ფილტრით და ჭრით', () => write(photos: true)),
    ('cclip', 'clips', 'კლიპი', 'მოკლე ვერტიკალური ვიდეო', () async {
      final p = await openPage<Post>(context, const ClipComposer(), full: true);
      if (p != null && context.mounted) toast(context, 'კლიპი გამოქვეყნდა');
    }),
    ('cpoll', 'poll', 'გამოკითხვა', 'მეგობრების აზრი', () => write(poll: true)),
    ('cstory', 'story', 'ისტორია', 'ქრება 24 საათში', () => addStory(context)),
    ('calbum', 'image', 'ალბომი', 'საერთო ფოტოები ერთად', () => albumForm(context)),
  ];
  final off = context.app.home.off;
  const feat = {'cclip': 'clips', 'cpoll': 'polls', 'cstory': 'stories', 'calbum': 'albums'};
  final admin = context.me.role == 'admin';
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: context.pc.surface,
    builder: (s) {
      final c = s.pc;
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('შექმნა', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.0,
              children: [
                for (final x in items)
                  if (admin || feat[x.$1] == null || !off.contains(feat[x.$1]))
                    Material(
                      color: c.sunk,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: ValueKey('create-${x.$1}'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(s).pop();
                          x.$5();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: c.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
                              child: PIcon(x.$2, size: 20, color: c.accent),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(x.$3, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                Text(x.$4, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 11.5, height: 1.2)),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                    ),
              ],
            ),
          ]),
        ),
      );
    },
  );
}

/// What I saved, every folder together, newest first.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<(int, String)> folders = const [];
  int? folder;
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
      final f = await app.api.saveFolders();
      final p = await app.api.saved(folder: folder);
      await app.posts.load(p);
      if (mounted) {
        setState(() {
          folders = f;
          posts = p;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, p = posts;
    return Scaffold(
      appBar: peeraBar(context, title: 'შენახული'),
      body: p == null
          ? (error != null ? Center(child: Empty(icon: 'bookmark', title: 'ვერ ჩაიტვირთა', action: 'თავიდან', onAction: _load)) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                if (folders.isNotEmpty)
                  SizedBox(
                    height: 52,
                    child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 10, 12, 4), children: [
                      for (final (id, name) in <(int?, String)>[(null, 'ყველა'), for (final f in folders) (f.$1, f.$2)])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(name),
                            selected: folder == id,
                            showCheckmark: false,
                            selectedColor: c.ink,
                            labelStyle: TextStyle(color: folder == id ? c.bg : c.ink, fontWeight: FontWeight.w600),
                            onSelected: (_) {
                              setState(() {
                                folder = id;
                                posts = null;
                              });
                              _load();
                            },
                          ),
                        ),
                    ]),
                  ),
                if (p.isEmpty)
                  const Empty(icon: 'bookmark', title: 'ჯერ არაფერი შეგინახავს', text: 'პოსტის 🔖 ღილაკით შეინახე, რაც მოგეწონა.')
                else
                  for (final x in p) PostCard(key: ValueKey('post-${x.id}'), post: x),
              ]),
            ),
    );
  }
}
