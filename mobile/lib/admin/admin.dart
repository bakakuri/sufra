// The team's panel (admin.js), the same as the site's without the games, the shop, payouts and the coin promotion:
// the numbers, reports grouped by what they are about, all content in one place, people (limit, role, verification, a
// message from the team), verification selfies, Peera's own ads and the pages' ads, a notification to many, the
// site's banner and sections, pages, masked words, the errors from people's phones, the team's log.
import 'dart:async';

import 'package:flutter/material.dart';

import '../calls/rooms.dart';
import '../community/events.dart';
import '../community/groups.dart';
import '../community/help.dart';
import '../community/jobs.dart';
import '../community/pages.dart';
import '../community/rides.dart';
import '../community/sport.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../feed/photo_viewer.dart';
import '../feed/post_card.dart';
import '../feed/comments_sheet.dart';
import '../media/video_tools.dart';
import '../people/person_screen.dart';
import '../places/places.dart';
import '../profile/profile.dart';
import '../settings/places.dart';
import '../ui/bits.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// the tabs: key, name, the number waiting, admin only
const adminTabs = [
  ('overview', 'მიმოხილვა', null, false),
  ('reports', 'საჩივრები', 'open_reports', false),
  ('content', 'კონტენტი', null, false),
  ('users', 'მომხმარებლები', null, false),
  ('verify', 'ვერიფიკაცია', 'pending_verifications', false),
  ('promo', 'რეკლამა', 'pending_ads', false),
  ('notify', 'შეტყობინებები', null, true),
  ('site', 'საიტი', null, true),
  ('pages', 'გვერდები', null, false),
  ('words', 'სიტყვები', null, false),
  ('errors', 'შეცდომები', null, false),
  ('log', 'ჟურნალი', null, false),
];

const targetNames = {
  'post': 'პოსტი', 'comment': 'კომენტარი', 'user': 'პროფილი', 'listing': 'განცხადება', 'message': 'შეტყობინება', 'page': 'გვერდი', //
  'story': 'ისტორია', 'event': 'ღონისძიება', 'place': 'ადგილი', 'review': 'შეფასება', 'help': 'დახმარება',
  'job': 'ვაკანსია', 'ride': 'მგზავრობა', 'group': 'ჯგუფი', 'room': 'ოთახი', 'album': 'ალბომი',
};
const roleNames = {'user': 'მომხმარებელი', 'moderator': 'მოდერატორი', 'admin': 'ადმინისტრატორი'};

/// the site's links a notification, a banner or an ad can open
const siteLinks = [('#events', 'შეხვედრები'), ('#market', 'ბაზრობა'), ('#rooms', 'სასწავლო ოთახები'), ('#study', 'სწავლა'), ('#jobs', 'ვაკანსიები'), ('#help', 'დახმარება')];

bool linkOk(String l) => l.isEmpty || RegExp(r'''^https://[^\s"'<>()]+$''').hasMatch(l) || RegExp(r'''^#[a-z]+(-[^\s"'<>()]+)?$''').hasMatch(l);

/// the sections that can be switched off for everyone (promo.js FEATS, without the shop and the games)
const siteFeatures = [
  ('rooms', 'სასწავლო ოთახი, დისკუსია, ლაივი'), ('places', 'ადგილები'), ('sport', 'მატჩები და პროგნოზები'), ('help', 'დახმარება'), //
  ('rides', 'ერთად წავიდეთ'), ('jobs', 'ვაკანსიები და CV'), ('market', 'ბაზრობა'), ('events', 'შეხვედრები'), ('albums', 'ალბომები'),
  ('groups', 'ჯგუფები'), ('pages', 'არხები და გვერდები'), ('tree', 'ოჯახის ხე'), ('namedays', 'სახელის დღეები'),
  ('map', 'ლაივ რუკა და ლოკაციის გაზიარება'), ('calendar', 'კალენდარი და შეხსენებები'), ('study', 'სწავლა: ცხრილი, გამოცდები, კონსპექტები, კლასელები, რჩევები'),
  ('stories', 'ისტორიები'), ('memories', 'მოგონებები'), ('polls', 'გამოკითხვები'),
  ('gchat', 'ჯგუფური ჩატები'), ('gifts', 'საჩუქრები'), ('clips', 'კლიპები'), ('date', 'გაცნობა'),
];

/// all content by kind (admin.js CT): key, name, table, columns, owner, text, can be hidden
const contentKinds = [
  ('post', 'პოსტები', 'posts', 'id,author,body,media,hidden,created_at', 'author', 'body', true),
  ('comment', 'კომენტარები', 'comments', 'id,author,body,post_id,hidden,created_at', 'author', 'body', true),
  ('story', 'ისტორიები', 'stories', 'id,author,media_url,media_type,created_at,expires_at', 'author', null, false),
  ('group', 'ჯგუფები', 'groups', 'id,owner,name,description,avatar_url,created_at', 'owner', 'name', false),
  ('event', 'ღონისძიებები', 'events', 'id,host,title,starts_at,created_at', 'host', 'title', false),
  ('listing', 'განცხადებები', 'listings', 'id,seller,title,media,hidden,created_at', 'seller', 'title', true),
  ('place', 'ადგილები', 'places', 'id,created_by,name,photo,hidden,created_at', 'created_by', 'name', true),
  ('help', 'დახმარება', 'help_requests', 'id,author,title,media,hidden,created_at', 'author', 'title', true),
  ('job', 'ვაკანსიები', 'jobs', 'id,poster,title,company,hidden,created_at', 'poster', 'title', true),
  ('ride', 'მგზავრობა', 'rides', 'id,driver,from_city,to_city,depart_at,created_at', 'driver', 'from_city', false),
  ('room', 'ოთახები', 'rooms', 'id,host,kind,title,live,created_at', 'host', 'title', false),
  ('album', 'ალბომები', 'albums', 'id,owner,title,cover_url,created_at', 'owner', 'title', false),
  ('review', 'ადგილის შეფასებები', 'place_reviews', 'id,place_id,author,rating,body,created_at', 'author', 'body', false),
  ('fixchat', 'მატჩის ჩატი', 'fixture_chat', 'id,fixture_id,user_id,body,created_at', 'user_id', 'body', false),
  ('highlight', 'ისტორიების ალბომები', 'highlights', 'id,owner,title,cover_url,created_at', 'owner', 'title', false),
];

const _delTable = {
  'post': 'posts', 'comment': 'comments', 'listing': 'listings', 'story': 'stories', 'event': 'events', 'place': 'places', //
  'review': 'place_reviews', 'toast': 'toasts', 'help': 'help_requests',
};

String? _img(Map<String, dynamic> x) {
  final m = x['media'] is List && (x['media'] as List).isNotEmpty ? (x['media'] as List).first : null;
  final ph = x['photos'] is List && (x['photos'] as List).isNotEmpty ? (x['photos'] as List).first : null;
  final v = x['media_url'] ?? x['photo'] ?? x['photo_url'] ?? x['cover_url'] ?? x['avatar_url'] ?? ph ?? (m is String ? m : (m is Map ? m['sm'] ?? m['url'] : null));
  return v is String && v.startsWith('http') ? v : null;
}

/// something the panel points at, opened where the app has it
Future<void> openThing(BuildContext context, String kind, Map<String, dynamic> r) async {
  final app = context.app;
  int n(String k) => asInt(r[k]);
  Widget? page;
  switch (kind) {
    case 'post' || 'comment':
      final p = await app.api.post(kind == 'post' ? n('id') : n('post_id')).catchError((_) => null);
      if (p == null) {
        if (context.mounted) toast(context, 'პოსტი წაშლილია');
        return;
      }
      await app.posts.load([p]);
      if (context.mounted) await openPost(context, p);
      return;
    case 'group':
      page = GroupScreen(id: n('id'));
    case 'page':
      page = PageScreen(id: n('id'));
    case 'event':
      page = EventScreen(id: n('id'));
    case 'place':
      page = PlaceScreen(id: n('id'));
    case 'review':
      page = PlaceScreen(id: n('place_id'));
    case 'help':
      page = HelpRequestScreen(id: n('id'));
    case 'job':
      page = JobScreen(id: n('id'));
    case 'ride':
      page = RideScreen(id: n('id'));
    case 'fixchat':
      page = FixtureScreen(id: n('fixture_id'));
    case 'room':
      await openRoom(context, n('id'));
      return;
    case 'story':
      final u = _img(r);
      if (u != null) await openPhotos(context, [Media(url: u, type: r['media_type'] == 'video' ? 'video' : 'image')]);
      return;
  }
  if (page != null && context.mounted) await openPage(context, page, full: true);
}

/// A card of the panel: ink shows on it (its list rows and buttons)
class _Card extends StatelessWidget {
  const _Card({super.key, required this.child, this.padding = const EdgeInsets.all(12)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Material(
        color: c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.line)),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// The panel.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, this.tab = 'overview'});
  final String tab;
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late String tab = widget.tab;

  /// the tabs opened before this one: back goes to them one at a time, then out of the panel
  final _trail = <String>[];
  Map<String, dynamic> stats = {};
  bool _started = false;

  bool get admin => context.me.role == 'admin';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!adminTabs.any((t) => t.$1 == tab && (!t.$4 || admin))) tab = 'overview';
    refresh();
  }

  Future<void> refresh() async {
    try {
      final s = await context.app.api.adminStats();
      if (mounted) setState(() => stats = s);
    } catch (_) {}
  }

  void go(String k) {
    if (k == tab) return;
    setState(() {
      _trail.add(tab);
      tab = k;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [for (final t in adminTabs) if (!t.$4 || admin) t];
    final Widget body = switch (tab) {
      'reports' => _Reports(onChange: refresh),
      'content' => const _Content(),
      'users' => const _Users(),
      'verify' => _Verify(onChange: refresh),
      'promo' => _Promo(onChange: refresh, pending: asInt(stats['pending_ads'])),
      'notify' => const _Notify(),
      'site' => const _Site(),
      'pages' => const _Pages(),
      'words' => const _Words(),
      'errors' => const _Errors(),
      'log' => const _Log(),
      _ => _Overview(stats: stats, onRefresh: refresh, go: go),
    };
    return PopScope(
      canPop: _trail.isEmpty,
      onPopInvokedWithResult: (did, _) {
        if (!did && _trail.isNotEmpty) setState(() => tab = _trail.removeLast());
      },
      child: Scaffold(
        appBar: peeraBar(context, title: 'ადმინ პანელი'),
        body: Column(children: [
          ChipsBar(
            prefix: 'at',
            items: [for (final (k, n, c, _) in tabs) (k, c != null && asInt(stats[c]) > 0 ? '$n · ${asInt(stats[c])}' : n)],
            value: tab,
            onPick: go,
          ),
          Expanded(child: KeyedSubtree(key: ValueKey('ab-$tab'), child: body)),
        ]),
      ),
    );
  }
}

// ---------- the numbers ----------
class _Overview extends StatelessWidget {
  const _Overview({required this.stats, required this.onRefresh, required this.go});
  final Map<String, dynamic> stats;
  final Future<void> Function() onRefresh;
  final void Function(String) go;

  @override
  Widget build(BuildContext context) {
    final c = context.pc, s = stats, admin = context.me.role == 'admin';
    Widget tiles(List<(String, String)> l) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.3,
            children: [
              for (final (k, label) in l)
                Container(
                  key: ValueKey('ast-$k'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(thousands(asNum(s[k]) ?? 0), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ]),
                ),
            ],
          ),
        );
    final days = [for (final d in (s['days'] is List ? s['days'] as List : const [])) if (d is Map) Map<String, dynamic>.from(d)];
    Widget chart(String k, String title) {
      if (days.isEmpty) return const SizedBox.shrink();
      final vals = [for (final d in days) asInt(d[k])], top = vals.reduce((a, b) => a > b ? a : b), mx = top < 1 ? 1 : top;
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
            Text('14 დღე · სულ ${vals.fold<int>(0, (a, b) => a + b)}', style: TextStyle(color: c.muted, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < vals.length; i++)
                Expanded(
                  child: Tooltip(
                    message: '${days[i]['d']} · ${vals[i]}',
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      height: 4 + 66 * vals[i] / mx,
                      decoration: BoxDecoration(color: i == vals.length - 1 ? c.accent : c.accent.withValues(alpha: .4), borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        const SecHead('ხალხი'),
        tiles([('users', 'მომხმარებელი'), ('users_today', 'ახალი, 24 სთ'), ('active_today', 'აქტიური დღეს'), ('active_week', 'აქტიური კვირაში')]),
        const SecHead('ბოლო 24 საათი'),
        tiles([('posts_today', 'პოსტი'), ('comments_today', 'კომენტარი'), ('messages_today', 'მესიჯი'), ('stories_live', 'ისტორია ახლა')]),
        chart('users', 'ახალი მომხმარებლები'),
        chart('posts', 'ახალი პოსტები'),
        const SecHead('საიტზე'),
        tiles([
          ('groups', 'ჯგუფი'), ('pages', 'გვერდი'), ('events_soon', 'ღონისძიება წინ'), ('rooms_live', 'ცოცხალი ოთახი'), //
          ('listings', 'განცხადება'), ('promos_live', 'აქტიური რეკლამა'), ('banned', 'შეზღუდული'), ('open_reports', 'ღია საჩივარი'),
        ]),
        if (admin)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                key: const ValueKey('ao-promo'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: () => openPage(context, const PromoEditor(), full: true),
                icon: PIcon('plus', size: 17, color: c.onAccent),
                label: const Text('ახალი რეკლამა'),
              ),
              OutlinedButton.icon(key: const ValueKey('ao-notify'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)), onPressed: () => go('notify'), icon: const PIcon('bell', size: 17), label: const Text('შეტყობინება ყველას')),
              OutlinedButton.icon(key: const ValueKey('ao-site'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)), onPressed: () => go('site'), icon: const PIcon('gear', size: 17), label: const Text('საიტის პარამეტრები')),
            ]),
          ),
      ]),
    );
  }
}

// ---------- reports ----------
class _Reports extends StatefulWidget {
  const _Reports({required this.onChange});
  final Future<void> Function() onChange;
  @override
  State<_Reports> createState() => _ReportsState();
}

class _ReportsState extends State<_Reports> {
  String status = 'open';
  List<({String type, String id, List<Map<String, dynamic>> list})>? groups;
  Map<String, Map<String, dynamic>> targets = {};
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
      final rows = await app.api.reports(status);
      final g = <String, ({String type, String id, List<Map<String, dynamic>> list})>{};
      for (final r in rows) {
        final k = '${r['target_type']}:${r['target_id']}';
        (g[k] ??= (type: '${r['target_type']}', id: '${r['target_id']}', list: <Map<String, dynamic>>[])).list.add(r);
      }
      final by = <String, List<String>>{};
      for (final x in g.values) {
        (by[x.type] ??= []).add(x.id);
      }
      final t = await app.api.reportTargets(by);
      String? owner(Map<String, dynamic>? x) => x == null ? null : '${x['author'] ?? x['seller'] ?? x['owner'] ?? x['host'] ?? x['created_by'] ?? ''}';
      await app.people.ensure([
        for (final r in rows) '${r['reporter']}',
        ...by['user'] ?? const <String>[],
        for (final x in t.values)
          if (owner(x) case final o? when o.isNotEmpty) o,
      ]);
      if (!mounted) return;
      setState(() {
        groups = [...g.values]..sort((a, b) => b.list.length.compareTo(a.list.length));
        targets = t;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _resolve(List<Map<String, dynamic>> list, String to) async {
    final api = context.app.api;
    if (await attempt(context, () => Future.wait([for (final r in list) api.resolveReport(asInt(r['id']), to)]))) {
      if (!mounted) return;
      toast(context, to == 'resolved' ? 'მონიშნულია გადაწყვეტილად' : (to == 'dismissed' ? 'საჩივარი უარყოფილია' : 'ხელახლა გაიხსნა'));
      widget.onChange();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, g = groups, app = context.app, me = app.api.myId;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: SegmentedButton<String>(
          key: const ValueKey('ar-seg'),
          showSelectedIcon: false,
          segments: const [ButtonSegment(value: 'open', label: Text('ღია')), ButtonSegment(value: 'resolved', label: Text('გადაწყვეტილი')), ButtonSegment(value: 'dismissed', label: Text('უარყოფილი'))],
          selected: {status},
          onSelectionChanged: (v) {
            setState(() {
              status = v.first;
              groups = null;
            });
            _load();
          },
        ),
      ),
      Expanded(
        child: g == null
            ? (error != null ? Empty(icon: 'flag', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load) : const Center(child: CircularProgressIndicator()))
            : g.isEmpty
                ? Empty(icon: 'flag', title: status == 'open' ? 'საჩივრები არ არის' : 'აქ ცარიელია', text: status == 'open' ? 'ყველაფერი წესრიგშია.' : null)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                      for (final x in g)
                        Builder(builder: (context) {
                          final k = x.type, t = targets['$k:${x.id}'];
                          final owner = k == 'user' ? x.id : (t == null ? null : '${t['author'] ?? t['seller'] ?? t['owner'] ?? t['host'] ?? t['created_by'] ?? ''}');
                          final reasons = {for (final r in x.list) '${r['reason']}'};
                          final tv = t ?? const <String, dynamic>{};
                          final canHide = t != null && const ['post', 'comment', 'listing', 'place', 'review', 'toast', 'help'].contains(k);
                          final canDel = t != null && _delTable.containsKey(k);
                          final op = owner == null || owner.isEmpty ? null : app.people[owner];
                          Widget sm(String key, String icon, String label, VoidCallback onTap) =>
                              OutlinedButton.icon(key: ValueKey(key), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)), onPressed: onTap, icon: PIcon(icon, size: 15), label: Text(label));
                          return _Card(
                            key: ValueKey('rep-$k-${x.id}'),
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                PTag(targetNames[k] ?? k),
                                const SizedBox(width: 8),
                                Text('${x.list.length} საჩივარი', style: const TextStyle(fontWeight: FontWeight.w800)),
                                const Spacer(),
                                Text(ago(asTime(x.list.last['created_at'])), style: TextStyle(color: c.muted, fontSize: 12)),
                              ]),
                              const SizedBox(height: 6),
                              Wrap(spacing: 5, runSpacing: 5, children: [for (final r in reasons) PTag(r, kind: 'warn')]),
                              for (final r in x.list.where((r) => '${r['details'] ?? ''}'.isNotEmpty).take(3))
                                Padding(padding: const EdgeInsets.only(top: 4), child: Text('„${r['details']}“', style: TextStyle(color: c.muted))),
                              const SizedBox(height: 8),
                              if (k == 'user' && op != null)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Avatar(p: op, size: 40),
                                  title: Text(op.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: Text(op.banned ? 'შეზღუდულია' : '@${op.username ?? ''}'),
                                  onTap: () => openPage(context, PersonScreen(uid: op.id, initial: op), full: true),
                                )
                              else if (t == null)
                                Text(k == 'message' ? 'პირადი მიმოწერა მოდერატორს არ უჩანს. გადაწყვიტე საჩივრის აღწერით ან შეზღუდე ავტორი პროფილიდან.' : 'შინაარსი უკვე წაშლილია ან ვადა გაუვიდა.', style: TextStyle(color: c.muted))
                              else
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  if (_img(t) case final u?) ...[
                                    ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 64, height: 64, child: PImage(u))),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      if (op != null) Text(op.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      Text(
                                        '${t['body'] ?? t['title'] ?? t['name'] ?? ''}'.isEmpty ? 'ტექსტის გარეშე' : '${t['body'] ?? t['title'] ?? t['name']}',
                                        maxLines: 5,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (t['hidden'] == true) const Padding(padding: EdgeInsets.only(top: 4), child: PTag('დამალულია', kind: 'warn')),
                                    ]),
                                  ),
                                ]),
                              const SizedBox(height: 8),
                              Wrap(spacing: 6, runSpacing: 6, children: [
                                if (t != null && const ['post', 'comment', 'page', 'event', 'place', 'review', 'help'].contains(k)) sm('rep-open', 'eye', 'ნახვა', () => openThing(context, k, tv)),
                                if (canHide)
                                  sm('rep-hide', tv['hidden'] == true ? 'eye' : 'lock', tv['hidden'] == true ? 'გამოჩენა' : 'დამალვა', () async {
                                    final h = tv['hidden'] != true;
                                    if (!await attempt(context, () => app.api.modHide(k, asInt(tv['id']), h)) || !context.mounted) return;
                                    toast(context, h ? 'დაიმალა ყველასთვის' : 'ისევ ჩანს');
                                    if (h && status == 'open') {
                                      _resolve(x.list, 'resolved');
                                    } else {
                                      _load();
                                    }
                                  }),
                                if (canDel)
                                  sm('rep-del', 'trash', 'წაშლა', () async {
                                    if (!await confirm(context, title: 'სამუდამოდ წაშლა', text: '${targetNames[k]} წაიშლება და ვეღარ აღდგება.', yes: 'წაშლა', danger: true) || !context.mounted) return;
                                    if (!await attempt(context, () => app.api.adminDelete(_delTable[k]!, asInt(tv['id']))) || !context.mounted) return;
                                    toast(context, 'წაიშალა');
                                    if (status == 'open') {
                                      _resolve(x.list, 'resolved');
                                    } else {
                                      _load();
                                    }
                                  }),
                                if (owner != null && owner.isNotEmpty && owner != me)
                                  sm('rep-ban', 'block', op?.banned == true ? 'შეზღუდვის მოხსნა' : 'ავტორის შეზღუდვა', () async {
                                    final ban = op?.banned != true;
                                    if (ban && !await confirm(context, title: 'მომხმარებლის შეზღუდვა', text: '${op?.name ?? ''} ვეღარ დაწერს პოსტებს, კომენტარებს და შეტყობინებებს, სანამ შეზღუდვას არ მოხსნი.', yes: 'შეზღუდვა', danger: true)) return;
                                    if (!context.mounted || !await attempt(context, () => app.api.adminBan(owner, ban)) || !context.mounted) return;
                                    toast(context, ban ? 'შეიზღუდა' : 'შეზღუდვა მოიხსნა');
                                    app.people.ensure([owner], fresh: true);
                                    if (ban && status == 'open') {
                                      _resolve(x.list, 'resolved');
                                    } else {
                                      _load();
                                    }
                                  }),
                                if (status == 'open') ...[
                                  sm('rep-ok', 'check', 'გადაწყვეტილია', () => _resolve(x.list, 'resolved')),
                                  sm('rep-no', 'x', 'უარყოფა', () => _resolve(x.list, 'dismissed')),
                                ] else
                                  sm('rep-reopen', 'repost', 'ხელახლა გახსნა', () => _resolve(x.list, 'open')),
                              ]),
                            ]),
                          );
                        }),
                    ]),
                  ),
      ),
    ]);
  }
}

// ---------- all content ----------
class _Content extends StatefulWidget {
  const _Content();
  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  String kind = 'post';
  final q = TextEditingController();
  bool hiddenOnly = false, more = false;
  List<Map<String, dynamic>>? rows;
  Object? error;
  Timer? _wait;
  int _gen = 0;
  bool _started = false;

  (String, String, String, String, String, String?, bool) get k => contentKinds.firstWhere((x) => x.$1 == kind);

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

  Future<void> _load({bool next = false}) async {
    final g = ++_gen, app = context.app, x = k;
    try {
      final r = await app.api.adminContent(x.$3, x.$4, textCol: x.$6, q: q.text.trim(), hiddenOnly: hiddenOnly && x.$7, from: next ? rows?.length ?? 0 : 0);
      await app.people.ensure([for (final y in r) if (y[x.$5] != null) '${y[x.$5]}']);
      if (!mounted || g != _gen) return;
      setState(() {
        rows = next ? [...?rows, ...r] : r;
        more = r.length == 40;
        error = null;
      });
    } catch (e) {
      if (mounted && g == _gen) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, r = rows, x = k, app = context.app, me = app.api.myId;
    return Column(children: [
      ChipsBar(prefix: 'act', items: [for (final y in contentKinds) (y.$1, y.$2)], value: kind, onPick: (v) {
        setState(() {
          kind = v;
          rows = null;
        });
        _load();
      }),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              key: const ValueKey('ac-q'),
              controller: q,
              textInputAction: TextInputAction.search,
              onChanged: (_) {
                _wait?.cancel();
                _wait = Timer(const Duration(milliseconds: 350), _load);
              },
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(hintText: 'ძიება ტექსტში', isDense: true, prefixIcon: Padding(padding: const EdgeInsets.all(10), child: PIcon('search', size: 18, color: c.muted))),
            ),
          ),
          if (x.$7) ...[
            Checkbox(
              key: const ValueKey('ac-hid'),
              value: hiddenOnly,
              onChanged: (v) {
                setState(() => hiddenOnly = v == true);
                _load();
              },
            ),
            const Text('დამალული'),
          ],
        ]),
      ),
      Expanded(
        child: r == null
            ? (error != null ? Empty(icon: 'note', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load) : const Center(child: CircularProgressIndicator()))
            : r.isEmpty
                ? Empty(icon: 'note', title: 'აქ არაფერია', text: q.text.trim().isNotEmpty ? 'სხვა სიტყვით სცადე.' : null)
                : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                    for (final y in r)
                      Builder(builder: (context) {
                        final o = y[x.$5] == null ? null : '${y[x.$5]}', who = o == null ? null : app.people[o], img = _img(y);
                        final text = kind == 'ride' ? '${y['from_city'] ?? ''} → ${y['to_city'] ?? ''}' : '${y[x.$6 ?? 'body'] ?? y['body'] ?? ''}';
                        final expired = kind == 'story' && asTime(y['expires_at']).isBefore(DateTime.now());
                        return Container(
                          key: ValueKey('acr-$kind-${y['id']}'),
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (img != null) ...[
                              ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 56, height: 56, child: PImage(img))),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(text.isEmpty ? 'ტექსტის გარეშე' : (text.length > 160 ? '${text.substring(0, 160)}…' : text), style: TextStyle(color: text.isEmpty ? c.muted : c.ink)),
                                const SizedBox(height: 2),
                                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                  Text('${who != null ? '${who.name} · ' : ''}${ago(asTime(y['created_at']))}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                                  if (y['hidden'] == true) const PTag('დამალულია', kind: 'warn'),
                                  if (kind == 'room') PTag(y['live'] == true ? 'ცოცხალი' : 'დასრულდა', kind: y['live'] == true ? 'ad' : ''),
                                  if (expired) const PTag('არქივში'),
                                ]),
                                const SizedBox(height: 6),
                                Wrap(spacing: 6, runSpacing: 6, children: [
                                  if (kind != 'highlight')
                                    OutlinedButton(key: ValueKey('acv-${y['id']}'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32)), onPressed: () => openThing(context, kind, y), child: const Text('ნახვა')),
                                  if (x.$7)
                                    OutlinedButton(
                                      key: ValueKey('ach-${y['id']}'),
                                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32)),
                                      onPressed: () async {
                                        final h = y['hidden'] != true;
                                        if (!await attempt(context, () => app.api.modHide(kind, asInt(y['id']), h)) || !context.mounted) return;
                                        setState(() => y['hidden'] = h);
                                        toast(context, h ? 'დაიმალა ყველასთვის' : 'ისევ ჩანს');
                                      },
                                      child: Text(y['hidden'] == true ? 'გამოჩენა' : 'დამალვა'),
                                    ),
                                  if (kind == 'room' && y['live'] == true)
                                      OutlinedButton(
                                        key: ValueKey('ace-${y['id']}'),
                                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32)),
                                        onPressed: () async {
                                          if (!await confirm(context, title: 'ოთახის დასრულება', text: 'ოთახი ყველასთვის დაიხურება.', yes: 'დასრულება', danger: true) || !context.mounted) return;
                                          if (await attempt(context, () => app.api.endRoom(asInt(y['id']))) && context.mounted) {
                                            setState(() => y['live'] = false);
                                            toast(context, 'ოთახი დასრულდა');
                                          }
                                        },
                                        child: const Text('დასრულება'),
                                      )
                                  else if (kind != 'room')
                                    OutlinedButton(
                                      key: ValueKey('acd-${y['id']}'),
                                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), foregroundColor: c.nope),
                                      onPressed: () async {
                                        if (!await confirm(context, title: 'სამუდამოდ წაშლა', text: '${x.$2}: ეს ჩანაწერი წაიშლება და ვეღარ აღდგება.', yes: 'წაშლა', danger: true) || !context.mounted) return;
                                        if (await attempt(context, () => app.api.adminDelete(x.$3, asInt(y['id']))) && context.mounted) {
                                          setState(() => rows?.remove(y));
                                          toast(context, 'წაიშალა');
                                        }
                                      },
                                      child: const Text('წაშლა'),
                                    ),
                                  if (o != null && o != me)
                                    OutlinedButton(key: ValueKey('aca-${y['id']}'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32)), onPressed: () => userSheet(context, o), child: const Text('ავტორი')),
                                ]),
                              ]),
                            ),
                          ]),
                        );
                      }),
                    if (more)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton(key: const ValueKey('ac-more'), onPressed: () => _load(next: true), child: const Text('მეტის ჩატვირთვა')),
                      ),
                  ]),
      ),
    ]);
  }
}

// ---------- people ----------
class _Users extends StatefulWidget {
  const _Users();
  @override
  State<_Users> createState() => _UsersState();
}

class _UsersState extends State<_Users> {
  String filter = 'new';
  final q = TextEditingController();
  List<(Profile, DateTime)>? rows;
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
      final r = await app.api.adminUsers(q: q.text.trim(), filter: filter);
      for (final x in r) {
        app.people.put(x.$1);
      }
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

  @override
  Widget build(BuildContext context) {
    final c = context.pc, r = rows;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: TextField(
          key: const ValueKey('au-q'),
          controller: q,
          textInputAction: TextInputAction.search,
          onChanged: (_) {
            _wait?.cancel();
            _wait = Timer(const Duration(milliseconds: 350), _load);
          },
          onSubmitted: (_) => _load(),
          decoration: InputDecoration(hintText: 'სახელი ან @username', isDense: true, prefixIcon: Padding(padding: const EdgeInsets.all(10), child: PIcon('search', size: 18, color: c.muted))),
        ),
      ),
      ChipsBar(prefix: 'auf', items: const [('new', 'ახალი'), ('banned', 'შეზღუდული'), ('staff', 'გუნდი'), ('verified', 'ვერიფიცირებული')], value: filter, onPick: (v) {
        setState(() => filter = v);
        _load();
      }),
      Expanded(
        child: r == null
            ? (error != null ? Empty(icon: 'users', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load) : const Center(child: CircularProgressIndicator()))
            : r.isEmpty
                ? const Empty(icon: 'users', title: 'ვერავინ მოიძებნა')
                : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                    for (final (p, at) in r)
                      ListTile(
                        key: ValueKey('au-${p.id}'),
                        leading: Avatar(p: p, size: 44),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          [if ((p.username ?? '').isNotEmpty) '@${p.username}', if (p.role != null && p.role != 'user') roleNames[p.role] ?? '', if (p.banned) 'შეზღუდულია', ago(at)].join(' · '),
                        ),
                        trailing: const PIcon('more', size: 18),
                        onTap: () async {
                          await userSheet(context, p.id);
                          _load();
                        },
                      ),
                  ]),
      ),
    ]);
  }
}

/// one person, for the team: their numbers, their profile, a message from the team, verification off, a limit, a role
Future<void> userSheet(BuildContext context, String uid) async {
  final app = context.app, me = context.me, c = context.pc;
  await app.people.ensure([uid]);
  if (!context.mounted) return;
  final p = app.people[uid] ?? Profile(id: uid, name: '…'), admin = me.role == 'admin', self = uid == me.id;
  final info = app.api.adminUserInfo(uid);
  final k = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: c.surface,
    builder: (s) => SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ListTile(
            leading: Avatar(p: p, size: 52),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            subtitle: Text([if ((p.username ?? '').isNotEmpty) '@${p.username}', roleNames[p.role ?? 'user'] ?? ''].join(' · ')),
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: info,
            builder: (s, snap) {
              final d = snap.data;
              if (snap.hasError) return Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(errText(snap.error!), style: TextStyle(color: s.pc.muted)));
              if (d == null) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
              Widget n(String k, String l) => Column(children: [Text(thousands(asNum(d[k]) ?? 0), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), Text(l, style: TextStyle(color: s.pc.muted, fontSize: 11.5))]);
              return Padding(
                key: const ValueKey('aus-info'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 18, runSpacing: 8, children: [
                    n('posts', 'პოსტი'), n('comments', 'კომენტარი'), n('friends', 'მეგობარი'), n('coins', 'მონეტა'), //
                    n('reports', 'საჩივარი პროფილზე'), n('reported_content', 'საჩივარი პოსტებზე'),
                  ]),
                  const SizedBox(height: 6),
                  Text('${d['last_seen'] != null ? 'ბოლოს იყო ${ago(asTime(d['last_seen']))}' : 'ჯერ არ შემოსულა'}${'${d['email'] ?? ''}'.isNotEmpty ? ' · ${d['email']}' : ''}', style: TextStyle(color: s.pc.muted, fontSize: 12.5)),
                ]),
              );
            },
          ),
          ListTile(key: const ValueKey('aus-profile'), leading: const PIcon('user'), title: const Text('პროფილის ნახვა'), onTap: () => Navigator.of(s).pop('profile')),
          ListTile(key: const ValueKey('aus-msg'), leading: const PIcon('msg'), title: const Text('შეტყობინება გუნდის სახელით'), onTap: () => Navigator.of(s).pop('msg')),
          if (p.verified) ListTile(key: const ValueKey('aus-unv'), leading: const PIcon('shield'), title: const Text('ვერიფიკაციის მოხსნა'), onTap: () => Navigator.of(s).pop('unv')),
          if (!self && p.role != 'admin')
            ListTile(
              key: const ValueKey('aus-ban'),
              leading: PIcon('block', color: p.banned ? null : s.pc.nope),
              title: Text(p.banned ? 'შეზღუდვის მოხსნა' : 'შეზღუდვა', style: TextStyle(color: p.banned ? null : s.pc.nope)),
              onTap: () => Navigator.of(s).pop('ban'),
            ),
          if (admin && !self)
            for (final r in roleNames.keys)
              if (r != (p.role ?? 'user')) ListTile(key: ValueKey('aus-role-$r'), leading: PIcon(r == 'user' ? 'user' : 'shield'), title: Text('როლი: ${roleNames[r]}'), onTap: () => Navigator.of(s).pop('role:$r')),
        ]),
      ),
    ),
  );
  if (k == null || !context.mounted) return;
  if (k == 'profile') {
    await openPage(context, PersonScreen(uid: uid, initial: p), full: true);
  } else if (k == 'msg') {
    final t = await askLine(context, title: 'შეტყობინება · ${p.name.split(' ').first}', hint: 'მაგ. შენი პოსტი წაიშალა, რადგან წესებს არღვევდა', note: 'მივა მის შეტყობინებებში „Peera-ს გუნდის“ სახელით. ამ ტიპს ვერ გამორთავს, ამიტომ გამოიყენე მნიშვნელოვანი საკითხისთვის.', max: 300);
    if (t == null || !context.mounted) return;
    if (await attempt(context, () => app.api.adminNotifyUser(uid, t)) && context.mounted) toast(context, 'გაიგზავნა');
  } else if (k == 'unv') {
    if (await attempt(context, () => app.api.adminUnverify(uid)) && context.mounted) {
      app.people.ensure([uid], fresh: true);
      toast(context, 'ვერიფიკაცია მოიხსნა');
    }
  } else if (k == 'ban') {
    final ban = !p.banned;
    if (ban && !await confirm(context, title: 'მომხმარებლის შეზღუდვა', text: '${p.name} ვეღარ დაწერს პოსტებს, კომენტარებს და შეტყობინებებს, სანამ შეზღუდვას არ მოხსნი.', yes: 'შეზღუდვა', danger: true)) return;
    if (!context.mounted) return;
    if (await attempt(context, () => app.api.adminBan(uid, ban)) && context.mounted) {
      app.people.ensure([uid], fresh: true);
      toast(context, ban ? 'შეიზღუდა' : 'შეზღუდვა მოიხსნა');
    }
  } else if (k.startsWith('role:')) {
    final r = k.substring(5);
    final extra = r == 'admin' ? ' ადმინისტრატორს სრული წვდომა აქვს, მათ შორის როლების შეცვლაზე.' : (r == 'moderator' ? ' მოდერატორი განიხილავს საჩივრებს, ვერიფიკაციას და რეკლამას.' : '');
    if (!await confirm(context, title: 'როლის შეცვლა', text: '${p.name} გახდება „${roleNames[r]}“.$extra', yes: 'შეცვლა', danger: r == 'admin') || !context.mounted) return;
    if (await attempt(context, () => app.api.adminSetRole(uid, r)) && context.mounted) {
      app.people.ensure([uid], fresh: true);
      toast(context, 'როლი შეიცვალა');
    }
  }
}

/// one line of words asked for (a message, a word)
Future<String?> askLine(BuildContext context, {required String title, String hint = '', String? note, int max = 200}) async {
  final c = context.pc, f = TextEditingController();
  final ok = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: c.surface,
    builder: (s) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(s).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (note != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(note, style: TextStyle(color: s.pc.muted, fontSize: 13))),
            const SizedBox(height: 10),
            TextField(key: const ValueKey('al-text'), controller: f, autofocus: true, maxLength: max, minLines: 2, maxLines: 5, decoration: InputDecoration(hintText: hint, counterText: '')),
            const SizedBox(height: 10),
            FilledButton(
              key: const ValueKey('al-ok'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () {
                if (f.text.trim().length < 2) {
                  toast(s, 'დაწერე ტექსტი');
                  return;
                }
                Navigator.of(s).pop(true);
              },
              child: const Text('გაგზავნა'),
            ),
          ]),
        ),
      ),
    ),
  );
  return ok == true ? f.text.trim() : null;
}

// ---------- verification ----------
class _Verify extends StatefulWidget {
  const _Verify({required this.onChange});
  final Future<void> Function() onChange;
  @override
  State<_Verify> createState() => _VerifyState();
}

class _VerifyState extends State<_Verify> {
  List<Map<String, dynamic>>? rows;
  Object? error;
  final busy = <int>{};
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
      final r = await app.api.verifyRequests();
      await app.people.ensure([for (final x in r) '${x['user_id']}']);
      if (mounted) {
        setState(() {
          rows = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _do(Map<String, dynamic> x, bool ok) async {
    final id = asInt(x['id']);
    setState(() => busy.add(id));
    if (await attempt(context, () => context.app.api.adminVerify(id, ok)) && mounted) {
      toast(context, ok ? 'ვერიფიცირდა ✓' : 'უარყოფილია');
      setState(() => rows?.remove(x));
      context.app.people.ensure(['${x['user_id']}'], fresh: true);
      widget.onChange();
    }
    if (mounted) setState(() => busy.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, r = rows, app = context.app;
    if (r == null) return error != null ? Empty(icon: 'shield', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load) : const Center(child: CircularProgressIndicator());
    if (r.isEmpty) return const Empty(icon: 'shield', title: 'მოთხოვნები არ არის', text: 'ახალი მოთხოვნა აქ გამოჩნდება.');
    Widget fig(String? url, Profile? p, String label) => Expanded(
          child: Column(children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: url != null ? PImage(url) : (p != null ? Container(color: c.sunk, child: Center(child: Avatar(p: p, size: 80))) : Container(color: c.sunk, child: const Center(child: Text('?', style: TextStyle(fontSize: 30))))),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: c.muted, fontSize: 12.5)),
          ]),
        );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 4), child: Text('შეადარე სელფი პროფილის ფოტოს. სელფის ბმული 10 წუთი მოქმედებს.', style: TextStyle(color: c.muted))),
        for (final x in r)
          Builder(builder: (context) {
            final uid = '${x['user_id']}', p = app.people[uid] ?? Profile(id: uid, name: '…'), id = asInt(x['id']), b = busy.contains(id);
            return _Card(
              key: ValueKey('vr-$id'),
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Avatar(p: p, size: 40),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${(p.username ?? '').isNotEmpty ? '@${p.username} · ' : ''}${ago(asTime(x['created_at']))}'),
                  trailing: TextButton(onPressed: () => openPage(context, PersonScreen(uid: uid, initial: p), full: true), child: const Text('პროფილი')),
                ),
                Row(children: [fig(p.avatarUrl, p, 'პროფილი'), const SizedBox(width: 10), fig(x['signed'] as String?, null, 'სელფი')]),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  FilledButton.icon(key: ValueKey('av-ok-$id'), style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: b ? null : () => _do(x, true), icon: PIcon('check', size: 16, color: c.onAccent), label: const Text('დადასტურება')),
                  OutlinedButton.icon(key: ValueKey('av-no-$id'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: b ? null : () => _do(x, false), icon: const PIcon('x', size: 16), label: const Text('უარყოფა')),
                ]),
              ]),
            );
          }),
      ]),
    );
  }
}

// ---------- ads ----------
class _Promo extends StatefulWidget {
  const _Promo({required this.onChange, required this.pending});
  final Future<void> Function() onChange;
  final int pending;
  @override
  State<_Promo> createState() => _PromoState();
}

class _PromoState extends State<_Promo> {
  late String part = context.me.role == 'admin' ? 'mine' : 'pages';
  List<Map<String, dynamic>>? promos;
  List<({Map<String, dynamic> ad, Post? post})>? ads;
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
      if (part == 'mine') {
        final p = await app.api.adminPromos();
        if (mounted) setState(() => promos = p);
      } else {
        final a = await app.api.adsToReview();
        await app.posts.load([for (final x in a) if (x.post != null) x.post!]);
        if (mounted) setState(() => ads = a);
      }
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _edit([Map<String, dynamic>? p, String kind = 'post']) async {
    final saved = await openPage<bool>(context, PromoEditor(promo: p, kind: kind), full: true);
    if (saved == true) _load();
  }

  (String, String) _state(Map<String, dynamic> p) {
    final now = DateTime.now();
    if (p['active'] != true) return ('პაუზაზეა', 'warn');
    if (asTime(p['starts_at']).isAfter(now)) return ('იწყება ${fullDate(asTime(p['starts_at']))}', '');
    if (p['ends_at'] != null && !asTime(p['ends_at']).isAfter(now)) return ('დასრულდა', '');
    return ('აქტიურია', 'ad');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, admin = context.me.role == 'admin', app = context.app;
    final Widget body;
    if (error != null && (part == 'mine' ? promos == null : ads == null)) {
      body = Empty(icon: 'mega', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load);
    } else if (part == 'mine') {
      final r = promos;
      body = r == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(key: const ValueKey('ap-new-post'), style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: () => _edit(), icon: PIcon('plus', size: 16, color: c.onAccent), label: const Text('რეკლამა ფიდში')),
                  OutlinedButton.icon(key: const ValueKey('ap-new-story'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: () => _edit(null, 'story'), icon: const PIcon('story', size: 16), label: const Text('სარეკლამო ისტორია')),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('ფიდის რეკლამა პოსტებს შორის ჩნდება, ისტორია კი ისტორიების რიგში. „ნახა“ ადამიანებს ითვლის, თითოს ერთხელ.', style: TextStyle(color: c.muted, fontSize: 13)),
              ),
              if (r.isEmpty) const Empty(icon: 'mega', title: 'რეკლამა ჯერ არ არის', text: 'შექმენი პირველი და ყველა მომხმარებელი დაინახავს.'),
              for (final p in r)
                Builder(builder: (context) {
                  final (st, cls) = _state(p);
                  final reach = asInt(p['reach']), clicks = asInt(p['clicks']), id = asInt(p['id']);
                  final ctr = reach == 0 ? 0 : (clicks / reach * 1000).round() / 10;
                  return _Card(
                    key: ValueKey('pr-$id'),
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        PTag(p['kind'] == 'story' ? 'ისტორია' : 'ფიდში'),
                        const SizedBox(width: 6),
                        PTag(st, kind: cls),
                        const Spacer(),
                        Text(ago(asTime(p['created_at'])), style: TextStyle(color: c.muted, fontSize: 12)),
                      ]),
                      const SizedBox(height: 8),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (_img(p) case final u?) ...[
                          ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 64, height: 64, child: PImage(u))),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${p['title'] ?? p['brand'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            if ('${p['body'] ?? ''}'.isNotEmpty) Text('${p['body']}', maxLines: 3, overflow: TextOverflow.ellipsis),
                            if ('${p['link'] ?? ''}'.isNotEmpty) Text('${p['link']}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text('${thousands(reach)} ნახა · ${thousands(clicks)} დააჭირა · $ctr% დაჭერის წილი${p['ends_at'] != null ? ' · მთავრდება ${fullDate(asTime(p['ends_at']))}' : ''}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        OutlinedButton(key: ValueKey('ap-edit-$id'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34)), onPressed: () => _edit(p), child: const Text('შეცვლა')),
                        OutlinedButton(
                          key: ValueKey('ap-act-$id'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34)),
                          onPressed: () async {
                            final on = p['active'] != true;
                            if (await attempt(context, () => app.api.setPromoActive(id, on)) && context.mounted) {
                              toast(context, on ? 'რეკლამა გაეშვა' : 'რეკლამა დაპაუზდა');
                              _load();
                            }
                          },
                          child: Text(p['active'] == true ? 'პაუზა' : 'გაშვება'),
                        ),
                        OutlinedButton(
                          key: ValueKey('ap-del-$id'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), foregroundColor: c.nope),
                          onPressed: () async {
                            if (!await confirm(context, title: 'რეკლამის წაშლა', text: 'რეკლამა და მისი სტატისტიკა წაიშლება.', yes: 'წაშლა', danger: true) || !context.mounted) return;
                            if (await attempt(context, () => app.api.deletePromo(id)) && context.mounted) {
                              toast(context, 'წაიშალა');
                              _load();
                            }
                          },
                          child: const Text('წაშლა'),
                        ),
                      ]),
                    ]),
                  );
                }),
            ]);
    } else {
      final a = ads;
      final pend = [for (final x in a ?? const <({Map<String, dynamic> ad, Post? post})>[]) if (x.ad['status'] == 'pending') x];
      final act = [for (final x in a ?? const <({Map<String, dynamic> ad, Post? post})>[]) if (x.ad['status'] == 'active') x];
      Widget card(({Map<String, dynamic> ad, Post? post}) x) {
        final ad = x.ad, id = asInt(ad['id']), pg = ad['page'] is Map ? ad['page'] as Map : const {}, pending = ad['status'] == 'pending';
        return _Card(
          key: ValueKey('pad-$id'),
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                PTag(pending ? 'განსახილველი' : 'აქტიური', kind: 'ad'),
                const SizedBox(width: 8),
                Expanded(child: Text('${pg['name'] ?? 'გვერდი'}', style: const TextStyle(fontWeight: FontWeight.w800))),
                Text(pending ? 'ბიუჯეტი ${ad['budget']}' : '${ad['spent']}/${ad['budget']} ნახვა', style: TextStyle(color: c.muted, fontSize: 12.5)),
              ]),
            ),
            if (x.post != null) PostCard(post: x.post!) else Padding(padding: const EdgeInsets.all(12), child: Text('პოსტი წაშლილია', style: TextStyle(color: c.muted))),
            if (pending)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton(
                    key: ValueKey('ad-ok-$id'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                    onPressed: () async {
                      if (await attempt(context, () => app.api.reviewAd(id, true)) && context.mounted) {
                        toast(context, 'რეკლამა დამტკიცდა');
                        widget.onChange();
                        _load();
                      }
                    },
                    child: const Text('დამტკიცება'),
                  ),
                  OutlinedButton(
                    key: ValueKey('ad-no-$id'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                    onPressed: () async {
                      if (await attempt(context, () => app.api.reviewAd(id, false)) && context.mounted) {
                        toast(context, 'უარყოფილია, მონეტები დაბრუნდა');
                        widget.onChange();
                        _load();
                      }
                    },
                    child: const Text('უარყოფა (მონეტები დაბრუნდება)'),
                  ),
                ]),
              ),
          ]),
        );
      }

      body = a == null
          ? const Center(child: CircularProgressIndicator())
          : a.isEmpty
              ? const Empty(icon: 'mega', title: 'რეკლამები არ არის', text: 'ბიზნეს გვერდების რეკლამები განსახილველად აქ გამოჩნდება.')
              : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                  if (pend.isNotEmpty) SecHead('განსახილველი · ${pend.length}'),
                  for (final x in pend) card(x),
                  if (act.isNotEmpty) SecHead('აქტიური · ${act.length}'),
                  for (final x in act) card(x),
                ]);
    }
    return Column(children: [
      if (admin)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: SegmentedButton<String>(
            key: const ValueKey('ap-part'),
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(value: 'mine', label: Text('Peera-ს რეკლამა')),
              ButtonSegment(value: 'pages', label: Text('გვერდების${widget.pending > 0 ? ' · ${widget.pending}' : ''}')),
            ],
            selected: {part},
            onSelectionChanged: (v) {
              setState(() => part = v.first);
              _load();
            },
          ),
        ),
      Expanded(child: body),
    ]);
  }
}

/// Peera's own ad: in the feed or among the stories, a picture or a video, in whose name (and a logo), a title, words,
/// a link and its button, how often in the feed, from when to when. Pops true when saved.
class PromoEditor extends StatefulWidget {
  const PromoEditor({super.key, this.promo, this.kind = 'post'});
  final Map<String, dynamic>? promo;
  final String kind;
  @override
  State<PromoEditor> createState() => _PromoEditorState();
}

class _PromoEditorState extends State<PromoEditor> {
  late final p = widget.promo ?? const <String, dynamic>{};
  late String kind = '${p['kind'] ?? widget.kind}';
  late ({String url, String type, int w, int h})? media = p['media_url'] != null
      ? (url: '${p['media_url']}', type: '${p['media_type'] ?? 'image'}', w: asInt(p['w']), h: asInt(p['h']))
      : null;
  late String? logo = p['brand_url'] as String?;
  late final brand = TextEditingController(text: '${p['brand'] ?? 'Peera'}');
  late final title = TextEditingController(text: '${p['title'] ?? ''}');
  late final body = TextEditingController(text: '${p['body'] ?? ''}');
  late final link = TextEditingController(text: '${p['link'] ?? ''}');
  late final cta = TextEditingController(text: '${p['cta'] ?? ''}');
  late final every = TextEditingController(text: '${p['every'] ?? 8}');
  late DateTime starts = p['starts_at'] != null ? asTime(p['starts_at']).toLocal() : DateTime.now();
  late DateTime? ends = p['ends_at'] != null ? asTime(p['ends_at']).toLocal() : null;
  String? busy;

  bool get isNew => widget.promo == null;

  @override
  void dispose() {
    for (final x in [brand, title, body, link, cta, every]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _photo() async {
    final api = context.app.api;
    final got = await photoSource(false);
    if (got.isEmpty || !mounted) return;
    setState(() => busy = 'ფოტო იტვირთება…');
    try {
      final m = await api.uploadPhoto(await photoPrep(got.first));
      if (mounted) setState(() => media = (url: m.mid, type: 'image', w: m.w, h: m.h));
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
    if (mounted) setState(() => busy = null);
  }

  Future<void> _video() async {
    final api = context.app.api;
    String? path;
    try {
      path = await videoPicker();
    } catch (_) {}
    if (path == null || !mounted) return;
    setState(() => busy = 'ვიდეო მზადდება…');
    try {
      final v = await videoPrep(path, (_) {});
      if (!mounted) return;
      setState(() => busy = 'ვიდეო იტვირთება…');
      final m = await api.uploadVideo(v);
      if (mounted) setState(() => media = (url: m.url, type: 'video', w: m.w, h: m.h));
    } catch (e) {
      if (mounted) toast(context, e is VideoTooBig ? e.toString() : errText(e));
    }
    if (mounted) setState(() => busy = null);
  }

  Future<void> _logo() async {
    final api = context.app.api;
    final got = await photoSource(false);
    if (got.isEmpty || !mounted) return;
    setState(() => busy = 'ლოგო იტვირთება…');
    try {
      final m = await api.uploadPhoto(await photoPrep(got.first));
      if (mounted) setState(() => logo = m.small);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
    if (mounted) setState(() => busy = null);
  }

  Future<DateTime?> _when(DateTime? v) async {
    final now = DateTime.now(), at = v ?? now;
    final d = await showDatePicker(context: context, initialDate: at, firstDate: now.subtract(const Duration(days: 365)), lastDate: now.add(const Duration(days: 730)));
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(at));
    return DateTime(d.year, d.month, d.day, t?.hour ?? at.hour, t?.minute ?? at.minute);
  }

  Future<void> _save() async {
    final t = title.text.trim(), b = body.text.trim(), l = link.text.trim(), m = media;
    if (kind == 'story' && m == null) {
      toast(context, 'ისტორიას ფოტო ან ვიდეო სჭირდება');
      return;
    }
    if (t.isEmpty && b.isEmpty && m == null) {
      toast(context, 'დაწერე სათაური ან ტექსტი, ან დაამატე ფოტო');
      return;
    }
    if (!linkOk(l)) {
      toast(context, 'ბმული https://-ით ან #-ით უნდა იწყებოდეს');
      return;
    }
    final e = ends;
    if (e != null && !e.isAfter(starts)) {
      toast(context, 'დასრულება დაწყების შემდეგ უნდა იყოს');
      return;
    }
    final row = <String, dynamic>{
      'kind': kind,
      'brand': brand.text.trim().isEmpty ? 'Peera' : brand.text.trim(),
      'brand_url': logo,
      'title': t.isEmpty ? null : t,
      'body': b.isEmpty ? null : b,
      'media_url': m?.url,
      'media_type': m?.type ?? 'image',
      'w': m == null || m.w == 0 ? null : m.w,
      'h': m == null || m.h == 0 ? null : m.h,
      'link': l.isEmpty ? null : l,
      'cta': cta.text.trim().isEmpty ? null : cta.text.trim(),
      'every': (int.tryParse(every.text.trim()) ?? 8).clamp(3, 50),
      'starts_at': starts.toUtc().toIso8601String(),
      'ends_at': e?.toUtc().toIso8601String(),
    };
    setState(() => busy = 'ინახება…');
    try {
      await context.app.api.savePromo(row, id: isNew ? null : asInt(p['id']));
      if (!mounted) return;
      toast(context, isNew ? 'რეკლამა გაეშვა' : 'შენახულია');
      Navigator.of(context).pop(true);
    } catch (x) {
      if (!mounted) return;
      setState(() => busy = null);
      toast(context, errText(x));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, m = media;
    return Scaffold(
      appBar: peeraBar(context, title: isNew ? 'ახალი რეკლამა' : 'რეკლამის შეცვლა', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(
            key: const ValueKey('pe-ok'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: busy != null ? null : _save,
            child: Text(busy ?? (isNew ? 'გაშვება' : 'შენახვა')),
          ),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<String>(
          key: const ValueKey('pe-kind'),
          showSelectedIcon: false,
          segments: const [ButtonSegment(value: 'post', label: Text('ფიდში')), ButtonSegment(value: 'story', label: Text('ისტორიად'))],
          selected: {kind},
          onSelectionChanged: (v) => setState(() => kind = v.first),
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: kind == 'story' ? 9 / 16 * 1.6 : (m != null && m.w > 0 && m.h > 0 ? (m.w / m.h).clamp(.8, 1.91).toDouble() : 16 / 9),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              color: c.sunk,
              child: m == null
                  ? Center(child: Text(kind == 'story' ? 'ისტორიას ფოტო ან ვიდეო სჭირდება (9:16)' : 'ფოტო ან ვიდეო არასავალდებულოა', style: TextStyle(color: c.muted)))
                  : m.type == 'video'
                      ? const Center(child: PIcon('video', size: 40))
                      : PImage(m.url),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(key: const ValueKey('pe-photo'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)), onPressed: busy != null ? null : _photo, icon: const PIcon('image', size: 16), label: const Text('ფოტო')),
          OutlinedButton.icon(key: const ValueKey('pe-video'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)), onPressed: busy != null ? null : _video, icon: const PIcon('clips', size: 16), label: const Text('ვიდეო')),
          if (m != null) TextButton(key: const ValueKey('pe-rm'), onPressed: () => setState(() => media = null), child: const Text('მოშორება')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          GestureDetector(
            key: const ValueKey('pe-logo'),
            onTap: busy != null ? null : _logo,
            child: ClipOval(child: SizedBox(width: 46, height: 46, child: logo != null ? PImage(logo!) : Container(color: c.sunk, child: Center(child: PIcon('image', size: 18, color: c.muted))))),
          ),
          const SizedBox(width: 10),
          Expanded(child: TextField(key: const ValueKey('pe-brand'), controller: brand, maxLength: 60, decoration: const InputDecoration(labelText: 'ვისი სახელით', counterText: ''))),
        ]),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('pe-title'), controller: title, maxLength: 120, decoration: const InputDecoration(labelText: 'სათაური', hintText: 'მაგ. ახალი სასწავლო ოთახები Peera-ზე', counterText: '')),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('pe-body'), controller: body, maxLength: 1000, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'ტექსტი', counterText: '')),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('pe-link'), controller: link, maxLength: 300, decoration: const InputDecoration(labelText: 'ბმული', hintText: 'https://… ან საიტის გვერდი ქვემოთ', counterText: '')),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final (h, l) in siteLinks) ActionChip(key: ValueKey('pe-l$h'), label: Text(l), onPressed: () => setState(() => link.text = h))]),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('pe-cta'), controller: cta, maxLength: 30, decoration: const InputDecoration(labelText: 'ღილაკის ტექსტი', hintText: 'გაიგე მეტი', counterText: '')),
        if (kind == 'post') ...[
          const SizedBox(height: 10),
          TextField(key: const ValueKey('pe-every'), controller: every, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ფიდში ჩნდება ყოველ … პოსტში', helperText: '3-დან 50-მდე')),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('pe-start'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () async {
                final d = await _when(starts);
                if (d != null) setState(() => starts = d);
              },
              child: Text('დაწყება: ${fullDate(starts)}', textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('pe-end'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () async {
                final d = await _when(ends);
                if (d != null) setState(() => ends = d);
              },
              onLongPress: () => setState(() => ends = null),
              child: Text(ends == null ? 'დასრულების გარეშე' : 'დასრულება: ${fullDate(ends!)}', textAlign: TextAlign.center),
            ),
          ),
        ]),
        if (ends != null) Align(alignment: Alignment.centerRight, child: TextButton(key: const ValueKey('pe-noend'), onPressed: () => setState(() => ends = null), child: const Text('დასრულების გარეშე'))),
      ]),
    );
  }
}

// ---------- a notification to many ----------
const _audiences = {'all': 'ყველას', 'active': 'აქტიურებს (7 დღე)', 'region': 'კუთხეს', 'verified': 'ვერიფიცირებულებს', 'me': 'მხოლოდ მე'};

class _Notify extends StatefulWidget {
  const _Notify();
  @override
  State<_Notify> createState() => _NotifyState();
}

class _NotifyState extends State<_Notify> {
  final text = TextEditingController(), link = TextEditingController();
  String aud = 'all', region = homeRegions.first;
  int? n;
  List<Map<String, dynamic>>? sent;
  int _tk = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _estimate();
    _history();
  }

  @override
  void dispose() {
    text.dispose();
    link.dispose();
    super.dispose();
  }

  Future<void> _estimate() async {
    final my = ++_tk;
    try {
      final v = await context.app.api.broadcast(text: '..', aud: aud, region: aud == 'region' ? region : null, dry: true);
      if (mounted && my == _tk) setState(() => n = v);
    } catch (_) {}
  }

  Future<void> _history() async {
    final app = context.app;
    try {
      final r = await app.api.broadcasts();
      await app.people.ensure([for (final x in r) if (x['sent_by'] != null) '${x['sent_by']}']);
      if (mounted) setState(() => sent = r);
    } catch (_) {
      if (mounted) setState(() => sent = const []);
    }
  }

  Future<void> _send(String a) async {
    final t = text.text.trim(), l = link.text.trim();
    if (t.length < 2) {
      toast(context, 'დაწერე ტექსტი');
      return;
    }
    if (!linkOk(l)) {
      toast(context, 'ბმული https://-ით ან #-ით უნდა იწყებოდეს');
      return;
    }
    if (a != 'me' &&
        !await confirm(context,
            title: 'შეტყობინების გაგზავნა',
            text: '„${t.length > 80 ? t.substring(0, 80) : t}“ მიუვა ${n ?? '…'} ადამიანს (${a == 'region' ? region : _audiences[a]}). გაგზავნილს უკან ვეღარ დააბრუნებ.',
            yes: 'გაგზავნა')) {
      return;
    }
    if (!mounted) return;
    try {
      final k = await context.app.api.broadcast(text: t, link: l.isEmpty ? null : l, aud: a, region: a == 'region' ? region : null);
      if (!mounted) return;
      toast(context, a == 'me' ? 'ტესტი გამოგეგზავნა. ნახე შეტყობინებებში' : 'გაეგზავნა $k ადამიანს');
      if (a != 'me') {
        text.clear();
        link.clear();
      }
      _history();
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, h = sent;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      Text('მივა შეტყობინებებში და ტელეფონზე, ვისაც ჩართული აქვს. ნებისმიერს შეუძლია ეს ტიპი გამორთოს („სიახლეები და რეკლამა“), ამიტომ იყოს იშვიათი და საინტერესო.', style: TextStyle(color: c.muted, fontSize: 13)),
      const SizedBox(height: 10),
      TextField(
        key: const ValueKey('an-t'),
        controller: text,
        maxLength: 200,
        minLines: 3,
        maxLines: 5,
        decoration: const InputDecoration(labelText: 'ტექსტი', hintText: 'მაგ. Peera-ზე ახალი ლექციების ცხრილია: ჩაწერე შენი და კურსელებიც ნახავენ 📚'),
      ),
      const SizedBox(height: 8),
      TextField(key: const ValueKey('an-l'), controller: link, maxLength: 300, decoration: const InputDecoration(labelText: 'ბმული (არასავალდებულო)', hintText: 'https://… ან საიტის გვერდი', counterText: '')),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [for (final (hh, l) in siteLinks) ActionChip(key: ValueKey('an-l$hh'), label: Text(l), onPressed: () => setState(() => link.text = hh))]),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        key: const ValueKey('an-a'),
        initialValue: aud,
        decoration: const InputDecoration(labelText: 'ვის მიუვიდეს'),
        items: [for (final e in _audiences.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) {
          setState(() => aud = v ?? 'all');
          _estimate();
        },
      ),
      if (aud == 'region') ...[
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const ValueKey('an-r'),
          isExpanded: true,
          initialValue: region,
          decoration: const InputDecoration(labelText: 'კუთხე'),
          items: [for (final r in homeRegions) DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis))],
          onChanged: (v) {
            setState(() => region = v ?? region);
            _estimate();
          },
        ),
      ],
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          PIcon('users', size: 16, color: c.muted),
          const SizedBox(width: 6),
          Text(n == null ? '…' : 'მიიღებს $n ადამიანი', key: const ValueKey('an-n'), style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(key: const ValueKey('an-test'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => _send('me'), icon: const PIcon('bell', size: 16), label: const Text('ტესტი ჩემთვის', maxLines: 1, overflow: TextOverflow.ellipsis)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(key: const ValueKey('an-go'), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => _send(aud), icon: PIcon('send', size: 16, color: c.onAccent), label: const Text('გაგზავნა', maxLines: 1, overflow: TextOverflow.ellipsis)),
        ),
      ]),
      const SecHead('გაგზავნილი'),
      if (h == null)
        const Center(child: CircularProgressIndicator())
      else if (h.isEmpty)
        Text('ჯერ არაფერი გაგზავნილა.', style: TextStyle(color: c.muted))
      else
        for (final r in h)
          Builder(builder: (context) {
            final a = r['audience'] is Map ? r['audience'] as Map : const {};
            return ListTile(
              key: ValueKey('bc-${r['id']}'),
              contentPadding: EdgeInsets.zero,
              leading: PIcon(a['aud'] == 'me' ? 'eye' : 'bell', color: c.accent),
              title: Text('${r['text']}'),
              subtitle: Text(
                '${a['aud'] == 'region' ? a['region'] : _audiences[a['aud']] ?? ''} · ${r['sent']} ადამიანი · ${ago(asTime(r['created_at']))}${r['sent_by'] != null ? ' · ${app.people['${r['sent_by']}']?.name ?? ''}' : ''}',
              ),
            );
          }),
    ]);
  }
}

// ---------- the site: the banner and the sections ----------
class _Site extends StatefulWidget {
  const _Site();
  @override
  State<_Site> createState() => _SiteState();
}

class _SiteState extends State<_Site> {
  bool loaded = false, on = false;
  String tone = 'info';
  final text = TextEditingController(), link = TextEditingController(), cta = TextEditingController();
  Set<String> off = {};
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
    text.dispose();
    link.dispose();
    cta.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    Map<String, dynamic> m = {};
    try {
      m = await context.app.api.appSettings();
    } catch (_) {}
    if (!mounted) return;
    final b = m['banner'] is Map ? Map<String, dynamic>.from(m['banner'] as Map) : const <String, dynamic>{}, f = m['features'];
    setState(() {
      on = b['on'] == true;
      tone = '${b['tone'] ?? 'info'}';
      text.text = '${b['text'] ?? ''}';
      link.text = '${b['link'] ?? ''}';
      cta.text = '${b['cta'] ?? ''}';
      off = {if (f is Map && f['off'] is List) for (final x in f['off'] as List) '$x'};
      loaded = true;
    });
  }

  Future<void> _saveBanner() async {
    final v = {'on': on, 'text': text.text.trim(), 'link': link.text.trim(), 'cta': cta.text.trim(), 'tone': tone};
    if (on && (v['text'] as String).length < 2) {
      toast(context, 'დაწერე ბანერის ტექსტი');
      return;
    }
    if (!linkOk(v['link'] as String)) {
      toast(context, 'ბმული https://-ით ან #-ით უნდა იწყებოდეს');
      return;
    }
    final app = context.app;
    if (await attempt(context, () => app.api.setAppSetting('banner', v)) && mounted) {
      toast(context, on ? 'ბანერი ჩანს ყველასთვის' : 'ბანერი გამოირთო');
      app.home.load(force: true);
    }
  }

  Future<void> _feature(String k, String label, bool enable) async {
    final app = context.app, was = {...off};
    // the sections not shown here (the shop, the games) keep their state
    setState(() => enable ? off.remove(k) : off.add(k));
    try {
      await app.api.setAppSetting('features', {'off': [...off]});
      if (!mounted) return;
      toast(context, '$label: ${enable ? 'ჩართულია' : 'გამორთულია ყველასთვის'}');
      app.home.load(force: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => off = was);
      toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    if (!loaded) return const Center(child: CircularProgressIndicator());
    final t = text.text.trim();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      const Text('ბანერი ყველასთვის', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('ჩანს მთავარი გვერდის თავში. ვინც დახურავს, იმავე ტექსტს აღარ დაინახავს. ახალი ტექსტი ყველას ისევ გამოუჩნდება.', style: TextStyle(color: c.muted, fontSize: 13)),
      SwitchListTile(key: const ValueKey('bn-on'), contentPadding: EdgeInsets.zero, value: on, onChanged: (v) => setState(() => on = v), title: const Text('ბანერი ჩართულია')),
      TextField(key: const ValueKey('bn-t'), controller: text, maxLength: 160, minLines: 2, maxLines: 4, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'ტექსტი')),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        key: const ValueKey('bn-tone'),
        showSelectedIcon: false,
        segments: const [ButtonSegment(value: 'info', label: Text('სიახლე')), ButtonSegment(value: 'warn', label: Text('გაფრთხილება')), ButtonSegment(value: 'fest', label: Text('დღესასწაული'))],
        selected: {tone},
        onSelectionChanged: (v) => setState(() => tone = v.first),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: TextField(key: const ValueKey('bn-l'), controller: link, maxLength: 300, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'ბმული', hintText: '#study ან https://…', counterText: ''))),
        const SizedBox(width: 8),
        Expanded(child: TextField(key: const ValueKey('bn-c'), controller: cta, maxLength: 24, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'ღილაკი', hintText: 'ნახვა', counterText: ''))),
      ]),
      if (t.isNotEmpty)
        Container(
          key: const ValueKey('bn-pv'),
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tone == 'warn' ? c.nope.withValues(alpha: .12) : (tone == 'fest' ? c.gold.withValues(alpha: .16) : c.accentSoft),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            PIcon(tone == 'warn' ? 'flag' : (tone == 'fest' ? 'gift' : 'mega'), size: 20, color: tone == 'warn' ? c.nope : c.accent),
            const SizedBox(width: 8),
            Expanded(child: Text(t)),
            if (link.text.trim().isNotEmpty) PTag(cta.text.trim().isEmpty ? 'ნახვა' : cta.text.trim(), kind: 'ad'),
          ]),
        ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(key: const ValueKey('bn-save'), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: _saveBanner, icon: PIcon('check', size: 16, color: c.onAccent), label: const Text('ბანერის შენახვა')),
      ),
      const SizedBox(height: 18),
      const Text('განყოფილებები', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('გამორთული განყოფილება მომხმარებლებს მენიუდან ქრება. შენ, როგორც ადმინისტრატორი, ყველაფერს მაინც ხედავ.', style: TextStyle(color: c.muted, fontSize: 13)),
      for (final (k, l) in siteFeatures)
        SwitchListTile(key: ValueKey('feat-$k'), contentPadding: EdgeInsets.zero, value: !off.contains(k), onChanged: (v) => _feature(k, l, v), title: Text(l)),
    ]);
  }
}

// ---------- pages ----------
class _Pages extends StatefulWidget {
  const _Pages();
  @override
  State<_Pages> createState() => _PagesState();
}

class _PagesState extends State<_Pages> {
  final q = TextEditingController();
  List<Map<String, dynamic>>? rows;
  Object? error;
  Timer? _wait;
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
    final app = context.app;
    try {
      final r = await app.api.adminPages(q.text.trim());
      await app.people.ensure([for (final x in r) if (x['owner'] != null) '${x['owner']}']);
      if (mounted) {
        setState(() {
          rows = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, r = rows, app = context.app;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: TextField(
          key: const ValueKey('apg-q'),
          controller: q,
          textInputAction: TextInputAction.search,
          onChanged: (_) {
            _wait?.cancel();
            _wait = Timer(const Duration(milliseconds: 350), _load);
          },
          onSubmitted: (_) => _load(),
          decoration: InputDecoration(hintText: 'გვერდის სახელი', isDense: true, prefixIcon: Padding(padding: const EdgeInsets.all(10), child: PIcon('search', size: 18, color: c.muted))),
        ),
      ),
      Expanded(
        child: r == null
            ? (error != null ? Empty(icon: 'note', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load) : const Center(child: CircularProgressIndicator()))
            : r.isEmpty
                ? const Empty(icon: 'note', title: 'გვერდები არ არის')
                : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                    for (final g in r)
                      ListTile(
                        key: ValueKey('apg-${g['id']}'),
                        leading: BoxPic(url: g['avatar_url'] as String?, name: '${g['name']}', hue: asInt(g['hue'], 200), size: 44),
                        title: Row(children: [
                          Flexible(child: Text('${g['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                          if (g['verified'] == true) const Verified(size: 14),
                        ]),
                        subtitle: Text('${g['kind'] == 'business' ? 'ბიზნესი' : 'არხი'} · ${app.people['${g['owner']}']?.name ?? ''}'),
                        onTap: () => openPage(context, PageScreen(id: asInt(g['id'])), full: true),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          TextButton(
                            key: ValueKey('apv-${g['id']}'),
                            onPressed: () async {
                              final v = g['verified'] != true;
                              if (await attempt(context, () => app.api.verifyPage(asInt(g['id']), v)) && context.mounted) {
                                toast(context, v ? 'გვერდი ვერიფიცირდა' : 'ვერიფიკაცია მოიხსნა');
                                _load();
                              }
                            },
                            child: Text(g['verified'] == true ? 'მოხსნა' : 'ვერიფიკაცია'),
                          ),
                          IconBtn('trash', key: ValueKey('apd-${g['id']}'), label: 'წაშლა', size: 20, color: c.nope, onTap: () async {
                            if (!await confirm(context, title: 'გვერდის წაშლა', text: '„${g['name']}“ და მისი პოსტები წაიშლება.', yes: 'წაშლა', danger: true) || !context.mounted) return;
                            if (await attempt(context, () => app.api.deletePage(asInt(g['id']))) && context.mounted) {
                              toast(context, 'წაიშალა');
                              _load();
                            }
                          }),
                        ]),
                      ),
                  ]),
      ),
    ]);
  }
}

// ---------- masked words ----------
class _Words extends StatefulWidget {
  const _Words();
  @override
  State<_Words> createState() => _WordsState();
}

class _WordsState extends State<_Words> {
  List<String>? words;
  final f = TextEditingController();
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
    f.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final w = await context.app.api.badWords();
      if (mounted) setState(() => words = w);
    } catch (e) {
      if (mounted) {
        setState(() => words ??= []);
        toast(context, errText(e));
      }
    }
  }

  Future<void> _add() async {
    final w = f.text.trim().toLowerCase();
    if (w.length < 2) {
      toast(context, 'მინიმუმ 2 ასო');
      return;
    }
    if (await attempt(context, () => context.app.api.addBadWord(w)) && mounted) {
      f.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, w = words;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      Text(
        'ჩამოთვლილი სიტყვები პოსტებსა და კომენტარებში ავტომატურად იცვლება („ც***“). სიტყვა ფუძედაც მუშაობს: ჩაწერე ის ნაწილი, რომლითაც ყველა ფორმა იწყება. პირად მიმოწერაზე ფილტრი არ მოქმედებს.',
        style: TextStyle(color: c.muted, fontSize: 13),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: TextField(key: const ValueKey('bw-i'), controller: f, maxLength: 40, onSubmitted: (_) => _add(), decoration: const InputDecoration(hintText: 'სიტყვა ან ფუძე', counterText: '', isDense: true))),
        const SizedBox(width: 8),
        FilledButton(key: const ValueKey('bw-add'), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: _add, child: const Text('დამატება')),
      ]),
      const SizedBox(height: 12),
      if (w == null)
        const Center(child: CircularProgressIndicator())
      else if (w.isEmpty)
        Text('სია ცარიელია.', style: TextStyle(color: c.muted))
      else
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final x in w)
            InputChip(
              key: ValueKey('bw-$x'),
              label: Text(x),
              deleteButtonTooltipMessage: 'წაშლა',
              onDeleted: () async {
                if (await attempt(context, () => context.app.api.deleteBadWord(x)) && mounted) setState(() => words?.remove(x));
              },
            ),
        ]),
      const SizedBox(height: 14),
      Text(
        'ასევე ავტომატურად: ერთი ადამიანი წუთში 8 კომენტარზე, საათში 15 პოსტზე და წუთში 30 მესიჯზე მეტს ვერ წერს; ერთი და იგივე ტექსტი ბევრგან ჩერდება; ახალი ანგარიში (24 საათამდე) ბმულებს შეზღუდულად აზიარებს; 3 სხვადასხვა საჩივრის შემდეგ პოსტი ან კომენტარი იმალება, სანამ მოდერატორი ნახავს.',
        style: TextStyle(color: c.muted, fontSize: 12.5),
      ),
    ]);
  }
}

// ---------- the errors from people's phones ----------
class _Errors extends StatefulWidget {
  const _Errors();
  @override
  State<_Errors> createState() => _ErrorsState();
}

class _ErrorsState extends State<_Errors> {
  List<({Map<String, dynamic> r, int n, Set<String> u, DateTime last})>? groups;
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
      final rows = await context.app.api.clientErrors();
      final g = <String, ({Map<String, dynamic> r, int n, Set<String> u, DateTime last})>{};
      for (final r in rows) {
        final k = '${r['msg']}|${r['src']}|${r['line'] ?? 0}';
        final x = g[k];
        final at = asTime(r['created_at']);
        g[k] = (
          r: x?.r ?? r,
          n: (x?.n ?? 0) + 1,
          u: {...?x?.u, if (r['user_id'] != null) '${r['user_id']}'},
          last: x == null || at.isAfter(x.last) ? at : x.last,
        );
      }
      if (!mounted) return;
      setState(() {
        groups = [...g.values]..sort((a, b) => b.n != a.n ? b.n.compareTo(a.n) : b.last.compareTo(a.last));
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  String _dev(Object? ua) {
    final s = '${ua ?? ''}';
    if (RegExp('iPhone|iPad').hasMatch(s)) return 'iPhone';
    if (s.contains('Android')) return 'Android';
    if (s.contains('Windows')) return 'Windows';
    if (s.contains('Mac OS')) return 'Mac';
    return 'სხვა';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, g = groups, admin = context.me.role == 'admin';
    if (g == null) return error != null ? Empty(icon: 'flag', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load) : const Center(child: CircularProgressIndicator());
    if (g.isEmpty) return const Empty(icon: 'check', title: 'შეცდომები არ არის', text: 'როცა ვინმეს ტელეფონზე რამე გაფუჭდება, აქ გამოჩნდება.');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 4), child: Text('ბოლო 14 დღის შეცდომები ხალხის ტელეფონებიდან. ერთნაირი ერთად ჩანს, ყველაზე ხშირი ზემოთაა.', style: TextStyle(color: c.muted, fontSize: 13))),
        for (var i = 0; i < g.length; i++)
          ExpansionTile(
            key: ValueKey('err-$i'),
            title: Text('${g[i].r['msg']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text('${g[i].n}-ჯერ · ${g[i].u.length} ადამიანი · ${ago(g[i].last)} · ${_dev(g[i].r['ua'])}${'${g[i].r['page'] ?? ''}'.isNotEmpty ? ' · ${g[i].r['page']}' : ''}', style: TextStyle(color: c.muted, fontSize: 12)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                '${g[i].r['src'] ?? ''}${g[i].r['line'] != null ? ':${g[i].r['line']}:${g[i].r['col'] ?? 0}' : ''}\n${g[i].r['stack'] ?? ''}\nვერსია ${g[i].r['ver'] ?? '?'}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              if (admin)
                TextButton.icon(
                  key: ValueKey('err-del-$i'),
                  onPressed: () async {
                    if (await attempt(context, () => context.app.api.deleteClientErrors('${g[i].r['msg']}', g[i].r['src'] as String?)) && context.mounted) {
                      toast(context, 'წაიშალა');
                      _load();
                    }
                  },
                  icon: const PIcon('check', size: 16),
                  label: const Text('მოგვარდა, წაშლა'),
                ),
            ],
          ),
      ]),
    );
  }
}

// ---------- the team's log ----------
const _logWords = {
  'ban': 'შეზღუდა', 'unban': 'შეზღუდვა მოუხსნა', 'role': 'როლი შეცვალა', 'verify': 'ვერიფიკაცია დაუდასტურა', 'unverify': 'ვერიფიკაცია მოუხსნა', //
  'hide': 'დამალა', 'unhide': 'ისევ გამოაჩინა', 'delete': 'წაშალა', 'coins': 'მონეტები', 'message': 'მისწერა გუნდის სახელით', 'broadcast': 'შეტყობინება გაგზავნა',
  'settings': 'შეცვალა საიტის პარამეტრები', 'promo_new': 'შექმნა რეკლამა', 'promo_on': 'გაუშვა რეკლამა', 'promo_off': 'დააპაუზა რეკლამა', 'promo_del': 'წაშალა რეკლამა',
  'coin_rule': 'შეცვალა მონეტის წესი', 'payout_paid': 'გადაიხადა გატანა', 'payout_rejected': 'უარყო გატანა',
};
const _logTables = {
  'posts': 'პოსტი', 'comments': 'კომენტარი', 'stories': 'ისტორია', 'groups': 'ჯგუფი', 'pages': 'გვერდი', 'events': 'ღონისძიება', 'listings': 'განცხადება', //
  'jobs': 'ვაკანსია', 'places': 'ადგილი', 'help_requests': 'დახმარება', 'albums': 'ალბომი', 'rides': 'მგზავრობა',
};
bool _isUid(Object? x) => RegExp(r'^[0-9a-f-]{36}$').hasMatch('${x ?? ''}') || RegExp(r'^u\d+$').hasMatch('${x ?? ''}');

class _Log extends StatefulWidget {
  const _Log();
  @override
  State<_Log> createState() => _LogState();
}

class _LogState extends State<_Log> {
  List<Map<String, dynamic>>? rows;
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
      final r = await app.api.adminLog();
      await app.people.ensure([
        for (final x in r) ...[
          if (x['actor'] != null) '${x['actor']}',
          if (_isUid(x['target'])) '${x['target']}',
          if (x['detail'] is Map && _isUid((x['detail'] as Map)['owner'])) '${(x['detail'] as Map)['owner']}',
        ],
      ]);
      if (mounted) {
        setState(() {
          rows = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  String _line(Map<String, dynamic> r) {
    final app = context.app, d = r['detail'] is Map ? Map<String, dynamic>.from(r['detail'] as Map) : <String, dynamic>{}, tg = '${r['target'] ?? ''}', a = '${r['action']}';
    String name(String u) => app.people[u]?.name ?? '…';
    final what = _logWords[a] ?? a;
    var obj = '';
    if (a == 'delete') {
      final t = tg.split(':').first;
      obj = '${_logTables[t] ?? t}${_isUid(d['owner']) ? ' · ${name('${d['owner']}')}' : ''}${d['text'] != null ? ' · „${'${d['text']}'.length > 60 ? '${d['text']}'.substring(0, 60) : d['text']}“' : ''}';
    } else if (a == 'hide' || a == 'unhide') {
      final p = tg.split(':');
      obj = '${targetNames[p.first] ?? p.first} #${p.length > 1 ? p[1] : ''}';
    } else if (a == 'message') {
      obj = '${name(tg)} · „${'${d['text'] ?? ''}'.length > 60 ? '${d['text']}'.substring(0, 60) : d['text'] ?? ''}“';
    } else if (a == 'broadcast') {
      obj = '„${'${d['text'] ?? ''}'.length > 60 ? '${d['text']}'.substring(0, 60) : d['text'] ?? ''}“ · ${d['sent'] ?? 0} ადამიანს';
    } else if (a == 'role') {
      obj = '${d['name'] ?? name(tg)} · ${roleNames[d['from']] ?? d['from']} → ${roleNames[d['to']] ?? d['to']}';
    } else if (a == 'settings') {
      obj = switch (tg) { 'banner' => 'ბანერი', 'features' => 'განყოფილებები', _ => tg };
    } else if (a.startsWith('promo')) {
      obj = d['title'] != null ? '„${d['title']}“' : '';
    } else if (_isUid(tg)) {
      obj = '${d['name'] ?? name(tg)}';
    }
    final who = r['actor'] != null ? name('${r['actor']}') : 'სისტემა';
    return '$who $what${obj.isNotEmpty ? ': $obj' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, r = rows, app = context.app;
    if (r == null) return error != null ? Empty(icon: 'note', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load) : const Center(child: CircularProgressIndicator());
    if (r.isEmpty) return const Empty(icon: 'note', title: 'ჟურნალი ცარიელია', text: 'აქ ჩაიწერება გუნდის ყველა მნიშვნელოვანი მოქმედება.');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 4), child: Text('ბოლო 100 მოქმედება. ჟურნალს ვერავინ შეცვლის, მას ბაზა თავად წერს.', style: TextStyle(color: c.muted, fontSize: 13))),
        for (final x in r)
          ListTile(
            key: ValueKey('lg-${x['id']}'),
            leading: x['actor'] != null && app.people['${x['actor']}'] != null
                ? Avatar(p: app.people['${x['actor']}']!, size: 36)
                : CircleAvatar(radius: 18, backgroundColor: c.sunk, child: PIcon('shield', size: 18, color: c.muted)),
            title: Text(_line(x)),
            subtitle: Text(ago(asTime(x['created_at']))),
          ),
      ]),
    );
  }
}

