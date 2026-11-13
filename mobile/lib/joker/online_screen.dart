// A Joker table with people: the waiting room (who sits where, the game's length, inviting friends, the start),
// then the same table as against the computer. Back leaves the screen; the seat stays mine (the server plays for me
// while I am away, as on the site).
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../profile/profile.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'engine.dart';
import 'online.dart';
import 'table_screen.dart';

Future<void> openJokerTable(BuildContext context, int id, {bool hint = true, bool c4 = false}) =>
    openPage(context, OnlineTableScreen(id: id, hint: hint, c4: c4), full: true);

class OnlineTableScreen extends StatefulWidget {
  const OnlineTableScreen({super.key, required this.id, this.hint = true, this.c4 = false});
  final int id;
  final bool hint, c4;
  @override
  State<OnlineTableScreen> createState() => _OnlineTableScreenState();
}

class _OnlineTableScreenState extends State<OnlineTableScreen> {
  OnlineJoker? _j;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_j != null) return;
    final app = context.app;
    _j = OnlineJoker(api: app.api, people: app.people, id: widget.id, hint: widget.hint, c4: widget.c4)..open();
  }

  @override
  void dispose() {
    _j?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final j = _j!;
    return ListenableBuilder(
      listenable: Listenable.merge([j, context.app.people]),
      builder: (context, _) {
        if (!j.loaded) return Scaffold(appBar: peeraBar(context, title: 'ჯოკერი ონლაინ'), body: const Center(child: CircularProgressIndicator()));
        if (j.closed) {
          return Scaffold(
            appBar: peeraBar(context, title: 'ჯოკერი ონლაინ'),
            body: const Center(child: Empty(icon: 'cards', title: 'ეს მაგიდა აღარ არსებობს', text: 'ახალი მაგიდა ჯოკერის ჩანართიდან გაშალე.')),
          );
        }
        if (j.status == 'wait') return _WaitRoom(j: j);
        if (j.seat < 0) {
          return Scaffold(
            appBar: peeraBar(context, title: 'ჯოკერი ონლაინ'),
            body: const Center(child: Empty(icon: 'cards', title: 'ამ მაგიდაზე უკვე თამაშობენ', text: 'შემდეგ თამაშზე შეგიძლია შეუერთდე, ან სხვა მაგიდა აირჩიე.')),
          );
        }
        return _OnlineTable(j: j);
      },
    );
  }
}

/// the table, with a line at the bottom when my move did not reach the server
class _OnlineTable extends StatelessWidget {
  const _OnlineTable({required this.j});
  final OnlineJoker j;
  @override
  Widget build(BuildContext context) {
    final p = j.problem;
    if (p != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (j.problem == p && context.mounted) {
          j.problem = null;
          toast(context, p);
        }
      });
    }
    return JokerTableScreen(session: j, title: 'მაგიდა #${j.id}');
  }
}

const _lenText = {'quick': ('სწრაფი', '8 ხელი'), 'full': ('სრული', '24 ხელი'), 'nines': ('ცხრიანები', '16 ხელი')};

class _WaitRoom extends StatelessWidget {
  const _WaitRoom({required this.j});
  final OnlineJoker j;

  Future<void> _run(BuildContext context, Future<void> Function() f) => attempt(context, f);

  Future<void> _invite(BuildContext context) async {
    final app = context.app;
    final ids = await showModalBottomSheet<List<String>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AppScope(app: app, me: context.me, child: _FriendPicker(skip: j.seats.whereType<String>().toSet())),
    );
    if (ids == null || ids.isEmpty || !context.mounted) return;
    await _run(context, () async {
      final n = await app.api.jkInvite(j.id, ids);
      if (context.mounted) toast(context, n > 0 ? 'მოწვევა გაეგზავნა $n მეგობარს' : 'მოწვევა ვერ გაიგზავნა');
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, t = j.t!, host = j.isHost, people = context.app.people;
    Widget seat(int i) {
      final u = t.seats[i];
      final Profile? p = u == null ? null : (people[u] ?? Profile(id: u, name: '…'));
      return Container(
        key: ValueKey('jseat-$i'),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: u == j.me ? c.accent : c.line, width: u == j.me ? 1.6 : 1),
        ),
        child: Column(children: [
          if (p != null)
            Avatar(p: p, size: 52)
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.sunk),
              child: Center(child: PIcon('plus', size: 22, color: c.muted)),
            ),
          const SizedBox(height: 8),
          Text(p == null ? 'ცარიელი' : (u == j.me ? 'შენ' : p.name.trim().split(' ').first),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: p == null ? c.muted : c.ink)),
          Text(u != null && u == t.host ? 'მასპინძელი' : (p == null ? 'ბოტი ჩაჯდება' : 'მოთამაშე'), style: TextStyle(color: c.muted, fontSize: 12.5)),
        ]),
      );
    }

    final free = t.seats.where((s) => s == null).length;
    return Scaffold(
      appBar: peeraBar(context, title: 'ჯოკერი ონლაინ', actions: [
        if (host) IconBtn('trash', label: 'მაგიდის დახურვა', onTap: () async {
          if (!await confirm(context, title: 'მაგიდა დავხუროთ?', text: 'თამაში ყველასთვის დასრულდება.', yes: 'დახურვა', danger: true)) return;
          if (context.mounted) await _run(context, j.close);
        }),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 32), children: [
        Text('მაგიდა #${t.id}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          host
              ? 'მოიწვიე მეგობრები ან დაელოდე სხვებს. ცარიელ ადგილებზე დაწყებისას ბოტები ჩასხდებიან.'
              : 'ელოდება მასპინძელს, რომ თამაში დაიწყოს.',
          style: TextStyle(color: c.muted, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [for (var i = 0; i < 4; i++) seat(i)],
        ),
        const SizedBox(height: 18),
        const Text('თამაში', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          for (final (i, l) in const ['quick', 'full', 'nines'].indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Material(
                color: t.len == l ? c.ink : c.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: t.len == l ? c.ink : c.line)),
                child: InkWell(
                  key: ValueKey('jlen-$l'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: host ? () => _run(context, () => j.setLen(l)) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(children: [
                      Text(_lenText[l]!.$1, style: TextStyle(color: t.len == l ? c.bg : c.ink, fontWeight: FontWeight.w800)),
                      Text(_lenText[l]!.$2, style: TextStyle(color: t.len == l ? c.bg.withValues(alpha: .8) : c.muted, fontSize: 12)),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ]),
        if (host) ...[
          const SizedBox(height: 12),
          PCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              key: const ValueKey('jpub'),
              value: t.pub,
              onChanged: (v) => _run(context, () => j.setPub(v)),
              title: const Text('ღია მაგიდა', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('სხვებიც ნახავენ ღია მაგიდებში და შემოუერთდებიან', style: TextStyle(color: c.muted, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('jinvite'),
            onPressed: () => _invite(context),
            icon: PIcon('uadd', size: 20, color: c.accent),
            label: const Text('მეგობრების მოწვევა'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 10),
          FilledButton(
            key: const ValueKey('jstart'),
            onPressed: () => _run(context, j.start),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(free == 0 ? 'დაწყება' : 'დაწყება · ${free == 3 ? 'სამი ბოტით' : (free == 2 ? 'ორი ბოტით' : 'ერთი ბოტით')}'),
          ),
        ] else if (j.seat >= 0) ...[
          const SizedBox(height: 18),
          OutlinedButton(
            key: const ValueKey('jleave'),
            onPressed: () => _run(context, j.leave),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('მაგიდიდან ადგომა'),
          ),
        ] else ...[
          const SizedBox(height: 18),
          FilledButton(
            key: const ValueKey('jjoin'),
            onPressed: free == 0 ? null : () => _run(context, j.join),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(free == 0 ? 'მაგიდა სავსეა' : 'დაჯდომა'),
          ),
        ],
      ]),
    );
  }
}

/// friends to invite, several at once
class _FriendPicker extends StatefulWidget {
  const _FriendPicker({required this.skip});
  final Set<String> skip;
  @override
  State<_FriendPicker> createState() => _FriendPickerState();
}

class _FriendPickerState extends State<_FriendPicker> {
  final picked = <String>{};
  @override
  Widget build(BuildContext context) {
    final app = context.app, c = context.pc;
    final ids = [for (final f in app.friends.friends) if (!widget.skip.contains(f)) f];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(children: [
          const Text('მოწვევა ჯოკერზე', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Expanded(
            child: ids.isEmpty
                ? const Empty(icon: 'users', title: 'მოსაწვევი მეგობარი არ არის')
                : ListenableBuilder(
                    listenable: app.people,
                    builder: (context, _) => ListView(children: [
                      for (final id in ids)
                        CheckboxListTile(
                          key: ValueKey('jfriend-$id'),
                          value: picked.contains(id),
                          onChanged: (v) => setState(() => v == true ? picked.add(id) : picked.remove(id)),
                          secondary: Avatar(p: app.people[id] ?? Profile(id: id, name: '…'), size: 40),
                          title: Text(app.people[id]?.fullName ?? '…', style: const TextStyle(fontWeight: FontWeight.w700)),
                          activeColor: c.accent,
                        ),
                    ]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              key: const ValueKey('jinvite-send'),
              onPressed: picked.isEmpty ? null : () => Navigator.pop(context, picked.toList()),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(picked.isEmpty ? 'მოწვევა' : 'მოწვევა · ${picked.length}'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// A table in the lists of the Joker tab: who sits there, the length, and what it waits for.
class JkTableTile extends StatelessWidget {
  const JkTableTile({super.key, required this.t, required this.onTap});
  final JkTable t;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, people = context.app.people, me = context.app.api.myId;
    final mine = t.seats.contains(me);
    final status = t.status == 'play' ? 'მიმდინარეობს' : (t.free == 0 ? 'სავსეა' : '${t.free} ადგილი თავისუფალია');
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: mine ? c.accent.withValues(alpha: .6) : c.line)),
      child: InkWell(
        key: ValueKey('jtable-${t.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            SizedBox(
              width: 76,
              height: 34,
              child: Stack(children: [
                for (var i = 0; i < 4; i++)
                  Positioned(
                    left: i * 14.0,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                      child: t.seats[i] == null
                          ? Container(width: 31, height: 31, decoration: BoxDecoration(color: c.sunk, shape: BoxShape.circle))
                          : Avatar(p: people[t.seats[i]!] ?? Profile(id: t.seats[i]!, name: '…'), size: 31),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${jLenName[t.len] ?? 'სწრაფი'} · #${t.id}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text(mine ? 'შენ ზიხარ · $status' : status, style: TextStyle(color: c.muted, fontSize: 13)),
              ]),
            ),
            PIcon('chev', size: 18, color: c.muted),
          ]),
        ),
      ),
    );
  }
}
