// A group as the big networks keep theirs: the month's most active members, its events, what it is about; and for
// its admins the log of what was done, the group's numbers and a member kept quiet for a while.
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../people/person_screen.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/translate.dart';
import '../ui/widgets.dart';
import 'community_ui.dart';
import 'events.dart';

/// How long a member stays quiet; 0 lifts it. Null when nothing was chosen.
Future<int?> muteSheet(BuildContext context, String name, {DateTime? until}) => showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text('$name · დადუმება', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('დადუმებული წევრი ჯგუფს კითხულობს, მაგრამ ვერც პოსტს წერს, ვერც კომენტარს.', style: TextStyle(color: s.pc.muted, fontSize: 13)),
          ),
          for (final (m, t) in const [(60, '1 საათით'), (1440, '1 დღით'), (10080, '1 კვირით'), (43200, '30 დღით')])
            ListTile(key: ValueKey('mute-$m'), leading: PIcon('mute', color: s.pc.ink), title: Text(t), onTap: () => Navigator.of(s).pop(m)),
          if (until != null)
            ListTile(
              key: const ValueKey('mute-0'),
              leading: PIcon('vol', color: s.pc.vine),
              title: Text('დადუმების მოხსნა', style: TextStyle(color: s.pc.vine, fontWeight: FontWeight.w700)),
              subtitle: Text('ახლა დადუმებულია ${fullDate(until.toLocal())}-მდე', style: TextStyle(color: s.pc.muted, fontSize: 12.5)),
              onTap: () => Navigator.of(s).pop(0),
            ),
          const SizedBox(height: 6),
        ]),
      ),
    );

/// The month's most active members, with a small flame: who they are and how much they wrote.
class GroupStars extends StatelessWidget {
  const GroupStars({super.key, required this.stars});
  final List<({String uid, int posts, int comments})> stars;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app;
    return Rise(
      order: 2,
      child: Container(
        key: const ValueKey('g-stars'),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: cardLook(context, radius: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🔥', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            const Expanded(child: Text('თვის აქტიური წევრები', style: TextStyle(fontWeight: FontWeight.w800))),
            Text('30 დღე', style: TextStyle(color: c.muted, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < stars.length; i++)
                Builder(builder: (context) {
                  final s = stars[i], p = app.people[s.uid] ?? Profile(id: s.uid, name: '…');
                  return Pressable(
                    key: ValueKey('gstar-${s.uid}'),
                    onTap: () => openPage(context, PersonScreen(uid: s.uid, initial: p)),
                    child: SizedBox(
                      width: 78,
                      child: Column(children: [
                        Stack(clipBehavior: Clip.none, children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: i == 0 ? [c.gold, const Color(0xFFFF7A3D)] : [c.accent, c.accent.withValues(alpha: .5)]),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                              child: Avatar(p: p, size: 50),
                            ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(color: i == 0 ? c.gold : c.accent, borderRadius: BorderRadius.circular(9), border: Border.all(color: c.surface, width: 2)),
                              child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 5),
                        Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        Text('${s.posts} პოსტი · ${s.comments} კომ.', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 11)),
                      ]),
                    ),
                  );
                }),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// What a group is: its words, closed or open, how one joins, since when, its rules and topics.
class GroupAbout extends StatelessWidget {
  const GroupAbout({super.key, required this.g, required this.count});
  final Map<String, dynamic> g;
  final int count;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, desc = '${g['description'] ?? ''}'.trim(), rules = '${g['rules'] ?? ''}'.trim();
    final topics = [for (final t in (g['topics'] as List? ?? const [])) '$t'];
    final private = g['is_private'] == true, byReq = private || g['join_mode'] == 'request';
    Widget row(String icon, String t, String sub) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(10)),
              child: PIcon(icon, size: 17, color: c.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(sub, style: TextStyle(color: c.muted, fontSize: 12.5)),
              ]),
            ),
          ]),
        );
    final items = <Widget>[
      if (desc.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 6), child: TranslatableBody(desc)),
      row(private ? 'lock' : 'globe', private ? 'დახურული ჯგუფი' : 'ღია ჯგუფი', private ? 'პოსტებს და წევრებს მხოლოდ წევრები ხედავენ' : 'პოსტებს ყველა ხედავს'),
      row('uadd', byReq ? 'გაწევრიანება მოთხოვნით' : 'გაწევრიანება თავისუფლად', byReq ? 'ახალ წევრს ადმინი ადასტურებს' : 'ნებისმიერს შეუძლია შემოსვლა'),
      row('users', '$count წევრი', g['created_at'] == null ? 'ჯგუფი' : 'შეიქმნა ${dayLabel(asTime(g['created_at']).toLocal())}'),
      if (g['post_approval'] == true) row('shield', 'პოსტები მოწმდება', 'ახალი პოსტი ადმინის დამტკიცების შემდეგ ჩანს'),
      if (topics.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final t in topics)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(20)),
                child: Text('# $t', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
          ]),
        ),
      if (rules.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('წესები', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(rules, style: const TextStyle(height: 1.45)),
          ]),
        ),
    ];
    return Container(
      key: const ValueKey('g-about'),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: cardLook(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < items.length; i++) Rise(order: i, child: items[i])]),
    );
  }
}

/// A group's coming events, and making one (its members).
class GroupEvents extends StatefulWidget {
  const GroupEvents({super.key, required this.groupId, required this.member});
  final int groupId;
  final bool member;
  @override
  State<GroupEvents> createState() => _GroupEventsState();
}

class _GroupEventsState extends State<GroupEvents> {
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)? d;
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
      final r = await app.api.events(groupId: widget.groupId);
      await app.people.ensure(r.$2.map((x) => '${x['user_id']}'));
      if (mounted) setState(() => d = r);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _new() async {
    final id = await openPage<int>(context, EventFormScreen(groupId: widget.groupId), full: true);
    if (id != null && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = d;
    if (x == null) {
      return error != null
          ? Empty(icon: 'cal', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
          : const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.member)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
          child: OutlinedButton.icon(
            key: const ValueKey('g-event'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            onPressed: _new,
            icon: PIcon('cal', size: 17, color: c.accent),
            label: const Text('ღონისძიების შექმნა'),
          ),
        ),
      if (x.$1.isEmpty)
        Empty(icon: 'cal', title: 'მომავალი ღონისძიებები არ არის', text: widget.member ? 'დაგეგმე შეხვედრა, ლაშქრობა ან ლექცია და წევრები გაიგებენ.' : null)
      else
        for (var i = 0; i < x.$1.length; i++) Rise(order: i, child: EventTile(e: x.$1[i], rsvps: x.$2, onBack: _load)),
    ]);
  }
}

String _mins(int m) => m >= 43200 ? '30 დღით' : (m >= 10080 ? '${m ~/ 10080} კვირით' : (m >= 1440 ? '${m ~/ 1440} დღით' : '${(m / 60).ceil()} საათით'));

/// What the group's admins did, newest first.
class GroupLog extends StatefulWidget {
  const GroupLog({super.key, required this.id});
  final int id;
  @override
  State<GroupLog> createState() => _GroupLogState();
}

class _GroupLogState extends State<GroupLog> {
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
      final r = await app.api.groupLog(widget.id);
      await app.people.ensure([for (final x in r) ...['${x['actor']}', if (x['target'] != null) '${x['target']}']]);
      if (mounted) setState(() => list = r);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, l = list;
    if (l == null) {
      return error != null ? Empty(icon: 'note', title: 'ვერ ჩაიტვირთა', text: errText(error!)) : const Center(child: CircularProgressIndicator());
    }
    if (l.isEmpty) return const Empty(icon: 'note', title: 'ჟურნალი ცარიელია', text: 'აქ ჩაიწერება, ვინ ვინ მიიღო, რა დაამტკიცა ან წაშალა.');
    String who(Object? u) => u == null ? '' : (app.people['$u']?.name ?? '…');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        for (var i = 0; i < l.length; i++)
          Builder(builder: (context) {
            final r = l[i], t = who(r['target']), note = '${r['note'] ?? ''}';
            final (icon, color, text) = switch ('${r['action']}') {
              'accept' => ('uadd', c.vine, 'მიიღო ჯგუფში $t'),
              'decline' => ('x', c.nope, 'უარი უთხრა $t-ს'),
              'role' => ('shield', c.accent, note == 'admin' ? 'ადმინი გახადა $t' : 'ადმინობა მოუხსნა $t-ს'),
              'remove' => ('out', c.nope, 'ჯგუფიდან მოაშორა $t'),
              'approve' => ('check', c.vine, 'დაამტკიცა $t-ს პოსტი'),
              'decline_post' => ('x', c.nope, 'უარყო $t-ს პოსტი'),
              'delete_post' => ('trash', c.nope, 'წაშალა $t-ს პოსტი'),
              'pin' => ('pin', c.gold, 'მიამაგრა პოსტი'),
              'unpin' => ('pin', c.muted, 'მოხსნა მიმაგრებული პოსტი'),
              'settings' => ('gear', c.accent, 'შეცვალა ჯგუფის პარამეტრები'),
              'mute' => ('mute', c.gold, 'დაადუმა $t ${_mins(int.tryParse(note) ?? 0)}'),
              'unmute' => ('vol', c.vine, 'დადუმება მოუხსნა $t-ს'),
              _ => ('note', c.muted, '${r['action']}'),
            };
            final snippet = const {'approve', 'decline_post', 'delete_post'}.contains('${r['action']}') && note.isNotEmpty ? note : null;
            return Rise(
              order: i,
              child: ListTile(
                key: ValueKey('glog-${r['id']}'),
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: color.withValues(alpha: .13), shape: BoxShape.circle),
                  child: PIcon(icon, size: 17, color: color),
                ),
                title: Text.rich(TextSpan(children: [
                  TextSpan(text: who(r['actor']), style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: ' $text'),
                ])),
                subtitle: Text([if (snippet != null) '„$snippet“', ago(asTime(r['created_at']))].join(' · '),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5)),
              ),
            );
          }),
      ]),
    );
  }
}

/// The group's numbers for its admins: members and how they grew, posts, comments, who was active.
class GroupStatsView extends StatefulWidget {
  const GroupStatsView({super.key, required this.id});
  final int id;
  @override
  State<GroupStatsView> createState() => _GroupStatsViewState();
}

class _GroupStatsViewState extends State<GroupStatsView> {
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
      final r = await context.app.api.groupStats(widget.id);
      if (mounted) setState(() => s = r);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = s;
    if (x == null) {
      return error != null ? Empty(icon: 'poll', title: 'ვერ ჩაიტვირთა', text: errText(error!)) : const Center(child: CircularProgressIndicator());
    }
    final members = asInt(x['members']), active = asInt(x['active30']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.only(top: 6, bottom: 24), children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 2, 16, 10), child: Text('ბოლო 30 დღე', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600))),
        StatGrid(tiles: [
          StatTile(key: const ValueKey('gs-members'), icon: 'users', label: 'წევრი', value: members, plus: asInt(x['new7']), order: 0),
          StatTile(icon: 'uadd', label: 'ახალი წევრი', value: asInt(x['new30']), order: 1),
          StatTile(icon: 'edit', label: 'პოსტი', value: asInt(x['posts30']), order: 2),
          StatTile(icon: 'comment', label: 'კომენტარი', value: asInt(x['comments30']), order: 3),
          StatTile(icon: 'heart', label: 'აქტიური წევრი', value: active, order: 4),
          StatTile(icon: 'poll', label: 'აქტიურობა, %', value: members == 0 ? 0 : (active * 100 / members).round(), order: 5),
        ]),
        DayBars(days: [for (final d in (x['daily'] as List? ?? const [])) Map<String, dynamic>.from(d as Map)], title: 'ახალი წევრები დღეების მიხედვით'),
      ]),
    );
  }
}
