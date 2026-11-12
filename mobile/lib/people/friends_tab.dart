import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'person_screen.dart';
import 'search_screen.dart';

/// Friends, requests to you, and people you may know; search at the top.
class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});
  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  int seg = 0;
  List<Suggestion>? sugg;
  Object? error;
  bool _started = false, _chosen = false;

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
      await Future.wait([
        app.friends.load(),
        app.api.suggestions().then((s) {
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

  @override
  Widget build(BuildContext context) {
    final c = context.pc, f = context.app.friends, people = context.app.people;
    return Scaffold(
      appBar: peeraBar(context, title: 'მეგობრები', actions: [
        IconBtn('search', label: 'ხალხის ძებნა', onTap: () => openPage(context, const SearchScreen())),
      ]),
      body: ListenableBuilder(
        listenable: Listenable.merge([f, people]),
        builder: (context, _) {
          Profile who(String id) => people[id] ?? Profile(id: id, name: '…');
          final friends = f.friends.map(who).toList()..sort((a, b) => a.name.compareTo(b.name));
          final incoming = f.incoming.map(who).toList(), outgoing = f.outgoing.map(who).toList();
          final segs = [('მეგობრები', friends.length), ('მოთხოვნები', incoming.length), ('იქნებ იცნობ', 0)];
          Widget list;
          if (!f.loaded && error == null) {
            list = const Center(child: SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 2.4)));
          } else if (error != null && !f.loaded) {
            list = ListView(children: [Empty(icon: 'users', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)]);
          } else if (seg == 0) {
            list = friends.isEmpty
                ? ListView(children: [
                    Empty(icon: 'users', title: 'ჯერ მეგობრები არ გყავს', text: 'მოძებნე ნაცნობები ან ნახე, ვის შეიძლება იცნობდე.', action: 'შეიძლება იცნობდე', onAction: () => setState(() => seg = 2)),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: friends.length,
                    itemBuilder: (_, i) => PersonRow(
                      p: friends[i],
                      onTap: () => _open(friends[i]),
                      sub: friends[i].online ? 'ონლაინ' : null,
                      trailing: PIcon('chev', size: 20, color: c.muted),
                    ),
                  );
          } else if (seg == 1) {
            list = incoming.isEmpty && outgoing.isEmpty
                ? ListView(children: const [Empty(icon: 'uadd', title: 'მოთხოვნები არ არის', text: 'ვინც მეგობრობას გთხოვს, აქ გამოჩნდება.')])
                : ListView(padding: const EdgeInsets.symmetric(vertical: 6), children: [
                    for (final p in incoming) _RequestRow(p: p, onOpen: () => _open(p), onAccept: () => attempt(context, () => f.accept(p.id)), onDecline: () => attempt(context, () => f.remove(p.id))),
                    if (outgoing.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text('შენ გაგზავნე', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 13.5)),
                      ),
                      for (final p in outgoing)
                        PersonRow(
                          p: p,
                          onTap: () => _open(p),
                          sub: 'ელოდება პასუხს',
                          trailing: TextButton(onPressed: () => attempt(context, () => f.remove(p.id)), child: const Text('გაუქმება')),
                        ),
                    ],
                  ]);
          } else {
            final s = sugg;
            list = s == null
                ? const Center(child: SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 2.4)))
                : s.isEmpty
                    ? ListView(children: const [Empty(icon: 'search', title: 'ჯერ არავის გთავაზობ', text: 'როცა მეგობრები გეყოლება, მათ ნაცნობებს აქ ნახავ.')])
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: s.length,
                        itemBuilder: (_, i) {
                          final x = s[i], st = f.stateWith(x.p.id);
                          return PersonRow(
                            p: x.p,
                            onTap: () => _open(x.p),
                            sub: [if (x.mutual > 0) '${x.mutual} საერთო მეგობარი', if ((x.p.city ?? '').isNotEmpty) x.p.city!].join(' · '),
                            trailing: st == Friendship.none
                                ? FilledButton.icon(
                                    style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 12)),
                                    onPressed: () => attempt(context, () => f.add(x.p.id)),
                                    icon: PIcon('uadd', size: 18, color: c.onAccent),
                                    label: const Text('დამატება'),
                                  )
                                : Text(st == Friendship.friends ? 'მეგობარია' : 'გაგზავნილია', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
                          );
                        },
                      );
          }
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(children: [
                for (var i = 0; i < segs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _Seg(
                      key: ValueKey('seg-$i'),
                      text: segs[i].$1,
                      n: segs[i].$2,
                      alert: i == 1 && incoming.isNotEmpty,
                      on: seg == i,
                      onTap: () => setState(() {
                        seg = i;
                        _chosen = true;
                      }),
                    ),
                  ),
                ],
              ]),
            ),
            Expanded(child: RefreshIndicator(onRefresh: _load, child: list)),
          ]);
        },
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({super.key, required this.text, required this.n, required this.on, required this.onTap, this.alert = false});
  final String text;
  final int n;
  final bool on, alert;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? c.ink : c.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: on ? c.ink : c.line)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(text, style: TextStyle(color: on ? c.bg : c.ink, fontWeight: FontWeight.w700, fontSize: 14)),
            if (n > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: alert ? c.nope : (on ? c.bg.withValues(alpha: .2) : c.sunk), borderRadius: BorderRadius.circular(10)),
                child: Text(grouped(n), style: TextStyle(color: alert ? Colors.white : (on ? c.bg : c.muted), fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ]),
          ),
        ),
      ),
    );
  }
}

/// A request to you: the person, and the two answers under the name.
class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.p, required this.onOpen, required this.onAccept, required this.onDecline});
  final Profile p;
  final VoidCallback onOpen, onAccept, onDecline;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(p: p, size: 62),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              NameLine(p, size: 15.5),
              const SizedBox(height: 2),
              Text(['მეგობრობას გთხოვს', if ((p.city ?? '').isNotEmpty) p.city!].join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 13.5)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 8)),
                    onPressed: onAccept,
                    child: const FittedBox(fit: BoxFit.scaleDown, child: Text('დადასტურება')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 8)),
                    onPressed: onDecline,
                    child: const FittedBox(fit: BoxFit.scaleDown, child: Text('უარყოფა')),
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
