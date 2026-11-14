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
import '../ui/theme.dart';
import '../ui/translate.dart';
import '../ui/widgets.dart';
import 'groups.dart';

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
      subtitle: Text([p['kind'] == 'business' ? 'ბიზნესი' : 'არხი', if ('${p['category'] ?? ''}'.isNotEmpty) '${p['category']}'].join(' · '),
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
  ({Map<String, dynamic> p, int count, bool following})? d;
  List<Post>? posts;
  List<Map<String, dynamic>> ads = const [];
  Object? error;
  bool gone = false, _started = false;

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
      if (r.p['owner'] == app.api.myId) {
        app.api.pageAds(widget.id).then((a) {
          if (mounted) setState(() => ads = a);
        }).catchError((_) {});
      }
      final p = await app.api.pagePosts(widget.id);
      await app.posts.load(p);
      if (mounted) setState(() => posts = p);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _follow() async {
    final on = !(d?.following ?? false);
    if (await attempt(context, () => context.app.api.followPage(widget.id, on)) && mounted) {
      if (on) toast(context, 'გამოიწერე');
      _load();
    }
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
    final p = x.p, mine = p['owner'] == context.me.id, name = '${p['name'] ?? ''}', hue = asInt(p['hue'], 200), url = p['avatar_url'] as String?;
    final desc = '${p['description'] ?? ''}'.trim();
    Widget btn(String key, String icon, String label, VoidCallback onTap, {bool filled = false}) => filled
        ? FilledButton.icon(key: ValueKey(key), style: FilledButton.styleFrom(minimumSize: const Size(0, 42)), onPressed: onTap, icon: PIcon(icon, size: 17, color: c.onAccent), label: Text(label))
        : OutlinedButton.icon(key: ValueKey(key), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)), onPressed: onTap, icon: PIcon(icon, size: 17, color: c.ink), label: Text(label));
    return Scaffold(
      appBar: peeraBar(context, title: name),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
                HSLColor.fromAHSL(1, (hue % 360).toDouble(), .45, .5).toColor().withValues(alpha: .25),
                Colors.transparent,
              ]),
            ),
            child: Row(children: [
              GestureDetector(
                key: const ValueKey('p-pic'),
                onTap: mine ? _pic : (url != null ? () => openPhotos(context, [Media(url: url)]) : null),
                child: BoxPic(name: name, hue: hue, url: url, size: 76),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
                    if (p['verified'] == true) const Padding(padding: EdgeInsets.only(left: 5), child: Verified(size: 18)),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    [p['kind'] == 'business' ? 'ბიზნესი' : 'არხი', if ('${p['category'] ?? ''}'.isNotEmpty) '${p['category']}', '${x.count} გამომწერი'].join(' · '),
                    style: TextStyle(color: c.muted, fontSize: 13.5),
                  ),
                ]),
              ),
            ]),
          ),
          if (desc.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: TranslatableBody(desc)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              if (mine) ...[
                btn('p-post', 'plus', 'პოსტი', () async {
                  final np = await openPage<Post>(context, ComposeScreen(pageId: widget.id, where: name), full: true);
                  if (np != null && mounted) _load();
                }, filled: true),
                btn('p-edit', 'edit', 'რედაქტირება', () async {
                  final r = await openPage<int>(context, PageFormScreen(p: p), full: true);
                  if (!mounted) return;
                  if (r == -1) {
                    Navigator.of(context).maybePop();
                  } else if (r != null) {
                    _load();
                  }
                }),
              ] else
                x.following ? btn('p-follow', 'check', 'გამოწერილი', _follow) : btn('p-follow', 'plus', 'გამოწერა', _follow, filled: true),
              btn('p-share', 'send', 'გაზიარება', () => shareText(context, pageLink(widget.id))),
              if (!mine) btn('p-report', 'flag', 'საჩივარი', () => reportSheet(context, 'page', '${widget.id}')),
              if (staff)
                btn('p-verify', 'check', p['verified'] == true ? 'ნიშნის მოხსნა' : 'ვერიფიკაცია', () async {
                  if (await attempt(context, () => context.app.api.verifyPage(widget.id, p['verified'] != true)) && mounted) _load();
                }),
            ]),
          ),
          if (mine && ads.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 4), child: Text('რეკლამები', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            for (final a in ads)
              ListTile(
                title: Text('პოსტი #${a['post_id']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${const {'pending': 'განხილვაშია', 'active': 'აქტიურია', 'rejected': 'უარყოფილია', 'ended': 'დასრულდა'}['${a['status']}'] ?? '${a['status']}'} · დახარჯული ${a['spent']}/${a['budget']}',
                    style: TextStyle(color: c.muted)),
              ),
          ],
          Container(height: 8, color: c.bg),
          if (posts == null)
            const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
          else if (posts!.isEmpty)
            const Empty(icon: 'note', title: 'პოსტები ჯერ არ არის')
          else
            for (final q in posts!) PostCard(key: ValueKey('ppost-${q.id}'), post: q, onDeleted: () => setState(() => posts = [for (final y in posts!) if (y.id != q.id) y])),
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
  bool busy = false;

  bool get edit => widget.p != null;

  @override
  void dispose() {
    name.dispose();
    cat.dispose();
    desc.dispose();
    super.dispose();
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
        await api.updatePage(id, {'name': n, 'category': cat.text.trim(), 'description': desc.text.trim(), 'avatar_url': pic});
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
