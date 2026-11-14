// The market (community.js PG.market, mitem, mknew): things for sale by category and by words; one item with its
// photos, the seller, a safety note, kept for later, a message to the seller with the question ready; mine marked
// sold or taken away; a new one with up to six photos.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../feed/photo_viewer.dart';
import '../feed/post_actions.dart';
import '../media/photo_edit.dart';
import '../people/person_screen.dart';
import '../people/profile_parts.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/translate.dart';
import '../ui/widgets.dart';

/// the market's categories (community.js CATS)
const marketCats = [
  ('all', 'ყველა'), ('tech', 'ელექტრონიკა'), ('home', 'სახლი'), ('fashion', 'ტანსაცმელი'), ('sport', 'სპორტი'), //
  ('auto', 'ავტო'), ('food', 'საკვები'), ('kids', 'ბავშვები'), ('other', 'სხვა'),
];

String _price(Object? p) {
  final n = asNum(p) ?? 0;
  final s = n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
  return '${s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')} ₾';
}

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final q = TextEditingController();
  String cat = 'all';
  List<Map<String, dynamic>>? rows;
  Object? error;
  Timer? _wait;
  int _gen = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    _wait?.cancel();
    q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final g = ++_gen;
    try {
      final r = await context.app.api.listings(cat: cat, q: q.text.trim());
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

  Future<void> _new() async {
    final ok = await openPage<bool>(context, const ListingFormScreen(), full: true);
    if (ok == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, r = rows;
    return Scaffold(
      appBar: peeraBar(context, title: 'ბაზრობა', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: FilledButton.icon(
            key: const ValueKey('mk-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: _new,
            icon: PIcon('plus', size: 17, color: c.onAccent),
            label: const Text('გაყიდვა'),
          ),
        ),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            key: const ValueKey('mk-q'),
            controller: q,
            textInputAction: TextInputAction.search,
            onChanged: (_) {
              _wait?.cancel();
              _wait = Timer(const Duration(milliseconds: 350), _load);
            },
            decoration: InputDecoration(hintText: 'რას ეძებ?', prefixIcon: Padding(padding: const EdgeInsets.all(12), child: PIcon('search', size: 20, color: c.muted))),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 4, 12, 4), children: [
            for (final (k, l) in marketCats)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  key: ValueKey('mkc-$k'),
                  label: Text(l),
                  selected: cat == k,
                  showCheckmark: false,
                  selectedColor: c.accentSoft,
                  side: BorderSide(color: cat == k ? c.accent : c.line),
                  onSelected: (_) {
                    setState(() => cat = k);
                    _load();
                  },
                ),
              ),
          ]),
        ),
        Expanded(
          child: error != null && r == null
              ? Empty(icon: 'store', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
              : r == null
                  ? const Center(child: CircularProgressIndicator())
                  : r.isEmpty
                      ? Empty(icon: 'store', title: 'ვერაფერი მოიძებნა', text: 'დაამატე პირველი განცხადება.', action: 'გაყიდვა', onAction: _new)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: GridView.count(
                            crossAxisCount: 2,
                            padding: const EdgeInsets.all(12),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: .74,
                            children: [for (final i in r) _ItemCard(i: i, onChanged: _load)],
                          ),
                        ),
        ),
      ]),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.i, required this.onChanged});
  final Map<String, dynamic> i;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, media = Media.listOf(i['media']), id = asInt(i['id']);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('mki-$id'),
        onTap: () async {
          final changed = await openPage<bool>(context, ListingScreen(id: id), full: true);
          if (changed == true) onChanged();
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: media.isEmpty
                ? Container(width: double.infinity, color: HSLColor.fromAHSL(1, (id * 47 % 360).toDouble(), .35, .6).toColor(), child: const Center(child: PIcon('store', size: 34, color: Colors.white)))
                : SizedBox(width: double.infinity, child: PImage(media.first.small)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Text('${_price(i['price'])}${i['status'] == 'sold' ? ' · გაყიდულია' : ''}', style: TextStyle(fontWeight: FontWeight.w900, color: i['status'] == 'sold' ? c.muted : c.accent)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('${i['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('${i['city'] ?? ''} · ${ago(asTime(i['created_at']))}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12)),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

/// One item for sale. Pops true when it changed (sold, taken away).
class ListingScreen extends StatefulWidget {
  const ListingScreen({super.key, required this.id});
  final int id;
  @override
  State<ListingScreen> createState() => _ListingScreenState();
}

class _ListingScreenState extends State<ListingScreen> {
  (Map<String, dynamic>, bool)? d;
  Object? error;
  bool gone = false, changed = false, _started = false;

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
      final r = await app.api.listing(widget.id);
      if (!mounted) return;
      if (r == null) {
        setState(() => gone = true);
        return;
      }
      await app.people.ensure(['${r.$1['seller']}']);
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

  void _back() => Navigator.of(context).pop(changed);

  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, x = d;
    if (gone) return Scaffold(appBar: peeraBar(context, title: 'განცხადება'), body: const Empty(icon: 'store', title: 'განცხადება აღარ არის'));
    if (x == null) {
      return Scaffold(
        appBar: peeraBar(context, title: 'განცხადება'),
        body: error != null ? Empty(icon: 'store', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load) : const Center(child: CircularProgressIndicator()),
      );
    }
    final i = x.$1, saved = x.$2, seller = '${i['seller']}', mine = seller == context.me.id, media = Media.listOf(i['media']);
    final catName = marketCats.where((k) => k.$1 == i['category']).firstOrNull?.$2 ?? 'სხვა', sold = i['status'] == 'sold';
    final who = app.people[seller] ?? Profile(id: seller, name: '…');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) {
        if (!did) _back();
      },
      child: Scaffold(
        appBar: peeraBar(context, title: _price(i['price'])),
        body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          if (media.isNotEmpty)
            SizedBox(
              height: 300,
              child: PageView(children: [
                for (var k = 0; k < media.length; k++)
                  GestureDetector(onTap: () => openPhotos(context, media, start: k), child: PImage(media[k].mid)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i['title'] ?? ''}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${_price(i['price'])}${sold ? ' · გაყიდულია' : ''}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: sold ? c.muted : c.accent)),
              const SizedBox(height: 4),
              Text('${i['city'] ?? ''} · $catName · ${ago(asTime(i['created_at']))}', style: TextStyle(color: c.muted)),
              if ('${i['description'] ?? ''}'.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: TranslatableBody('${i['description']}'.trim())),
            ]),
          ),
          if (!mine) ...[
            const SizedBox(height: 10),
            ListTile(
              key: const ValueKey('mk-seller'),
              leading: Avatar(p: who, size: 42),
              title: NameLine(who, size: 15),
              subtitle: const Text('გამყიდველი'),
              onTap: () => openPage(context, PersonScreen(uid: seller, initial: who), full: true),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.gold.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
                child: const Text('უსაფრთხოება: შეხვდი საჯარო ადგილას, ნივთი ნახე და მერე გადაიხადე. წინასწარ ფულს ნუ გადარიცხავ.', style: TextStyle(height: 1.4)),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              if (mine) ...[
                OutlinedButton(
                  key: const ValueKey('mk-sold'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () async {
                    if (await attempt(context, () => app.api.setListingStatus(widget.id, sold ? 'active' : 'sold')) && mounted) {
                      changed = true;
                      _load();
                    }
                  },
                  child: Text(sold ? 'ისევ იყიდება' : 'გაყიდულია'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('mk-del'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: c.nope),
                  onPressed: () async {
                    if (!await confirm(context, title: 'განცხადების წაშლა', text: 'განცხადება წაიშლება.', yes: 'წაშლა', danger: true) || !mounted) return;
                    if (await attempt(context, () => app.api.deleteListing(widget.id)) && mounted) Navigator.of(context).pop(true);
                  },
                  icon: PIcon('trash', size: 17, color: c.nope),
                  label: const Text('წაშლა'),
                ),
              ] else ...[
                FilledButton.icon(
                  key: const ValueKey('mk-chat'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => chatWith(context, seller, draft: 'გამარჯობა! „${i['title']}“ ისევ იყიდება?'),
                  icon: PIcon('msg', size: 17, color: c.onAccent),
                  label: const Text('მიწერა'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('mk-save'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () async {
                    if (await attempt(context, () => app.api.saveListing(widget.id, !saved)) && mounted) _load();
                  },
                  icon: PIcon(saved ? 'heartfill' : 'heart', size: 17, color: saved ? c.nope : c.ink),
                  label: Text(saved ? 'შენახულია' : 'შენახვა'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('mk-report'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => reportSheet(context, 'listing', '${widget.id}'),
                  icon: PIcon('flag', size: 17, color: c.ink),
                  label: const Text('საჩივარი'),
                ),
                if (isStaff(context))
                  OutlinedButton(
                    key: const ValueKey('mk-hide'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () async {
                      if (await attempt(context, () => app.api.modHide('listing', widget.id, true)) && mounted) {
                        toast(context, 'დაიმალა ყველასთვის');
                        Navigator.of(context).pop(true);
                      }
                    },
                    child: const Text('დამალვა'),
                  ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A new item for sale: up to six photos (cut square, 4:5 or as they are), what it is, the price, a category, the
/// city, the words about it.
class ListingFormScreen extends StatefulWidget {
  const ListingFormScreen({super.key});
  @override
  State<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends State<ListingFormScreen> {
  final title = TextEditingController(), price = TextEditingController(), desc = TextEditingController();
  late final city = TextEditingController(text: context.me.city ?? '');
  final photos = <Uint8List>[];
  String cat = 'tech';
  bool busy = false;
  String? stage;

  @override
  void dispose() {
    title.dispose();
    price.dispose();
    desc.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (photos.length >= 6) return;
    final got = await photoSource(false);
    if (got.isEmpty || !mounted) return;
    final first = await photoEdit(context, got.first) ?? got.first;
    if (!mounted) return;
    setState(() => photos.addAll([first, ...got.skip(1)].take(6 - photos.length)));
  }

  Future<void> _save() async {
    final t = title.text.trim(), p = double.tryParse(price.text.replaceAll(',', '.').trim()), y = city.text.trim();
    if (t.isEmpty || p == null || y.isEmpty) {
      toast(context, 'ჩაწერე რას ყიდი, ფასი და ქალაქი');
      return;
    }
    final api = context.app.api;
    setState(() => busy = true);
    try {
      final media = <Media>[];
      for (var i = 0; i < photos.length; i++) {
        setState(() => stage = 'იტვირთება ${i + 1}/${photos.length}…');
        media.add(await api.uploadPhoto(await photoPrep(photos[i])));
      }
      await api.createListing(title: t, price: p, category: cat, city: y, description: desc.text.trim(), media: media);
      if (!mounted) return;
      toast(context, 'განცხადება გამოქვეყნდა');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        stage = null;
      });
      toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      appBar: peeraBar(context, title: 'ახალი განცხადება', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(key: const ValueKey('lf-ok'), style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: busy ? null : _save, child: const Text('გამოქვეყნება')),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (stage != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(stage!, style: TextStyle(color: c.muted))),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < photos.length; i++)
            SizedBox.square(
              dimension: 90,
              child: Stack(fit: StackFit.expand, children: [
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(photos[i], fit: BoxFit.cover, cacheWidth: 300)),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    key: ValueKey('lf-rm-$i'),
                    onTap: busy ? null : () => setState(() => photos.removeAt(i)),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const PIcon('x', size: 14, color: Colors.white, stroke: 2.4),
                    ),
                  ),
                ),
              ]),
            ),
          if (photos.length < 6)
            OutlinedButton.icon(
              key: const ValueKey('lf-photo'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: busy ? null : _add,
              icon: PIcon('image', size: 17, color: c.ink),
              label: const Text('ფოტოს დამატება (მაქს. 6)'),
            ),
        ]),
        const SizedBox(height: 12),
        TextField(key: const ValueKey('lf-title'), controller: title, maxLength: 100, decoration: const InputDecoration(labelText: 'რას ყიდი', hintText: 'მაგალითად: ნარდის დაფა', counterText: '')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              key: const ValueKey('lf-price'),
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'ფასი, ₾'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              key: const ValueKey('lf-cat'),
              isExpanded: true,
              initialValue: cat,
              decoration: const InputDecoration(labelText: 'კატეგორია'),
              items: [for (final (k, l) in marketCats.skip(1)) DropdownMenuItem(value: k, child: Text(l))],
              onChanged: (v) => setState(() => cat = v ?? 'other'),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('lf-city'), controller: city, maxLength: 60, decoration: const InputDecoration(labelText: 'ქალაქი', counterText: '')),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('lf-desc'),
          controller: desc,
          maxLength: 1500,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'აღწერა', hintText: 'მდგომარეობა, ზომა, სად ხდება გადაცემა', counterText: ''),
        ),
      ]),
    );
  }
}
