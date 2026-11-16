// Channels and business pages (community.js PG.pages, PG.pagev): mine, the ones I follow and the rest; a page with
// its followers, posts, following it, a complaint; its owner writes as the page, changes or deletes it and sees its
// ads; the staff give or take the blue mark.
import 'package:flutter/material.dart';

import '../config.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../feed/photo_viewer.dart';
import '../feed/post_actions.dart';
import '../feed/post_card.dart';
import '../people/profile_parts.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'community_ui.dart';
import 'groups.dart';
import 'page_pro.dart';

String pageLink(int id) => '$siteUrl/#pagev-$id';

class PageRow extends StatelessWidget {
  const PageRow({super.key, required this.p});
  final Map<String, dynamic> p;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return ListTile(
      key: ValueKey('pg-${p['id']}'),
      leading: BoxPic(name: '${p['name'] ?? ''}', hue: asInt(p['hue'], 200), url: p['avatar_url'] as String?),
      title: Row(children: [
        Flexible(child: Text('${p['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
        if (p['verified'] == true) const Padding(padding: EdgeInsets.only(left: 4), child: Verified(size: 15)),
      ]),
      subtitle: Text(
          [
            p['kind'] == 'business' ? 'ბიზნესი' : 'არხი',
            if ('${p['category'] ?? ''}'.isNotEmpty) '${p['category']}',
            if (asInt(p['reviews']) > 0 && double.tryParse('${p['rating']}') != null) '★ ${double.parse('${p['rating']}').toStringAsFixed(1)}',
          ].join(' · '),
          style: TextStyle(color: c.muted)),
      onTap: () => openPage(context, PageScreen(id: asInt(p['id'])), full: true),
    );
  }
}

class PagesScreen extends StatefulWidget {
  const PagesScreen({super.key});
  @override
  State<PagesScreen> createState() => _PagesScreenState();
}

class _PagesScreenState extends State<PagesScreen> {
  (Set<int>, List<Map<String, dynamic>>)? d;
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
      final r = await context.app.api.pages();
      if (mounted) {
        setState(() {
          d = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _new() async {
    final id = await openPage<int>(context, const PageFormScreen(), full: true);
    if (id != null && mounted) {
      _load();
      await openPage(context, PageScreen(id: id), full: true);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, me = context.me.id, x = d;
    Widget sec(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)));
    return Scaffold(
      appBar: peeraBar(context, title: 'არხები და ბიზნესი', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: FilledButton.icon(
            key: const ValueKey('pages-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: _new,
            icon: PIcon('plus', size: 17, color: c.onAccent),
            label: const Text('ახალი'),
          ),
        ),
      ]),
      body: error != null && x == null
          ? Empty(icon: 'mega', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
          : x == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Builder(builder: (context) {
                    final mine = [for (final p in x.$2) if (p['owner'] == me) p];
                    final fol = [for (final p in x.$2) if (x.$1.contains(asInt(p['id'])) && p['owner'] != me) p];
                    final rest = [for (final p in x.$2) if (!x.$1.contains(asInt(p['id'])) && p['owner'] != me) p];
                    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                      if (mine.isNotEmpty) ...[sec('ჩემი გვერდები'), for (final p in mine) PageRow(p: p)],
                      if (fol.isNotEmpty) ...[sec('გამოწერილი'), for (final p in fol) PageRow(p: p)],
                      sec('აღმოაჩინე'),
                      if (rest.isEmpty)
                        const Empty(icon: 'mega', title: 'გვერდები ჯერ არ არის', text: 'შექმენი არხი სიახლეებისთვის ან ბიზნეს გვერდი.')
                      else
                        for (final p in rest) PageRow(p: p),
                    ]);
                  }),
                ),
    );
  }
}

class PageScreen extends StatefulWidget {
  const PageScreen({super.key, required this.id});
  final int id;
  @override
  State<PageScreen> createState() => _PageScreenState();
}

class _PageScreenState extends State<PageScreen> {
  ({Map<String, dynamic> p, int count, bool following, String notify, String? role})? d;
  List<Post>? posts;
  Post? pinned;
  List<Map<String, dynamic>> ads = const [];
  Object? error;
  String tab = 'posts';
  bool gone = false, _started = false;

  String? get role => d?.role;
  bool get canEdit => role == 'owner' || role == 'admin';
  bool get business => d?.p['kind'] == 'business';

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
      final r = await app.api.page(widget.id);
      if (!mounted) return;
      if (r == null) {
        setState(() => gone = true);
        return;
      }
      setState(() {
        d = r;
        error = null;
      });
      if (r.role == 'owner') {
        app.api.pageAds(widget.id).then((a) {
          if (mounted) setState(() => ads = a);
        }).catchError((_) {});
      }
      final pin = r.p['pinned_post'] == null ? null : asInt(r.p['pinned_post']);
      final p = await app.api.pagePosts(widget.id);
      Post? pp = pin == null ? null : p.where((x) => x.id == pin).firstOrNull;
      if (pin != null && pp == null) pp = await app.api.post(pin).catchError((_) => null);
      await app.posts.load([...p, if (pp != null) pp]);
      if (mounted) {
        setState(() {
          posts = [for (final x in p) if (x.id != pin) x];
          pinned = pp;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _follow() async {
    final x = d;
    if (x == null) return;
    final api = context.app.api;
    if (!x.following) {
      if (await attempt(context, () => api.followPage(widget.id, true)) && mounted) {
        toast(context, 'გამოიწერე · ყველა ახალ პოსტზე გაცნობებთ');
        _load();
      }
      return;
    }
    final k = await pageNotifySheet(context, x.notify);
    if (k == null || k == x.notify || !mounted) return;
    final ok = await attempt(context, () => k == 'unfollow' ? api.followPage(widget.id, false) : api.pageNotify(widget.id, k));
    if (!ok || !mounted) return;
    toast(context, const {'unfollow': 'გამოწერა გაუქმდა', 'all': 'ყველა პოსტზე გაცნობებთ', 'highlights': 'მხოლოდ მთავარზე გაცნობებთ', 'off': 'შეტყობინებები გამოირთო'}[k]!);
    _load();
  }

  Future<void> _pic() async {
    try {
      final url = await pickSquarePic(context, 'გვერდის სურათი');
      if (url == null || !mounted) return;
      await context.app.api.updatePage(widget.id, {'avatar_url': url});
      if (!mounted) return;
      toast(context, 'სურათი შეიცვალა');
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  Future<void> _cover() async {
    try {
      final url = await pickCover(context, 'გვერდის ქავერი');
      if (url == null || !mounted) return;
      await context.app.api.updatePage(widget.id, {'cover_url': url});
      if (!mounted) return;
      toast(context, 'ქავერი შეიცვალა');
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  Future<void> _pin(int? postId) async {
    if (await attempt(context, () => context.app.api.updatePage(widget.id, {'pinned_post': postId})) && mounted) {
      toast(context, postId == null ? 'მოიხსნა' : 'მიმაგრდა 📌 გამომწერებს ვაცნობებთ');
      _load();
    }
  }

  Future<void> _write() async {
    final np = await openPage<Post>(context, ComposeScreen(pageId: widget.id, where: '${d?.p['name'] ?? ''}'), full: true);
    if (np != null && mounted) _load();
  }

  Future<void> _edit() async {
    final r = await openPage<int>(context, PageFormScreen(p: d!.p), full: true);
    if (!mounted) return;
    if (r == -1) {
      Navigator.of(context).maybePop();
    } else if (r != null) {
      _load();
    }
  }

  Widget _post(Post q, {bool isPinned = false}) => PostCard(
        key: ValueKey('ppost-${q.id}'),
        post: q,
        menu: [
          if (canEdit)
            isPinned ? SheetItem('pin', 'მიმაგრების მოხსნა', () => _pin(null)) : SheetItem('pin', 'მიმაგრება გვერდზე', () => _pin(q.id)),
        ],
        onDeleted: () => setState(() {
          posts = [for (final y in posts!) if (y.id != q.id) y];
          if (pinned?.id == q.id) pinned = null;
        }),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = d, staff = isStaff(context);
    if (gone) return Scaffold(appBar: peeraBar(context, title: 'გვერდი'), body: const Empty(icon: 'mega', title: 'გვერდი ვერ მოიძებნა'));
    if (x == null) {
      return Scaffold(
        appBar: peeraBar(context, title: 'გვერდი'),
        body: error != null ? Empty(icon: 'mega', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load) : const Center(child: CircularProgressIndicator()),
      );
    }
    final p = x.p, ours = role != null, name = '${p['name'] ?? ''}', hue = asInt(p['hue'], 200), url = p['avatar_url'] as String?;
    final rating = double.tryParse('${p['rating'] ?? ''}'), reviews = asInt(p['reviews']);
    final open = p['hours'] is Map ? openNow(p['hours'] as Map, DateTime.now()) : null;
    Widget btn(String key, String icon, String label, VoidCallback onTap, {bool filled = false}) => filled
        ? FilledButton.icon(key: ValueKey(key), style: FilledButton.styleFrom(minimumSize: const Size(0, 42)), onPressed: onTap, icon: PIcon(icon, size: 17, color: c.onAccent), label: Text(label))
        : OutlinedButton.icon(key: ValueKey(key), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)), onPressed: onTap, icon: PIcon(icon, size: 17, color: c.ink), label: Text(label));
    final act = pageActionButton(context, p);
    final tabs = [('posts', 'edit', 'პოსტები'), ('about', 'help', 'შესახებ'), if (business) ('reviews', 'star', 'შეფასებები')];
    if (!tabs.any((t) => t.$1 == tab)) tab = 'posts';
    final List<Widget> body = switch (tab) {
      'about' => [PageAbout(key: const ValueKey('p-about'), p: p, count: x.count)],
      'reviews' => [PageReviews(key: const ValueKey('p-reviews'), id: widget.id, canReview: !ours, onChanged: _load)],
      _ => [
          if (pinned != null) PinnedBox(onUnpin: canEdit ? () => _pin(null) : null, child: _post(pinned!, isPinned: true)),
          if (posts == null)
            const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
          else if (posts!.isEmpty && pinned == null)
            Empty(icon: 'note', title: 'პოსტები ჯერ არ არის', text: ours ? 'დაწერე პირველი პოსტი გვერდის სახელით.' : null, action: ours ? 'პოსტის დაწერა' : null, onAction: ours ? _write : null)
          else
            for (final q in posts!) _post(q),
        ],
    };
    return Scaffold(
      appBar: peeraBar(context, title: name),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          CoverHead(
            name: name,
            hue: hue,
            cover: p['cover_url'] as String?,
            avatar: url,
            coverKey: 'p-cover',
            picKey: 'p-pic',
            onCover: canEdit ? _cover : null,
            onAvatar: canEdit ? _pic : (url != null ? () => openPhotos(context, [Media(url: url)]) : null),
            title: Row(children: [
              Flexible(child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
              if (p['verified'] == true) const Padding(padding: EdgeInsets.only(left: 5), child: Verified(size: 18)),
            ]),
            sub: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                [business ? 'ბიზნესი' : 'არხი', if ('${p['category'] ?? ''}'.isNotEmpty) '${p['category']}', '${x.count} გამომწერი'].join(' · '),
                style: TextStyle(color: c.muted, fontSize: 13.5),
              ),
              if (business && (reviews > 0 || open != null))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    if (reviews > 0 && rating != null)
                      GestureDetector(
                        key: const ValueKey('p-rating'),
                        onTap: () => setState(() => tab = 'reviews'),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Stars(rating, size: 14),
                          const SizedBox(width: 4),
                          Text('${rating.toStringAsFixed(1)} ($reviews)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        ]),
                      ),
                    if (open != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: open.$1 ? c.vine : c.nope, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        // "closed · opens on … at …" can be long: it wraps instead of running past the edge
                        Flexible(child: Text(open.$2, style: TextStyle(color: open.$1 ? c.vine : c.nope, fontWeight: FontWeight.w700, fontSize: 13))),
                      ]),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              if (ours) ...[
                btn('p-post', 'plus', 'პოსტი', _write, filled: true),
                if (canEdit) btn('p-edit', 'edit', 'რედაქტირება', _edit),
                if (canEdit)
                  btn('p-stats', 'poll', 'სტატისტიკა', () => openPage(context, PageStatsScreen(id: widget.id, name: name), full: true)),
                btn('p-admins', 'shield', 'ადმინები', () async {
                  final left = await openPage<bool>(context, PageAdminsScreen(id: widget.id, owner: '${p['owner']}', role: role!), full: true);
                  if (left == true && mounted) _load();
                }),
              ] else ...[
                if (act != null) act,
                x.following
                    ? btn('p-follow', x.notify == 'off' ? 'mute' : 'bell', x.notify == 'all' ? 'გამოწერილი' : (x.notify == 'off' ? 'ჩუმად' : 'მთავარი'), _follow)
                    : btn('p-follow', 'plus', 'გამოწერა', _follow, filled: act == null),
              ],
              btn('p-share', 'send', 'გაზიარება', () => shareText(context, pageLink(widget.id))),
              if (!ours) btn('p-report', 'flag', 'საჩივარი', () => reportSheet(context, 'page', '${widget.id}')),
              if (staff)
                btn('p-verify', 'check', p['verified'] == true ? 'ნიშნის მოხსნა' : 'ვერიფიკაცია', () async {
                  if (await attempt(context, () => context.app.api.verifyPage(widget.id, p['verified'] != true)) && mounted) _load();
                }),
            ]),
          ),
          if (role == 'owner' && ads.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 4), child: Text('რეკლამები', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            for (final a in ads)
              ListTile(
                title: Text('პოსტი #${a['post_id']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${const {'pending': 'განხილვაშია', 'active': 'აქტიურია', 'rejected': 'უარყოფილია', 'ended': 'დასრულდა'}['${a['status']}'] ?? '${a['status']}'} · დახარჯული ${a['spent']}/${a['budget']}',
                    style: TextStyle(color: c.muted)),
              ),
          ],
          SlideTabs(tabs: tabs, value: tab, prefix: 'ptb', onChanged: (t) => setState(() => tab = t)),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (ch, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(a), child: ch)),
            child: Column(key: ValueKey('ptab-$tab'), crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
          ),
        ]),
      ),
    );
  }
}

/// A new page (a channel or a business) or the owner's changes to one; pops its id, or -1 when it was deleted.
class PageFormScreen extends StatefulWidget {
  const PageFormScreen({super.key, this.p});
  final Map<String, dynamic>? p;
  @override
  State<PageFormScreen> createState() => _PageFormScreenState();
}

class _PageFormScreenState extends State<PageFormScreen> {
  late final name = TextEditingController(text: '${widget.p?['name'] ?? ''}');
  late final cat = TextEditingController(text: '${widget.p?['category'] ?? ''}');
  late final desc = TextEditingController(text: '${widget.p?['description'] ?? ''}');
  late String kind = '${widget.p?['kind'] ?? 'channel'}';
  late String? pic = widget.p?['avatar_url'] as String?;
  late final addr = TextEditingController(text: '${widget.p?['address'] ?? ''}');
  late final phone = TextEditingController(text: '${widget.p?['phone'] ?? ''}');
  late final site = TextEditingController(text: '${widget.p?['website'] ?? ''}');
  late String action = '${widget.p?['action'] ?? 'msg'}';
  late final hours = <int, (String, String)?>{for (var d = 1; d <= 7; d++) d: widget.p?['hours'] is Map ? dayHours(widget.p!['hours'] as Map, d) : null};
  bool busy = false;

  bool get edit => widget.p != null;

  @override
  void dispose() {
    name.dispose();
    cat.dispose();
    desc.dispose();
    addr.dispose();
    phone.dispose();
    site.dispose();
    super.dispose();
  }

  static final _timeBtn = TextButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 8), tapTargetSize: MaterialTapTargetSize.shrinkWrap);

  Future<void> _time(int day, bool from) async {
    final h = hours[day] ?? ('09:00', '18:00');
    final now = from ? h.$1 : h.$2, parts = now.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(parts.first) ?? 9, minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0),
      helpText: '${weekDays[day - 1]} · ${from ? 'იხსნება' : 'იკეტება'}',
    );
    if (t == null || !mounted) return;
    final v = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => hours[day] = from ? (v, h.$2) : (h.$1, v));
  }

  Future<void> _save() async {
    final n = name.text.trim();
    if (n.length < 2) {
      toast(context, 'ჩაწერე სახელი');
      return;
    }
    final api = context.app.api;
    setState(() => busy = true);
    try {
      if (edit) {
        final id = asInt(widget.p!['id']);
        var web = site.text.trim();
        if (web.isNotEmpty && !RegExp(r'^https?://').hasMatch(web)) web = 'https://$web';
        await api.updatePage(id, {
          'name': n,
          'category': cat.text.trim(),
          'description': desc.text.trim(),
          'avatar_url': pic,
          'phone': phone.text.trim(),
          'website': web,
          'action': action,
          if (kind == 'business') 'address': addr.text.trim(),
          if (kind == 'business') 'hours': {for (final e in hours.entries) if (e.value != null) '${e.key}': [e.value!.$1, e.value!.$2]},
        });
        if (!mounted) return;
        toast(context, 'შენახულია');
        Navigator.of(context).pop(id);
      } else {
        final id = await api.createPage(kind: kind, name: n, category: cat.text.trim(), description: desc.text.trim(), avatarUrl: pic);
        if (!mounted) return;
        toast(context, 'გვერდი შეიქმნა');
        Navigator.of(context).pop(id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e));
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, title: 'გვერდის წაშლა', text: 'წაიშლება გვერდი და მისი პოსტები.', yes: 'წაშლა', danger: true) || !mounted) return;
    if (await attempt(context, () => context.app.api.deletePage(asInt(widget.p!['id']))) && mounted) {
      toast(context, 'გვერდი წაიშალა');
      Navigator.of(context).pop(-1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      appBar: peeraBar(context, title: edit ? 'გვერდის რედაქტირება' : 'ახალი გვერდი', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(
            key: const ValueKey('pf-ok'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: busy ? null : _save,
            child: Text(edit ? 'შენახვა' : 'შექმნა'),
          ),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (!edit)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SegmentedButton<String>(
              key: const ValueKey('pf-kind'),
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: 'channel', label: Text('არხი')), ButtonSegment(value: 'business', label: Text('ბიზნესი'))],
              selected: {kind},
              onSelectionChanged: (v) => setState(() => kind = v.first),
            ),
          ),
        Row(children: [
          GestureDetector(
            key: const ValueKey('pf-pic'),
            onTap: busy
                ? null
                : () async {
                    try {
                      final u = await pickSquarePic(context, 'გვერდის სურათი');
                      if (u != null && mounted) setState(() => pic = u);
                    } catch (e) {
                      if (mounted) toast(context, errText(e));
                    }
                  },
            child: BoxPic(name: name.text.trim(), hue: asInt(widget.p?['hue'], 200), url: pic, size: 64),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('გვერდის სურათი', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(pic == null ? 'ლოგო ან კვადრატული ფოტო. შეგიძლია მერეც დაამატო' : 'შეეხე, რომ შეცვალო', style: TextStyle(color: c.muted, fontSize: 13)),
            ]),
          ),
          if (pic != null) TextButton(onPressed: () => setState(() => pic = null), child: const Text('მოშორება')),
        ]),
        const SizedBox(height: 14),
        TextField(key: const ValueKey('pf-name'), controller: name, maxLength: 80, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'სახელი', counterText: '')),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('pf-cat'), controller: cat, maxLength: 40, decoration: const InputDecoration(labelText: 'კატეგორია', hintText: 'მაგ. სიახლეები, კაფე, მაღაზია', counterText: '')),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('pf-desc'), controller: desc, maxLength: 500, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'აღწერა', counterText: '')),
        if (edit) ...[
          const SizedBox(height: 18),
          const SectionHead('კონტაქტები და მთავარი ღილაკი', padding: EdgeInsets.fromLTRB(0, 4, 0, 8)),
          if (kind == 'business') ...[
            TextField(key: const ValueKey('pf-addr'), controller: addr, maxLength: 160, decoration: const InputDecoration(labelText: 'მისამართი', hintText: 'ქალაქი, ქუჩა, ნომერი', counterText: '')),
            const SizedBox(height: 10),
          ],
          TextField(
            key: const ValueKey('pf-phone'),
            controller: phone,
            maxLength: 30,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'ტელეფონი', hintText: '+995 5XX XX XX XX', counterText: ''),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('pf-site'),
            controller: site,
            maxLength: 200,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'ვებსაიტი', hintText: 'https://…', counterText: ''),
          ),
          const SizedBox(height: 12),
          Text('რა აკეთოს მთავარმა ღილაკმა', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (k, l) in const [('msg', 'მიწერა'), ('call', 'დარეკვა'), ('site', 'საიტზე გადასვლა'), ('none', 'არაფერი')])
              ChoiceChip(
                key: ValueKey('pf-act-$k'),
                label: Text(l),
                selected: action == k,
                showCheckmark: false,
                selectedColor: c.accentSoft,
                side: BorderSide(color: action == k ? c.accent : c.line),
                onSelected: (_) => setState(() => action = k),
              ),
          ]),
          if (kind == 'business') ...[
            const SizedBox(height: 18),
            SectionHead('სამუშაო საათები',
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
                trailing: hours[1] == null
                    ? null
                    : TextButton(
                        key: const ValueKey('pf-hours-copy'),
                        onPressed: () => setState(() {
                          for (var d = 2; d <= 7; d++) {
                            hours[d] = hours[1];
                          }
                        }),
                        child: const Text('ყველა დღე ორშაბათივით'),
                      )),
            for (var d = 1; d <= 7; d++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(weekDays[d - 1], style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (hours[d] == null)
                        Text('დაკეტილია', style: TextStyle(color: c.muted, fontSize: 13))
                      else
                        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                          TextButton(key: ValueKey('pf-from-$d'), style: _timeBtn, onPressed: () => _time(d, true), child: Text(hours[d]!.$1)),
                          Text('–', style: TextStyle(color: c.muted)),
                          TextButton(key: ValueKey('pf-to-$d'), style: _timeBtn, onPressed: () => _time(d, false), child: Text(hours[d]!.$2)),
                        ]),
                    ]),
                  ),
                  Switch(key: ValueKey('pf-day-$d'), value: hours[d] != null, onChanged: (on) => setState(() => hours[d] = on ? (hours[1] ?? ('09:00', '18:00')) : null)),
                ]),
              ),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            key: const ValueKey('pf-delete'),
            style: OutlinedButton.styleFrom(foregroundColor: c.nope, side: BorderSide(color: c.nope.withValues(alpha: .5))),
            onPressed: busy ? null : _delete,
            icon: PIcon('trash', size: 17, color: c.nope),
            label: const Text('გვერდის წაშლა'),
          ),
        ],
      ]),
    );
  }
}
