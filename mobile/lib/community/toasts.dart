// The toast book (toasts.js): toasts for every occasion, the best or the newest, liked with a glass, shared or posted;
// one written or changed. The leader of an event's evening picks from the same book (events.dart).
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../feed/post_actions.dart';
import '../feed/post_card.dart';
import '../people/profile_parts.dart';
import '../ui/bits.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const occasions = [
  ('supra', 'სუფრა'), ('homeland', 'სამშობლო'), ('parents', 'მშობლები'), ('memorial', 'შენდობა'), ('friends', 'მეგობრობა'), ('love', 'სიყვარული'), //
  ('kids', 'ბავშვები'), ('guests', 'სტუმარი'), ('wedding', 'ქორწილი'), ('christening', 'ნათლობა'), ('birthday', 'დაბადების დღე'), ('other', 'სხვა'),
];

String occasionName(Object? k) => occasions.firstWhere((o) => o.$1 == k, orElse: () => occasions.last).$2;

/// The toast book.
class ToastsScreen extends StatefulWidget {
  const ToastsScreen({super.key});
  @override
  State<ToastsScreen> createState() => _ToastsScreenState();
}

class _ToastsScreenState extends State<ToastsScreen> {
  String occ = '', sort = 'top';
  List<Map<String, dynamic>>? rows;
  Set<int> liked = {};
  final open = <int>{};
  Object? error;
  int _gen = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final g = ++_gen, app = context.app;
    try {
      final r = await app.api.toasts(occ: occ, sort: sort);
      await app.people.ensure([for (final t in r.$1) if (t['author'] != null) '${t['author']}']);
      if (mounted && g == _gen) {
        setState(() {
          rows = r.$1;
          liked = {...r.$2};
          error = null;
        });
      }
    } catch (e) {
      if (mounted && g == _gen) setState(() => error = e);
    }
  }

  Future<void> _like(Map<String, dynamic> t) async {
    final id = asInt(t['id']), on = !liked.contains(id);
    setState(() {
      on ? liked.add(id) : liked.remove(id);
      t['likes'] = (asInt(t['likes']) + (on ? 1 : -1)).clamp(0, 1 << 30);
    });
    try {
      await context.app.api.likeToast(id, on);
    } catch (e) {
      if (!mounted || '$e'.toLowerCase().contains('duplicate')) return;
      setState(() {
        on ? liked.remove(id) : liked.add(id);
        t['likes'] = (asInt(t['likes']) + (on ? -1 : 1)).clamp(0, 1 << 30);
      });
      toast(context, errText(e));
    }
  }

  Future<void> _write([Map<String, dynamic>? t]) async {
    final saved = await toastForm(context, t, occ.isEmpty ? 'supra' : occ);
    if (saved != true || !mounted) return;
    toast(context, t != null ? 'შენახულია' : 'გამოქვეყნდა. გაგიმარჯოს!');
    if (t == null) setState(() => sort = 'new');
    _load();
  }

  Future<void> _more(Map<String, dynamic> t) async {
    final app = context.app, c = context.pc, mine = t['author'] == app.api.myId, staff = isStaff(context);
    final k = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(key: const ValueKey('tm-post'), leading: const PIcon('edit'), title: const Text('პოსტად გაზიარება'), onTap: () => Navigator.of(s).pop('post')),
          if (mine) ...[
            ListTile(key: const ValueKey('tm-edit'), leading: const PIcon('edit'), title: const Text('რედაქტირება'), onTap: () => Navigator.of(s).pop('edit')),
            ListTile(key: const ValueKey('tm-del'), leading: PIcon('trash', color: c.nope), title: Text('წაშლა', style: TextStyle(color: c.nope)), onTap: () => Navigator.of(s).pop('del')),
          ] else
            ListTile(key: const ValueKey('tm-report'), leading: const PIcon('flag'), title: const Text('საჩივარი'), onTap: () => Navigator.of(s).pop('report')),
          if (staff && !mine)
            ListTile(key: const ValueKey('tm-mod'), leading: PIcon('lock', color: c.nope), title: Text('მოდერაცია: დამალვა', style: TextStyle(color: c.nope)), onTap: () => Navigator.of(s).pop('mod')),
        ]),
      ),
    );
    if (k == null || !mounted) return;
    switch (k) {
      case 'post':
        await openPage(context, ComposeScreen(text: '🍷 ${t['title']}\n\n${t['body']}\n\n#სადღეგრძელო'), full: true);
      case 'edit':
        await _write(t);
      case 'del':
        if (!await confirm(context, title: 'სადღეგრძელოს წაშლა', text: 'წაშლილს ვეღარ აღადგენ.', yes: 'წაშლა', danger: true) || !mounted) return;
        if (await attempt(context, () => app.api.deleteToast(asInt(t['id']))) && mounted) _load();
      case 'report':
        await reportSheet(context, 'toast', '${t['id']}');
      case 'mod':
        if (await attempt(context, () => app.api.modHide('toast', asInt(t['id']), true)) && mounted) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, r = rows, app = context.app;
    return Scaffold(
      appBar: peeraBar(context, title: 'სადღეგრძელოები', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: FilledButton.icon(
            key: const ValueKey('ts-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: _write,
            icon: PIcon('edit', size: 17, color: c.onAccent),
            label: const Text('დაწერა'),
          ),
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('თამადის წიგნი: სადღეგრძელოები ყველა შემთხვევისთვის. საუკეთესოს მოუწონე ყანწით, შეხვედრაზე კი თამადა პირდაპირ აქედან ამოიღებს.', style: TextStyle(color: c.muted)),
          ),
          ChipsBar(prefix: 'tso', items: [('', 'ყველა'), ...occasions], value: occ, onPick: (k) {
            setState(() => occ = k);
            _load();
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: SegmentedButton<String>(
              key: const ValueKey('ts-sort'),
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: 'top', label: Text('საუკეთესო')), ButtonSegment(value: 'new', label: Text('ახალი'))],
              selected: {sort},
              onSelectionChanged: (v) {
                setState(() => sort = v.first);
                _load();
              },
            ),
          ),
          if (r == null && error == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (r == null)
            Empty(icon: 'wine', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
          else if (r.isEmpty)
            Empty(icon: 'wine', title: 'აქ ჯერ ცარიელია', text: 'დაწერე პირველი სადღეგრძელო ამ შემთხვევისთვის.', action: 'დაწერა', onAction: _write)
          else
            for (final t in r)
              Builder(builder: (context) {
                final id = asInt(t['id']), body = '${t['body'] ?? ''}', long = body.length > 260, on = liked.contains(id), au = t['author'] as String?;
                return Container(
                  key: ValueKey('tc-$id'),
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      PTag(occasionName(t['occasion'])),
                      const Spacer(),
                      if (au != null)
                        if (app.people[au] case final p?)
                          GestureDetector(onTap: () => openPerson(context, p), child: Text(p.name, style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w700)))
                        else
                          const SizedBox.shrink()
                      else
                        Text('სუფრის წიგნიდან', style: TextStyle(color: c.muted, fontSize: 12.5)),
                      const SizedBox(width: 8),
                    ]),
                    const SizedBox(height: 8),
                    Text('${t['title']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      key: ValueKey('tc-body-$id'),
                      onTap: long ? () => setState(() => open.contains(id) ? open.remove(id) : open.add(id)) : null,
                      child: Text(
                        body,
                        maxLines: long && !open.contains(id) ? 6 : null,
                        overflow: long && !open.contains(id) ? TextOverflow.ellipsis : null,
                        style: const TextStyle(fontSize: 15, height: 1.4),
                      ),
                    ),
                    Row(children: [
                      TextButton.icon(
                        key: ValueKey('tl-$id'),
                        onPressed: () => _like(t),
                        icon: PIcon('wine', size: 19, color: on ? c.gold : c.muted),
                        label: Text(asInt(t['likes']) > 0 ? '${asInt(t['likes'])}' : '', style: TextStyle(color: on ? c.gold : c.muted, fontWeight: FontWeight.w800)),
                      ),
                      IconBtn('send', key: ValueKey('tsh-$id'), label: 'გაზიარება', size: 20, color: c.muted, onTap: () => shareText(context, '${t['title']}\n\n$body\n\n— Peera')),
                      const Spacer(),
                      IconBtn('more', key: ValueKey('tm-$id'), label: 'მეტი', size: 20, color: c.muted, onTap: () => _more(t)),
                    ]),
                  ]),
                );
              }),
        ]),
      ),
    );
  }
}

/// A toast written or changed: the occasion, a title, the words. True when saved.
Future<bool?> toastForm(BuildContext context, Map<String, dynamic>? t, String occ) {
  final app = context.app, me = context.me;
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => AppScope(app: app, me: me, child: _ToastForm(t: t, occ: '${t?['occasion'] ?? occ}')),
  );
}

class _ToastForm extends StatefulWidget {
  const _ToastForm({this.t, required this.occ});
  final Map<String, dynamic>? t;
  final String occ;
  @override
  State<_ToastForm> createState() => _ToastFormState();
}

class _ToastFormState extends State<_ToastForm> {
  late String occ = widget.occ;
  late final title = TextEditingController(text: '${widget.t?['title'] ?? ''}');
  late final body = TextEditingController(text: '${widget.t?['body'] ?? ''}');
  bool busy = false;

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final a = title.text.trim(), b = body.text.trim();
    if (a.length < 2 || b.length < 10) {
      toast(context, 'ჩაწერე სათაური და სადღეგრძელო (მინ. 10 სიმბოლო)');
      return;
    }
    setState(() => busy = true);
    try {
      await context.app.api.saveToast(id: widget.t == null ? null : asInt(widget.t!['id']), occasion: occ, title: a, body: b);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, '$e'.contains('too_many') ? 'დღეს უკვე ბევრი დაწერე, სცადე ხვალ' : errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.t != null ? 'რედაქტირება' : 'ახალი სადღეგრძელო', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (k, n) in occasions)
                ChoiceChip(
                  key: ValueKey('tn-o-$k'),
                  label: Text(n),
                  selected: occ == k,
                  showCheckmark: false,
                  selectedColor: c.accentSoft,
                  side: BorderSide(color: occ == k ? c.accent : c.line),
                  onSelected: (_) => setState(() => occ = k),
                ),
            ]),
            const SizedBox(height: 10),
            TextField(key: const ValueKey('tn-title'), controller: title, maxLength: 80, decoration: const InputDecoration(labelText: 'სათაური', hintText: 'მაგ. მეგობრობის სადღეგრძელო', counterText: '')),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('tn-body'),
              controller: body,
              maxLength: 1500,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(labelText: 'სადღეგრძელო', hintText: 'დაწერე ისე, როგორც სუფრაზე იტყოდი…', counterText: ''),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const ValueKey('tn-ok'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: busy ? null : _save,
                icon: PIcon('send', size: 17, color: c.onAccent),
                label: Text(widget.t != null ? 'შენახვა' : 'გამოქვეყნება'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
