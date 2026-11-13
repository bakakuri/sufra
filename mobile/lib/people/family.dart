// The family tree and surnames (family.js): generations around the tree's owner with lines between them, the Georgian
// word for each relative, adding a parent, child, sibling or spouse (someone on Peera gets a request), the requests
// I got, and the page of a surname with its people and its group.
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'person_screen.dart';
import 'profile_parts.dart';
import 'search_screen.dart';

const kinRelations = [('parent', 'მშობელი'), ('child', 'შვილი'), ('sibling', 'და ან ძმა'), ('spouse', 'მეუღლე')];
const _genText = {-3: 'დიდი ბებია-ბაბუები', -2: 'ბებია-ბაბუები', -1: 'მშობლები', 0: 'თაობა', 1: 'შვილები', 2: 'შვილიშვილები', 3: 'შვილთაშვილები'};
const _genDelta = {'parent': -1, 'child': 1, 'sibling': 0, 'spouse': 0};

String? sexOf(String? gender) => gender == 'f' || gender == 'm' ? gender : null;

/// The Georgian kinship word for a chain of relations from the tree's owner, e.g. [parent(f), sibling(f)] → დეიდა.
String kinLabel(List<(String, String?)> chain, String? ownerSex) {
  final r = chain.map((c) => c.$1).join('>');
  final sx = chain.isEmpty ? null : chain.last.$2, f = sx == 'f', m = sx == 'm';
  final s0 = chain.isNotEmpty ? chain[0].$2 : null, s1 = chain.length > 1 ? chain[1].$2 : null;
  String pick(String a, String b, String c) => f ? a : (m ? b : c);
  switch (r) {
    case 'parent':
      return pick('დედა', 'მამა', 'მშობელი');
    case 'parent>parent':
      return pick('ბებია', 'ბაბუა', 'ბებია ან ბაბუა');
    case 'parent>parent>parent':
      return pick('დიდი ბებია', 'დიდი ბაბუა', 'წინაპარი');
    case 'parent>parent>parent>parent':
      return 'წინაპარი';
    case 'child':
      return pick('ქალიშვილი', 'ვაჟი', 'შვილი');
    case 'child>child':
      return 'შვილიშვილი';
    case 'child>child>child':
      return 'შვილთაშვილი';
    case 'sibling':
      return pick('და', 'ძმა', 'და ან ძმა');
    case 'spouse':
      return ownerSex == 'm' ? 'ცოლი' : (ownerSex == 'f' ? 'ქმარი' : 'მეუღლე');
    case 'parent>sibling':
      return m ? 'ბიძა' : (f ? (s0 == 'f' ? 'დეიდა' : (s0 == 'm' ? 'მამიდა' : 'დეიდა ან მამიდა')) : 'მშობლის და-ძმა');
    case 'parent>sibling>child':
      return s1 == 'm' ? 'ბიძაშვილი' : (s1 == 'f' ? (s0 == 'f' ? 'დეიდაშვილი' : 'მამიდაშვილი') : 'ბიძაშვილი');
    case 'sibling>child':
      return s0 == 'f' ? 'დისშვილი' : (s0 == 'm' ? 'ძმისშვილი' : 'ძმისშვილი ან დისშვილი');
    case 'child>spouse':
    case 'sibling>spouse':
      return pick('რძალი', 'სიძე', 'მეუღლე');
    case 'spouse>parent':
      return ownerSex == 'm'
          ? pick('სიდედრი', 'სიმამრი', 'სიდედრი ან სიმამრი')
          : (ownerSex == 'f' ? pick('დედამთილი', 'მამამთილი', 'დედამთილი ან მამამთილი') : 'მეუღლის მშობელი');
    case 'spouse>sibling':
      return ownerSex == 'm' ? pick('ცოლისდა', 'ცოლისძმა', 'ცოლის და-ძმა') : (ownerSex == 'f' ? pick('მული', 'მაზლი', 'ქმრის და-ძმა') : 'მეუღლის და-ძმა');
    case 'parent>spouse':
      return pick('დედინაცვალი', 'მამინაცვალი', 'მშობლის მეუღლე');
    case 'parent>child':
      return pick('და', 'ძმა', 'და ან ძმა');
    default:
      return 'ნათესავი';
  }
}

/// One person in the tree: the owner ('r') or a row of the kin table hanging off its anchor.
class KinNode {
  KinNode({required this.key, this.row, this.parent, required this.gen, required this.chain, this.uid, required this.name, this.sex});
  final String key;
  final Map<String, dynamic>? row;
  final String? parent, uid, sex;
  final int gen;
  final List<(String, String?)> chain;
  final String name;
  String label = '';
  bool get root => row == null;
  bool get pending => row?['status'] == 'pending';
  String get years {
    final r = row;
    if (r == null || (r['born'] == null && r['died'] == null)) return '';
    return '${r['born'] ?? '?'}${r['died'] != null ? '–${r['died']}' : ''}';
  }
}

/// The tree's nodes, every row hanging off its anchor (or the owner), each with its kinship word.
Map<String, KinNode> buildTree(Profile owner, List<Map<String, dynamic>> rows, Profile? Function(String) person) {
  final n = <String, KinNode>{};
  final ownerSex = sexOf(owner.gender);
  n['r'] = KinNode(key: 'r', gen: 0, chain: const [], uid: owner.id, name: owner.name, sex: ownerSex);
  for (final r in rows) {
    final par = n[r['anchor'] != null ? 'k${r['anchor']}' : 'r'];
    if (par == null) continue;
    final rel = '${r['relation']}', relative = r['relative'] == null ? null : '${r['relative']}';
    final sex = (r['sex'] as String?) ?? (relative != null ? sexOf(person(relative)?.gender) : null);
    n['k${r['id']}'] = KinNode(
      key: 'k${r['id']}',
      row: r,
      parent: par.key,
      gen: par.gen + (_genDelta[rel] ?? 0),
      chain: [...par.chain, (rel, sex)],
      uid: relative,
      name: relative != null ? (person(relative)?.name ?? '…') : '${r['name'] ?? ''}',
      sex: sex,
    );
  }
  for (final x in n.values) {
    if (!x.root) x.label = kinLabel(x.chain, ownerSex);
  }
  return n;
}

/// Each generation's people in order: siblings before me, then me, then the rest in the order they were added.
List<(int, List<KinNode>)> treeGenerations(Map<String, KinNode> n) {
  List<int> path(KinNode x) {
    final p = <int>[];
    KinNode? y = x;
    while (y != null && !y.root) {
      p.insert(0, asInt(y.row!['id']));
      y = n[y.parent];
    }
    return p;
  }

  int cmp(KinNode a, KinNode b) {
    if (a.root) return b.row?['relation'] == 'sibling' ? 1 : -1;
    if (b.root) return a.row?['relation'] == 'sibling' ? -1 : 1;
    final pa = path(a), pb = path(b);
    for (var i = 0; i < (pa.length > pb.length ? pa.length : pb.length); i++) {
      final x = i < pa.length ? pa[i] : -1, y = i < pb.length ? pb[i] : -1;
      if (x != y) return x - y;
    }
    return 0;
  }

  final gens = n.values.map((x) => x.gen).toSet().toList()..sort();
  return [for (final g in gens) (g, n.values.where((x) => x.gen == g).toList()..sort(cmp))];
}

class TreeScreen extends StatefulWidget {
  const TreeScreen({super.key, required this.uid});
  final String uid;
  @override
  State<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends State<TreeScreen> {
  Map<String, KinNode>? nodes;
  List<Map<String, dynamic>> pend = const [];
  Profile? owner;
  Object? error;
  bool _started = false;

  bool get mine => widget.uid == context.me.id;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final app = context.app, me = context.me, uid = widget.uid;
    try {
      final rows = await app.api.kinOf(uid);
      final p = mine ? await app.api.kinRequests() : <Map<String, dynamic>>[];
      await app.people.ensure([uid, for (final r in rows) if (r['relative'] != null) '${r['relative']}', for (final x in p) '${x['owner']}']);
      final o = uid == me.id ? me : (app.people[uid] ?? await app.api.person(uid));
      if (o == null) throw 'not found';
      if (!mounted) return;
      setState(() {
        owner = o;
        nodes = buildTree(o, rows, (id) => id == me.id ? me : app.people[id]);
        pend = p;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _add({int? anchor, String rel = 'parent', String? uid}) async {
    final n = nodes;
    final an = anchor == null || n == null ? null : n['k$anchor'];
    if (await kinAddSheet(context, anchor: anchor, anchorName: an?.name, rel: rel, uid: uid) && mounted) _load();
  }

  void _node(KinNode n) {
    final c = context.pc, me = context.me, r = n.row;
    final canAdd = mine && (n.root || r?['relative'] == null);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: c.surface,
      builder: (s) {
        Widget item(String key, String icon, String label, VoidCallback onTap, {bool danger = false}) => ListTile(
              key: ValueKey(key),
              leading: PIcon(icon, size: 22, color: danger ? c.nope : c.ink),
              title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: danger ? c.nope : c.ink)),
              onTap: () {
                Navigator.pop(s);
                onTap();
              },
            );
        return SafeArea(
          child: ListView(shrinkWrap: true, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                if (!n.root)
                  Text([n.label, if (n.years.isNotEmpty) n.years, if (n.pending) 'ელოდება დადასტურებას'].join(' · '), style: TextStyle(color: c.muted)),
              ]),
            ),
            if (n.uid != null && n.uid != me.id) ...[
              item('kn-profile', 'user', 'პროფილი', () => openPage(context, PersonScreen(uid: n.uid!))),
              item('kn-tree', 'tree', 'მისი ოჯახის ხე', () => openPage(context, TreeScreen(uid: n.uid!))),
            ],
            if (canAdd)
              for (final (k, l) in kinRelations) item('kn-add-$k', 'plus', '${n.root ? 'ჩემი' : 'მისი'} $l', () => _add(anchor: n.root ? null : asInt(r!['id']), rel: k)),
            if (mine && r != null && r['relative'] == null)
              item('kn-edit', 'edit', 'რედაქტირება', () async {
                if (await kinEditSheet(context, r) && mounted) _load();
              }),
            if (mine && r != null)
              item('kn-del', 'trash', 'ხიდან ამოღება', () async {
                if (!await confirm(context, title: 'ხიდან ამოღება', text: 'ამოიშლება ეს ადამიანი და ყველა, ვინც მასზეა მიბმული.', yes: 'ამოღება', danger: true) || !mounted) return;
                if (await attempt(context, () => context.app.api.deleteKin(asInt(r['id']))) && mounted) _load();
              }, danger: true),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }

  Future<void> _respond(Map<String, dynamic> x, bool ok) async {
    if (await attempt(context, () => context.app.api.respondKin(asInt(x['id']), ok)) && mounted) {
      if (ok) toast(context, 'ნათესაობა დადასტურდა');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, me = context.me, n = nodes, o = owner;
    final title = mine || o == null ? 'ოჯახის ხე' : 'ოჯახის ხე · ${o.name.split(' ').first}';
    Widget body;
    if (n == null) {
      body = error != null ? Center(child: Empty(icon: 'tree', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'თავიდან', onAction: _load)) : const Center(child: CircularProgressIndicator());
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          if (pend.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 4), child: Text('ნათესაობის მოთხოვნები', style: TextStyle(color: c.muted, fontWeight: FontWeight.w800))),
            for (final x in pend)
              Padding(
                key: ValueKey('kreq-${x['id']}'),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(children: [
                  Avatar(p: app.people['${x['owner']}'] ?? Profile(id: '${x['owner']}', name: '…'), size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(app.people['${x['owner']}']?.name ?? '…', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('მის ოჯახის ხეში: ${kinLabel([('${x['relation']}', sexOf(me.gender))], sexOf(app.people['${x['owner']}']?.gender))}',
                          style: TextStyle(color: c.muted, fontSize: 13)),
                    ]),
                  ),
                  FilledButton(key: ValueKey('kreq-ok-${x['id']}'), onPressed: () => _respond(x, true), child: const Text('დადასტურება')),
                  IconBtn('x', key: ValueKey('kreq-no-${x['id']}'), label: 'უარყოფა', onTap: () => _respond(x, false)),
                ]),
              ),
          ],
          if (n.length < 2 && !mine) const Empty(icon: 'tree', title: 'ოჯახის ხე ჯერ ცარიელია'),
          if (n.length >= 2 || mine) Padding(padding: const EdgeInsets.only(top: 8), child: _Tree(nodes: n, mine: mine, me: me, people: app.people, onTap: _node)),
          if (mine) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(key: const ValueKey('kin-add'), onPressed: () => _add(), icon: PIcon('plus', size: 18, color: c.ink), label: const Text('ნათესავის დამატება')),
                OutlinedButton.icon(
                  onPressed: () => openSurname(context, me.surname),
                  icon: PIcon('users', size: 18, color: c.ink),
                  label: const Text('ჩემი გვარი'),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'შეეხე ადამიანს და დაამატე მისი მშობელი, შვილი ან მეუღლე. Peera-ზე მყოფ ნათესავს მოთხოვნა მიუვა და დადასტურების შემდეგ ხეში გამოჩნდება. ხეს ხედავენ შენი მეგობრები და ნათესავები.',
                style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        ]),
      );
    }
    return Scaffold(
      appBar: peeraBar(context, title: title, actions: [if (mine) IconBtn('plus', key: const ValueKey('tree-add'), label: 'დამატება', onTap: () => _add())]),
      body: body,
    );
  }
}

const _nodeW = 96.0, _nodeH = 112.0, _gap = 10.0, _bandLabel = 24.0, _bandGap = 30.0, _pad = 16.0;

/// The generations drawn as rows with lines from each person to the one they hang off.
class _Tree extends StatelessWidget {
  const _Tree({required this.nodes, required this.mine, required this.me, required this.people, required this.onTap});
  final Map<String, KinNode> nodes;
  final bool mine;
  final Profile me;
  final People people;
  final void Function(KinNode) onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pc, gens = treeGenerations(nodes);
    final widest = gens.fold<int>(0, (a, g) => g.$2.length > a ? g.$2.length : a);
    final screen = MediaQuery.sizeOf(context).width;
    final w = [widest * _nodeW + (widest - 1) * _gap + _pad * 2, screen].reduce((a, b) => a > b ? a : b);
    final rects = <String, Rect>{};
    final labels = <Widget>[], kids = <Widget>[];
    for (final (i, (g, list)) in gens.indexed) {
      final top = i * (_bandLabel + _nodeH + _bandGap);
      final rowW = list.length * _nodeW + (list.length - 1) * _gap;
      final left = (w - rowW) / 2;
      labels.add(Positioned(
        left: _pad,
        top: top,
        child: Text(g == 0 && mine ? 'მე და ჩემი თაობა' : (_genText[g] ?? (g < 0 ? 'წინაპრები' : 'შთამომავლები')),
            style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ));
      for (final (j, x) in list.indexed) {
        final r = Rect.fromLTWH(left + j * (_nodeW + _gap), top + _bandLabel, _nodeW, _nodeH);
        rects[x.key] = r;
        kids.add(Positioned.fromRect(rect: r, child: _NodeCard(node: x, mine: mine, me: me, people: people, onTap: () => onTap(x))));
      }
    }
    final h = gens.length * (_bandLabel + _nodeH + _bandGap) - _bandGap + 8;
    final edges = <(String, Rect, Rect)>[
      for (final x in nodes.values)
        if (!x.root && rects[x.parent] != null && rects[x.key] != null) ('${x.row!['relation']}', rects[x.parent]!, rects[x.key]!),
    ];
    return SingleChildScrollView(
      key: const ValueKey('tree-scroll'),
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _Edges(edges, c.muted.withValues(alpha: .55)))),
          ...labels,
          ...kids,
        ]),
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.node, required this.mine, required this.me, required this.people, required this.onTap});
  final KinNode node;
  final bool mine;
  final Profile me;
  final People people;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, n = node, gone = n.row?['died'] != null;
    final p = n.uid != null ? (n.uid == me.id ? me : people[n.uid!]) : null;
    final av = p ?? Profile(id: n.key, name: n.name, hue: n.sex == 'f' ? 330 : (n.sex == 'm' ? 210 : 40));
    final sub = [n.root ? (mine ? 'მე' : '') : n.label, if (n.years.isNotEmpty) n.years, if (n.pending) 'ელოდება'].where((s) => s.isNotEmpty).join(' · ');
    return Opacity(
      opacity: n.pending ? .6 : 1,
      child: Material(
        color: n.root ? c.accent.withValues(alpha: .1) : c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: n.root ? c.accent : c.line, width: n.root ? 1.4 : 1)),
        child: InkWell(
          key: ValueKey('knode-${n.key}'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
            child: Column(children: [
              ColorFiltered(
                colorFilter: gone ? const ColorFilter.matrix([.33, .33, .33, 0, 0, .33, .33, .33, 0, 0, .33, .33, .33, 0, 0, 0, 0, 0, 1, 0]) : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: Avatar(p: av, size: 44),
              ),
              const SizedBox(height: 6),
              Text(n.name.split(' ').take(2).join(' '), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 11, height: 1.2)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Edges extends CustomPainter {
  _Edges(this.edges, this.color);
  final List<(String, Rect, Rect)> edges;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final solid = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final dashed = Path(), line = Path();
    for (final (rel, a, b) in edges) {
      switch (rel) {
        case 'parent':
          final y = (b.bottom + a.top) / 2;
          line
            ..moveTo(a.center.dx, a.top)
            ..lineTo(a.center.dx, y)
            ..lineTo(b.center.dx, y)
            ..lineTo(b.center.dx, b.bottom);
        case 'child':
          final y = (a.bottom + b.top) / 2;
          line
            ..moveTo(a.center.dx, a.bottom)
            ..lineTo(a.center.dx, y)
            ..lineTo(b.center.dx, y)
            ..lineTo(b.center.dx, b.top);
        case 'spouse':
          final l = a.left < b.left ? a : b, r = a.left < b.left ? b : a;
          dashed
            ..moveTo(l.right, l.center.dy)
            ..lineTo(r.left, r.center.dy);
        default:
          final y = (a.top < b.top ? a.top : b.top) - 6;
          dashed
            ..moveTo(a.center.dx, a.top)
            ..lineTo(a.center.dx, y)
            ..lineTo(b.center.dx, y)
            ..lineTo(b.center.dx, b.top);
      }
    }
    canvas.drawPath(line, solid);
    for (final m in dashed.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5 < m.length ? d + 5 : m.length), solid);
      }
    }
  }

  @override
  bool shouldRepaint(_Edges old) => old.edges != edges || old.color != color;
}

int? _year(String v) {
  final x = int.tryParse(v.trim());
  return x != null && x >= 1000 && x <= 2100 ? x : null;
}

Widget _sexChips(String? sex, void Function(String) set, BuildContext s) => Wrap(spacing: 6, children: [
      for (final (k, l) in const [('f', 'ქალი'), ('m', 'კაცი')])
        ChoiceChip(
          key: ValueKey('ksex-$k'),
          label: Text(l),
          selected: sex == k,
          showCheckmark: false,
          selectedColor: s.pc.ink,
          labelStyle: TextStyle(color: sex == k ? s.pc.bg : s.pc.ink, fontWeight: FontWeight.w600),
          onSelected: (_) => set(k),
        ),
    ]);

/// Adding a relative: who they are to me (or to [anchor]), someone on Peera (a friend gets a request) or by name. True once added.
Future<bool> kinAddSheet(BuildContext context, {int? anchor, String? anchorName, String rel = 'parent', String? uid}) async {
  final app = context.app;
  if (!app.friends.loaded) await app.friends.load().catchError((_) {});
  await app.people.ensure(app.friends.friends);
  if (!context.mounted) return false;
  var who = anchor != null ? 'name' : (uid != null ? 'user' : 'name');
  String? pick = uid, sex;
  final name = TextEditingController(), born = TextEditingController(), died = TextEditingController();
  var busy = false;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => StatefulBuilder(builder: (s, set) {
      final c = s.pc, friends = app.friends.friends;
      Widget chip(String key, String label, bool on, VoidCallback tap) => ChoiceChip(
            key: ValueKey(key),
            label: Text(label),
            selected: on,
            showCheckmark: false,
            selectedColor: c.ink,
            labelStyle: TextStyle(color: on ? c.bg : c.ink, fontWeight: FontWeight.w600),
            onSelected: (_) => set(tap),
          );
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(s).bottom),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(s).height * .85),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), children: [
              Text(anchorName != null ? '$anchorName · ნათესავი' : 'ნათესავის დამატება', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final (k, l) in kinRelations) chip('krel-$k', l, rel == k, () => rel = k)]),
              if (anchor == null) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, children: [
                  chip('kwho-user', 'Peera-ზეა', who == 'user', () => who = 'user'),
                  chip('kwho-name', 'სახელით', who == 'name', () => who = 'name'),
                ]),
              ],
              const SizedBox(height: 12),
              if (who == 'user') ...[
                Text('აირჩიე მეგობრებიდან. მას მოთხოვნა მიუვა.', style: TextStyle(color: c.muted, fontSize: 13)),
                if (friends.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('მეგობრები ჯერ არ გყავს.', style: TextStyle(color: c.muted))),
                for (final id in friends)
                  ListTile(
                    key: ValueKey('kfr-$id'),
                    contentPadding: EdgeInsets.zero,
                    leading: Avatar(p: app.people[id] ?? Profile(id: id, name: '…'), size: 36),
                    title: Text(app.people[id]?.name ?? '…', style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: pick == id ? PIcon('check', size: 22, color: c.accent) : null,
                    selected: pick == id,
                    onTap: () => set(() => pick = id),
                  ),
              ] else ...[
                TextField(key: const ValueKey('kn-name'), controller: name, maxLength: 60, decoration: const InputDecoration(labelText: 'სახელი და გვარი', hintText: 'მაგ. ვახტანგ ბერიძე', counterText: '')),
                const SizedBox(height: 10),
                _sexChips(sex, (k) => set(() => sex = k), s),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: born, maxLength: 4, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'დაბადების წელი', counterText: ''))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: died, maxLength: 4, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'გარდაცვალების წელი', hintText: 'თუ აღარ არის', counterText: ''))),
                ]),
              ],
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('kn-ok'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: busy
                    ? null
                    : () async {
                        final row = <String, dynamic>{'relation': rel, 'anchor': anchor};
                        if (who == 'user') {
                          if (pick == null) {
                            toast(s, 'აირჩიე მეგობარი');
                            return;
                          }
                          row['relative'] = pick;
                        } else {
                          final t = name.text.trim();
                          if (t.length < 2) {
                            toast(s, 'ჩაწერე სახელი');
                            return;
                          }
                          row.addAll({'name': t, 'sex': sex, 'born': _year(born.text), 'died': _year(died.text)});
                        }
                        set(() => busy = true);
                        try {
                          await app.api.addKin(row);
                          if (!s.mounted) return;
                          toast(s, row['relative'] != null ? 'მოთხოვნა გაიგზავნა' : 'დაემატა');
                          Navigator.of(s).pop(true);
                        } catch (e) {
                          final m = '$e';
                          if (s.mounted) {
                            toast(s, RegExp('duplicate', caseSensitive: false).hasMatch(m) ? 'ეს ადამიანი უკვე შენს ხეშია' : (m.contains('too_many') ? 'ხეში მაქსიმუმ 200 ადამიანია' : errText(e)));
                            set(() => busy = false);
                          }
                        }
                      },
                child: const Text('დამატება'),
              ),
            ]),
          ),
        ),
      );
    }),
  );
  return ok == true;
}

/// Changing a relative added by name: the name, man or woman, the years. True once saved.
Future<bool> kinEditSheet(BuildContext context, Map<String, dynamic> r) async {
  final app = context.app;
  final name = TextEditingController(text: '${r['name'] ?? ''}'), born = TextEditingController(text: '${r['born'] ?? ''}'), died = TextEditingController(text: '${r['died'] ?? ''}');
  String? sex = r['sex'] as String?;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => StatefulBuilder(
      builder: (s, set) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(s).bottom),
        child: SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), children: [
            const Text('რედაქტირება', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(key: const ValueKey('ke-name'), controller: name, maxLength: 60, decoration: const InputDecoration(labelText: 'სახელი და გვარი', counterText: '')),
            const SizedBox(height: 10),
            _sexChips(sex, (k) => set(() => sex = k), s),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: born, maxLength: 4, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'დაბადების წელი', counterText: ''))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: died, maxLength: 4, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'გარდაცვალების წელი', counterText: ''))),
            ]),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('ke-ok'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () async {
                try {
                  await app.api.updateKin(asInt(r['id']), {
                    'name': name.text.trim().isEmpty ? r['name'] : name.text.trim(),
                    'sex': sex,
                    'born': _year(born.text),
                    'died': _year(died.text),
                  });
                  if (s.mounted) Navigator.of(s).pop(true);
                } catch (e) {
                  if (s.mounted) toast(s, errText(e));
                }
              },
              child: const Text('შენახვა'),
            ),
          ]),
        ),
      ),
    ),
  );
  return ok == true;
}

/// A surname's page, or (when I have none yet) the sheet that sets mine first.
Future<void> openSurname(BuildContext context, String? s) async {
  final v = (s ?? '').trim();
  if (v.isNotEmpty) {
    await openPage(context, SurnameScreen(surname: v));
    return;
  }
  final got = await setSurnameSheet(context);
  if (got != null && context.mounted) await openPage(context, SurnameScreen(surname: got, mineNow: got));
}

String lastWord(String n) {
  final w = n.trim().split(RegExp(r'\s+'));
  return w.length > 1 ? w.last : '';
}

/// Setting my surname; the new one, or null when closed.
Future<String?> setSurnameSheet(BuildContext context, {String? current}) {
  final app = context.app, me = context.me;
  final ctl = TextEditingController(text: current ?? me.surname ?? lastWord(me.name));
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(s).bottom),
      child: SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), children: [
          const Text('ჩემი გვარი', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(key: const ValueKey('sn-v'), controller: ctl, maxLength: 40, decoration: const InputDecoration(labelText: 'გვარი', hintText: 'მაგ. ბერიძე', counterText: '')),
          const SizedBox(height: 8),
          Text('გვარით გაერთიანდებიან ერთი გვარის ადამიანები: საერთო ჯგუფი, ისტორია და ნათესავები.', style: TextStyle(color: s.pc.muted, fontSize: 13)),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('sn-ok'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () async {
              final v = ctl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
              if (v.length < 2) {
                toast(s, 'ჩაწერე გვარი');
                return;
              }
              try {
                await app.api.updateMe({'surname': v});
                app.refreshMe?.call();
                if (s.mounted) Navigator.of(s).pop(v);
              } catch (e) {
                if (s.mounted) toast(s, errText(e));
              }
            },
            child: const Text('შენახვა'),
          ),
        ]),
      ),
    ),
  );
}

/// One surname: how many on Peera, its group, its people.
class SurnameScreen extends StatefulWidget {
  const SurnameScreen({super.key, required this.surname, this.mineNow});
  final String surname;

  /// my surname when it changed after this screen's [AppScope] was made
  final String? mineNow;
  @override
  State<SurnameScreen> createState() => _SurnameScreenState();
}

class _SurnameScreenState extends State<SurnameScreen> {
  late String s = widget.surname;
  String? my;
  List<Profile>? people;
  int? group;
  Object? error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    my = widget.mineNow ?? context.me.surname;
    _load();
  }

  Future<void> _load() async {
    final app = context.app;
    try {
      final p = await app.api.surnamePeople(s);
      final g = await app.api.surnameGroup(s).catchError((_) => null);
      for (final x in p) {
        app.people.put(x);
      }
      if (mounted) {
        setState(() {
          people = p;
          group = g;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _join() async {
    if (group == null) {
      final yes = await confirm(context, title: 'გვარის ჯგუფის შექმნა', text: 'ჯგუფი „გვარი · $s“ ღია იქნება ამ გვარის ყველა ადამიანისთვის. შენ იქნები მისი მფლობელი.', yes: 'შექმნა');
      if (!yes || !mounted) return;
    }
    try {
      final g = await context.app.api.joinSurnameGroup();
      if (!mounted) return;
      if (group == null) toast(context, 'ჯგუფი შეიქმნა');
      setState(() => group = g);
      openSite('#group-$g');
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  Future<void> _set() async {
    final v = await setSurnameSheet(context, current: my);
    if (v == null || !mounted) return;
    setState(() {
      my = v;
      s = v;
      people = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, me = context.me, p = people, mine = my == s;
    Widget body;
    if (p == null) {
      body = error != null ? Center(child: Empty(icon: 'users', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'თავიდან', onAction: _load)) : const Center(child: CircularProgressIndicator());
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [c.accent, c.vine]), borderRadius: BorderRadius.circular(20)),
                child: Text(s.characters.first, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  Text('${p.length} ადამიანი Peera-ზე', style: TextStyle(color: c.muted)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              if (mine)
                FilledButton.icon(
                  key: const ValueKey('sn-group'),
                  onPressed: _join,
                  icon: PIcon('users', size: 18, color: c.onAccent),
                  label: Text(group != null ? 'გვარის ჯგუფი' : 'გვარის ჯგუფის შექმნა'),
                )
              else if (group != null)
                FilledButton.icon(
                  key: const ValueKey('sn-group'),
                  onPressed: () => openSite('#group-$group'),
                  icon: PIcon('users', size: 18, color: c.onAccent),
                  label: const Text('გვარის ჯგუფი'),
                ),
              OutlinedButton.icon(
                key: const ValueKey('sn-tree'),
                onPressed: () => openPage(context, TreeScreen(uid: me.id)),
                icon: PIcon('tree', size: 18, color: c.ink),
                label: const Text('ჩემი ოჯახის ხე'),
              ),
              if (mine || (my ?? '').isEmpty)
                OutlinedButton.icon(
                  key: const ValueKey('sn-set'),
                  onPressed: _set,
                  icon: PIcon('edit', size: 18, color: c.ink),
                  label: Text(mine ? 'გვარის შეცვლა' : 'ჩემი გვარის მითითება'),
                ),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text('ამ გვარის ადამიანები', style: TextStyle(color: c.muted, fontWeight: FontWeight.w800))),
          if (p.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('ჯერ არავინ.', style: TextStyle(color: c.muted))),
          for (final x in p) PersonRow(key: ValueKey('snp-${x.id}'), p: x, onTap: () => openPage(context, PersonScreen(uid: x.id))),
        ]),
      );
    }
    return Scaffold(appBar: peeraBar(context, title: 'გვარი · $s'), body: body);
  }
}
