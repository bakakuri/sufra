// The conversation's tools (chat.js): choices in a sheet, forwarding, muting, disappearing messages, the group's
// members, search inside a conversation, its photos, links and places, a conversation's menu in the list (mute,
// archive) and a new group conversation.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../feed/photo_viewer.dart';
import '../people/person_screen.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'chat_screen.dart';
import 'chats_tab.dart';

/// A short list of choices in a sheet: the key of the one picked, or null.
Future<String?> pickFrom(BuildContext context, String title, List<(String, String, String)> items, {String? note}) => showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(s).height * .8),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 10), children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 6), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            for (final (k, icon, label) in items)
              ListTile(
                key: ValueKey('pf-$k'),
                leading: PIcon(icon, color: s.pc.ink),
                title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.of(s).pop(k),
              ),
            if (note != null) Padding(padding: const EdgeInsets.fromLTRB(20, 6, 20, 6), child: Text(note, style: TextStyle(color: s.pc.muted, fontSize: 13))),
          ]),
        ),
      ),
    );

/// A line of text asked for in a dialog; null when cancelled.
Future<String?> askText(BuildContext context, {required String title, String initial = '', String? hint, int max = 80}) async {
  final f = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const ValueKey('ask-text'),
        controller: f,
        autofocus: true,
        maxLength: max,
        decoration: InputDecoration(hintText: hint, counterText: ''),
        onSubmitted: (v) => Navigator.pop(d, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('გაუქმება')),
        TextButton(key: const ValueKey('ask-ok'), onPressed: () => Navigator.pop(d, f.text.trim()), child: const Text('შენახვა')),
      ],
    ),
  );
  return r;
}

/// "გადაგზავნა": the message into another conversation, marked as forwarded from its author.
Future<void> forwardMessage(BuildContext context, Message m, String fromName) async {
  final app = context.app;
  if (!app.chats.loaded) await app.chats.load();
  if (!context.mounted) return;
  final sent = <int>{};
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => StatefulBuilder(
      builder: (s, set) {
        final c = s.pc, list = app.chats.chats.where((x) => x.convId != m.convId).toList();
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(s).height * .8),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: [
              const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('ვის გადავუგზავნო?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              if (list.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('სხვა მიმოწერა ჯერ არ გაქვს.', style: TextStyle(color: c.muted))),
              for (final ch in list)
                ListTile(
                  key: ValueKey('fw-${ch.convId}'),
                  leading: ch.other != null
                      ? Avatar(p: app.people[ch.other!] ?? Profile(id: ch.other!, name: '…'), size: 40)
                      : GroupAvatar(id: ch.convId, size: 40),
                  title: Text(ch.isGroup ? ((ch.title ?? '').isEmpty ? 'ჯგუფი' : ch.title!) : (app.people[ch.other ?? '']?.name ?? ''),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: sent.contains(ch.convId) ? Text('გაიგზავნა', style: TextStyle(color: c.accent, fontWeight: FontWeight.w700)) : PIcon('send', size: 20, color: c.accent),
                  onTap: sent.contains(ch.convId)
                      ? null
                      : () async {
                          try {
                            await app.api.send(ch.convId,
                                body: m.body, kind: m.kind == 'system' ? 'text' : m.kind, media: {...?m.media, 'fwd': fromName.isEmpty ? 'Peera' : fromName});
                            set(() => sent.add(ch.convId));
                          } catch (e) {
                            if (s.mounted) toast(s, errText(e));
                          }
                        },
                ),
            ]),
          ),
        );
      },
    ),
  );
}

/// Muting a conversation: for an hour, eight, a week or until I turn it on; when muted, the sound back on.
Future<void> muteSheet(BuildContext context, Chat ch) async {
  final app = context.app;
  if (ch.muted) {
    if (await attempt(context, () => app.api.muteChat(ch.convId, null)) && context.mounted) {
      toast(context, 'ხმა ჩაირთო');
      await app.chats.load();
    }
    return;
  }
  final h = await pickFrom(
    context,
    'დადუმება',
    [('1', 'mute', '1 საათით'), ('8', 'mute', '8 საათით'), ('168', 'mute', '1 კვირით'), ('0', 'mute', 'სანამ თავად ჩავრთავ')],
    note: 'დადუმებული საუბრიდან შეტყობინება და push აღარ მოვა. მესიჯები ჩატში ჩვეულებრივად დაგხვდება.',
  );
  if (h == null || !context.mounted) return;
  final n = int.parse(h);
  final until = n == 0 ? DateTime.utc(2999) : DateTime.now().add(Duration(hours: n));
  if (await attempt(context, () => app.api.muteChat(ch.convId, until)) && context.mounted) {
    toast(context, 'საუბარი დადუმდა');
    await app.chats.load();
  }
}

/// Disappearing messages: off, an hour, a day or a week; 0 for off, null when closed.
Future<int?> ttlSheet(BuildContext context, int? current) async {
  String mark(int? v) => v == current ? '✓ ' : '';
  final r = await pickFrom(
    context,
    'თვითგაქრობა',
    [
      ('0', 'timer', '${mark(null)}გამორთული'),
      ('3600', 'timer', '${mark(3600)}1 საათში'),
      ('86400', 'timer', '${mark(86400)}24 საათში'),
      ('604800', 'timer', '${mark(604800)}7 დღეში'),
    ],
    note: 'ჩართვის შემდეგ ახალი შეტყობინებები ორივე მხარეს თავისით გაქრება. ეკრანის სურათს ეს ვერ შეაჩერებს.',
  );
  return r == null ? null : int.parse(r);
}

/// A group's members, me first.
Future<void> groupMembers(BuildContext context, Chat ch) async {
  final app = context.app, me = context.me;
  await app.people.ensure(ch.members);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(s).height * .8),
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('წევრები · ${ch.members.length + 1}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          ListTile(leading: Avatar(p: me, size: 40), title: Text('${me.name} (შენ)', style: const TextStyle(fontWeight: FontWeight.w700))),
          for (final id in ch.members)
            ListTile(
              key: ValueKey('gm-$id'),
              leading: Avatar(p: app.people[id] ?? Profile(id: id, name: '…'), size: 40),
              title: Text(app.people[id]?.name ?? '…', style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.of(s).pop();
                openPage(context, PersonScreen(uid: id, initial: app.people[id]), full: true);
              },
            ),
        ]),
      ),
    ),
  );
}

/// A conversation held in the list: mute or archive it.
Future<void> chatMenu(BuildContext context, Chat ch) async {
  final app = context.app;
  final title = ch.isGroup ? ((ch.title ?? '').isEmpty ? 'ჯგუფი' : ch.title!) : (app.people[ch.other ?? '']?.name ?? '');
  final k = await pickFrom(context, title, [
    ('mute', 'mute', ch.muted ? 'ხმის ჩართვა' : 'დადუმება'),
    ('arch', 'archive', ch.archived ? 'არქივიდან ამოღება' : 'არქივში გადატანა'),
  ]);
  if (k == null || !context.mounted) return;
  if (k == 'mute') return muteSheet(context, ch);
  final on = !ch.archived;
  if (await attempt(context, () => app.api.archiveChat(ch.convId, on)) && context.mounted) {
    toast(context, on ? 'გადავიდა არქივში' : 'ამოვიდა არქივიდან');
    await app.chats.load();
  }
}

/// Searching inside one conversation; the message picked goes back to it (its id).
class ChatSearchScreen extends StatefulWidget {
  const ChatSearchScreen({super.key, required this.convId});
  final int convId;
  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final field = TextEditingController();
  Timer? _wait;
  List<Message>? found;
  Object? error;
  int _gen = 0;

  @override
  void dispose() {
    _wait?.cancel();
    field.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final v = field.text.trim(), g = ++_gen, app = context.app;
    if (v.length < 2) {
      setState(() => found = null);
      return;
    }
    try {
      final r = await app.api.searchMessages(widget.convId, v);
      await app.people.ensure(r.map((m) => m.sender));
      if (mounted && g == _gen) {
        setState(() {
          found = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && g == _gen) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, me = context.me.id, v = field.text.trim(), list = found;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        leading: backButton(context),
        titleSpacing: 0,
        title: TextField(
          key: const ValueKey('cs-q'),
          controller: field,
          autofocus: true,
          maxLength: 60,
          onChanged: (_) {
            _wait?.cancel();
            _wait = Timer(const Duration(milliseconds: 300), _run);
          },
          decoration: InputDecoration(
            hintText: 'ძებნა საუბარში',
            counterText: '',
            isDense: true,
            prefixIcon: Padding(padding: const EdgeInsets.all(11), child: PIcon('search', size: 20, color: c.muted)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: c.accent, width: 1.5)),
          ),
        ),
        actions: const [SizedBox(width: 14)],
      ),
      body: error != null
          ? Empty(icon: 'search', title: 'ძებნა ვერ მოხერხდა', text: errText(error!))
          : list == null
              ? Empty(icon: 'search', title: 'რას ეძებ?', text: 'ჩაწერე მინიმუმ 2 ასო.')
              : list.isEmpty
                  ? const Empty(icon: 'search', title: 'ვერაფერი მოიძებნა')
                  : ListView(children: [
                      for (final m in list)
                        ListTile(
                          key: ValueKey('csr-${m.id}'),
                          leading: Avatar(p: app.people[m.sender] ?? Profile(id: m.sender, name: '…'), size: 38),
                          title: Text('${m.sender == me ? 'შენ' : (app.people[m.sender]?.name ?? '')} · ${ago(m.createdAt)}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          subtitle: _Hl(m.body, v),
                          onTap: () => Navigator.of(context).pop(m.id),
                        ),
                    ]),
    );
  }
}

/// the found words lit up, with a little around them
class _Hl extends StatelessWidget {
  const _Hl(this.text, this.q);
  final String text, q;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, i = text.toLowerCase().indexOf(q.toLowerCase());
    if (i < 0 || q.isEmpty) return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);
    final from = i > 30 ? i - 30 : 0;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '${from > 0 ? '…' : ''}${text.substring(from, i)}'),
        TextSpan(text: text.substring(i, i + q.length), style: TextStyle(backgroundColor: c.gold.withValues(alpha: .35), color: c.ink, fontWeight: FontWeight.w700)),
        TextSpan(text: text.substring(i + q.length)),
      ]),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: c.muted),
    );
  }
}

/// Photos, links and places shared in a conversation, in three tabs.
class ChatMediaScreen extends StatefulWidget {
  const ChatMediaScreen({super.key, required this.convId});
  final int convId;
  @override
  State<ChatMediaScreen> createState() => _ChatMediaScreenState();
}

class _ChatMediaScreenState extends State<ChatMediaScreen> {
  ({List<Message> photos, List<Message> links, List<Message> places})? d;
  Object? error;
  String tab = 'img';
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final app = context.app;
    app.api.chatMedia(widget.convId).then((r) async {
      await app.people.ensure([...r.links, ...r.places].map((m) => m.sender));
      if (mounted) setState(() => d = r);
    }).catchError((Object e) {
      if (mounted) setState(() => error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, me = context.me.id, x = d;
    Widget body;
    if (error != null) {
      body = Empty(icon: 'image', title: 'ვერ ჩაიტვირთა', text: errText(error!));
    } else if (x == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (tab == 'img') {
      final ph = [for (final m in x.photos) if (m.photo != null) m.photo!];
      body = ph.isEmpty
          ? const Empty(icon: 'image', title: 'ამ საუბარში ფოტოები ჯერ არ არის')
          : GridView.count(crossAxisCount: 3, padding: const EdgeInsets.all(4), mainAxisSpacing: 4, crossAxisSpacing: 4, children: [
              for (var i = 0; i < ph.length; i++)
                GestureDetector(key: ValueKey('cmi-$i'), onTap: () => openPhotos(context, ph, start: i), child: PImage(ph[i].small, radius: 6)),
            ]);
    } else if (tab == 'link') {
      final rows = [
        for (final m in x.links)
          if (RegExp(r'https?://[^\s<]+').firstMatch(m.body)?.group(0) case final u?) (m, u),
      ];
      body = rows.isEmpty
          ? const Empty(icon: 'link', title: 'ბმულები ჯერ არ არის')
          : ListView(children: [
              for (final (m, u) in rows)
                ListTile(
                  leading: CircleAvatar(backgroundColor: c.sunk, child: PIcon('link', size: 20, color: c.accent)),
                  title: Text(((m.media?['link'] as Map?)?['title'] as String?) ?? u.replaceFirst(RegExp(r'^https?://'), ''),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${m.sender == me ? 'შენ' : (app.people[m.sender]?.name ?? '')} · ${fullDate(m.createdAt)}', style: TextStyle(color: c.muted)),
                  onTap: () => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication),
                ),
            ]);
    } else {
      final locs = [for (final m in x.places) if (m.media?['loc'] is Map) m];
      body = locs.isEmpty
          ? const Empty(icon: 'pin', title: 'ლოკაციები ჯერ არ არის')
          : ListView(padding: const EdgeInsets.all(12), children: [
              for (final m in locs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    LocCard(lat: asNum((m.media!['loc'] as Map)['lat']) ?? 0, lng: asNum((m.media!['loc'] as Map)['lng']) ?? 0, acc: asNum((m.media!['loc'] as Map)['acc'])),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text('${m.sender == me ? 'შენ' : (app.people[m.sender]?.name ?? '')} · ${fullDate(m.createdAt)}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                    ),
                  ]),
                ),
            ]);
    }
    return Scaffold(
      appBar: peeraBar(context, title: 'ფოტოები და ბმულები'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'img', label: Text('ფოტოები')),
              ButtonSegment(value: 'link', label: Text('ბმულები')),
              ButtonSegment(value: 'loc', label: Text('ლოკაციები')),
            ],
            selected: {tab},
            onSelectionChanged: (s) => setState(() => tab = s.first),
          ),
        ),
        Expanded(child: body),
      ]),
    );
  }
}

/// A new group conversation: its name and the friends in it.
class NewGroupChatScreen extends StatefulWidget {
  const NewGroupChatScreen({super.key});
  @override
  State<NewGroupChatScreen> createState() => _NewGroupChatScreenState();
}

class _NewGroupChatScreenState extends State<NewGroupChatScreen> {
  final title = TextEditingController();
  final sel = <String>{};
  bool busy = false;

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> _make() async {
    if (sel.isEmpty) {
      toast(context, 'აირჩიე მინიმუმ ერთი მეგობარი');
      return;
    }
    final app = context.app;
    setState(() => busy = true);
    try {
      final id = await app.api.createGroupChat(title.text.trim(), sel.toList());
      await app.chats.load();
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return Scaffold(
      appBar: peeraBar(context, title: 'ახალი ჯგუფური ჩატი', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(
            key: const ValueKey('gc-make'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: busy || sel.isEmpty ? null : _make,
            child: Text(sel.isEmpty ? 'შექმნა' : 'შექმნა (${sel.length})'),
          ),
        ),
      ]),
      body: ListenableBuilder(
        listenable: Listenable.merge([app.friends, app.people]),
        builder: (context, _) {
          final ids = app.friends.friends.toList()..sort((a, b) => (app.people[a]?.name ?? '').compareTo(app.people[b]?.name ?? ''));
          return ListView(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                key: const ValueKey('gc-title'),
                controller: title,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'ჯგუფის სახელი', hintText: 'მაგ. მე-11 ბ კლასი', counterText: ''),
              ),
            ),
            if (ids.isEmpty) const Empty(icon: 'users', title: 'მეგობრები ჯერ არ გყავს'),
            for (final id in ids)
              CheckboxListTile(
                key: ValueKey('gc-$id'),
                value: sel.contains(id),
                onChanged: busy ? null : (v) => setState(() => v == true ? sel.add(id) : sel.remove(id)),
                secondary: Avatar(p: app.people[id] ?? Profile(id: id, name: '…'), size: 40),
                title: Text(app.people[id]?.name ?? '…', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
          ]);
        },
      ),
    );
  }
}
