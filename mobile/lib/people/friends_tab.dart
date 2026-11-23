import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../map/live_map.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'family.dart';
import 'people_cards.dart';
import 'person_screen.dart';
import 'search_screen.dart';

/// Friends, requests to you, and people you may know, under a switch whose marker slides between them. Friends: my
/// relatives first (the people on Peera in my family tree, each with the tree's word for them), then the friends online
/// now in a row, then all of them, each a card with a button to write. Requests: each a card with its
/// two answers; one accepted stays a moment, saying you are friends now. People you may know: two to a row, the
/// picture large, as Facebook shows them.
class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});
  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  int seg = 0;
  List<Suggestion>? sugg;
  Set<String> hidden = {};
  Object? error;
  bool _started = false, _chosen = false;
  String find = '';
  final findCtl = TextEditingController();

  /// my family tree's rows (null while they load)
  List<Map<String, dynamic>>? kin;

  /// the row of friends online shows them all once "+N" is tapped
  bool allOnline = false;

  /// requests accepted here: they stay in the list a moment, saying so
  final accepted = <String>{};
  ValueNotifier<int?>? _segAsk;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final ask = _segAsk = context.app.friendsSeg..addListener(_asked);
    if (ask.value != null) {
      seg = ask.value!;
      _chosen = true;
      ask.value = null;
    }
    HiddenSuggestions.load().then((h) {
      if (mounted) setState(() => hidden = {...h});
    });
    _load();
  }

  @override
  void dispose() {
    _segAsk?.removeListener(_asked);
    findCtl.dispose();
    super.dispose();
  }

  /// another page asked for one of the parts (the feed's "ყველას ნახვა")
  void _asked() {
    final v = _segAsk?.value;
    if (v == null) return;
    _segAsk!.value = null;
    if (mounted) {
      setState(() {
        seg = v;
        _chosen = true;
      });
    }
  }

  Future<void> _load() async {
    final app = context.app;
    try {
      await Future.wait([
        app.friends.load(),
        app.api.kinOf(app.api.myId).then((rows) async {
          await app.people.ensure([for (final r in rows) if (r['relative'] != null) '${r['relative']}']);
          if (mounted) setState(() => kin = rows);
        }, onError: (_) {
          if (mounted) setState(() => kin ??= const []);
        }),
        app.api.suggestions().then((s) {
          for (final x in s) {
            app.people.put(x.p);
          }
          if (mounted) setState(() => sugg = s);
        }, onError: (_) {
          if (mounted) setState(() => sugg = const []);
        }),
      ]);
      if (!mounted) return;
      setState(() {
        error = null;
        // with requests waiting, they come first
        if (!_chosen && app.friends.incoming.isNotEmpty) seg = 1;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  void _open(Profile p) => openPage(context, PersonScreen(uid: p.id, initial: p));

  void _pick(int i) => setState(() {
        seg = i;
        _chosen = true;
        accepted.clear();
      });

  Future<void> _accept(Profile p) async {
    setState(() => accepted.add(p.id));
    final ok = await attempt(context, () => context.app.friends.accept(p.id));
    if (!ok && mounted) setState(() => accepted.remove(p.id));
  }

  Widget _spinner() => const Center(child: SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 2.4)));

  // ---------- friends ----------

  /// the people on Peera in my family tree (their request answered), each with the tree's word for them
  List<(Profile, String)> _relatives(Profile Function(String) who) {
    final rows = kin;
    if (rows == null || rows.isEmpty) return const [];
    final people = context.app.people;
    final n = buildTree(context.me, rows, (id) => people[id]);
    return [for (final x in n.values) if (!x.root && x.uid != null && !x.pending) (who(x.uid!), x.label)];
  }

  Widget _friends(List<Profile> friends, List<(Profile, String)> relatives) {
    final c = context.pc;
    final online = [for (final p in friends) if (p.online) p];
    final q = find.trim().toLowerCase();
    final shown = q.isEmpty ? friends : [for (final p in friends) if (p.fullName.toLowerCase().contains(q) || (p.username ?? '').toLowerCase().contains(q)) p];
    final row = allOnline || online.length <= 5 ? online : online.take(4).toList();
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      // relatives, from the family tree
      if (q.isEmpty && kin != null) ...[
        SectionHead('ნათესავები', count: relatives.length, padding: const EdgeInsets.fromLTRB(16, 6, 12, 8)),
        if (relatives.isEmpty)
          _KinHint(onOpen: () => openPage(context, TreeScreen(uid: context.app.api.myId)))
        else
          for (final (i, (p, word)) in relatives.indexed)
            Rise(
              key: ValueKey('kin-${p.id}'),
              order: i,
              child: _FriendCard(p: p, kin: word, onOpen: () => _open(p), onWrite: () => chatWith(context, p.id)),
            ),
      ],
      if (friends.isEmpty)
        Empty(icon: 'users', title: 'ჯერ მეგობრები არ გყავს', text: 'მოძებნე ნაცნობები ან ნახე, ვის შეიძლება იცნობდე.', action: 'შეიძლება იცნობდე', onAction: () => _pick(2))
      else ...[
        // only the friends online now
        if (online.isNotEmpty && q.isEmpty) ...[
          SectionHead('ონლაინ მეგობრები', count: online.length, padding: const EdgeInsets.fromLTRB(16, 14, 12, 8)),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (i, p) in row.indexed)
                  Rise(
                    order: i,
                    dy: 10,
                    child: Pressable(
                      key: ValueKey('fr-on-${p.id}'),
                      onTap: () => chatWith(context, p.id),
                      child: SizedBox(
                        width: 72,
                        child: Column(children: [
                          Avatar(p: p, size: 58, online: true),
                          const SizedBox(height: 6),
                          Text(p.name.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
                if (row.length < online.length)
                  Pressable(
                    key: const ValueKey('fr-on-more'),
                    onTap: () => setState(() => allOnline = true),
                    child: SizedBox(
                      width: 72,
                      child: Column(children: [
                        Container(
                          width: 58,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(c.accent, Colors.white, .2)!, c.accent]),
                          ),
                          child: Text('+${online.length - row.length}', style: TextStyle(color: c.onAccent, fontSize: 17, fontWeight: FontWeight.w900)),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (friends.length > 4)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
            child: TextField(
              key: const ValueKey('fr-find'),
              controller: findCtl,
              onChanged: (v) => setState(() => find = v),
              decoration: InputDecoration(
                hintText: 'მოძებნე მეგობრებში',
                isDense: true,
                filled: true,
                fillColor: c.surface,
                prefixIcon: Padding(padding: const EdgeInsets.all(11), child: PIcon('search', size: 18, color: c.muted)),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.accent, width: 1.5)),
              ),
            ),
          ),
        SectionHead(q.isEmpty ? 'ყველა მეგობარი' : 'ნაპოვნი', count: shown.length),
        if (shown.isEmpty)
          Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('ასეთი მეგობარი ვერ ვიპოვე', style: TextStyle(color: c.muted))))
        else if (q.isEmpty)
          // all of them as a sideways row of raised photo cards, as on Facebook (a search lists the found ones)
          SingleChildScrollView(
            key: const ValueKey('fr-row'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (i, p) in shown.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Rise(
                    key: ValueKey('frr-${p.id}'),
                    order: i,
                    dy: 10,
                    child: Pressable(onTap: () => _open(p), child: FriendPhotoCard(p: p, onOpen: () => _open(p), onWrite: () => chatWith(context, p.id))),
                  ),
                ),
            ]),
          )
        else
          for (final (i, p) in shown.indexed)
            Rise(
              key: ValueKey('frr-${p.id}'),
              order: i,
              child: _FriendCard(p: p, onOpen: () => _open(p), onWrite: () => chatWith(context, p.id)),
            ),
      ],
    ]);
  }

  // ---------- requests ----------

  Widget _requests(List<Profile> incoming, List<Profile> outgoing, List<Profile> justFriends) {
    final c = context.pc, f = context.app.friends;
    final asks = [...justFriends, ...incoming];
    if (asks.isEmpty && outgoing.isEmpty) {
      return ListView(children: [
        const Empty(icon: 'uadd', title: 'მოთხოვნები არ არის', text: 'ვინც მეგობრობას გთხოვს, აქ გამოჩნდება.'),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => _pick(2),
            icon: PIcon('search', size: 18, color: c.accent),
            label: const Text('ნახე, ვის შეიძლება იცნობდე'),
          ),
        ),
      ]);
    }
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      if (asks.isNotEmpty) SectionHead('მეგობრობას გთხოვენ', count: incoming.length, padding: const EdgeInsets.fromLTRB(16, 6, 12, 8)),
      for (final (i, p) in asks.indexed)
        Rise(
          key: ValueKey('rq-${p.id}'),
          order: i,
          child: _RequestCard(
            p: p,
            done: accepted.contains(p.id) && f.stateWith(p.id) == Friendship.friends,
            onOpen: () => _open(p),
            onAccept: () => _accept(p),
            onDecline: () => attempt(context, () => f.remove(p.id)),
            onWrite: () => chatWith(context, p.id),
          ),
        ),
      if (outgoing.isNotEmpty) ...[
        SectionHead('შენ გაგზავნე', count: outgoing.length),
        for (final (i, p) in outgoing.indexed)
          Rise(
            key: ValueKey('out-${p.id}'),
            order: i,
            child: Pressable(
              onTap: () => _open(p),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                decoration: cardLook(context, radius: 16),
                child: Row(children: [
                  Avatar(p: p, size: 46),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      NameLine(p, size: 15),
                      const SizedBox(height: 2),
                      Row(children: [
                        PIcon('clock', size: 13, color: c.muted),
                        const SizedBox(width: 4),
                        Flexible(child: Text('ელოდება პასუხს', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5))),
                      ]),
                    ]),
                  ),
                  TextButton(onPressed: () => attempt(context, () => f.remove(p.id)), child: const Text('გაუქმება')),
                ]),
              ),
            ),
          ),
      ],
    ]);
  }

  // ---------- people you may know ----------

  Widget _suggestions() {
    final f = context.app.friends, s = sugg;
    if (s == null) return _spinner();
    final l = [for (final x in s) if (!hidden.contains(x.p.id)) x];
    if (l.isEmpty) {
      return ListView(children: const [Empty(icon: 'search', title: 'ჯერ არავის გთავაზობ', text: 'როცა მეგობრები გეყოლება, მათ ნაცნობებს აქ ნახავ.')]);
    }
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: SectionHead('შეიძლება იცნობდე', count: l.length, padding: const EdgeInsets.fromLTRB(16, 6, 12, 10))),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 286),
          delegate: SliverChildBuilderDelegate(
            childCount: l.length,
            (context, i) {
              final x = l[i];
              return Rise(
                key: ValueKey('sgg-${x.p.id}'),
                order: i,
                child: SuggestCard(
                  s: x,
                  state: f.stateWith(x.p.id),
                  onOpen: () => _open(x.p),
                  onAdd: () => attempt(context, () => f.add(x.p.id)),
                  onHide: () {
                    setState(() => hidden.add(x.p.id));
                    HiddenSuggestions.hide(x.p.id);
                  },
                ),
              );
            },
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final f = context.app.friends, people = context.app.people;
    return Scaffold(
      appBar: peeraBar(context, title: 'მეგობრები', actions: [
        IconBtn('locate', label: 'ლაივ რუკა', onTap: () => openLiveMap(context)),
        IconBtn('search', label: 'ხალხის ძებნა', onTap: () => openPage(context, const SearchScreen(tab: 'people'))),
      ]),
      body: ListenableBuilder(
        listenable: Listenable.merge([f, people]),
        builder: (context, _) {
          Profile who(String id) => people[id] ?? Profile(id: id, name: '…');
          final friends = f.friends.map(who).toList()..sort((a, b) => a.name.compareTo(b.name));
          final incoming = f.incoming.map(who).toList(), outgoing = f.outgoing.map(who).toList();
          final justFriends = [for (final id in accepted) if (f.stateWith(id) == Friendship.friends) who(id)];
          final segs = [('ყველა მეგობარი', friends.length), ('მოთხოვნები', incoming.length), ('იქნებ იცნობ', 0)];
          Widget list;
          if (!f.loaded && error == null) {
            list = _spinner();
          } else if (error != null && !f.loaded) {
            list = ListView(children: [Empty(icon: 'users', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)]);
          } else if (seg == 0) {
            list = _friends(friends, _relatives(who));
          } else if (seg == 1) {
            list = _requests(incoming, outgoing, justFriends);
          } else {
            list = _suggestions();
          }
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: _Segments(segs: segs, on: seg, alert: incoming.isNotEmpty, onPick: _pick),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (ch, a) => FadeTransition(opacity: a, child: ch),
                  child: KeyedSubtree(key: ValueKey('fseg-$seg'), child: list),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// The switch between the three parts: one track, the marker sliding under the part that is open. Each part is as wide
/// as its words need (with its number), so a longer name is not made smaller than the others.
class _Segments extends StatelessWidget {
  const _Segments({required this.segs, required this.on, required this.alert, required this.onPick});
  final List<(String, int)> segs;
  final int on;
  final bool alert;
  final void Function(int) onPick;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, n = segs.length;
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(16)),
      child: LayoutBuilder(builder: (context, box) {
        final weights = <double>[for (final x in segs) (x.$1.length + (x.$2 > 0 ? 3 : 0)).toDouble()];
        final all = weights.fold<double>(0, (a, b) => a + b);
        double at(int i) => box.maxWidth * weights.take(i).fold<double>(0, (a, b) => a + b) / all;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            left: at(on),
            top: 0,
            bottom: 0,
            width: at(on + 1) - at(on),
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: const Color(0xFF141830).withValues(alpha: .12), blurRadius: 10, offset: const Offset(0, 3))],
              ),
            ),
          ),
          Row(children: [
            for (var i = 0; i < n; i++)
              SizedBox(
                width: at(i + 1) - at(i),
                child: Semantics(
                  button: true,
                  selected: on == i,
                  child: GestureDetector(
                    key: ValueKey('seg-$i'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onPick(i),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: DefaultTextStyle.of(context).style.copyWith(color: on == i ? c.ink : c.muted, fontWeight: on == i ? FontWeight.w800 : FontWeight.w600, fontSize: 14),
                              child: Text(segs[i].$1),
                            ),
                            if (segs[i].$2 > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: i == 1 && alert ? c.nope : (on == i ? c.accent.withValues(alpha: .12) : c.line),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(grouped(segs[i].$2),
                                    style: TextStyle(color: i == 1 && alert ? Colors.white : (on == i ? c.accent : c.muted), fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                            ],
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

/// A friend: the picture with the green dot when online, the name, the username and town (or "ონლაინ"), a button to
/// write to them.
class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.p, required this.onOpen, required this.onWrite, this.kin});
  final Profile p;
  final VoidCallback onOpen, onWrite;

  /// a relative: the family tree's word for them (ძმა, დეიდა, ბიძაშვილი…)
  final String? kin;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final sub = p.online ? 'ონლაინ' : [if ((p.username ?? '').isNotEmpty) '@${p.username}', if ((p.city ?? '').isNotEmpty) p.city!].join(' · ');
    return Pressable(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
        decoration: cardLook(context, radius: 16),
        child: Row(children: [
          Avatar(p: p, size: 50, online: p.online),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              NameLine(p, size: 15.5),
              if (sub.isNotEmpty || kin != null) ...[
                const SizedBox(height: 3),
                Row(children: [
                  if (kin != null) ...[
                    Container(
                      key: ValueKey('kin-word-${p.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(10)),
                      child: Text(kin!, style: TextStyle(color: c.accent, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(sub,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.online ? c.vine : c.muted, fontSize: 13, fontWeight: p.online ? FontWeight.w700 : FontWeight.w400)),
                  ),
                ]),
              ],
            ]),
          ),
          Material(
            color: c.accent.withValues(alpha: .1),
            shape: const CircleBorder(),
            child: InkWell(
              key: ValueKey('fr-msg-${p.id}'),
              customBorder: const CircleBorder(),
              onTap: onWrite,
              child: Padding(padding: const EdgeInsets.all(9), child: Semantics(label: 'მიწერა', child: PIcon('msg', size: 19, color: c.accent))),
            ),
          ),
          const SizedBox(width: 4),
          PIcon('chev', size: 18, color: c.muted),
        ]),
      ),
    );
  }
}

/// A request to you: the picture larger, the name, and the two answers; once accepted, a line saying you are friends
/// now and a button to write.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.p, required this.done, required this.onOpen, required this.onAccept, required this.onDecline, required this.onWrite});
  final Profile p;
  final bool done;
  final VoidCallback onOpen, onAccept, onDecline, onWrite;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final btnShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return Pressable(
      onTap: onOpen,
      scale: .985,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.all(12),
        decoration: cardLook(context, radius: 18, raised: !done),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(clipBehavior: Clip.none, children: [
            Avatar(p: p, size: 66),
            Positioned(
              right: -2,
              bottom: -2,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: done ? c.vine : c.accent, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
                child: PIcon(done ? 'check' : 'uadd', size: 12, color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              NameLine(p, size: 16),
              const SizedBox(height: 2),
              Text(done ? 'ახლა მეგობრები ხართ 🎉' : ['მეგობრობას გთხოვს', if ((p.city ?? '').isNotEmpty) p.city!].join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: done ? c.vine : c.muted, fontSize: 13.5, fontWeight: done ? FontWeight.w700 : FontWeight.w400)),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (ch, a) => FadeTransition(opacity: a, child: SizeTransition(sizeFactor: a, axisAlignment: -1, child: ch)),
                child: done
                    ? SizedBox(
                        key: const ValueKey('done'),
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), shape: btnShape),
                          onPressed: onWrite,
                          icon: PIcon('msg', size: 17, color: c.accent),
                          label: const Text('მიწერა'),
                        ),
                      )
                    : Row(key: const ValueKey('ask'), children: [
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 8), shape: btnShape),
                            onPressed: onAccept,
                            child: const FittedBox(fit: BoxFit.scaleDown, child: Text('დადასტურება')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 8), shape: btnShape),
                            onPressed: onDecline,
                            child: const FittedBox(fit: BoxFit.scaleDown, child: Text('უარყოფა')),
                          ),
                        ),
                      ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// No relatives on Peera yet: they come from the family tree.
class _KinHint extends StatelessWidget {
  const _KinHint({required this.onOpen});
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Pressable(
      key: const ValueKey('kin-hint'),
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        decoration: cardLook(context, radius: 16),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
            child: PIcon('tree', size: 22, color: c.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ოჯახის ხე', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('დაამატე ნათესავები ოჯახის ხეში და აქ გამოჩნდებიან', style: TextStyle(color: c.muted, fontSize: 13)),
            ]),
          ),
          PIcon('chev', size: 18, color: c.muted),
        ]),
      ),
    );
  }
}
