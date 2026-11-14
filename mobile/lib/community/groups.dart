// Groups (community.js): mine and the ones to discover; a group's page with its rules, members' count, posts (a
// closed group shows them to members only), joining at once or by a request, the starosta of a class or a course,
// an invite with a link and a QR code; and for its admins the management: requests, posts waiting for approval,
// members and roles, the settings.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
import 'events.dart';

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

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
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
      final r = await context.app.api.groups();
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
    final id = await openPage<int>(context, const GroupFormScreen(), full: true);
    if (id != null && mounted) {
      _load();
      await openPage(context, GroupScreen(id: id), full: true);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, me = context.me.id, x = d;
    Widget sec(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)));
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
                    final mine = [for (final g in x.$2) if (x.$1.contains(asInt(g['id'])) || g['owner'] == me) g];
                    // my village's or town's groups (community.js placeGroups): suggested, never made for me
                    final home = (context.me.homePlace ?? '').trim();
                    bool near(Map<String, dynamic> g) => home.isNotEmpty && '${g['name'] ?? ''}'.toLowerCase().contains(home.toLowerCase());
                    final corner = [for (final g in x.$2) if (!x.$1.contains(asInt(g['id'])) && g['owner'] != me && near(g)) g].take(6).toList();
                    final other = [for (final g in x.$2) if (!x.$1.contains(asInt(g['id'])) && g['owner'] != me && !corner.contains(g)) g];
                    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                      if (mine.isNotEmpty) ...[sec('ჩემი ჯგუფები'), for (final g in mine) GroupRow(g: g)],
                      if (corner.isNotEmpty) ...[sec('შენი კუთხის ჯგუფები'), for (final g in corner) GroupRow(g: g)],
                      if (home.isNotEmpty && !x.$2.any(near))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('შენი კუთხის ჯგუფი ჯერ არ არის. შექმენი და მოიწვიე თანასოფლელები:', style: TextStyle(color: c.muted)),
                            const SizedBox(height: 6),
                            ActionChip(
                              key: const ValueKey('groups-home'),
                              avatar: PIcon('plus', size: 16, color: c.accent),
                              label: Text(home),
                              onPressed: () async {
                                final id = await openPage<int>(context, GroupFormScreen(name: home), full: true);
                                if (id != null && context.mounted) {
                                  _load();
                                  await openPage(context, GroupScreen(id: id), full: true);
                                }
                              },
                            ),
                          ]),
                        ),
                      sec('აღმოაჩინე'),
                      if (other.isEmpty)
                        const Empty(icon: 'users', title: 'სხვა ჯგუფები ჯერ არ არის', text: 'შექმენი პირველი და მოიწვიე მეგობრები.')
                      else
                        for (final g in other) GroupRow(g: g),
                    ]);
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
  List<String> starostas = const [];
  int waiting = 0;
  Object? error;
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
      final p = await app.api.groupPosts(widget.id);
      await app.posts.load(p);
      if (mounted) setState(() => posts = p);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
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
    final ok = await openPage<bool>(context, _RequestScreen(groupId: widget.id, rules: rules), full: true);
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
    if (!await confirm(context, title: 'ჯგუფის წაშლა', text: 'წაიშლება ჯგუფი და მისი ყველა პოსტი.', yes: 'წაშლა', danger: true) || !mounted) return;
    if (await attempt(context, () => context.app.api.deleteGroup(widget.id)) && mounted) {
      toast(context, 'ჯგუფი წაიშალა');
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _post() async {
    final p = await openPage<Post>(context, ComposeScreen(groupId: widget.id, where: '${g['name']}'), full: true);
    if (p != null && mounted) {
      if (g['post_approval'] == true && !admin) toast(context, 'პოსტი გამოჩნდება ადმინის დამტკიცების შემდეგ');
      _load();
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

  Future<void> _invite() {
    final k = eduInvite['${g['kind']}'] ?? ('მოიწვიე', 'ჯგუფში');
    final url = '$siteUrl/#join-${widget.id}';
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => SafeArea(
        child: Padding(
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
    final byRequest = g['is_private'] == true || g['join_mode'] == 'request';
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
                key: const ValueKey('g-pic'),
                onTap: owner ? _pic : (url != null ? () => openPhotos(context, [Media(url: url)]) : null),
                child: Stack(children: [
                  BoxPic(name: name, hue: hue, url: url, size: 76),
                  if (owner)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const PIcon('camera', size: 14, color: Colors.white),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    '${g['is_private'] == true ? '🔒 დახურული' : 'ღია'} ჯგუფი · ${x.count} წევრი${g['post_approval'] == true ? ' · პოსტები მოწმდება' : ''}',
                    style: TextStyle(color: c.muted, fontSize: 13.5),
                  ),
                ]),
              ),
            ]),
          ),
          if (desc.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: TranslatableBody(desc)),
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
                btn('g-event', 'cal', 'ღონისძიება', () => openPage(context, EventFormScreen(groupId: widget.id), full: true)),
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
          Container(height: 8, color: c.bg),
          if (posts == null)
            const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
          else if (g['is_private'] == true && !member)
            const Empty(icon: 'lock', title: 'დახურული ჯგუფი', text: 'პოსტებს მხოლოდ წევრები ხედავენ. გაგზავნე მოთხოვნა და ადმინი დაგიდასტურებს.')
          else if (posts!.isEmpty)
            Empty(icon: 'note', title: 'ჯგუფში ჯერ არაფერია', text: member ? 'დაწერე პირველი პოსტი.' : 'გაწევრიანდი და დაწერე პირველი პოსტი.')
          else
            for (final p in posts!)
              PostCard(key: ValueKey('gpost-${p.id}'), post: p, onDeleted: () => setState(() => posts = [for (final y in posts!) if (y.id != p.id) y])),
        ]),
      ),
    );
  }
}

/// Asking to join: a few words for the admin and, when the group has rules, agreeing to them.
class _RequestScreen extends StatefulWidget {
  const _RequestScreen({required this.groupId, required this.rules});
  final int groupId;
  final String rules;
  @override
  State<_RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<_RequestScreen> {
  final note = TextEditingController();
  bool agree = false, busy = false;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (widget.rules.isNotEmpty && !agree) {
      toast(context, 'ჯერ დაეთანხმე წესებს');
      return;
    }
    setState(() => busy = true);
    try {
      final t = note.text.trim();
      await context.app.api.requestGroup(widget.groupId, t.isEmpty ? null : t);
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
  bool busy = false;

  bool get edit => widget.g != null;

  @override
  void dispose() {
    name.dispose();
    desc.dispose();
    rules.dispose();
    super.dispose();
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
          'description': desc.text.trim(),
          'rules': rules.text.trim().isEmpty ? null : rules.text.trim(),
          'is_private': private,
          'join_mode': byRequest ? 'request' : 'open',
          'post_approval': approval,
        });
        if (!mounted) return;
        toast(context, 'შენახულია');
        Navigator.of(context).pop(asInt(widget.g!['id']));
      } else {
        final id = await api.createGroup(name: n, description: desc.text.trim(), private: private, avatarUrl: pic);
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
  String tab = 'requests';
  List<Map<String, dynamic>>? reqs, members;
  List<Post>? pending;
  Object? error;
  bool _started = false;

  int get id => asInt(widget.g['id']);

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
        final owner = '${widget.g['owner']}';
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
      openPage<int>(context, GroupFormScreen(g: widget.g), full: true).then((v) {
        if (v != null && mounted) Navigator.of(context).maybePop();
      });
      return;
    }
    setState(() {
      tab = k;
      error = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, me = context.me.id, owner = '${widget.g['owner']}';
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
                  text: widget.g['post_approval'] == true ? null : 'ჩართე „პოსტების შემოწმება“ პარამეტრებში, თუ გინდა, რომ ახალ პოსტებს ჯერ ადმინი ნახავდეს.',
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
                    subtitle: Text('${isOwner ? 'მფლობელი' : (isAdm ? 'ადმინი' : 'წევრი')} · ${ago(asTime(r['created_at']))}', style: TextStyle(color: c.muted)),
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
            for (final (k, l) in [('requests', 'მოთხოვნები'), ('pending', 'პოსტები'), ('members', 'წევრები'), if (widget.owner) ('settings', 'პარამეტრები')])
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
