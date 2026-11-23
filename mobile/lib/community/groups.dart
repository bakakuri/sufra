// Groups (community.js): mine and the ones to discover; a group's page with its rules, members' count, posts (a
// closed group shows them to members only), joining at once or by a request, the starosta of a class or a course,
// an invite with a link and a QR code; and for its admins the management: requests, posts waiting for approval,
// members and roles, the settings.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../chat/chat_screen.dart';
import '../config.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../feed/photo_viewer.dart';
import '../feed/post_card.dart';
import '../people/person_screen.dart';
import '../people/profile_parts.dart';
import '../profile/profile.dart';
import '../settings/frame_photo.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/translate.dart';
import '../ui/widgets.dart';
import 'community_ui.dart';
import 'group_pro.dart';

/// A group's or a page's square picture: the photo, or its first letter on its colour.
class BoxPic extends StatelessWidget {
  const BoxPic({super.key, required this.name, required this.hue, this.url, this.size = 44, this.radius});
  final String name;
  final int hue;
  final String? url;
  final double size;
  final double? radius;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: HSLColor.fromAHSL(1, (hue % 360).toDouble(), .5, .45).toColor(), borderRadius: BorderRadius.circular(radius ?? size * .26)),
        child: url != null && url!.startsWith('http')
            ? PImage(url!)
            : Center(child: Text(name.isEmpty ? '?' : name.characters.first, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * .42))),
      );
}

/// A square picture chosen, cut and uploaded (community.js bindPic): its address, or null.
Future<String?> pickSquarePic(BuildContext context, String title) async {
  final app = context.app;
  final got = await photoSource(false);
  if (got.isEmpty || !context.mounted) return null;
  final f = await photoFrame(context, got.first, aspect: 1, max: 720, title: title);
  if (f == null || !context.mounted) return null;
  toast(context, 'იტვირთება…');
  final m = await app.api.uploadPhoto(await photoPrep(f.bytes));
  return m.url;
}

/// the school, class, university and course groups' invite words (community.js EDUK)
const eduInvite = {
  'class': ('მოიწვიე კლასელები', 'ჩვენს კლასში'),
  'course': ('მოიწვიე კურსელები', 'ჩვენს კურსზე'),
  'school': ('მოიწვიე სკოლელები', 'ჩვენი სკოლის ჯგუფში'),
  'uni': ('მოიწვიე სტუდენტები', 'ჩვენი უნივერსიტეტის ჯგუფში'),
};

String groupLink(int id) => '$siteUrl/#group-$id';

/// One group in a list.
class GroupRow extends StatelessWidget {
  const GroupRow({super.key, required this.g});
  final Map<String, dynamic> g;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, d = '${g['description'] ?? ''}';
    return ListTile(
      key: ValueKey('grp-${g['id']}'),
      leading: BoxPic(name: '${g['name'] ?? ''}', hue: asInt(g['hue'], 200), url: g['avatar_url'] as String?),
      title: Text('${g['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text([g['is_private'] == true ? '🔒 დახურული' : 'ღია', if (d.isNotEmpty) d].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted)),
      onTap: () => openPage(context, GroupScreen(id: asInt(g['id'])), full: true),
    );
  }
}

/// what a group is about (community.js GRCATS)
const groupCats = [
  ('edu', '🎓', 'განათლება'),
  ('place', '📍', 'კუთხე და დიასპორა'),
  ('hobby', '🎨', 'ჰობი'),
  ('sport', '⚽', 'სპორტი'),
  ('food', '🍲', 'კულინარია'),
  ('travel', '✈️', 'მოგზაურობა'),
  ('tech', '💻', 'ტექნოლოგია'),
  ('family', '👨‍👩‍👧', 'ოჯახი და ბავშვები'),
  ('work', '💼', 'სამსახური და ბიზნესი'),
  ('market', '🛒', 'ყიდვა-გაყიდვა'),
  ('fun', '🎉', 'გართობა'),
  ('health', '🩺', 'ჯანმრთელობა'),
  ('faith', '⛪', 'რწმენა'),
  ('other', '💬', 'სხვა'),
];

(String, String, String) groupCat(Object? k) => groupCats.firstWhere((c) => c.$1 == '$k', orElse: () => groupCats.last);

String _num(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1).replaceAll('.0', '')}ათ.' : '$n';

/// One group as a raised card (community.js gCard): a wide picture with its category on it, the name, members and
/// life, friends in it, and a button (join an open one, look at a closed one, open mine). It gives under a finger.
class GroupCard extends StatefulWidget {
  const GroupCard({super.key, required this.g, this.small = false, this.width, required this.onOpen, required this.onJoin});
  final Map<String, dynamic> g;
  final bool small;
  final double? width;
  final VoidCallback onOpen, onJoin;
  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  bool down = false;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, g = widget.g, id = asInt(g['id']), dark = Theme.of(context).brightness == Brightness.dark;
    final cat = groupCat(g['category']), name = '${g['name'] ?? ''}', pic = '${g['cover_url'] ?? g['avatar_url'] ?? ''}';
    final mine = g['mine'] == true, open = g['is_private'] != true && g['join_mode'] != 'request';
    final members = asInt(g['members']), posts = asInt(g['posts14']), friends = asInt(g['friends']);
    final meta = ['${_num(members)} წევრი', if (posts > 0) '$posts პოსტი 2 კვირაში' else if (g['is_private'] == true) 'დახურული'].join(' · ');
    final hue = (asInt(g['hue'], 200) % 360).toDouble();
    return AnimatedScale(
      scale: down ? .97 : 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        width: widget.width ?? (widget.small ? 168 : 236),
        margin: const EdgeInsets.fromLTRB(6, 6, 6, 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.line.withValues(alpha: .6)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: dark ? .4 : .06), blurRadius: 2, offset: const Offset(0, 1)),
            BoxShadow(color: Colors.black.withValues(alpha: dark ? .5 : .12), blurRadius: 22, spreadRadius: -6, offset: const Offset(0, 12)),
          ],
        ),
        child: Listener(
          onPointerDown: (_) => setState(() => down = true),
          onPointerUp: (_) => setState(() => down = false),
          onPointerCancel: (_) => setState(() => down = false),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            InkWell(
              key: ValueKey('grp-$id'),
              onTap: widget.onOpen,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AspectRatio(
                  aspectRatio: widget.small ? 4 / 3 : 16 / 10,
                  child: Stack(fit: StackFit.expand, children: [
                    if (pic.startsWith('http'))
                      PImage(pic, fit: BoxFit.cover)
                    else
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(center: const Alignment(-.5, -.7), radius: 1.3, colors: [
                            HSLColor.fromAHSL(1, hue, .8, .66).toColor(),
                            HSLColor.fromAHSL(1, (hue + 38) % 360, .64, .38).toColor(),
                          ]),
                        ),
                        child: Center(child: Text(name.isEmpty ? '?' : name.characters.first, style: const TextStyle(color: Colors.white, fontSize: 54, fontWeight: FontWeight.w800))),
                      ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      right: 8,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .45), borderRadius: BorderRadius.circular(999)),
                          child: Text('${cat.$2} ${cat.$3}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.25)),
                    const SizedBox(height: 3),
                    Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ]),
                ),
              ]),
            ),
            if (!widget.small && friends > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Row(children: [
                  for (final (i, u) in [for (final x in (g['friend_ids'] as List? ?? const [])) '$x'].take(3).indexed)
                    Transform.translate(
                      offset: Offset(-6.0 * i, 0),
                      child: Builder(builder: (context) {
                        final p = context.app.people[u] ?? Profile(id: u, name: '…');
                        return Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)), child: Avatar(p: p, size: 22));
                      }),
                    ),
                  Expanded(child: Text('$friends მეგობარი წევრია', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12))),
                ]),
              ),
            if (!widget.small)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: mine
                    ? OutlinedButton(key: ValueKey('grpo-$id'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)), onPressed: widget.onOpen, child: const Text('გახსნა'))
                    : open
                        ? FilledButton.icon(
                            key: ValueKey('grpj-$id'),
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                            onPressed: widget.onJoin,
                            icon: PIcon('plus', size: 16, color: c.onAccent),
                            label: const Text('შესვლა'),
                          )
                        : OutlinedButton.icon(
                            key: ValueKey('grpv-$id'),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                            onPressed: widget.onOpen,
                            icon: const PIcon('lock', size: 15),
                            label: const Text('ნახვა'),
                          ),
              )
            else
              const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }
}

/// Groups (community.js PG.groups), laid out as Facebook does: a search, the categories in a sideways row; mine,
/// the ones suggested for me (friends in them, my groups' kinds, their life, my town), the popular ones and each
/// category as sideways rows of raised cards. A category or a search shows its groups as a grid. No group is made
/// for anyone by itself.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<Map<String, dynamic>>? all;
  Object? error;
  bool _started = false;
  String cat = '', q = '';
  final search = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.app;
    try {
      final r = await app.api.groupCards();
      await app.people.ensure({for (final g in r) for (final u in (g['friend_ids'] as List? ?? const [])) '$u'});
      if (mounted) {
        setState(() {
          all = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _new() async {
    final id = await openPage<int>(context, const GroupFormScreen(), full: true);
    if (id != null && mounted) {
      _load();
      await openPage(context, GroupScreen(id: id), full: true);
      _load();
    }
  }

  Future<void> _open(Map<String, dynamic> g) async {
    await openPage(context, GroupScreen(id: asInt(g['id'])), full: true);
    if (mounted) _load();
  }

  Future<void> _join(Map<String, dynamic> g) async {
    if (await attempt(context, () => context.app.api.joinGroup(asInt(g['id']))) && mounted) {
      toast(context, 'შეუერთდი ჯგუფს: ${g['name']}');
      setState(() {
        g['mine'] = true;
        g['members'] = asInt(g['members']) + 1;
      });
    }
  }

  Widget _card(Map<String, dynamic> g, {bool small = false, double? width}) =>
      GroupCard(key: ValueKey('gc-${g['id']}'), g: g, small: small, width: width, onOpen: () => _open(g), onJoin: () => _join(g));

  Widget _row(String title, List<Map<String, dynamic>> list, {bool small = false, String? more}) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          if (more != null) TextButton(onPressed: () => setState(() => cat = more), child: const Text('ყველა')),
        ]),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final g in list) _card(g, small: small)]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = all;
    return Scaffold(
      appBar: peeraBar(context, title: 'ჯგუფები', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: FilledButton.icon(
            key: const ValueKey('groups-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: _new,
            icon: PIcon('plus', size: 17, color: c.onAccent),
            label: const Text('ახალი'),
          ),
        ),
      ]),
      body: error != null && x == null
          ? Empty(icon: 'users', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
          : x == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Builder(builder: (context) {
                    double fit(Map<String, dynamic> g) => (g['fit'] as num?)?.toDouble() ?? 0;
                    double pop(Map<String, dynamic> g) => (g['pop'] as num?)?.toDouble() ?? 0;
                    final cats = [for (final k in groupCats) if (x.any((g) => groupCat(g['category']).$1 == k.$1)) k];
                    final low = q.toLowerCase();
                    final filtered = cat.isNotEmpty || q.isNotEmpty;
                    final children = <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        child: TextField(
                          key: const ValueKey('groups-q'),
                          controller: search,
                          onChanged: (v) => setState(() => q = v.trim()),
                          decoration: InputDecoration(hintText: 'ჯგუფის ძებნა', isDense: true, prefixIcon: Padding(padding: const EdgeInsets.all(10), child: PIcon('search', size: 18, color: c.muted))),
                        ),
                      ),
                      if (cats.length > 1)
                        SizedBox(
                          height: 50,
                          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 6, 12, 4), children: [
                            for (final k in [('', '', 'ყველა'), ...cats])
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: ChoiceChip(
                                  key: ValueKey('gcat-${k.$1.isEmpty ? 'all' : k.$1}'),
                                  label: Text(k.$2.isEmpty ? k.$3 : '${k.$2} ${k.$3}'),
                                  selected: cat == k.$1,
                                  showCheckmark: false,
                                  onSelected: (_) => setState(() => cat = k.$1),
                                ),
                              ),
                          ]),
                        ),
                    ];
                    if (filtered) {
                      final list = [
                        for (final g in x)
                          if ((cat.isEmpty || groupCat(g['category']).$1 == cat) &&
                              (low.isEmpty || '${g['name'] ?? ''}'.toLowerCase().contains(low) || '${g['description'] ?? ''}'.toLowerCase().contains(low)))
                            g,
                      ]..sort((a, b) => fit(b).compareTo(fit(a)));
                      children.add(list.isEmpty
                          ? Empty(
                              icon: 'users',
                              title: q.isNotEmpty ? 'ასეთი ჯგუფი ვერ ვიპოვე' : 'ამ კატეგორიაში ჯგუფი ჯერ არ არის',
                              text: 'შექმენი პირველი და მოიწვიე მეგობრები.',
                              action: 'ჯგუფის შექმნა',
                              onAction: _new,
                            )
                          : LayoutBuilder(builder: (context, box) {
                              final w = (box.maxWidth - 20) / 2 - 12;
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                                child: Wrap(children: [for (final g in list) _card(g, width: w)]),
                              );
                            }));
                    } else {
                      final mine = [for (final g in x) if (g['mine'] == true) g]
                        ..sort((a, b) => '${b['last_post'] ?? ''}'.compareTo('${a['last_post'] ?? ''}'));
                      final rest = [for (final g in x) if (g['mine'] != true) g];
                      final sug = ([...rest]..sort((a, b) => fit(b).compareTo(fit(a)))).take(10).toList();
                      final shown = {for (final g in sug) g['id']};
                      final popular = rest.length > 6 ? ([for (final g in rest) if (!shown.contains(g['id'])) g]..sort((a, b) => pop(b).compareTo(pop(a)))).take(10).toList() : <Map<String, dynamic>>[];
                      shown.addAll(popular.map((g) => g['id']));
                      children
                        ..add(_row('ჩემი ჯგუფები', mine, small: true))
                        ..add(_row('შემოთავაზებული შენთვის', sug))
                        ..add(_row('პოპულარული', popular));
                      if (rest.length > 6) {
                        for (final k in cats) {
                          final l = [for (final g in rest) if (!shown.contains(g['id']) && groupCat(g['category']).$1 == k.$1) g];
                          if (l.length >= 2) children.add(_row('${k.$2} ${k.$3}', l, more: k.$1));
                        }
                      }
                      if (rest.isEmpty) {
                        children.add(Empty(icon: 'users', title: 'ახალი ჯგუფები ჯერ არ არის', text: 'შექმენი ჯგუფი შენი ინტერესით და მოიწვიე მეგობრები.', action: 'ჯგუფის შექმნა', onAction: _new));
                      }
                    }
                    return ListView(padding: const EdgeInsets.only(bottom: 24), children: children);
                  }),
                ),
    );
  }
}

/// A group's page.
class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key, required this.id});
  final int id;
  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  ({Map<String, dynamic> g, int count, String? role, String? request})? d;
  List<Post>? posts;
  Post? pinned;
  List<String> starostas = const [];
  List<({String uid, int posts, int comments})> stars = const [];
  int waiting = 0;
  Object? error;
  String tab = 'posts';
  String? topic;
  bool gone = false, _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  bool get member => d?.role != null;
  bool get admin => d?.role == 'owner' || d?.role == 'admin';
  bool get owner => d?.role == 'owner';
  Map<String, dynamic> get g => d!.g;
  List<String> get topics => [for (final t in (d?.g['topics'] as List? ?? const [])) '$t'];

  Future<void> _load() async {
    final app = context.app;
    try {
      final r = await app.api.group(widget.id);
      if (!mounted) return;
      if (r == null) {
        setState(() => gone = true);
        return;
      }
      setState(() {
        d = r;
        error = null;
      });
      final kind = '${r.g['kind'] ?? ''}';
      if (kind == 'class' || kind == 'course') {
        app.api.groupStarostas(widget.id, '${r.g['owner']}').then((s) async {
          await app.people.ensure(s);
          if (mounted) setState(() => starostas = s);
        }).catchError((_) {});
      }
      if (admin) {
        app.api.groupWaiting(widget.id).then((n) {
          if (mounted) setState(() => waiting = n);
        }).catchError((_) {});
      }
      if (r.g['is_private'] == true && r.role == null) {
        setState(() => posts = const []);
        return;
      }
      app.api.groupStars(widget.id).then((s) async {
        await app.people.ensure(s.map((x) => x.uid));
        if (mounted) setState(() => stars = s);
      }).catchError((_) {});
      await _posts();
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  /// the posts (of the chosen topic) and the pinned one
  Future<void> _posts() async {
    final app = context.app, x = d;
    if (x == null) return;
    final pin = x.g['pinned_post'] == null ? null : asInt(x.g['pinned_post']);
    final want = topic;
    final p = await app.api.groupPosts(widget.id, topic: want);
    Post? pp = pin == null ? null : p.where((y) => y.id == pin).firstOrNull;
    if (pin != null && pp == null && pinned?.id == pin) pp = pinned;
    if (pin != null && pp == null) pp = await app.api.post(pin).catchError((_) => null);
    await app.posts.load([...p, if (pp != null) pp]);
    if (!mounted || want != topic) return;
    setState(() {
      posts = [for (final y in p) if (y.id != pin) y];
      pinned = pp;
    });
  }

  void _topic(String? t) {
    if (t == topic) return;
    setState(() {
      topic = t;
      posts = null;
    });
    _posts().catchError((e) {
      if (mounted) setState(() => error = e);
    });
  }

  Future<void> _join() async {
    final app = context.app;
    try {
      await app.api.joinGroup(widget.id);
      if (!mounted) return;
      toast(context, 'შეუერთდი ჯგუფს');
      _load();
    } catch (e) {
      if (mounted) toast(context, '$e'.contains('row-level') ? 'დახურულ ჯგუფში შესასვლელად მფლობელმა უნდა დაგამატოს' : errText(e));
    }
  }

  Future<void> _request() async {
    final rules = '${g['rules'] ?? ''}'.trim();
    final qs = [for (final q in (g['questions'] as List? ?? const [])) '$q'.trim()]..removeWhere((q) => q.isEmpty);
    final ok = await openPage<bool>(context, _RequestScreen(groupId: widget.id, rules: rules, questions: qs), full: true);
    if (ok == true && mounted) {
      toast(context, 'მოთხოვნა გაიგზავნა. ადმინი მალე გიპასუხებს');
      _load();
    }
  }

  Future<void> _cancel() async {
    if (!await confirm(context, title: 'მოთხოვნის გაუქმება', text: 'ადმინს აღარ ექნება შენი მოთხოვნა.', yes: 'გაუქმება') || !mounted) return;
    if (await attempt(context, () => context.app.api.cancelGroupRequest(widget.id)) && mounted) _load();
  }

  Future<void> _leave() async {
    if (!await confirm(context, title: 'ჯგუფიდან გასვლა', text: 'ჯგუფის პოსტებს აღარ ნახავ ფიდში.', yes: 'გასვლა', danger: true) || !mounted) return;
    if (await attempt(context, () => context.app.api.leaveGroup(widget.id)) && mounted) _load();
  }

  Future<void> _delete() async {
    if (!await confirm(context, title: 'ჯგუფის წაშლა', text: 'წაიშლება ჯგუფი, მისი ყველა პოსტი და ჩატი.', yes: 'წაშლა', danger: true) || !mounted) return;
    if (await attempt(context, () => context.app.api.deleteGroup(widget.id)) && mounted) {
      toast(context, 'ჯგუფი წაიშალა');
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _post() async {
    final p = await openPage<Post>(context, ComposeScreen(groupId: widget.id, where: '${g['name']}', topics: topics, topic: topic), full: true);
    if (p != null && mounted) {
      if (g['post_approval'] == true && !admin) toast(context, 'პოსტი გამოჩნდება ადმინის დამტკიცების შემდეგ');
      _load();
    }
  }

  Future<void> _chat() async {
    final app = context.app;
    try {
      final conv = await app.api.groupChat(widget.id);
      if (mounted) await openChat(context, conv);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  Future<void> _pic() async {
    try {
      final url = await pickSquarePic(context, 'ჯგუფის სურათი');
      if (url == null || !mounted) return;
      await context.app.api.updateGroup(widget.id, {'avatar_url': url});
      if (!mounted) return;
      toast(context, 'სურათი შეიცვალა');
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  Future<void> _cover() async {
    try {
      final url = await pickCover(context, 'ჯგუფის ქავერი');
      if (url == null || !mounted) return;
      await context.app.api.updateGroup(widget.id, {'cover_url': url});
      if (!mounted) return;
      toast(context, 'ქავერი შეიცვალა');
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  Future<void> _pin(int? postId) async {
    if (await attempt(context, () => context.app.api.updateGroup(widget.id, {'pinned_post': postId})) && mounted) {
      toast(context, postId == null ? 'მოიხსნა' : 'მიმაგრდა 📌');
      _load();
    }
  }

  Widget _postCard(Post p, {bool isPinned = false}) {
    final mine = p.author == context.me.id;
    return PostCard(
      key: ValueKey('gpost-${p.id}'),
      post: p,
      menu: [
        if (admin && !p.pending)
          isPinned ? SheetItem('pin', 'მიმაგრების მოხსნა', () => _pin(null)) : SheetItem('pin', 'განცხადებად მიმაგრება', () => _pin(p.id)),
        if (admin && !mine)
          SheetItem('trash', 'ჯგუფიდან წაშლა', () async {
            if (!await confirm(context, title: 'პოსტის წაშლა', text: 'პოსტი წაიშლება ჯგუფიდან.', yes: 'წაშლა', danger: true) || !mounted) return;
            if (await attempt(context, () => context.app.api.deletePost(p.id)) && mounted) {
              toast(context, 'წაიშალა');
              _load();
            }
          }, danger: true),
      ],
      onDeleted: () => setState(() {
        posts = [for (final y in posts!) if (y.id != p.id) y];
        if (pinned?.id == p.id) pinned = null;
      }),
    );
  }

  Future<void> _invite() {
    final k = eduInvite['${g['kind']}'] ?? ('მოიწვიე', 'ჯგუფში');
    final url = '$siteUrl/#join-${widget.id}';
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(k.$1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(key: const ValueKey('ginv-qr'), data: url, size: 190, backgroundColor: Colors.white, padding: EdgeInsets.zero),
            ),
            const SizedBox(height: 8),
            Text('${g['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('გაუგზავნე ბმული კლასის Viber-ის ან Messenger-ის ჯგუფში, ან დაასკანერებინე QR კოდი. ვინც გახსნის, რეგისტრაციის შემდეგ პირდაპირ ამ ჯგუფში მოხვდება.',
                textAlign: TextAlign.center, style: TextStyle(color: s.pc.muted, fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('ginv-share'),
                  onPressed: () => shareText(context, 'შემოდი ${k.$2} Peera-ზე: ${g['name']}\n$url'),
                  icon: PIcon('send', size: 17, color: s.pc.onAccent),
                  label: const Text('გაზიარება'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('ginv-copy'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    toast(context, 'ბმული დაკოპირდა');
                  },
                  icon: PIcon('copy', size: 17, color: s.pc.ink),
                  label: const Text('კოპირება'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _starosta(bool on) async {
    final app = context.app;
    final yes = on
        ? await confirm(context, title: 'სტაროსტა გახდები?', text: 'შეძლებ ჯგუფის პოსტების დამტკიცებას და წაშლას და წევრების მართვას. ჯგუფს მაქსიმუმ ორი სტაროსტა ჰყავს.', yes: 'გავხდე სტაროსტა')
        : await confirm(context, title: 'სტაროსტობის დატოვება', text: 'ამ ჯგუფის მართვა აღარ შეგეძლება.', yes: 'დატოვება', danger: true);
    if (!yes || !mounted) return;
    if (await attempt(context, () => on ? app.api.claimStarosta(widget.id) : app.api.leaveStarosta(widget.id)) && mounted) {
      toast(context, on ? 'ახლა სტაროსტა ხარ 🎓' : 'სტაროსტობა დატოვე');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = d, me = context.me.id;
    if (gone) return Scaffold(appBar: peeraBar(context, title: 'ჯგუფი'), body: const Empty(icon: 'users', title: 'ჯგუფი ვერ მოიძებნა', text: 'შეიძლება წაშლილია.'));
    if (x == null) {
      return Scaffold(
        appBar: peeraBar(context, title: 'ჯგუფი'),
        body: error != null ? Empty(icon: 'users', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load) : const Center(child: CircularProgressIndicator()),
      );
    }
    final name = '${g['name'] ?? ''}', kind = '${g['kind'] ?? ''}', rules = '${g['rules'] ?? ''}'.trim(), desc = '${g['description'] ?? ''}'.trim();
    final byRequest = g['is_private'] == true || g['join_mode'] == 'request', locked = g['is_private'] == true && !member;
    final hue = asInt(g['hue'], 200), url = g['avatar_url'] as String?;
    Widget btn(String key, String icon, String label, VoidCallback onTap, {bool filled = false, int badge = 0}) {
      final child = Row(mainAxisSize: MainAxisSize.min, children: [
        PIcon(icon, size: 17, color: filled ? c.onAccent : c.ink),
        const SizedBox(width: 6),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (badge > 0)
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: c.nope, borderRadius: BorderRadius.circular(9)),
            child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
      ]);
      return filled
          ? FilledButton(key: ValueKey(key), style: FilledButton.styleFrom(minimumSize: const Size(0, 42)), onPressed: onTap, child: child)
          : OutlinedButton(key: ValueKey(key), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)), onPressed: onTap, child: child);
    }

    final canStar = (kind == 'class' || kind == 'course') && member && !owner && !starostas.contains(me) && starostas.length < 2;
    final tabs = [('posts', 'edit', 'პოსტები'), ('events', 'cal', 'ღონისძიებები'), ('about', 'help', 'შესახებ')];
    final List<Widget> body = switch (tab) {
      'events' => [GroupEvents(key: const ValueKey('g-events'), groupId: widget.id, member: member)],
      'about' => [GroupAbout(g: g, count: x.count)],
      _ => [
          if (topics.isNotEmpty && !locked)
            SizedBox(
              height: 46,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 4, 12, 6), children: [
                for (final t in [null, ...topics])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey('gtopic-${t ?? 'all'}'),
                      label: Text(t == null ? 'ყველა' : '# $t'),
                      selected: topic == t,
                      showCheckmark: false,
                      selectedColor: c.accentSoft,
                      side: BorderSide(color: topic == t ? c.accent : c.line),
                      onSelected: (_) => _topic(t),
                    ),
                  ),
              ]),
            ),
          if (pinned != null && topic == null && !locked)
            KeyedSubtree(key: const ValueKey('g-pinned'), child: PinnedBox(onUnpin: admin ? () => _pin(null) : null, child: _postCard(pinned!, isPinned: true))),
          if (stars.isNotEmpty && topic == null && !locked) GroupStars(stars: stars),
          if (posts == null)
            const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
          else if (locked)
            const Empty(icon: 'lock', title: 'დახურული ჯგუფი', text: 'პოსტებს მხოლოდ წევრები ხედავენ. გაგზავნე მოთხოვნა და ადმინი დაგიდასტურებს.')
          else if (posts!.isEmpty && (pinned == null || topic != null))
            Empty(
              icon: 'note',
              title: topic != null ? 'ამ რუბრიკაში ჯერ არაფერია' : 'ჯგუფში ჯერ არაფერია',
              text: member ? 'დაწერე პირველი პოსტი.' : 'გაწევრიანდი და დაწერე პირველი პოსტი.',
            )
          else
            for (final p in posts!) _postCard(p),
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
            cover: g['cover_url'] as String?,
            avatar: url,
            coverKey: 'g-cover',
            picKey: 'g-pic',
            onCover: admin ? _cover : null,
            onAvatar: owner ? _pic : (url != null ? () => openPhotos(context, [Media(url: url)]) : null),
            title: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            sub: Text(
              '${g['is_private'] == true ? '🔒 დახურული' : 'ღია'} ჯგუფი · ${x.count} წევრი${g['post_approval'] == true ? ' · პოსტები მოწმდება' : ''}',
              style: TextStyle(color: c.muted, fontSize: 13.5),
            ),
          ),
          if (desc.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: TranslatableBody(desc)),
          const SizedBox(height: 10),
          if (rules.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Material(
                type: MaterialType.transparency,
                child: ExpansionTile(
                  key: const ValueKey('g-rules'),
                  initiallyExpanded: !member,
                  leading: PIcon('flag', size: 18, color: c.muted),
                  title: const Text('ჯგუფის წესები', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(rules, style: const TextStyle(height: 1.45))],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              if (member) ...[
                btn('g-post', 'plus', 'პოსტი', _post, filled: true),
                btn('g-chat', 'msg', 'ჯგუფის ჩატი', _chat),
              ] else if (!byRequest)
                btn('g-join', 'uadd', 'გაწევრიანება', _join, filled: true)
              else if (x.request == 'pending')
                btn('g-reqx', 'clock', 'მოთხოვნა გაგზავნილია', _cancel)
              else
                btn('g-req', 'user', 'მოთხოვნის გაგზავნა', _request, filled: true),
              if (admin)
                btn('g-manage', 'gear', 'მართვა', () async {
                  await openPage(context, GroupManageScreen(g: g, owner: owner), full: true);
                  _load();
                }, badge: waiting),
              if (member && eduInvite.containsKey(kind)) btn('g-invite', 'users', eduInvite[kind]!.$1, _invite),
              if (member && !owner) btn('g-leave', 'out', 'გასვლა', _leave),
              if (owner) btn('g-delete', 'trash', 'წაშლა', _delete),
              btn('g-share', 'send', 'გაზიარება', () => shareText(context, groupLink(widget.id))),
            ]),
          ),
          if (kind == 'class' || kind == 'course')
            Container(
              key: const ValueKey('g-star'),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: BoxDecoration(color: c.gold.withValues(alpha: .12), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.gold.withValues(alpha: .4))),
              child: Row(children: [
                PIcon('star', size: 20, color: c.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: starostas.isEmpty
                      ? const Text.rich(TextSpan(children: [
                          TextSpan(text: 'სტაროსტა ჯერ არ ჰყავს. ', style: TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(text: 'სტაროსტა ჯგუფს უვლის: პოსტებს ამოწმებს და წესებს იცავს.'),
                        ]))
                      : Text.rich(TextSpan(children: [
                          const TextSpan(text: 'სტაროსტა: ', style: TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(text: starostas.map((u) => context.app.people[u]?.name ?? '…').join(', ')),
                        ])),
                ),
                if (canStar)
                  TextButton(key: const ValueKey('g-starme'), onPressed: () => _starosta(true), child: const Text('გავხდე სტაროსტა'))
                else if (starostas.contains(me))
                  TextButton(key: const ValueKey('g-starleave'), onPressed: () => _starosta(false), child: const Text('დატოვება')),
              ]),
            ),
          SlideTabs(tabs: tabs, value: tab, prefix: 'gtb', onChanged: (t) => setState(() => tab = t)),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (ch, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(a), child: ch)),
            child: Column(key: ValueKey('gtab-$tab'), crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
          ),
        ]),
      ),
    );
  }
}

/// Asking to join: a few words for the admin and, when the group has rules, agreeing to them.
class _RequestScreen extends StatefulWidget {
  const _RequestScreen({required this.groupId, required this.rules, this.questions = const []});
  final int groupId;
  final String rules;

  /// the group's questions to whoever wants to join (three at most)
  final List<String> questions;
  @override
  State<_RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<_RequestScreen> {
  final note = TextEditingController();
  late final answers = [for (final _ in widget.questions) TextEditingController()];
  bool agree = false, busy = false;

  @override
  void dispose() {
    note.dispose();
    for (final a in answers) {
      a.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (answers.any((a) => a.text.trim().isEmpty)) {
      toast(context, 'უპასუხე ადმინის კითხვებს');
      return;
    }
    if (widget.rules.isNotEmpty && !agree) {
      toast(context, 'ჯერ დაეთანხმე წესებს');
      return;
    }
    setState(() => busy = true);
    try {
      final t = note.text.trim();
      await context.app.api.requestGroup(widget.groupId, t.isEmpty ? null : t, answers: [for (final a in answers) a.text.trim()]);
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
    return Scaffold(
      appBar: peeraBar(context, title: 'გაწევრიანების მოთხოვნა'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (widget.questions.isNotEmpty) ...[
          Text('ადმინი გეკითხება', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (var i = 0; i < widget.questions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                key: ValueKey('greq-a-$i'),
                controller: answers[i],
                maxLength: 300,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(labelText: '${i + 1}. ${widget.questions[i]}', counterText: ''),
              ),
            ),
        ],
        TextField(
          key: const ValueKey('greq-note'),
          controller: note,
          maxLength: 300,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'რამდენიმე სიტყვა ადმინისთვის (არასავალდებულო)', hintText: 'მაგ. ამ სოფლიდან ვარ, ბაბუაჩემი…'),
        ),
        if (widget.rules.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('წესები', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(widget.rules, style: const TextStyle(height: 1.45)),
            ]),
          ),
          CheckboxListTile(
            key: const ValueKey('greq-agree'),
            contentPadding: EdgeInsets.zero,
            value: agree,
            onChanged: (v) => setState(() => agree = v == true),
            title: const Text('წესები წავიკითხე და ვეთანხმები'),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(key: const ValueKey('greq-send'), onPressed: busy ? null : _send, child: const Text('გაგზავნა')),
      ]),
    );
  }
}

/// Making a group, or changing one (its owner): picture, name, description; and when changing it, the rules, closed
/// or open, joining by request, posts checked first.
class GroupFormScreen extends StatefulWidget {
  const GroupFormScreen({super.key, this.g, this.name = ''});
  final Map<String, dynamic>? g;
  final String name;
  @override
  State<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends State<GroupFormScreen> {
  late final name = TextEditingController(text: '${widget.g?['name'] ?? widget.name}');
  late final desc = TextEditingController(text: '${widget.g?['description'] ?? ''}');
  late final rules = TextEditingController(text: '${widget.g?['rules'] ?? ''}');
  late String? pic = widget.g?['avatar_url'] as String?;
  late bool private = widget.g?['is_private'] == true, byRequest = widget.g?['join_mode'] == 'request', approval = widget.g?['post_approval'] == true;
  late String category = groupCat(widget.g?['category']).$1;
  late final topics = [for (final t in (widget.g?['topics'] as List? ?? const [])) '$t'];
  late final newTopic = TextEditingController();
  late final questions = [
    for (var i = 0; i < 3; i++) TextEditingController(text: i < (widget.g?['questions'] as List? ?? const []).length ? '${(widget.g!['questions'] as List)[i]}' : ''),
  ];
  late final words = TextEditingController(text: [for (final w in (widget.g?['blocked_words'] as List? ?? const [])) '$w'].join(', '));
  bool busy = false;

  bool get edit => widget.g != null;

  @override
  void dispose() {
    name.dispose();
    desc.dispose();
    rules.dispose();
    newTopic.dispose();
    words.dispose();
    for (final q in questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _addTopic() {
    final t = newTopic.text.trim().replaceFirst(RegExp(r'^#\s*'), '');
    if (t.isEmpty) return;
    if (t.length > 24) {
      toast(context, 'რუბრიკა 24 ასომდე იყოს');
      return;
    }
    if (topics.length >= 12) {
      toast(context, 'რუბრიკა მაქსიმუმ 12');
      return;
    }
    setState(() {
      if (!topics.contains(t)) topics.add(t);
      newTopic.clear();
    });
  }

  Future<void> _pic() async {
    try {
      final u = await pickSquarePic(context, 'ჯგუფის სურათი');
      if (u != null && mounted) setState(() => pic = u);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
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
        await api.updateGroup(asInt(widget.g!['id']), {
          'avatar_url': pic,
          'name': n,
          'category': category,
          'description': desc.text.trim(),
          'rules': rules.text.trim().isEmpty ? null : rules.text.trim(),
          'is_private': private,
          'join_mode': byRequest ? 'request' : 'open',
          'post_approval': approval,
          'topics': topics,
          'questions': [for (final q in questions) if (q.text.trim().isNotEmpty) q.text.trim()],
          'blocked_words': {for (final w in words.text.split(RegExp(r'[,\n]'))) if (w.trim().isNotEmpty) w.trim().toLowerCase()}.take(50).toList(),
        });
        if (!mounted) return;
        toast(context, 'შენახულია');
        Navigator.of(context).pop(asInt(widget.g!['id']));
      } else {
        final id = await api.createGroup(name: n, description: desc.text.trim(), private: private, avatarUrl: pic, category: category);
        if (!mounted) return;
        toast(context, 'ჯგუფი შეიქმნა');
        Navigator.of(context).pop(id);
      }
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
      appBar: peeraBar(context, title: edit ? 'ჯგუფის პარამეტრები' : 'ახალი ჯგუფი', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(
            key: const ValueKey('gf-ok'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: busy ? null : _save,
            child: Text(edit ? 'შენახვა' : 'შექმნა'),
          ),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          GestureDetector(key: const ValueKey('gf-pic'), onTap: busy ? null : _pic, child: BoxPic(name: name.text.trim(), hue: asInt(widget.g?['hue'], 200), url: pic, size: 64)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ჯგუფის სურათი', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(pic == null ? 'კვადრატული ფოტო ან ლოგო. შეგიძლია მერეც დაამატო' : 'შეეხე, რომ შეცვალო', style: TextStyle(color: c.muted, fontSize: 13)),
            ]),
          ),
          if (pic != null) TextButton(onPressed: () => setState(() => pic = null), child: const Text('მოშორება')),
        ]),
        const SizedBox(height: 14),
        TextField(key: const ValueKey('gf-name'), controller: name, maxLength: 80, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'სახელი', counterText: '')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const ValueKey('gf-cat'),
          initialValue: category,
          decoration: const InputDecoration(labelText: 'კატეგორია'),
          items: [for (final k in groupCats) DropdownMenuItem(value: k.$1, child: Text('${k.$2} ${k.$3}'))],
          onChanged: (v) => setState(() => category = v ?? 'other'),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('gf-desc'),
          controller: desc,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'აღწერა', hintText: 'რისთვის არის ეს ჯგუფი', counterText: ''),
        ),
        if (edit) ...[
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('gf-rules'),
            controller: rules,
            maxLength: 2000,
            minLines: 3,
            maxLines: 7,
            decoration: const InputDecoration(labelText: 'წესები', hintText: 'მაგ. 1. პატივი ეცით ერთმანეთს. 2. რეკლამა მხოლოდ ადმინის ნებართვით.', counterText: ''),
          ),
        ],
        SwitchListTile(
          key: const ValueKey('gf-private'),
          contentPadding: EdgeInsets.zero,
          value: private,
          onChanged: (v) => setState(() => private = v),
          title: const Text('დახურული ჯგუფი', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('პოსტებს მხოლოდ წევრები ხედავენ, შესვლა მოთხოვნით'),
        ),
        if (edit) ...[
          SwitchListTile(
            key: const ValueKey('gf-request'),
            contentPadding: EdgeInsets.zero,
            value: byRequest,
            onChanged: (v) => setState(() => byRequest = v),
            title: const Text('გაწევრიანება მოთხოვნით', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('ახალ წევრს ადმინი ადასტურებს'),
          ),
          SwitchListTile(
            key: const ValueKey('gf-approval'),
            contentPadding: EdgeInsets.zero,
            value: approval,
            onChanged: (v) => setState(() => approval = v),
            title: const Text('პოსტების შემოწმება', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('ახალი პოსტი ჯგუფში ადმინის დამტკიცების შემდეგ ჩანს'),
          ),
          const SizedBox(height: 14),
          const Text('რუბრიკები', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          Text('პოსტის ავტორი აირჩევს რუბრიკას, წევრები კი მიხედვით გაფილტრავენ.', style: TextStyle(color: c.muted, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final t in topics)
              InputChip(key: ValueKey('gf-topic-$t'), label: Text('# $t'), onDeleted: () => setState(() => topics.remove(t))),
          ]),
          Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('gf-topic-new'),
                controller: newTopic,
                maxLength: 24,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addTopic(),
                decoration: const InputDecoration(hintText: 'მაგ. სიახლეები, კითხვები, ფოტოები', counterText: ''),
              ),
            ),
            IconBtn('plus', key: const ValueKey('gf-topic-add'), label: 'რუბრიკის დამატება', onTap: _addTopic),
          ]),
          const SizedBox(height: 14),
          const Text('კითხვები გაწევრებისას', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          Text('ვინც მოთხოვნას აგზავნის, ამ კითხვებს უპასუხებს. ცარიელი არ გამოჩნდება.', style: TextStyle(color: c.muted, fontSize: 13)),
          const SizedBox(height: 8),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(key: ValueKey('gf-q-$i'), controller: questions[i], maxLength: 160, decoration: InputDecoration(labelText: '${i + 1}. კითხვა', counterText: '')),
            ),
          const SizedBox(height: 6),
          const Text('აკრძალული სიტყვები', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          Text('პოსტი, რომელშიც ასეთი სიტყვაა, ჯერ ადმინთან მივა შესამოწმებლად. მძიმით გამოყავი.', style: TextStyle(color: c.muted, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(key: const ValueKey('gf-words'), controller: words, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'მაგ. რეკლამა, ფასდაკლება')),
        ],
      ]),
    );
  }
}

/// The group's management for its admins: requests to join, posts waiting, members and roles, and (the owner) the
/// settings.
class GroupManageScreen extends StatefulWidget {
  const GroupManageScreen({super.key, required this.g, required this.owner});
  final Map<String, dynamic> g;
  final bool owner;
  @override
  State<GroupManageScreen> createState() => _GroupManageScreenState();
}

class _GroupManageScreenState extends State<GroupManageScreen> {
  late Map<String, dynamic> g = widget.g;
  String tab = 'requests';
  List<Map<String, dynamic>>? reqs, members;
  Map<String, DateTime> muted = const {};
  List<Post>? pending;
  Object? error;
  bool _started = false;

  int get id => asInt(g['id']);

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
      if (tab == 'requests') {
        final r = await app.api.groupRequests(id);
        await app.people.ensure(r.map((x) => '${x['user_id']}'));
        if (mounted) setState(() => reqs = r);
      } else if (tab == 'pending') {
        final p = await app.api.groupPending(id);
        await app.posts.load(p);
        if (mounted) setState(() => pending = p);
      } else if (tab == 'members') {
        final m = await app.api.groupMembers(id);
        await app.people.ensure(m.map((x) => '${x['user_id']}'));
        final mu = await app.api.groupMutes(id).catchError((_) => <String, DateTime>{});
        if (mounted) setState(() => muted = mu);
        final owner = '${g['owner']}';
        int ord(Map<String, dynamic> r) => '${r['user_id']}' == owner ? 0 : (r['role'] == 'admin' ? 1 : 2);
        m.sort((a, b) => ord(a).compareTo(ord(b)));
        if (mounted) setState(() => members = m);
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  void _tab(String k) {
    if (k == 'settings') {
      // saving the settings closes them and comes back here (one step), with the group read again
      openPage<int>(context, GroupFormScreen(g: g), full: true).then((v) async {
        if (v == null || !mounted) return;
        final r = await context.app.api.group(id).catchError((_) => null);
        if (r != null && mounted) setState(() => g = r.g);
      });
      return;
    }
    setState(() {
      tab = k;
      error = null;
    });
    _load();
  }

  Future<void> _mute(String u, Profile p) async {
    final app = context.app;
    final m = await muteSheet(context, p.name, until: muted[u]);
    if (m == null || !mounted) return;
    if (await attempt(context, () => app.api.muteInGroup(id, u, m)) && mounted) {
      toast(context, m == 0 ? 'დადუმება მოიხსნა' : 'დადუმდა');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, me = context.me.id, owner = '${g['owner']}';
    final qs = [for (final q in (g['questions'] as List? ?? const [])) '$q'];
    Widget body;
    if (error != null) {
      body = Empty(icon: 'users', title: 'ვერ ჩაიტვირთა', text: errText(error!));
    } else if (tab == 'requests') {
      final r = reqs;
      body = r == null
          ? const Center(child: CircularProgressIndicator())
          : r.isEmpty
              ? const Empty(icon: 'user', title: 'ახალი მოთხოვნები არ არის')
              : ListView(children: [
                  for (final x in r)
                    Builder(builder: (context) {
                      final u = '${x['user_id']}', p = app.people[u] ?? Profile(id: u, name: '…');
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            GestureDetector(onTap: () => openPage(context, PersonScreen(uid: u, initial: p), full: true), child: Avatar(p: p, size: 42)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                NameLine(p, size: 15),
                                Text(ago(asTime(x['created_at'])), style: TextStyle(color: c.muted, fontSize: 12.5)),
                              ]),
                            ),
                          ]),
                          for (final (i, a) in [for (final v in (x['answers'] as List? ?? const [])) '$v'].indexed)
                            Container(
                              key: ValueKey('gm-ans-$u-$i'),
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(10)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (i < qs.length) Text(qs[i], style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
                                Text(a),
                              ]),
                            ),
                          if ('${x['note'] ?? ''}'.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(10)),
                              child: Text('${x['note']}'),
                            ),
                          const SizedBox(height: 6),
                          Row(children: [
                            FilledButton(
                              key: ValueKey('gm-ok-$u'),
                              style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                              onPressed: () async {
                                if (await attempt(context, () => app.api.groupRespond(id, u, true)) && mounted) {
                                  toast(context, 'მიღებულია');
                                  setState(() => reqs = [for (final y in reqs!) if (y['user_id'] != u) y]);
                                }
                              },
                              child: const Text('მიღება'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              key: ValueKey('gm-no-$u'),
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                              onPressed: () async {
                                if (await attempt(context, () => app.api.groupRespond(id, u, false)) && mounted) {
                                  toast(context, 'უარყოფილია');
                                  setState(() => reqs = [for (final y in reqs!) if (y['user_id'] != u) y]);
                                }
                              },
                              child: const Text('უარი'),
                            ),
                          ]),
                        ]),
                      );
                    }),
                ]);
    } else if (tab == 'pending') {
      final p = pending;
      body = p == null
          ? const Center(child: CircularProgressIndicator())
          : p.isEmpty
              ? Empty(
                  icon: 'note',
                  title: 'დასამტკიცებელი პოსტები არ არის',
                  text: g['post_approval'] == true ? null : 'ჩართე „პოსტების შემოწმება“ პარამეტრებში, თუ გინდა, რომ ახალ პოსტებს ჯერ ადმინი ნახავდეს.',
                )
              : ListView(children: [
                  for (final x in p) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        FilledButton.icon(
                          key: ValueKey('gp-ok-${x.id}'),
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                          onPressed: () async {
                            if (await attempt(context, () => app.api.reviewGroupPost(x.id, true)) && mounted) {
                              toast(context, 'დამტკიცდა');
                              setState(() => pending = [for (final y in pending!) if (y.id != x.id) y]);
                            }
                          },
                          icon: PIcon('check', size: 16, color: c.onAccent),
                          label: const Text('დამტკიცება'),
                        ),
                        OutlinedButton(
                          key: ValueKey('gp-no-${x.id}'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), foregroundColor: c.nope),
                          onPressed: () async {
                            if (await attempt(context, () => app.api.reviewGroupPost(x.id, false)) && mounted) {
                              toast(context, 'უარყოფილია');
                              setState(() => pending = [for (final y in pending!) if (y.id != x.id) y]);
                            }
                          },
                          child: const Text('უარყოფა'),
                        ),
                      ]),
                    ),
                    PostCard(post: x),
                  ],
                ]);
    } else if (tab == 'log') {
      body = GroupLog(id: id);
    } else if (tab == 'stats') {
      body = GroupStatsView(id: id);
    } else {
      final m = members;
      body = m == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 4), child: Text('${m.length} წევრი', style: TextStyle(color: c.muted))),
              for (final r in m)
                Builder(builder: (context) {
                  final u = '${r['user_id']}', p = app.people[u] ?? Profile(id: u, name: '…');
                  final isOwner = u == owner, isAdm = r['role'] == 'admin';
                  return ListTile(
                    key: ValueKey('gmm-$u'),
                    leading: Avatar(p: p, size: 40),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        [
                          isOwner ? 'მფლობელი' : (isAdm ? 'ადმინი' : 'წევრი'),
                          if (muted[u] != null) '🔇 დადუმებულია',
                          ago(asTime(r['created_at'])),
                        ].join(' · '),
                        style: TextStyle(color: muted[u] != null ? c.gold : c.muted)),
                    onTap: () => openPage(context, PersonScreen(uid: u, initial: p), full: true),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (widget.owner && !isOwner)
                        TextButton(
                          key: ValueKey('gm-role-$u'),
                          onPressed: () async {
                            final role = isAdm ? 'member' : 'admin';
                            if (await attempt(context, () => app.api.setGroupRole(id, u, role)) && mounted) {
                              toast(context, role == 'admin' ? 'ადმინი გახდა' : 'ადმინობა მოეხსნა');
                              _load();
                            }
                          },
                          child: Text(isAdm ? 'ადმინის მოხსნა' : 'ადმინად'),
                        ),
                      if (!isOwner && !isAdm && u != me)
                        IconBtn(muted[u] != null ? 'vol' : 'mute',
                            key: ValueKey('gm-mute-$u'), label: 'დადუმება', size: 18, color: muted[u] != null ? c.gold : c.muted, onTap: () => _mute(u, p)),
                      if (!isOwner && u != me && (widget.owner || !isAdm))
                        IconBtn('x', key: ValueKey('gm-kick-$u'), label: 'ჯგუფიდან მოშორება', size: 18, color: c.muted, onTap: () async {
                          if (!await confirm(context, title: 'წევრის მოშორება', text: '${p.name} აღარ იქნება ჯგუფის წევრი.', yes: 'მოშორება', danger: true) || !mounted) return;
                          if (await attempt(context, () => app.api.kickFromGroup(id, u)) && mounted) {
                            toast(context, 'მოშორდა');
                            setState(() => members = [for (final y in members!) if (y['user_id'] != u) y]);
                          }
                        }),
                    ]),
                  );
                }),
            ]);
    }
    return Scaffold(
      appBar: peeraBar(context, title: 'ჯგუფის მართვა'),
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(children: [
            for (final (k, l) in [('requests', 'მოთხოვნები'), ('pending', 'პოსტები'), ('members', 'წევრები'), ('stats', 'სტატისტიკა'), ('log', 'ჟურნალი'), ('settings', 'პარამეტრები')])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  key: ValueKey('gmt-$k'),
                  label: Text(l),
                  selected: tab == k,
                  showCheckmark: false,
                  selectedColor: c.accentSoft,
                  side: BorderSide(color: tab == k ? c.accent : c.line),
                  onSelected: (_) => _tab(k),
                ),
              ),
          ]),
        ),
        Expanded(child: body),
      ]),
    );
  }
}
