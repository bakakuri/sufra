// Places (places.js): cafes, libraries, guesthouses and sights on a map or in a list, by kind and by words; one place
// with its photos, reviews and the posts made there, "აქ ვარ" (a post from there), the route, a call; a review with
// stars and photos; a new place marked on the map (with a look for one already there).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../feed/photo_viewer.dart';
import '../feed/place_pick.dart';
import '../feed/post_actions.dart';
import '../feed/post_card.dart';
import '../map/loc_device.dart';
import '../people/profile_parts.dart';
import '../profile/profile.dart';
import '../settings/frame_photo.dart';
import '../settings/places.dart';
import '../ui/bits.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/look.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const tbilisi = LatLng(41.7151, 44.8271);

(String, String) placeKind(Object? k) => placeKinds['$k'] ?? placeKinds['other']!;

/// where the phone is, when it may tell without asking ([ask]: it asks)
Future<LatLng?> phoneHere({bool ask = false}) async {
  final p = await locDevice.permission(ask: ask);
  if (p != 'granted') return null;
  final h = await locDevice.here();
  return h == null ? null : LatLng(h.lat, h.lng);
}

List<String> _photos(Object? v) => [for (final u in (v is List ? v : const [])) if (u is String && u.startsWith('https://')) u];

/// the stars and how many, or "not rated yet"
class RatingLine extends StatelessWidget {
  const RatingLine({super.key, required this.p});
  final Map<String, dynamic> p;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, n = asInt(p['reviews']), r = asNum(p['rating']) ?? 0;
    if (n == 0) return Text('ჯერ არ შეუფასებიათ', style: TextStyle(color: c.muted, fontSize: 12.5));
    return Text.rich(TextSpan(children: [
      TextSpan(text: starsText(r), style: TextStyle(color: c.gold, fontSize: 14)),
      TextSpan(text: '  ${r.toStringAsFixed(1)} · $n', style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
    ]));
  }
}

/// One place in a list.
class SpotCard extends StatelessWidget {
  const SpotCard({super.key, required this.p, this.onBack});
  final Map<String, dynamic> p;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, k = placeKind(p['kind']), photo = p['photo'] as String?, km = asNum(p['km']);
    return InkWell(
      key: ValueKey('spot-${p['id']}'),
      onTap: () async {
        await openPage(context, PlaceScreen(id: asInt(p['id'])), full: true);
        onBack?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 58,
              height: 58,
              child: photo != null && !ecoMode.value
                  ? PImage(photo)
                  : Container(color: c.sunk, child: Center(child: Text(k.$2, style: const TextStyle(fontSize: 26)))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(
                [k.$1, '${p['city'] ?? ''}', kmText(km)].where((x) => x.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.muted, fontSize: 13),
              ),
              RatingLine(p: p),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The places: a map (what is in view) or a list (what is near), by kind and by words.
class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});
  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  final q = TextEditingController();
  var map = MapController();
  String kind = '', viewKind = 'map';
  LatLng center = tbilisi;
  double zoom = 13;
  LatLng? me;
  bool ready = false;
  List<Map<String, dynamic>>? rows;
  Map<String, dynamic>? peek;
  Object? error;
  Timer? _wait;
  int _gen = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    phoneHere().then((g) {
      if (!mounted) return;
      if (g != null) {
        me = g;
        center = g;
        if (ready) map.move(g, zoom);
      }
      _load();
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final g = ++_gen, onMap = viewKind == 'map' && ready, words = q.text.trim();
    var at = center;
    var km = words.isNotEmpty ? 250.0 : 30.0;
    if (onMap) {
      final cam = map.camera, b = cam.visibleBounds;
      at = cam.center;
      km = (const Distance().as(LengthUnit.Meter, cam.center, b.northEast) / 1000).clamp(.5, 400).toDouble();
    }
    try {
      final r = await context.app.api.placesNear(lat: at.latitude, lng: at.longitude, km: km, kind: kind, q: words, limit: onMap ? 150 : 60);
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

  void _soon([int ms = 450]) {
    _wait?.cancel();
    _wait = Timer(Duration(milliseconds: ms), _load);
  }

  Future<void> _near() async {
    toast(context, 'ვადგენ შენს მდებარეობას…');
    final g = await phoneHere(ask: true);
    if (!mounted) return;
    if (g == null) {
      toast(context, 'მდებარეობა ვერ დადგინდა. ჩართე ლოკაციაზე წვდომა');
      return;
    }
    setState(() {
      me = g;
      center = g;
    });
    if (ready && viewKind == 'map') {
      map.move(g, 14);
    }
    _load();
  }

  Future<void> _new() async {
    final id = await openPage<int>(context, const PlaceFormScreen(), full: true);
    if (id != null && mounted) {
      await openPage(context, PlaceScreen(id: id), full: true);
    }
    _load();
  }

  Widget _pin(Map<String, dynamic> p) {
    final c = context.pc, on = peek?['id'] == p['id'], n = asInt(p['reviews']);
    return GestureDetector(
      key: ValueKey('mpin-${p['id']}'),
      onTap: () => setState(() => peek = p),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: on ? c.accent : c.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? c.accent : c.line),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(placeKind(p['kind']).$2, style: const TextStyle(fontSize: 15)),
            if (n > 0) ...[
              const SizedBox(width: 3),
              Text((asNum(p['rating']) ?? 0).toStringAsFixed(1), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: on ? c.onAccent : c.ink)),
            ],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, r = rows, words = q.text.trim();
    final list = r == null
        ? const Center(child: CircularProgressIndicator())
        : error != null && r.isEmpty
            ? Empty(icon: 'map', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
            : r.isEmpty
                ? Empty(
                    icon: 'map',
                    title: words.isNotEmpty ? 'ვერაფერი ვიპოვე' : 'აქ ადგილები ჯერ არ დაუმატებიათ',
                    text: words.isNotEmpty ? 'სცადე სხვა სიტყვა ან გადაიტანე რუკა.' : 'დაამატე შენი საყვარელი კაფე, ბიბლიოთეკა ან სასწავლო სივრცე.',
                    action: 'ადგილის დამატება',
                    onAction: _new,
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                        child: Text('${viewKind == 'map' ? 'ამ ხედზე' : 'ახლოს'} · ${r.length}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      for (final p in r.take(viewKind == 'map' ? 30 : 60)) SpotCard(p: p, onBack: _load),
                    ]),
                  );
    return Scaffold(
      appBar: peeraBar(context, title: 'ადგილები', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: FilledButton.icon(
            key: const ValueKey('pl-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            onPressed: _new,
            icon: PIcon('plus', size: 17, color: c.onAccent),
            label: const Text('დამატება'),
          ),
        ),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('pl-q'),
                controller: q,
                textInputAction: TextInputAction.search,
                onChanged: (_) => _soon(),
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(hintText: 'კაფე, ბიბლიოთეკა, სასტუმრო, ქალაქი', prefixIcon: Padding(padding: const EdgeInsets.all(12), child: PIcon('search', size: 20, color: c.muted))),
              ),
            ),
            const SizedBox(width: 6),
            IconBtn('locate', key: const ValueKey('pl-near'), label: 'ჩემთან ახლოს', onTap: _near),
          ]),
        ),
        ChipsBar(
          prefix: 'plk',
          items: [('', 'ყველა'), for (final e in placeKinds.entries) (e.key, '${e.value.$2} ${e.value.$1}')],
          value: kind,
          onPick: (k) {
            setState(() => kind = k);
            _load();
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: SegmentedButton<String>(
            key: const ValueKey('pl-view'),
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: 'map', label: Text('რუკა')), ButtonSegment(value: 'list', label: Text('სია'))],
            selected: {viewKind},
            onSelectionChanged: (v) {
              setState(() {
                viewKind = v.first;
                peek = null;
                // the map is made anew when it comes back
                ready = false;
                if (viewKind == 'map') map = MapController();
              });
              _load();
            },
          ),
        ),
        if (viewKind == 'map') ...[
          Expanded(
            flex: 5,
            child: Stack(children: [
              Positioned.fill(
                child: FlutterMap(
                  key: const ValueKey('pl-map'),
                  mapController: map,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: zoom,
                    minZoom: 5,
                    maxZoom: 19,
                    backgroundColor: c.sunk,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                    onMapReady: () {
                      ready = true;
                      _load();
                    },
                    onTap: (_, __) => setState(() => peek = null),
                    onPositionChanged: (cam, gesture) {
                      center = cam.center;
                      zoom = cam.zoom;
                      if (gesture) _soon(250);
                    },
                  ),
                  children: [
                    osmLayer(),
                    if (me != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: me!,
                          width: 18,
                          height: 18,
                          child: Container(decoration: BoxDecoration(color: const Color(0xFF3E8EF7), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3))),
                        ),
                      ]),
                    MarkerLayer(markers: [for (final p in r ?? const <Map<String, dynamic>>[]) Marker(point: LatLng(asNum(p['lat'])!.toDouble(), asNum(p['lng'])!.toDouble()), width: 64, height: 30, child: _pin(p))]),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        color: const Color(0xB3FFFFFF),
                        child: const Text('© OpenStreetMap', style: TextStyle(fontSize: 9.5, color: Color(0xFF333333))),
                      ),
                    ),
                  ],
                ),
              ),
              if (peek != null)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Material(
                    key: const ValueKey('pl-peek'),
                    color: c.surface,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Row(children: [
                      Expanded(child: SpotCard(p: peek!, onBack: _load)),
                      IconBtn('x', key: const ValueKey('pl-peek-x'), label: 'დახურვა', size: 20, onTap: () => setState(() => peek = null)),
                    ]),
                  ),
                ),
            ]),
          ),
          Expanded(flex: 4, child: list),
        ] else
          Expanded(child: list),
      ]),
    );
  }
}

/// One place: where it is, its stars, about it, what to do (here, a review, the route, a call, the site, share), the
/// friends who were there, the photos, the reviews and the posts from there.
class PlaceScreen extends StatefulWidget {
  const PlaceScreen({super.key, required this.id});
  final int id;
  @override
  State<PlaceScreen> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends State<PlaceScreen> {
  Map<String, dynamic>? p;
  List<Map<String, dynamic>> reviews = const [];
  List<Post> posts = const [];
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
      final x = await app.api.place(widget.id);
      final rv = x == null ? const <Map<String, dynamic>>[] : await app.api.placeReviews(widget.id);
      final ps = x == null ? const <Post>[] : await app.api.placePosts(widget.id).catchError((_) => <Post>[]);
      await app.people.ensure([for (final r in rv) '${r['author']}', if (x?['created_by'] != null) '${x!['created_by']}']);
      await app.posts.load(ps);
      if (!mounted) return;
      setState(() {
        p = x;
        reviews = rv;
        posts = ps;
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

  Future<void> _review() async {
    final x = p!;
    final saved = await reviewSheet(context, asInt(x['id']), '${x['name']}');
    if (saved == true && mounted) {
      toast(context, 'მადლობა, შეფასება შენახულია');
      _load();
    }
  }

  Future<void> _more() async {
    final x = p!, app = context.app, own = x['created_by'] == app.api.myId, staff = isStaff(context);
    final c = context.pc;
    final k = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (own || staff) ListTile(key: const ValueKey('plm-edit'), leading: const PIcon('edit'), title: const Text('რედაქტირება'), onTap: () => Navigator.of(s).pop('edit')),
          if (own || staff)
            ListTile(key: const ValueKey('plm-del'), leading: PIcon('trash', color: c.nope), title: Text('წაშლა', style: TextStyle(color: c.nope)), onTap: () => Navigator.of(s).pop('del')),
          if (!own) ListTile(key: const ValueKey('plm-report'), leading: const PIcon('flag'), title: const Text('საჩივარი (არასწორი ინფორმაცია, სპამი)'), onTap: () => Navigator.of(s).pop('report')),
          if (staff)
            ListTile(
              key: const ValueKey('plm-mod'),
              leading: const PIcon('lock'),
              title: Text(x['hidden'] == true ? 'მოდერაცია: გამოჩენა' : 'მოდერაცია: დამალვა'),
              onTap: () => Navigator.of(s).pop('mod'),
            ),
        ]),
      ),
    );
    if (k == null || !mounted) return;
    switch (k) {
      case 'edit':
        final id = await openPage<int>(context, PlaceFormScreen(edit: x), full: true);
        if (id != null) _load();
      case 'del':
        if (!await confirm(context, title: 'ადგილის წაშლა', text: 'ადგილი და მისი შეფასებები წაიშლება. პოსტები დარჩება.', yes: 'წაშლა', danger: true) || !mounted) return;
        if (await attempt(context, () => app.api.deletePlace(asInt(x['id']))) && mounted) {
          toast(context, 'წაიშალა');
          Navigator.of(context).pop();
        }
      case 'report':
        await reportSheet(context, 'place', '${x['id']}');
      case 'mod':
        if (await attempt(context, () => app.api.modHide('place', asInt(x['id']), x['hidden'] != true)) && mounted) {
          toast(context, 'შენახულია');
          _load();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, x = p, app = context.app;
    if (x == null) {
      return Scaffold(
        appBar: peeraBar(context, title: 'ადგილი'),
        body: !loaded
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Empty(icon: 'map', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: _load)
                : const Empty(icon: 'map', title: 'ადგილი ვერ მოიძებნა', text: 'შეიძლება წაშლილია.'),
      );
    }
    final k = placeKind(x['kind']), at = LatLng(asNum(x['lat'])!.toDouble(), asNum(x['lng'])!.toDouble()), photo = x['photo'] as String?;
    final me = app.api.myId, mine = reviews.where((r) => r['author'] == me).firstOrNull;
    final friendSet = app.friends.friends.toSet();
    final friends = {for (final q in posts) q.author, for (final r in reviews) '${r['author']}'}.where(friendSet.contains).take(12).toList();
    final pics = [
      for (final q in posts)
        for (final m in q.media)
          if (!m.isVideo) m,
      for (final r in reviews)
        for (final u in _photos(r['photos'])) Media(url: u),
    ].take(12).toList();
    final tel = '${x['phone'] ?? ''}'.replaceAll(RegExp(r'[^\d+]'), ''), web = '${x['website'] ?? ''}';
    final tags = [for (final t in (x['tags'] is List ? x['tags'] as List : const [])) '$t'];
    final total = reviews.isEmpty ? 1 : reviews.length;
    final rating = asNum(x['rating']) ?? 0;
    Widget btn(String key, String icon, String label, VoidCallback onTap, {bool filled = false}) => filled
        ? FilledButton.icon(key: ValueKey(key), style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: onTap, icon: PIcon(icon, size: 17, color: c.onAccent), label: Text(label))
        : OutlinedButton.icon(key: ValueKey(key), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: onTap, icon: PIcon(icon, size: 17), label: Text(label));
    return Scaffold(
      appBar: peeraBar(context, title: '${x['name']}', actions: [
        IconBtn('share', key: const ValueKey('pl-share'), label: 'გაზიარება', onTap: () => shareText(context, '${x['name']}\n$siteUrl/#place-${x['id']}')),
        IconBtn('more', key: const ValueKey('pl-more'), label: 'მეტი', onTap: _more),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          SizedBox(
            height: photo != null && !ecoMode.value ? 200 : 170,
            child: photo != null && !ecoMode.value
                ? PImage(photo)
                : IgnorePointer(
                    child: FlutterMap(
                      options: MapOptions(initialCenter: at, initialZoom: 15, backgroundColor: c.sunk, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
                      children: [
                        osmLayer(),
                        MarkerLayer(markers: [
                          Marker(
                            point: at,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                              child: Center(child: Text(k.$2, style: const TextStyle(fontSize: 18))),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${x['name']}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(
                [
                  '${k.$2} ${k.$1}',
                  '${x['city'] ?? ''}',
                  if ('${x['region'] ?? ''}' != '${x['city'] ?? ''}') '${x['region'] ?? ''}',
                ].where((s) => s.trim().isNotEmpty).join(' · '),
                style: TextStyle(color: c.muted),
              ),
              if ('${x['address'] ?? ''}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [PIcon('pin', size: 15, color: c.muted), const SizedBox(width: 4), Expanded(child: Text('${x['address']}', style: TextStyle(color: c.muted)))]),
                ),
              const SizedBox(height: 4),
              RatingLine(p: x),
              if ('${x['about'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('${x['about']}')),
              if (tags.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Wrap(spacing: 6, runSpacing: 6, children: [for (final t in tags) PTag(t)])),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                btn('pl-here', 'pin', 'აქ ვარ', () => openPage(context, ComposeScreen(place: (asInt(x['id']), '${x['name']}')), full: true), filled: true),
                btn('pl-review', 'star', mine != null ? 'შეფასების შეცვლა' : 'შეფასება', _review),
                btn('pl-route', 'route', 'მარშრუტი', () => openExternal(Uri.parse('https://www.openstreetmap.org/directions?to=${at.latitude}%2C${at.longitude}'))),
                if (tel.isNotEmpty) btn('pl-call', 'phone', 'დარეკვა', () => openExternal(Uri.parse('tel:$tel'))),
                if (web.startsWith('http')) btn('pl-web', 'globe', 'საიტი', () => openExternal(Uri.parse(web))),
              ]),
            ]),
          ),
          if (friends.isNotEmpty) ...[
            const SecHead('მეგობრები აქ იყვნენ'),
            SizedBox(
              height: 48,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                for (final u in friends)
                  if (app.people[u] case final pr?)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(onTap: () => openPerson(context, pr), child: Avatar(p: pr, size: 44)),
                    ),
              ]),
            ),
          ],
          if (pics.isNotEmpty && !ecoMode.value) ...[
            const SecHead('ფოტოები'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: [
                  for (var i = 0; i < pics.length; i++)
                    GestureDetector(
                      key: ValueKey('plph-$i'),
                      onTap: () => openPhotos(context, pics, start: i),
                      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: PImage(pics[i].small)),
                    ),
                ],
              ),
            ),
          ],
          SecHead('შეფასებები · ${reviews.length}'),
          if (reviews.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                Column(children: [
                  Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                  Text(starsText(rating), style: TextStyle(color: c.gold)),
                  Text('${reviews.length} შეფასება', style: TextStyle(color: c.muted, fontSize: 12)),
                ]),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(children: [
                    for (final s in [5, 4, 3, 2, 1])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: Row(children: [
                          SizedBox(width: 14, child: Text('$s', style: TextStyle(color: c.muted, fontSize: 12))),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: LinearProgressIndicator(value: reviews.where((r) => asInt(r['rating']) == s).length / total, minHeight: 7, color: c.gold, backgroundColor: c.sunk),
                            ),
                          ),
                          SizedBox(width: 26, child: Text('${reviews.where((r) => asInt(r['rating']) == s).length}', textAlign: TextAlign.end, style: TextStyle(color: c.muted, fontSize: 12))),
                        ]),
                      ),
                  ]),
                ),
              ]),
            ),
          if (reviews.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('იყავი პირველი, ვინც შეაფასებს.', style: TextStyle(color: c.muted))),
          for (final r in reviews) _ReviewRow(r: r, onChanged: _load),
          if (posts.isNotEmpty) ...[
            const SecHead('პოსტები აქედან'),
            for (final q in posts) PostCard(key: ValueKey('plpost-${q.id}'), post: q),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              '${x['created_by'] != null ? 'დაამატა ${app.people['${x['created_by']}']?.name ?? '…'} · ' : ''}${ago(asTime(x['created_at']))}',
              style: TextStyle(color: c.muted, fontSize: 12.5),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.r, required this.onChanged});
  final Map<String, dynamic> r;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, uid = '${r['author']}', who = app.people[uid] ?? Profile(id: uid, name: '…'), ph = _photos(r['photos']);
    return Padding(
      key: ValueKey('rv-${r['id']}'),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(onTap: () => openPerson(context, who), child: Avatar(p: who, size: 36)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(who.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(starsText(asInt(r['rating'])), style: TextStyle(color: c.gold, fontSize: 13)),
            Text('${ago(asTime(r['updated_at'] ?? r['created_at']))}${r['hidden'] == true ? ' · დამალულია' : ''}', style: TextStyle(color: c.muted, fontSize: 12)),
            if ('${r['body'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${r['body']}')),
            if (ph.isNotEmpty && !ecoMode.value)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 4, runSpacing: 4, children: [
                  for (var i = 0; i < ph.length; i++)
                    GestureDetector(
                      onTap: () => openPhotos(context, [for (final u in ph) Media(url: u)], start: i),
                      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 70, height: 70, child: PImage(ph[i]))),
                    ),
                ]),
              ),
          ]),
        ),
        if (uid != app.api.myId) IconBtn('flag', key: ValueKey('rv-report-${r['id']}'), label: 'საჩივარი', size: 18, color: c.muted, onTap: () => reportSheet(context, 'review', '${r['id']}')),
        if (isStaff(context))
          IconBtn(r['hidden'] == true ? 'eye' : 'lock', key: ValueKey('rv-mod-${r['id']}'), label: 'მოდერაცია', size: 18, color: c.muted, onTap: () async {
            if (await attempt(context, () => app.api.modHide('review', asInt(r['id']), r['hidden'] != true))) onChanged();
          }),
      ]),
    );
  }
}

/// The review of a place: stars, words, up to four photos. True when saved.
Future<bool?> reviewSheet(BuildContext context, int placeId, String name) async {
  final app = context.app, me = context.me;
  Map<String, dynamic>? mine;
  try {
    mine = await app.api.myPlaceReview(placeId);
  } catch (_) {}
  if (!context.mounted) return null;
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => AppScope(app: app, me: me, child: _ReviewSheet(placeId: placeId, name: name, mine: mine)),
  );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.placeId, required this.name, this.mine});
  final int placeId;
  final String name;
  final Map<String, dynamic>? mine;
  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late int rating = asInt(widget.mine?['rating']);
  late final body = TextEditingController(text: '${widget.mine?['body'] ?? ''}');
  late final photos = _photos(widget.mine?['photos']);
  bool busy = false;

  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  Future<void> _photo() async {
    if (photos.length >= 4) {
      toast(context, 'მაქსიმუმ 4 ფოტო');
      return;
    }
    final app = context.app;
    final got = await photoSource(false);
    if (got.isEmpty || !mounted) return;
    setState(() => busy = true);
    try {
      toast(context, 'იტვირთება…');
      final m = await app.api.uploadPhoto(await photoPrep(got.first));
      if (mounted) setState(() => photos.add(m.url));
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _save() async {
    if (rating == 0) {
      toast(context, 'აირჩიე ვარსკვლავები');
      return;
    }
    setState(() => busy = true);
    try {
      await context.app.api.reviewPlace(widget.placeId, rating, body.text.trim(), photos);
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('შეფასება · ${widget.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  key: ValueKey('rv-s$i'),
                  tooltip: '$i',
                  onPressed: () => setState(() => rating = i),
                  icon: Text('★', style: TextStyle(fontSize: 34, color: i <= rating ? c.gold : c.line)),
                ),
            ]),
            TextField(
              key: const ValueKey('rv-body'),
              controller: body,
              maxLength: 1000,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'შენი აზრი', hintText: 'რა მოგეწონა, რას ურჩევ სხვებს?', counterText: ''),
            ),
            if (photos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (var i = 0; i < photos.length; i++)
                    Stack(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 72, height: 72, child: PImage(photos[i]))),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          key: ValueKey('rv-rm-$i'),
                          onTap: () => setState(() => photos.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                            child: const PIcon('x', size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ]),
                ]),
              ),
            const SizedBox(height: 10),
            Row(children: [
              IconBtn('image', key: const ValueKey('rv-photo'), label: 'ფოტოს დამატება', onTap: busy ? null : _photo),
              const Spacer(),
              FilledButton(key: const ValueKey('rv-ok'), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: busy ? null : _save, child: const Text('შენახვა')),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// A new place marked on the map, or one changed: the name, kind, region and city, the address, the spot, the phone and
/// the site, a few words, tags, a photo. Pops with its id.
class PlaceFormScreen extends StatefulWidget {
  const PlaceFormScreen({super.key, this.edit});
  final Map<String, dynamic>? edit;
  @override
  State<PlaceFormScreen> createState() => _PlaceFormScreenState();
}

class _PlaceFormScreenState extends State<PlaceFormScreen> {
  late final e = widget.edit ?? const <String, dynamic>{};
  late final name = TextEditingController(text: '${e['name'] ?? ''}');
  late final city = TextEditingController(text: '${e['city'] ?? (widget.edit == null ? context.me.city ?? '' : '')}');
  late final address = TextEditingController(text: '${e['address'] ?? ''}');
  late final phone = TextEditingController(text: '${e['phone'] ?? ''}');
  late final site = TextEditingController(text: '${e['website'] ?? ''}');
  late final about = TextEditingController(text: '${e['about'] ?? ''}');
  late final tags = TextEditingController(text: [for (final t in (e['tags'] is List ? e['tags'] as List : const [])) '$t'].join(', '));
  late String kind = '${e['kind'] ?? 'cafe'}';
  late String region = widget.edit != null ? '${e['region'] ?? ''}' : (context.me.homeRegion ?? '');
  late LatLng? at = widget.edit != null ? LatLng(asNum(e['lat'])!.toDouble(), asNum(e['lng'])!.toDouble()) : null;
  late String? photo = e['photo'] as String?;
  final map = MapController();
  bool ready = false, busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.edit == null) {
      phoneHere().then((g) {
        if (g != null && mounted && at == null && ready) map.move(g, 15);
      });
    }
  }

  @override
  void dispose() {
    for (final x in [name, city, address, phone, site, about, tags]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _me() async {
    final g = await phoneHere(ask: true);
    if (!mounted) return;
    if (g == null) {
      toast(context, 'მდებარეობა ვერ დადგინდა');
      return;
    }
    setState(() => at = g);
    if (ready) map.move(g, 17);
  }

  Future<void> _photo() async {
    final app = context.app;
    final got = await photoSource(false);
    if (got.isEmpty || !mounted) return;
    final f = await photoFrame(context, got.first, aspect: 16 / 9, max: ecoMode.value ? 1080 : 1600, title: 'ადგილის ფოტო');
    if (f == null || !mounted) return;
    toast(context, 'იტვირთება…');
    try {
      final m = await app.api.uploadPhoto(await photoPrep(f.bytes));
      if (mounted) setState(() => photo = m.url);
    } catch (x) {
      if (mounted) toast(context, errText(x));
    }
  }

  Future<void> _save() async {
    final n = name.text.trim();
    if (n.length < 2) {
      toast(context, 'ჩაწერე სახელი');
      return;
    }
    final ll = at;
    if (ll == null) {
      toast(context, 'მონიშნე ადგილი რუკაზე');
      return;
    }
    var w = site.text.trim();
    if (w.isNotEmpty && !RegExp(r'^https?://', caseSensitive: false).hasMatch(w)) w = 'https://$w';
    final row = <String, dynamic>{
      'name': n,
      'kind': kind,
      'region': region,
      'city': city.text.trim(),
      'address': address.text.trim(),
      'lat': ll.latitude,
      'lng': ll.longitude,
      'phone': phone.text.trim(),
      'website': w,
      'about': about.text.trim(),
      'photo': photo,
      'tags': tags.text.split(RegExp('[,،]')).map((s) => s.trim().replaceFirst(RegExp('^#'), '')).where((s) => s.isNotEmpty).take(12).toList(),
    };
    final api = context.app.api;
    setState(() => busy = true);
    try {
      if (widget.edit != null) {
        final id = await api.savePlace(row, id: asInt(e['id']));
        if (!mounted) return;
        toast(context, 'შენახულია');
        Navigator.of(context).pop(id);
        return;
      }
      final near = await api.placesNear(lat: ll.latitude, lng: ll.longitude, km: .3, q: n.length > 20 ? n.substring(0, 20) : n, limit: 3).catchError((_) => <Map<String, dynamic>>[]);
      if (!mounted) return;
      if (near.isNotEmpty && !await _sameAsk(near)) {
        setState(() => busy = false);
        return;
      }
      final id = await api.savePlace(row);
      if (!mounted) return;
      toast(context, 'ადგილი დაემატა');
      Navigator.of(context).pop(id);
    } catch (x) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, '$x'.contains('too_many') ? 'დღეს უკვე ბევრი ადგილი დაამატე, სცადე ხვალ' : errText(x));
    }
  }

  /// one like it is already near: add it anyway?
  Future<bool> _sameAsk(List<Map<String, dynamic>> near) async {
    final app = context.app, me = context.me;
    final r = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => AppScope(
        app: app,
        me: me,
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 4), child: Text('ასეთი ადგილი უკვე არის?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 4), child: Text('ახლოს უკვე არსებობს:')),
            for (final p in near) SpotCard(p: p),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(key: const ValueKey('plf-force'), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.of(s).pop(true), child: const Text('მაინც დამატება')),
              ),
            ),
          ]),
        ),
      ),
    );
    return r == true;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, ll = at;
    Widget field(String key, TextEditingController x, String label, {String? hint, int max = 80, int lines = 1, TextInputType? type}) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: TextField(
            key: ValueKey(key),
            controller: x,
            maxLength: max,
            minLines: lines,
            maxLines: lines == 1 ? 1 : lines + 3,
            keyboardType: type,
            decoration: InputDecoration(labelText: label, hintText: hint, counterText: ''),
          ),
        );
    return Scaffold(
      appBar: peeraBar(context, title: widget.edit != null ? 'ადგილის რედაქტირება' : 'ახალი ადგილი', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(
            key: const ValueKey('plf-ok'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: busy ? null : _save,
            child: Text(widget.edit != null ? 'შენახვა' : 'დამატება'),
          ),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(key: const ValueKey('plf-name'), controller: name, maxLength: 80, decoration: const InputDecoration(labelText: 'სახელი', hintText: 'მაგ. ეროვნული ბიბლიოთეკა, კაფე კამპუსთან', counterText: '')),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final k in placeKinds.entries)
            ChoiceChip(
              key: ValueKey('plf-k-${k.key}'),
              label: Text('${k.value.$2} ${k.value.$1}'),
              selected: kind == k.key,
              showCheckmark: false,
              selectedColor: c.accentSoft,
              side: BorderSide(color: kind == k.key ? c.accent : c.line),
              onSelected: (_) => setState(() => kind = k.key),
            ),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const ValueKey('plf-region'),
          isExpanded: true,
          initialValue: homeRegions.contains(region) ? region : '',
          decoration: const InputDecoration(labelText: 'რეგიონი'),
          items: [const DropdownMenuItem(value: '', child: Text('—')), for (final r in homeRegions) DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => region = v ?? ''),
        ),
        field('plf-city', city, 'ქალაქი ან სოფელი', max: 60),
        field('plf-address', address, 'მისამართი', hint: 'ქუჩა, ნომერი', max: 120),
        const Padding(padding: EdgeInsets.fromLTRB(0, 14, 0, 6), child: Text('მდებარეობა რუკაზე', style: TextStyle(fontWeight: FontWeight.w700))),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 220,
            child: FlutterMap(
              key: const ValueKey('plf-map'),
              mapController: map,
              options: MapOptions(
                initialCenter: ll ?? tbilisi,
                initialZoom: ll != null ? 16 : 13,
                backgroundColor: c.sunk,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                onMapReady: () => ready = true,
                onTap: (_, p) => setState(() => at = p),
              ),
              children: [
                osmLayer(),
                if (ll != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: ll,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: Column(children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
                          child: Center(child: Text(placeKind(kind).$2, style: const TextStyle(fontSize: 14))),
                        ),
                      ]),
                    ),
                  ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          OutlinedButton.icon(
            key: const ValueKey('plf-me'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: _me,
            icon: const PIcon('locate', size: 17),
            label: const Text('ჩემი მდებარეობა'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ll == null ? 'შეეხე რუკას' : '${ll.latitude.toStringAsFixed(5)}, ${ll.longitude.toStringAsFixed(5)}',
              key: const ValueKey('plf-ll'),
              style: TextStyle(color: c.muted, fontSize: 12.5),
            ),
          ),
        ]),
        field('plf-phone', phone, 'ტელეფონი', max: 30, type: TextInputType.phone),
        field('plf-site', site, 'ვებგვერდი', hint: 'https://', max: 200, type: TextInputType.url),
        field('plf-about', about, 'მოკლე აღწერა', hint: 'რით არის გამორჩეული, სამუშაო საათები', max: 600, lines: 3),
        field('plf-tags', tags, 'თეგები (მძიმით)', hint: 'ხინკალი, ცოცხალი მუსიკა, wifi', max: 200),
        const Padding(padding: EdgeInsets.fromLTRB(0, 14, 0, 6), child: Text('ფოტო', style: TextStyle(fontWeight: FontWeight.w700))),
        Row(children: [
          if (photo != null) ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 120, height: 68, child: PImage(photo!))),
          if (photo != null) const SizedBox(width: 10),
          OutlinedButton.icon(
            key: const ValueKey('plf-photo'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: _photo,
            icon: const PIcon('image', size: 17),
            label: Text(photo != null ? 'შეცვლა' : 'დამატება'),
          ),
        ]),
      ]),
    );
  }
}
