// Help (help.js): blood donors, lost and found pets and things, volunteers. The open requests by kind and region; being
// told about the ones nearby (the region, a donor's blood type, which kinds); a request written with photos; one request
// answered ("შემიძლია დახმარება"), its author told and thanked when it is resolved.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../config.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../feed/photo_viewer.dart';
import '../feed/post_actions.dart';
import '../feed/post_card.dart';
import '../people/profile_parts.dart';
import '../profile/profile.dart';
import '../settings/places.dart';
import '../ui/bits.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/look.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const helpKinds = [
  ('blood', 'საჭიროა სისხლი', '🩸'),
  ('lost_pet', 'დაიკარგა ცხოველი', '🐾'),
  ('found_pet', 'ნაპოვნია ცხოველი', '🐶'),
  ('lost_item', 'დაიკარგა ნივთი', '🔑'),
  ('found_item', 'ნაპოვნია ნივთი', '📦'),
  ('volunteer', 'საჭიროა მოხალისე', '🤝'),
  ('other', 'სხვა თხოვნა', '💬'),
];
const _filters = [('', 'ყველა'), ('blood', '🩸 სისხლი'), ('pets', '🐾 ცხოველები'), ('items', '🔑 ნივთები'), ('volunteer', '🤝 მოხალისეობა'), ('other', '💬 სხვა')];
const bloodTypes = ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'];

(String, String, String) helpKind(Object? k) => helpKinds.firstWhere((x) => x.$1 == k, orElse: () => helpKinds.last);

List<String> _media(Object? v) => [for (final u in (v is List ? v : const [])) if (u is String && u.startsWith('https://')) u];

/// the labels on a request: its kind, the blood type, urgent, resolved
Widget helpTags(Map<String, dynamic> h) {
  final k = helpKind(h['kind']), open = h['status'] == 'open';
  return Wrap(spacing: 5, runSpacing: 5, children: [
    PTag(k.$2),
    if ('${h['blood_type'] ?? ''}'.isNotEmpty) PTag('${h['blood_type']}', kind: 'blood'),
    if (h['urgent'] == true && open) const PTag('სასწრაფო', kind: 'warn'),
    if (!open) const PTag('მოგვარდა', kind: 'ok'),
  ]);
}

String _where(Map<String, dynamic> h) {
  final r = '${h['region'] ?? ''}', c = '${h['city'] ?? ''}';
  return [r, if (c.isNotEmpty && c != r) c].where((x) => x.isNotEmpty).join(' · ');
}

/// One request in the list.
class HelpCard extends StatelessWidget {
  const HelpCard({super.key, required this.h, required this.onBack});
  final Map<String, dynamic> h;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, k = helpKind(h['kind']), img = _media(h['media']).firstOrNull, urgent = h['urgent'] == true && h['status'] == 'open';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: urgent ? c.nope.withValues(alpha: .06) : c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: urgent ? c.nope.withValues(alpha: .4) : c.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('hc-${h['id']}'),
          onTap: () async {
            await openPage(context, HelpRequestScreen(id: asInt(h['id'])), full: true);
            onBack();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(k.$3, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  helpTags(h),
                  const SizedBox(height: 4),
                  Text('${h['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('${_where(h)} · ${ago(asTime(h['created_at']))}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                ]),
              ),
              if (img != null && !ecoMode.value) ...[
                const SizedBox(width: 8),
                ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 60, height: 60, child: PImage(img))),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// The help board.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String kind = '';
  late String region = homeRegions.contains(context.me.homeRegion) ? context.me.homeRegion! : '';
  bool done = false;
  List<Map<String, dynamic>>? rows;
  Map<String, dynamic>? helper;
  Object? error;
  int _gen = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
    _helper();
  }

  Future<void> _load() async {
    final g = ++_gen;
    try {
      final r = await context.app.api.helpRequests(kind: kind, region: region, done: done);
      if (mounted && g == _gen) {
        setState(() {
          rows = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && g == _gen) setState(() => error = e);
    }
  }

  Future<void> _helper() async {
    try {
      final h = await context.app.api.helperSettings();
      if (mounted) setState(() => helper = h);
    } catch (_) {}
  }

  Future<void> _settings() async {
    final saved = await helperSheet(context, helper);
    if (saved != null && mounted) {
      setState(() => helper = saved.isEmpty ? null : saved);
    }
  }

  Future<void> _new() async {
    final id = await openPage<int>(context, const HelpNewScreen(), full: true);
    if (id != null && mounted) await openPage(context, HelpRequestScreen(id: id), full: true);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, h = helper, r = rows;
    final on = h != null && '${h['region'] ?? ''}'.isNotEmpty && (h['notify_blood'] == true || h['notify_pets'] == true || h['notify_volunteer'] == true);
    return Scaffold(
      appBar: peeraBar(context, title: 'დახმარება', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: FilledButton.icon(
            key: const ValueKey('hl-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: _new,
            icon: PIcon('plus', size: 17, color: c.onAccent),
            label: const Text('თხოვნა'),
          ),
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              PIcon('help', size: 30, color: c.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('ერთმანეთის გვერდით', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(
                    on
                        ? 'შეტყობინებები ჩართულია · ${h['region']}${h['notify_blood'] == true && '${h['blood_type'] ?? ''}'.isNotEmpty ? ' · დონორი ${h['blood_type']}' : ''}'
                        : 'ჩართე შეტყობინებები და გაიგებ, როცა შენს მახლობლად დახმარება სჭირდებათ',
                    key: const ValueKey('hl-status'),
                    style: TextStyle(color: c.muted, fontSize: 13),
                  ),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey('hl-set'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                onPressed: _settings,
                icon: const PIcon('bell', size: 17),
                label: const Text('შეტყობინებები'),
              ),
            ),
          ),
          ChipsBar(
            prefix: 'hlf',
            items: _filters,
            value: kind,
            onPick: (k) {
              setState(() => kind = k);
              _load();
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('hl-region'),
                  isExpanded: true,
                  initialValue: region,
                  decoration: const InputDecoration(labelText: 'რეგიონი'),
                  items: [const DropdownMenuItem(value: '', child: Text('ყველა რეგიონი')), for (final x in homeRegions) DropdownMenuItem(value: x, child: Text(x, overflow: TextOverflow.ellipsis))],
                  onChanged: (v) {
                    setState(() => region = v ?? '');
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 4),
              Checkbox(
                key: const ValueKey('hl-done'),
                value: done,
                onChanged: (v) {
                  setState(() => done = v == true);
                  _load();
                },
              ),
              const Text('მოგვარებულიც'),
            ]),
          ),
          if (r == null && error == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (r == null)
            Empty(icon: 'help', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
          else if (r.isEmpty)
            Empty(
              icon: 'help',
              title: region.isNotEmpty ? '$region: ღია თხოვნა არ არის' : 'ღია თხოვნა არ არის',
              text: 'კარგი ამბავია. თუ დახმარება გჭირდება, დაწერე.',
              action: 'თხოვნის დაწერა',
              onAction: _new,
            )
          else
            for (final x in r) HelpCard(h: x, onBack: _load),
        ]),
      ),
    );
  }
}

/// What help I am told about. The settings saved (empty when switched off), or null when left.
Future<Map<String, dynamic>?> helperSheet(BuildContext context, Map<String, dynamic>? h) {
  final app = context.app, me = context.me;
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => AppScope(app: app, me: me, child: _HelperSheet(h: h)),
  );
}

class _HelperSheet extends StatefulWidget {
  const _HelperSheet({this.h});
  final Map<String, dynamic>? h;
  @override
  State<_HelperSheet> createState() => _HelperSheetState();
}

class _HelperSheetState extends State<_HelperSheet> {
  late final h = widget.h;
  late String region = '${h?['region'] ?? context.me.homeRegion ?? ''}';
  late String blood = '${h?['blood_type'] ?? ''}';
  late bool nb = h?['notify_blood'] == true, np = h?['notify_pets'] == true, nv = h?['notify_volunteer'] == true;
  bool busy = false;

  Future<void> _save() async {
    if ((nb || np || nv) && region.isEmpty) {
      toast(context, 'აირჩიე რეგიონი');
      return;
    }
    if (nb && blood.isEmpty) {
      toast(context, 'აირჩიე სისხლის ჯგუფი');
      return;
    }
    final row = <String, dynamic>{'region': region, 'blood_type': blood.isEmpty ? null : blood, 'notify_blood': nb, 'notify_pets': np, 'notify_volunteer': nv};
    setState(() => busy = true);
    try {
      await context.app.api.saveHelper(row);
      if (!mounted) return;
      toast(context, 'შენახულია. მადლობა!');
      Navigator.of(context).pop(row);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e));
    }
  }

  Future<void> _off() async {
    setState(() => busy = true);
    try {
      await context.app.api.saveHelper(null);
      if (!mounted) return;
      toast(context, 'გამოირთო');
      Navigator.of(context).pop(<String, dynamic>{});
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('შეტყობინებები დახმარებაზე', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('როცა შენს რეგიონში ვინმე დახმარებას ითხოვს, შეტყობინებას მიიღებ.', style: TextStyle(color: c.muted)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: const ValueKey('hs-region'),
            isExpanded: true,
            initialValue: homeRegions.contains(region) ? region : '',
            decoration: const InputDecoration(labelText: 'ჩემი რეგიონი'),
            items: [const DropdownMenuItem(value: '', child: Text('—')), for (final x in homeRegions) DropdownMenuItem(value: x, child: Text(x, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => region = v ?? ''),
          ),
          SwitchListTile(key: const ValueKey('hs-blood'), contentPadding: EdgeInsets.zero, value: nb, onChanged: (v) => setState(() => nb = v), title: const Text('🩸 სისხლის დონორი ვარ')),
          if (nb)
            DropdownButtonFormField<String>(
              key: const ValueKey('hs-bt'),
              initialValue: bloodTypes.contains(blood) ? blood : '',
              decoration: const InputDecoration(labelText: 'სისხლის ჯგუფი'),
              items: [const DropdownMenuItem(value: '', child: Text('—')), for (final b in bloodTypes) DropdownMenuItem(value: b, child: Text(b))],
              onChanged: (v) => setState(() => blood = v ?? ''),
            ),
          SwitchListTile(key: const ValueKey('hs-pets'), contentPadding: EdgeInsets.zero, value: np, onChanged: (v) => setState(() => np = v), title: const Text('🐾 დაკარგული და ნაპოვნი ცხოველები')),
          SwitchListTile(key: const ValueKey('hs-vol'), contentPadding: EdgeInsets.zero, value: nv, onChanged: (v) => setState(() => nv = v), title: const Text('🤝 მოხალისეობა')),
          Text(
            'სისხლის ჯგუფს ვერავინ ნახავს. ის მხოლოდ შესაბამისი თხოვნის შეტყობინებისთვის გამოიყენება. სისხლის ჩაბარებამდე გაიარე ექიმის კონსულტაცია.',
            style: TextStyle(color: c.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          Row(children: [
            if (h != null) TextButton(key: const ValueKey('hs-off'), onPressed: busy ? null : _off, child: const Text('ყველას გამორთვა')),
            const Spacer(),
            FilledButton(key: const ValueKey('hs-ok'), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: busy ? null : _save, child: const Text('შენახვა')),
          ]),
        ]),
      ),
    );
  }
}

/// A request for help: what is needed, the blood type, details, where, a contact, urgent, photos. Pops with its id.
class HelpNewScreen extends StatefulWidget {
  const HelpNewScreen({super.key});
  @override
  State<HelpNewScreen> createState() => _HelpNewScreenState();
}

class _HelpNewScreenState extends State<HelpNewScreen> {
  String kind = 'blood', blood = '';
  bool urgent = true, busy = false;
  final title = TextEditingController(), body = TextEditingController(), contact = TextEditingController();
  late final city = TextEditingController(text: context.me.city ?? '');
  late String region = homeRegions.contains(context.me.homeRegion) ? context.me.homeRegion! : 'თბილისი';
  final photos = <Uint8List>[];
  String stage = '';

  @override
  void dispose() {
    for (final x in [title, body, contact, city]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _photo() async {
    if (photos.length >= 4) {
      toast(context, 'მაქსიმუმ 4 ფოტო');
      return;
    }
    final got = await photoSource(false);
    if (got.isNotEmpty && mounted) setState(() => photos.addAll(got.take(4 - photos.length)));
  }

  Future<void> _send() async {
    final t = title.text.trim();
    if (t.length < 4) {
      toast(context, 'დაწერე, რა გჭირდება');
      return;
    }
    final api = context.app.api;
    setState(() => busy = true);
    try {
      final media = <String>[];
      for (var i = 0; i < photos.length; i++) {
        setState(() => stage = 'იტვირთება ${i + 1}/${photos.length}…');
        media.add((await api.uploadPhoto(await photoPrep(photos[i]))).url);
      }
      final id = await api.createHelp({
        'kind': kind,
        'title': t,
        'body': body.text.trim(),
        'media': media,
        'region': region,
        'city': city.text.trim(),
        'blood_type': kind == 'blood' && blood.isNotEmpty ? blood : null,
        'contact': contact.text.trim(),
        'urgent': urgent,
      });
      if (!mounted) return;
      toast(context, 'თხოვნა გამოქვეყნდა. იმედია, მალე მოგვარდება');
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        stage = '';
      });
      toast(context, '$e'.contains('too_many') ? 'დღეში მაქსიმუმ 3 თხოვნა შეიძლება' : errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      appBar: peeraBar(context, title: 'დახმარების თხოვნა', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(
            key: const ValueKey('hn-ok'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: busy ? null : _send,
            child: Text(stage.isNotEmpty ? stage : 'გამოქვეყნება'),
          ),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (k, n, e) in helpKinds)
            ChoiceChip(
              key: ValueKey('hn-k-$k'),
              label: Text('$e $n'),
              selected: kind == k,
              showCheckmark: false,
              selectedColor: c.accentSoft,
              side: BorderSide(color: kind == k ? c.accent : c.line),
              onSelected: (_) => setState(() {
                kind = k;
                urgent = k == 'blood';
              }),
            ),
        ]),
        const SizedBox(height: 12),
        TextField(key: const ValueKey('hn-title'), controller: title, maxLength: 100, decoration: const InputDecoration(labelText: 'მოკლედ', hintText: 'მაგ. საჭიროა A+ სისხლი რესპუბლიკურ საავადმყოფოში', counterText: '')),
        if (kind == 'blood') ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: const ValueKey('hn-bt'),
            initialValue: blood,
            decoration: const InputDecoration(labelText: 'სისხლის ჯგუფი'),
            items: [const DropdownMenuItem(value: '', child: Text('ნებისმიერი')), for (final b in bloodTypes) DropdownMenuItem(value: b, child: Text(b))],
            onChanged: (v) => setState(() => blood = v ?? ''),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('hn-body'),
          controller: body,
          maxLength: 1500,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(labelText: 'დეტალები', hintText: 'სად, როდის, ვის მიმართონ. ცხოველისთვის: ჯიში, ფერი, სად ნახეს ბოლოს', counterText: ''),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const ValueKey('hn-region'),
          isExpanded: true,
          initialValue: region,
          decoration: const InputDecoration(labelText: 'რეგიონი'),
          items: [for (final x in homeRegions) DropdownMenuItem(value: x, child: Text(x, overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => region = v ?? region),
        ),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('hn-city'), controller: city, maxLength: 60, decoration: const InputDecoration(labelText: 'ქალაქი ან სოფელი', counterText: '')),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('hn-contact'),
          controller: contact,
          maxLength: 60,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'საკონტაქტო (არასავალდებულო)', hintText: 'ტელეფონი ან სხვა კონტაქტი', counterText: ''),
        ),
        SwitchListTile(key: const ValueKey('hn-urgent'), contentPadding: EdgeInsets.zero, value: urgent, onChanged: (v) => setState(() => urgent = v), title: const Text('სასწრაფოა')),
        const Text('ფოტოები', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < photos.length; i++)
            Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(photos[i], width: 76, height: 76, fit: BoxFit.cover)),
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  key: ValueKey('hn-rm-$i'),
                  onTap: () => setState(() => photos.removeAt(i)),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                    child: const PIcon('x', size: 14, color: Colors.white),
                  ),
                ),
              ),
            ]),
          OutlinedButton.icon(
            key: const ValueKey('hn-photo'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: busy ? null : _photo,
            icon: const PIcon('image', size: 17),
            label: const Text('ფოტოს დამატება'),
          ),
        ]),
        const SizedBox(height: 12),
        Text(
          'თხოვნა 30 დღე ჩანს. შენს რეგიონში შეტყობინებას მიიღებენ ისინი, ვინც ამ ტიპის დახმარებაზე დათანხმდა. პირად მონაცემებს ფრთხილად გაუზიარე.',
          style: TextStyle(color: c.muted, fontSize: 12.5),
        ),
      ]),
    );
  }
}

/// One request: who asked, the details, the photos and the contact; "I can help" (or withdrawn), resolved by its
/// author, who sees everyone who answered.
class HelpRequestScreen extends StatefulWidget {
  const HelpRequestScreen({super.key, required this.id});
  final int id;
  @override
  State<HelpRequestScreen> createState() => _HelpRequestScreenState();
}

class _HelpRequestScreenState extends State<HelpRequestScreen> {
  Map<String, dynamic>? h;
  List<Map<String, dynamic>> offers = const [];
  bool loaded = false;
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
      final r = await app.api.helpRequest(widget.id);
      if (r != null) await app.people.ensure(['${r.$1['author']}', for (final o in r.$2) '${o['user_id']}']);
      if (!mounted) return;
      setState(() {
        h = r?.$1;
        offers = r?.$2 ?? const [];
        loaded = true;
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loaded = true;
        });
      }
    }
  }

  Future<void> _offer() async {
    final x = h!, app = context.app, c = context.pc;
    final author = app.people['${x['author']}']?.name ?? 'ავტორი';
    final note = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (s) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(s).bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('დახმარება', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('$author მიიღებს შეტყობინებას, რომ შეგიძლია დახმარება.'),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('ho-note'),
                controller: note,
                maxLength: 300,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'მოკლე შეტყობინება (არასავალდებულო)', hintText: 'მაგ. ჩემი ჯგუფია A+, შემიძლია ხვალ დილით მოსვლა', counterText: ''),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const ValueKey('ho-send'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => Navigator.of(s).pop(true),
                  icon: PIcon('send', size: 17, color: s.pc.onAccent),
                  label: const Text('გაგზავნა'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    final text = note.text.trim();
    if (ok != true || !mounted) return;
    if (await attempt(context, () => app.api.offerHelp(asInt(x['id']), text)) && mounted) {
      toast(context, 'ავტორს ეცნობა. მადლობა!');
      _load();
    }
  }

  Future<void> _resolve() async {
    if (!await confirm(context, title: 'მოგვარდა?', text: 'თხოვნა დაიხურება და ვინც გამოგეხმაურა, მადლობის შეტყობინებას მიიღებს.', yes: 'მოგვარდა') || !mounted) return;
    if (await attempt(context, () => context.app.api.resolveHelp(widget.id)) && mounted) {
      toast(context, 'ძალიან კარგი!');
      _load();
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, title: 'თხოვნის წაშლა', text: 'თხოვნა წაიშლება ყველასთვის.', yes: 'წაშლა', danger: true) || !mounted) return;
    if (await attempt(context, () => context.app.api.deleteHelp(widget.id)) && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = h, app = context.app;
    if (x == null) {
      return Scaffold(
        appBar: peeraBar(context, title: 'თხოვნა'),
        body: !loaded
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Empty(icon: 'help', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
                : const Empty(icon: 'help', title: 'თხოვნა ვერ მოიძებნა', text: 'შეიძლება წაიშალა.'),
      );
    }
    final me = app.api.myId, uid = '${x['author']}', mine = uid == me, open = x['status'] == 'open', k = helpKind(x['kind']);
    final my = offers.where((o) => o['user_id'] == me).firstOrNull, who = app.people[uid] ?? Profile(id: uid, name: '…');
    final contact = '${x['contact'] ?? ''}'.trim(), isTel = RegExp(r'^[+\d][\d\s()-]{5,}$').hasMatch(contact), pics = _media(x['media']);
    Widget btn(String key, String icon, String label, VoidCallback onTap, {bool filled = false, Color? color}) => filled
        ? FilledButton.icon(key: ValueKey(key), style: FilledButton.styleFrom(minimumSize: const Size(0, 42)), onPressed: onTap, icon: PIcon(icon, size: 17, color: c.onAccent), label: Text(label))
        : OutlinedButton.icon(
            key: ValueKey(key),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), foregroundColor: color),
            onPressed: onTap,
            icon: PIcon(icon, size: 17, color: color),
            label: Text(label),
          );
    return Scaffold(
      appBar: peeraBar(context, title: 'თხოვნა'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: x['urgent'] == true && open ? c.nope.withValues(alpha: .06) : c.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: x['urgent'] == true && open ? c.nope.withValues(alpha: .4) : c.line),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Text(k.$3, style: const TextStyle(fontSize: 26)), const SizedBox(width: 8), Expanded(child: helpTags(x))]),
              const SizedBox(height: 8),
              Text('${x['title'] ?? ''}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              Text('${_where(x)} · ${ago(asTime(x['created_at']))}', style: TextStyle(color: c.muted)),
              const SizedBox(height: 10),
              Row(children: [
                GestureDetector(onTap: () => openPerson(context, who), child: Avatar(p: who, size: 40)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(who.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('ავტორი', style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ]),
                ),
                if (!mine)
                  OutlinedButton.icon(
                    key: const ValueKey('hr-chat'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                    onPressed: () => chatWith(context, uid),
                    icon: const PIcon('msg', size: 16),
                    label: const Text('მიწერა'),
                  ),
              ]),
              if ('${x['body'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('${x['body']}', style: const TextStyle(fontSize: 15.5))),
              if (pics.isNotEmpty && !ecoMode.value)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (var i = 0; i < pics.length; i++)
                      GestureDetector(
                        onTap: () => openPhotos(context, [for (final u in pics) Media(url: u)], start: i),
                        child: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 96, height: 96, child: PImage(pics[i]))),
                      ),
                  ]),
                ),
              if (contact.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: InkWell(
                    key: const ValueKey('hr-contact'),
                    onTap: isTel ? () => openExternal(Uri.parse('tel:${contact.replaceAll(RegExp(r'[^\d+]'), '')}')) : null,
                    child: Row(children: [
                      PIcon('phone', size: 18, color: c.accent),
                      const SizedBox(width: 6),
                      Text(contact, style: TextStyle(color: isTel ? c.accent : c.ink, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (mine && open) btn('hr-resolve', 'check', 'მოგვარდა', _resolve, filled: true),
                if (!mine && open)
                  if (my != null)
                    btn('hr-unoffer', 'check', 'გამოეხმაურე · გაუქმება', () async {
                      if (await attempt(context, () => app.api.unofferHelp(widget.id))) _load();
                    })
                  else
                    btn('hr-offer', 'help', 'შემიძლია დახმარება', _offer, filled: true),
                btn('hr-share', 'share', 'გაზიარება', () => shareText(context, '${x['title']}\n$siteUrl/#helpreq-${x['id']}')),
                if (mine)
                  btn('hr-del', 'trash', 'წაშლა', _delete, color: c.nope)
                else
                  btn('hr-report', 'flag', 'საჩივარი', () => reportSheet(context, 'help', '${x['id']}')),
                if (isStaff(context) && !mine)
                  btn('hr-mod', 'lock', x['hidden'] == true ? 'გამოჩენა' : 'დამალვა', () async {
                    if (await attempt(context, () => app.api.modHide('help', widget.id, x['hidden'] != true))) _load();
                  }),
              ]),
            ]),
          ),
          if (mine) ...[
            SecHead('გამოეხმაურნენ · ${offers.length}'),
            if (offers.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('ჯერ არავინ. გაუზიარე მეგობრებს, რომ მეტმა ნახოს.', style: TextStyle(color: c.muted))),
            for (final o in offers)
              if (app.people['${o['user_id']}'] case final p?)
                ListTile(
                  key: ValueKey('ho-${o['user_id']}'),
                  leading: GestureDetector(onTap: () => openPerson(context, p), child: Avatar(p: p, size: 40)),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${'${o['note'] ?? ''}'.isNotEmpty ? '${o['note']} · ' : ''}${ago(asTime(o['created_at']))}'),
                  trailing: FilledButton.icon(
                    key: ValueKey('ho-chat-${o['user_id']}'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                    onPressed: () => chatWith(context, p.id),
                    icon: PIcon('msg', size: 15, color: c.onAccent),
                    label: const Text('მიწერა'),
                  ),
                ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text('Peera ამოწმებს საჩივრებს, მაგრამ თხოვნების სისწორეს ვერ ადასტურებს. ფულს წინასწარ ნუ გადარიცხავ.', style: TextStyle(color: c.muted, fontSize: 12.5)),
          ),
        ]),
      ),
    );
  }
}
