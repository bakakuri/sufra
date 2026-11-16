// A channel's and a business's page as the big networks keep theirs: the business's contacts and opening hours
// ("ახლა ღიაა"), its main button, reviews with stars, the numbers for its admins, its co-admins (an admin edits the
// page, an editor writes as it) and how much a follower is told (every post, only the pinned ones, nothing).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../chat/chat_screen.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/comments_sheet.dart';
import '../people/albums.dart';
import '../people/person_screen.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/translate.dart';
import '../ui/widgets.dart';
import 'community_ui.dart';

const weekDays = ['ორშაბათი', 'სამშაბათი', 'ოთხშაბათი', 'ხუთშაბათი', 'პარასკევი', 'შაბათი', 'კვირა'];

/// a day's hours (1 Monday … 7 Sunday): opening and closing ("09:00", "18:00"), or null when closed
(String, String)? dayHours(Map hours, int day) {
  final v = hours['$day'];
  return v is List && v.length == 2 ? ('${v[0]}', '${v[1]}') : null;
}

int _min(String hm) {
  final p = hm.split(':');
  return (int.tryParse(p.first) ?? 0) * 60 + (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
}

/// open now, and the line that says so ("ღიაა · 19:00-მდე", "დაკეტილია · გაიხსნება ხვალ 09:00"); null without hours
(bool, String)? openNow(Map hours, DateTime now) {
  if (!hours.values.any((v) => v is List)) return null;
  final t = now.hour * 60 + now.minute;
  // last night's hours that go past midnight
  final y = dayHours(hours, now.subtract(const Duration(days: 1)).weekday);
  if (y != null && _min(y.$2) <= _min(y.$1) && t < _min(y.$2)) return (true, 'ღიაა · ${y.$2}-მდე');
  final d = dayHours(hours, now.weekday);
  if (d != null) {
    final a = _min(d.$1), b = _min(d.$2);
    final overnight = b <= a;
    if (t >= a && (overnight || t < b)) return (true, 'ღიაა · ${d.$2}-მდე');
    if (t < a) return (false, 'დაკეტილია · გაიხსნება ${d.$1}-ზე');
  }
  for (var i = 1; i <= 7; i++) {
    final day = now.add(Duration(days: i)), n = dayHours(hours, day.weekday);
    if (n != null) return (false, 'დაკეტილია · გაიხსნება ${i == 1 ? 'ხვალ' : weekDays[day.weekday - 1]} ${n.$1}-ზე');
  }
  return (false, 'დაკეტილია');
}

Map<String, dynamic> _hoursOf(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// The page's main button: write to it, call it, open its site (or nothing).
Widget? pageActionButton(BuildContext context, Map<String, dynamic> p) {
  final c = context.pc, act = '${p['action'] ?? 'msg'}', phone = '${p['phone'] ?? ''}'.trim(), site = '${p['website'] ?? ''}'.trim();
  var icon = '', label = '';
  VoidCallback? go;
  if (act == 'call' && phone.isNotEmpty) {
    (icon, label) = ('phone', 'დარეკვა');
    go = () => launchUrl(Uri.parse('tel:${phone.replaceAll(' ', '')}'));
  } else if (act == 'site' && site.isNotEmpty) {
    (icon, label) = ('globe', 'საიტზე გადასვლა');
    go = () => launchUrl(Uri.parse(site), mode: LaunchMode.externalApplication);
  } else if (act == 'msg') {
    (icon, label) = ('msg', 'მიწერა');
    go = () => _write(context, '${p['owner']}');
  }
  if (go == null || p['owner'] == context.me.id) return null;
  return FilledButton.icon(
    key: const ValueKey('p-act'),
    style: FilledButton.styleFrom(minimumSize: const Size(0, 42), backgroundColor: c.vine),
    onPressed: go,
    icon: PIcon(icon, size: 17, color: Colors.white),
    label: Text(label),
  );
}

Future<void> _write(BuildContext context, String owner) async {
  try {
    final conv = await context.app.api.startDm(owner);
    if (context.mounted) await openChat(context, conv);
  } catch (e) {
    if (context.mounted) toast(context, errText(e));
  }
}

/// How much a follower is told; 'unfollow' to stop following. Null when nothing was chosen.
Future<String?> pageNotifySheet(BuildContext context, String now) => showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) {
        final c = s.pc;
        Widget opt(String k, String icon, String t, String sub) => ListTile(
              key: ValueKey('pn-$k'),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: now == k ? c.accentSoft : c.sunk, shape: BoxShape.circle),
                child: PIcon(icon, size: 18, color: now == k ? c.accent : c.ink),
              ),
              title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(sub, style: TextStyle(color: c.muted, fontSize: 13)),
              trailing: now == k ? PIcon('check', size: 20, color: c.accent) : null,
              onTap: () => Navigator.of(s).pop(k),
            );
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('შეტყობინებები ამ გვერდიდან', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            opt('all', 'bell', 'ყველა პოსტი', 'ყოველ ახალ პოსტზე გაცნობებთ'),
            opt('highlights', 'pin', 'მხოლოდ მთავარი', 'როცა გვერდი პოსტს მიამაგრებს'),
            opt('off', 'mute', 'გამორთული', 'პოსტები ფიდში მაინც გამოჩნდება'),
            const Divider(height: 18),
            ListTile(
              key: const ValueKey('pn-unfollow'),
              leading: Padding(padding: const EdgeInsets.all(8), child: PIcon('x', size: 18, color: c.nope)),
              title: Text('გამოწერის გაუქმება', style: TextStyle(color: c.nope, fontWeight: FontWeight.w700)),
              onTap: () => Navigator.of(s).pop('unfollow'),
            ),
            const SizedBox(height: 6),
          ]),
        );
      },
    );

/// What a page is: its words, and for a business where it is, its phone and site, and when it is open.
class PageAbout extends StatefulWidget {
  const PageAbout({super.key, required this.p, required this.count});
  final Map<String, dynamic> p;
  final int count;
  @override
  State<PageAbout> createState() => _PageAboutState();
}

class _PageAboutState extends State<PageAbout> {
  bool week = false;

  @override
  Widget build(BuildContext context) {
    final c = context.pc, p = widget.p, desc = '${p['description'] ?? ''}'.trim();
    final addr = '${p['address'] ?? ''}'.trim(), phone = '${p['phone'] ?? ''}'.trim(), site = '${p['website'] ?? ''}'.trim();
    final hours = _hoursOf(p['hours']), now = DateTime.now(), open = openNow(hours, now);
    Widget row(String key, String icon, String text, {String? sub, VoidCallback? onTap, Color? color, Widget? trailing}) => InkWell(
          key: ValueKey(key),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: (color ?? c.accent).withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
                child: PIcon(icon, size: 17, color: color ?? c.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                  if (sub != null) Text(sub, style: TextStyle(color: c.muted, fontSize: 12.5)),
                ]),
              ),
              if (trailing != null) trailing,
            ]),
          ),
        );
    final items = <Widget>[
      if (desc.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: TranslatableBody(desc)),
      row('pa-kind', p['kind'] == 'business' ? 'store' : 'mega', p['kind'] == 'business' ? 'ბიზნესი' : 'არხი',
          sub: [if ('${p['category'] ?? ''}'.isNotEmpty) '${p['category']}', '${widget.count} გამომწერი'].join(' · ')),
      if (open != null)
        row('pa-hours', 'clock', open.$1 ? 'ახლა ღიაა' : 'ახლა დაკეტილია',
            sub: open.$2.split(' · ').skip(1).join(' · '),
            color: open.$1 ? c.vine : c.nope,
            onTap: () => setState(() => week = !week),
            trailing: AnimatedRotation(turns: week ? .25 : 0, duration: const Duration(milliseconds: 220), child: PIcon('chev', size: 18, color: c.muted))),
      if (open != null)
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: !week
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(64, 0, 16, 8),
                  child: Column(children: [
                    for (var d = 1; d <= 7; d++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Expanded(
                            child: Text(weekDays[d - 1], style: TextStyle(fontWeight: d == now.weekday ? FontWeight.w800 : FontWeight.w500)),
                          ),
                          Text(
                            dayHours(hours, d) == null ? 'დაკეტილია' : '${dayHours(hours, d)!.$1} – ${dayHours(hours, d)!.$2}',
                            style: TextStyle(color: dayHours(hours, d) == null ? c.muted : c.ink, fontWeight: d == now.weekday ? FontWeight.w800 : FontWeight.w500),
                          ),
                        ]),
                      ),
                  ]),
                ),
        ),
      if (addr.isNotEmpty)
        row('pa-addr', 'map', addr,
            sub: 'რუკაზე ნახვა',
            onTap: () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}'), mode: LaunchMode.externalApplication)),
      if (phone.isNotEmpty) row('pa-phone', 'phone', phone, sub: 'დარეკვა', onTap: () => launchUrl(Uri.parse('tel:${phone.replaceAll(' ', '')}'))),
      if (site.isNotEmpty)
        row('pa-site', 'globe', site.replaceFirst(RegExp(r'^https?://'), ''), sub: 'ვებსაიტი', onTap: () => launchUrl(Uri.parse(site), mode: LaunchMode.externalApplication)),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: cardLook(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < items.length; i++) Rise(order: i, child: items[i])]),
    );
  }
}

/// A business's reviews: the average and how the stars fall, mine to write or change, and everyone's.
class PageReviews extends StatefulWidget {
  const PageReviews({super.key, required this.id, required this.canReview, this.onChanged});
  final int id;

  /// not for the page's own people
  final bool canReview;
  final VoidCallback? onChanged;
  @override
  State<PageReviews> createState() => _PageReviewsState();
}

class _PageReviewsState extends State<PageReviews> {
  List<Map<String, dynamic>>? list;
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
      final r = await app.api.pageReviews(widget.id);
      await app.people.ensure(r.map((x) => '${x['author']}'));
      if (mounted) setState(() => list = r);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _write(Map<String, dynamic>? mine) async {
    final app = context.app;
    final r = await showModalBottomSheet<(String, int, String)>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => _ReviewSheet(mine: mine),
    );
    if (r == null || !mounted) return;
    final del = r.$1 == 'del';
    final ok = await attempt(context, () => del ? app.api.deletePageReview(widget.id) : app.api.reviewPage(widget.id, r.$2, r.$3));
    if (!ok || !mounted) return;
    toast(context, del ? 'შეფასება წაიშალა' : 'მადლობა შეფასებისთვის ⭐');
    _load();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, l = list, me = context.me.id, app = context.app;
    if (l == null) {
      return error != null
          ? Empty(icon: 'star', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
          : const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()));
    }
    final mine = l.where((r) => r['author'] == me).firstOrNull;
    final avg = l.isEmpty ? 0.0 : l.fold<int>(0, (s, r) => s + asInt(r['rating'])) / l.length;
    final by = [for (var s = 5; s >= 1; s--) l.where((r) => asInt(r['rating']) == s).length];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Rise(
        order: 0,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          padding: const EdgeInsets.all(16),
          decoration: cardLook(context),
          child: Row(children: [
            Column(children: [
              Text(l.isEmpty ? '–' : avg.toStringAsFixed(1), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 1)),
              const SizedBox(height: 4),
              Stars(avg, size: 15),
              const SizedBox(height: 4),
              Text('${l.length} შეფასება', style: TextStyle(color: c.muted, fontSize: 12.5)),
            ]),
            const SizedBox(width: 18),
            Expanded(
              child: Column(children: [
                for (var i = 0; i < 5; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      SizedBox(width: 14, child: Text('${5 - i}', style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: l.isEmpty ? 0 : by[i] / l.length),
                            duration: Duration(milliseconds: 500 + i * 90),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 7, backgroundColor: c.sunk, color: c.gold),
                          ),
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
      ),
      if (widget.canReview)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: OutlinedButton.icon(
            key: const ValueKey('rv-write'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            onPressed: () => _write(mine),
            icon: PIcon(mine == null ? 'star' : 'edit', size: 17, color: c.gold),
            label: Text(mine == null ? 'შეფასების დაწერა' : 'ჩემი შეფასების შეცვლა'),
          ),
        ),
      if (l.isEmpty)
        const Empty(icon: 'star', title: 'შეფასებები ჯერ არ არის', text: 'იყავი პირველი, ვინც გამოცდილებას გაუზიარებს სხვებს.')
      else
        for (var i = 0; i < l.length; i++)
          Builder(builder: (context) {
            final r = l[i], u = '${r['author']}', p = app.people[u] ?? Profile(id: u, name: '…'), body = '${r['body'] ?? ''}'.trim();
            return Rise(
              order: i + 1,
              child: Container(
                key: ValueKey('rv-${r['id']}'),
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: cardLook(context, radius: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    GestureDetector(onTap: () => openPage(context, PersonScreen(uid: u, initial: p)), child: Avatar(p: p, size: 36)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        NameLine(p, size: 14.5),
                        Row(children: [
                          Stars(asInt(r['rating']).toDouble(), size: 13),
                          const SizedBox(width: 6),
                          Flexible(child: Text(ago(asTime(r['created_at'])), maxLines: 1, style: TextStyle(color: c.muted, fontSize: 12))),
                        ]),
                      ]),
                    ),
                  ]),
                  if (body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(body, style: const TextStyle(height: 1.4))),
                ]),
              ),
            );
          }),
    ]);
  }
}

/// Writing a review (or changing mine): the stars, a few words; pops what to do ('send' or 'del'), the stars, the words.
class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({this.mine});
  final Map<String, dynamic>? mine;
  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late int stars = asInt(widget.mine?['rating'], 0);
  late final body = TextEditingController(text: '${widget.mine?['body'] ?? ''}');

  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, mine = widget.mine;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(mine == null ? 'შენი შეფასება' : 'შეფასების შეცვლა', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        StarPick(value: stars, onChanged: (v) => setState(() => stars = v)),
        const SizedBox(height: 6),
        Text(const ['შეეხე ვარსკვლავებს', 'ცუდი', 'ასე რა', 'ნორმალური', 'კარგი', 'შესანიშნავი'][stars],
            textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('rv-body'),
          controller: body,
          maxLength: 1000,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'რა მოგეწონა, რა გააუმჯობესონ (არასავალდებულო)', counterText: ''),
        ),
        const SizedBox(height: 10),
        FilledButton(
          key: const ValueKey('rv-send'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: stars == 0 ? null : () => Navigator.of(context).pop(('send', stars, body.text.trim())),
          child: const Text('გამოქვეყნება'),
        ),
        if (mine != null)
          TextButton(
            key: const ValueKey('rv-del'),
            onPressed: () => Navigator.of(context).pop(('del', 0, '')),
            child: Text('შეფასების წაშლა', style: TextStyle(color: c.nope)),
          ),
      ]),
    );
  }
}

/// The page's numbers for its owner and admins: followers and how they grew, posts, reactions, comments, the best posts.
class PageStatsScreen extends StatefulWidget {
  const PageStatsScreen({super.key, required this.id, required this.name});
  final int id;
  final String name;
  @override
  State<PageStatsScreen> createState() => _PageStatsScreenState();
}

class _PageStatsScreenState extends State<PageStatsScreen> {
  Map<String, dynamic>? s;
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
      final r = await context.app.api.pageStats(widget.id);
      if (mounted) setState(() => s = r);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = s;
    final top = x == null ? const <Map<String, dynamic>>[] : [for (final t in (x['top'] as List? ?? const [])) Map<String, dynamic>.from(t as Map)];
    return Scaffold(
      appBar: peeraBar(context, title: 'სტატისტიკა'),
      body: x == null
          ? (error != null ? Empty(icon: 'poll', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text('${widget.name} · ბოლო 30 დღე', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
                ),
                StatGrid(tiles: [
                  StatTile(key: const ValueKey('ps-followers'), icon: 'users', label: 'გამომწერი', value: asInt(x['followers']), plus: asInt(x['new7']), order: 0),
                  StatTile(icon: 'uadd', label: 'ახალი გამომწერი', value: asInt(x['new30']), order: 1),
                  StatTile(icon: 'edit', label: 'პოსტი', value: asInt(x['posts30']), order: 2),
                  StatTile(icon: 'heart', label: 'რეაქცია', value: asInt(x['reactions30']), order: 3),
                  StatTile(icon: 'comment', label: 'კომენტარი', value: asInt(x['comments30']), order: 4),
                  StatTile(
                    icon: 'star',
                    label: 'რეაქცია პოსტზე',
                    value: asInt(x['posts30']) == 0 ? 0 : (asInt(x['reactions30']) / asInt(x['posts30'])).round(),
                    order: 5,
                  ),
                ]),
                DayBars(days: [for (final d in (x['daily'] as List? ?? const [])) Map<String, dynamic>.from(d as Map)], title: 'ახალი გამომწერები დღეების მიხედვით'),
                if (top.isNotEmpty) ...[
                  const SectionHead('საუკეთესო პოსტები'),
                  for (final t in top)
                    ListTile(
                      key: ValueKey('ps-top-${t['id']}'),
                      leading: PIcon('trophy', color: c.gold),
                      title: Text('${t['body'] ?? ''}'.trim().isEmpty ? 'ფოტო' : '${t['body']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${t['reactions']} რეაქცია · ${t['comments']} კომენტარი', style: TextStyle(color: c.muted)),
                      onTap: () async {
                        final app = context.app;
                        final p = await app.api.post(asInt(t['id']));
                        if (p == null || !context.mounted) return;
                        await app.posts.load([p]);
                        if (context.mounted) await openPost(context, p);
                      },
                    ),
                ],
              ]),
            ),
    );
  }
}

/// The page's co-admins: the owner adds friends as admins (they edit the page and write as it) or editors (they only
/// write as it), changes or takes it back; one of them may step down.
class PageAdminsScreen extends StatefulWidget {
  const PageAdminsScreen({super.key, required this.id, required this.owner, required this.role});
  final int id;
  final String owner;

  /// what I am on the page
  final String role;
  @override
  State<PageAdminsScreen> createState() => _PageAdminsScreenState();
}

class _PageAdminsScreenState extends State<PageAdminsScreen> {
  List<Map<String, dynamic>>? list;
  Object? error;
  bool _started = false;

  bool get isOwner => widget.role == 'owner';

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
      final r = await app.api.pageAdmins(widget.id);
      await app.people.ensure([widget.owner, ...r.map((x) => '${x['user_id']}')]);
      if (mounted) setState(() => list = r);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<String?> _role(String now) => showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        backgroundColor: context.pc.surface,
        builder: (s) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final (k, t, d) in const [
              ('admin', 'ადმინი', 'არედაქტირებს გვერდს, წერს მისი სახელით, ხედავს სტატისტიკას'),
              ('editor', 'რედაქტორი', 'წერს და აქვეყნებს პოსტებს გვერდის სახელით'),
            ])
              ListTile(
                key: ValueKey('pa-role-$k'),
                leading: PIcon(k == 'admin' ? 'shield' : 'edit', color: s.pc.accent),
                title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(d, style: TextStyle(color: s.pc.muted, fontSize: 13)),
                trailing: now == k ? PIcon('check', color: s.pc.accent) : null,
                onTap: () => Navigator.of(s).pop(k),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      );

  Future<void> _add() async {
    final app = context.app;
    final picked = await pickFriends(context, title: 'ვინ მართოს გვერდი', action: 'დამატება', skip: {widget.owner, ...?list?.map((x) => '${x['user_id']}')});
    if (picked == null || picked.isEmpty || !mounted) return;
    final role = await _role('editor');
    if (role == null || !mounted) return;
    final ok = await attempt(context, () async {
      for (final u in picked) {
        await app.api.addPageAdmin(widget.id, u, role);
      }
    });
    if (!ok || !mounted) return;
    toast(context, picked.length == 1 ? 'დაემატა' : 'დაემატნენ');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, me = context.me.id, l = list;
    Widget person(String u, String role, {Map<String, dynamic>? r}) {
      final p = app.people[u] ?? Profile(id: u, name: '…');
      final label = const {'owner': 'მფლობელი', 'admin': 'ადმინი', 'editor': 'რედაქტორი'}[role] ?? role;
      return ListTile(
        key: ValueKey('pam-$u'),
        leading: Avatar(p: p, size: 42),
        title: NameLine(p, size: 15),
        subtitle: Text(label, style: TextStyle(color: role == 'owner' ? c.gold : c.muted, fontWeight: FontWeight.w600)),
        onTap: () => openPage(context, PersonScreen(uid: u, initial: p)),
        trailing: r == null
            ? null
            : isOwner
                ? IconBtn('more', key: ValueKey('pa-more-$u'), label: 'მეტი', color: c.muted, onTap: () async {
                    await showChoices(context, [
                      SheetItem('shield', 'როლის შეცვლა', () async {
                        final nr = await _role(role);
                        if (nr == null || nr == role || !mounted) return;
                        if (await attempt(context, () => app.api.setPageAdmin(widget.id, u, nr)) && mounted) _load();
                      }),
                      SheetItem('x', 'მოხსნა', () async {
                        if (await attempt(context, () => app.api.removePageAdmin(widget.id, u)) && mounted) {
                          toast(context, 'მოიხსნა');
                          _load();
                        }
                      }, danger: true),
                    ]);
                  })
                : u == me
                    ? TextButton(
                        key: const ValueKey('pa-leave'),
                        onPressed: () async {
                          if (!await confirm(context, title: 'გვერდის მართვის დატოვება', text: 'ამ გვერდის სახელით ვეღარ დაწერ.', yes: 'დატოვება', danger: true) || !mounted) return;
                          if (await attempt(context, () => app.api.removePageAdmin(widget.id, me)) && mounted) Navigator.of(context).pop(true);
                        },
                        child: Text('დატოვება', style: TextStyle(color: c.nope)),
                      )
                    : null,
      );
    }

    return Scaffold(
      appBar: peeraBar(context, title: 'გვერდის მართვა', actions: [
        if (isOwner)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton.icon(
              key: const ValueKey('pa-add'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
              onPressed: _add,
              icon: PIcon('uadd', size: 17, color: c.onAccent),
              label: const Text('დამატება'),
            ),
          ),
      ]),
      body: l == null
          ? (error != null ? Empty(icon: 'shield', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load) : const Center(child: CircularProgressIndicator()))
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text('ადმინი არედაქტირებს გვერდს და ხედავს სტატისტიკას, რედაქტორი წერს პოსტებს გვერდის სახელით.', style: TextStyle(color: c.muted, fontSize: 13)),
              ),
              person(widget.owner, 'owner'),
              for (final r in l) person('${r['user_id']}', '${r['role']}', r: r),
              if (l.isEmpty && isOwner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text('დაამატე მეგობრები, რომ გვერდი ერთად მართოთ.', style: TextStyle(color: c.muted)),
                ),
            ]),
    );
  }
}
