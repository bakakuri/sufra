// The live map (js/livemap.js): where friends are right now, on satellite photos or the street map, and sharing my own
// place live — for a while (15 minutes, an hour, 8 hours or until stopped), with friends or everyone, exactly or
// roughly (about a kilometre, rounded on the server). In the app the place goes on being shared with the app closed:
// the phone's own service sends it, with a notification and a stop button. Who sees what is decided on the server.
import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../chat/chat_screen.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../people/person_screen.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'loc_device.dart';

/// a map tile from the network (kept on the phone after the first time); the tests draw a picture instead
ImageProvider Function(String url) mapTile = (u) => CachedNetworkImageProvider(u, headers: const {'User-Agent': 'Peera/0.4 (my.peera.app; www.peera.my)'});

class _Tiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => mapTile(getTileUrl(coordinates, options));
}

const _sat = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
const _labels = 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}';
const _osm = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _georgia = LatLng(42.2, 43.5);
const _liveCol = Color(0xFF2FBF80), _zoneCol = Color(0xFF3E8EF7);

double geoKm(double lat1, double lng1, double lat2, double lng2) {
  const r = math.pi / 180;
  final x = math.pow(math.sin((lat2 - lat1) * r / 2), 2) + math.cos(lat1 * r) * math.cos(lat2 * r) * math.pow(math.sin((lng2 - lng1) * r / 2), 2);
  return 12742 * math.asin(math.min(1, math.sqrt(x)));
}

String fmtKm(double km) => km < 1 ? '${(km * 1000 / 10).round() * 10} მ' : (km < 10 ? '${km.toStringAsFixed(1)} კმ' : '${km.round()} კმ');
String _ago(DateTime t) {
  final a = ago(t);
  return a == 'ახლა' ? 'ახლა' : '$a წინ';
}

String _first(Profile? p) => (p?.name ?? '').trim().split(' ').first.isEmpty ? 'მომხმარებელი' : p!.name.trim().split(' ').first;

/// The choices for sharing: who sees it, for how long (minutes, 0 = until stopped), how exactly.
typedef ShareChoice = ({String audience, int minutes, bool approx});

Future<void> openLiveMap(BuildContext context) => openPage(context, const LiveMapScreen(), full: true);

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});
  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> with WidgetsBindingObserver {
  final map = MapController();
  List<LiveSpot> rows = [];
  bool loaded = false, failed = false, ready = false, fitted = false, minor = false, busy = false;
  MyShare? mine;
  Here? here;
  String mode = 'sat';
  String? follow;
  Timer? _t;
  final _later = <Timer>[];
  AppState? _app;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_app != null) return;
    _app = context.app;
    WidgetsBinding.instance.addObserver(this);
    _load();
    _mine();
    _app!.api.amMinor().then((m) {
      if (mounted) setState(() => minor = m);
    }).catchError((_) {});
    _t = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _load();
      _mine();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _t?.cancel();
    for (final t in _later) {
      t.cancel();
    }
    map.dispose();
    super.dispose();
  }

  String get _me => _app!.api.myId;

  Future<void> _load() async {
    final app = _app!;
    try {
      final r = await app.api.liveMap();
      await app.people.ensure(r.map((x) => x.userId));
      if (!mounted) return;
      setState(() {
        rows = r;
        loaded = true;
        failed = false;
      });
      final f = follow;
      if (f != null && ready) {
        final s = rows.where((x) => x.userId == f).firstOrNull;
        if (s != null) {
          map.move(LatLng(s.lat, s.lng), map.camera.zoom);
        } else {
          follow = null;
        }
      }
      _fit();
    } catch (_) {
      if (mounted) {
        setState(() {
          loaded = true;
          failed = rows.isEmpty;
        });
      }
    }
  }

  Future<void> _mine() async {
    try {
      final m = await _app!.api.myShare();
      if (mounted) setState(() => mine = m);
    } catch (_) {}
  }

  /// the first look: whoever is on the map, or me, or the whole country
  void _fit() {
    if (fitted || !loaded || !ready) return;
    fitted = true;
    final pts = [for (final r in rows) LatLng(r.lat, r.lng)];
    if (pts.isEmpty) {
      final h = here;
      map.move(h != null ? LatLng(h.lat, h.lng) : _georgia, h != null ? 13 : 6.6);
    } else if (pts.length == 1) {
      map.move(pts.first, 14);
    } else {
      map.fitCamera(CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.fromLTRB(50, 120, 70, 240), maxZoom: 14));
    }
  }

  Future<void> _goMe() async {
    var h = here;
    if (h == null) {
      final perm = await locDevice.permission();
      if (perm != 'granted') {
        if (mounted) _noLocation(perm);
        return;
      }
      if (mounted) toast(context, 'ვადგენ შენს მდებარეობას…');
      h = await locDevice.here();
      if (h == null) {
        if (mounted) toast(context, 'მდებარეობა ვერ დადგინდა. ჩართე ტელეფონში ლოკაცია (GPS)');
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      here = h;
      follow = null;
    });
    if (ready) map.move(LatLng(h.lat, h.lng), math.max(map.camera.zoom, 15));
  }

  void _noLocation(String perm) {
    if (perm == 'blocked') {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('ლოკაციაზე წვდომა გამორთულია. ჩართე ტელეფონის პარამეტრებში'),
          action: SnackBarAction(label: 'პარამეტრები', onPressed: locDevice.settings),
        ));
    } else {
      toast(context, 'ლოკაციაზე წვდომა არ მოგვეცა');
    }
  }

  // ---------- my share ----------

  Future<void> _share() async {
    final c = await showModalBottomSheet<ShareChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(child: _ShareSheet(mine: mine, minor: minor, onStop: _stop)),
    );
    if (c == null || !mounted) return;
    setState(() => busy = true);
    try {
      final perm = await locDevice.permission();
      if (perm != 'granted') {
        if (mounted) _noLocation(perm);
        return;
      }
      final token = await _app!.api.locToken();
      final ok = await locDevice.start(token: token, audience: c.audience, minutes: c.minutes, approx: c.approx);
      if (!mounted) return;
      if (!ok) {
        toast(context, 'გაზიარება ვერ ჩაირთო. სცადე ხელახლა');
        return;
      }
      setState(() => mine = MyShare(
            audience: c.audience,
            approx: c.approx,
            device: true,
            expiresAt: c.minutes > 0 ? DateTime.now().add(Duration(minutes: c.minutes)) : null,
          ));
      toast(context, c.audience == 'public' ? 'შენი ლოკაცია ყველას უჩანს' : 'შენი ლოკაცია მეგობრებს უჩანს');
      // the phone's service starts the share with its first place; the map shows it as soon as the server has it
      for (final s in const [4, 10, 20, 40]) {
        _later.add(Timer(Duration(seconds: s), () {
          if (!mounted) return;
          _load();
          _mine();
        }));
      }
      final h = await locDevice.here();
      if (h != null && mounted) {
        setState(() => here = h);
        if (ready) map.move(LatLng(h.lat, h.lng), math.max(map.camera.zoom, c.approx ? 13.5 : 15));
      }
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _stop() async {
    setState(() => busy = true);
    try {
      await _app!.api.locStop();
      await locDevice.stop();
      if (!mounted) return;
      setState(() => mine = null);
      toast(context, 'ლაივ ლოკაცია გაითიშა');
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ---------- a person on the map ----------

  void _fly(LiveSpot r) {
    if (!ready) {
      _peek(r);
      return;
    }
    final c = map.camera.center;
    if (geoKm(c.latitude, c.longitude, r.lat, r.lng) < .05 && map.camera.zoom >= 14) {
      _peek(r);
      return;
    }
    follow = null;
    map.move(LatLng(r.lat, r.lng), math.max(map.camera.zoom, r.approx ? 13 : 15.5));
  }

  Future<void> _peek(LiveSpot r) async {
    final me = r.userId == _me, app = _app!;
    final p = app.people[r.userId];
    final h = here;
    final km = !me && h != null ? geoKm(h.lat, h.lng, r.lat, r.lng) : null;
    final facts = <(String, String)>[
      (r.live ? 'ახლა აქ არის' : 'ბოლოს განახლდა ${_ago(r.updatedAt)}', 'clock'),
      if (km != null) ('შენგან ${fmtKm(km)}', 'pin'),
      if (!r.approx && r.live && (r.speed ?? 0) > 1.2) ('მოძრაობს, ~${((r.speed ?? 0) * 3.6).round()} კმ/სთ', 'pin'),
      if (r.approx) ('მიახლოებითი ადგილი, ~1 კმ', 'globe'),
      (r.audience == 'public' ? 'ყველას უზიარებს' : 'მეგობრებს უზიარებს', 'users'),
      if (r.expiresAt != null) ('დასრულდება ${MyShare(expiresAt: r.expiresAt).left}-ში', 'clock'),
    ];
    final act = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final c = ctx.pc;
        Widget btn(String key, String icon, String label, {bool filled = false}) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: filled
                    ? FilledButton(
                        key: ValueKey('peek-$key'),
                        onPressed: () => Navigator.pop(ctx, key),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46), padding: EdgeInsets.zero),
                        child: FittedBox(child: Text(label)),
                      )
                    : OutlinedButton(
                        key: ValueKey('peek-$key'),
                        onPressed: () => Navigator.pop(ctx, key),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), padding: EdgeInsets.zero),
                        child: FittedBox(child: Text(label)),
                      ),
              ),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Avatar(p: p ?? Profile(id: r.userId, name: '…'), size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(me ? 'შენ' : (p?.fullName ?? '…'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    if (!me && p?.username != null) Text('@${p!.username}', style: TextStyle(color: c.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              for (final f in facts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    PIcon(f.$2, size: 18, color: c.muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(f.$1, style: const TextStyle(fontSize: 15))),
                  ]),
                ),
              const SizedBox(height: 14),
              Row(
                children: me
                    ? [btn('change', 'edit', 'შეცვლა'), btn('stop', 'x', 'გაჩერება', filled: true)]
                    : [btn('profile', 'user', 'პროფილი'), btn('chat', 'msg', 'მიწერა'), btn('follow', 'pin', 'მიყოლა'), btn('route', 'pin', 'მარშრუტი', filled: true)],
              ),
            ]),
          ),
        );
      },
    );
    if (!mounted || act == null) return;
    switch (act) {
      case 'change':
        _share();
      case 'stop':
        _stop();
      case 'profile':
        openPage(context, PersonScreen(uid: r.userId), full: true);
      case 'chat':
        try {
          final conv = await app.api.startDm(r.userId);
          if (mounted) await openChat(context, conv);
        } catch (e) {
          if (mounted) toast(context, errText(e));
        }
      case 'follow':
        setState(() => follow = r.userId);
        if (ready) map.move(LatLng(r.lat, r.lng), math.max(map.camera.zoom, 16));
        toast(context, 'რუკა მიჰყვება: ${_first(p)}. რუკის გაწევა შეწყვეტს');
      case 'route':
        launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${r.lat},${r.lng}'), mode: LaunchMode.externalApplication);
    }
  }

  // ---------- the screen ----------

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final meRow = rows.where((r) => r.userId == _me).firstOrNull;
    final h = here;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: mode == 'sat' ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: map,
              options: MapOptions(
                initialCenter: _georgia,
                initialZoom: 6.6,
                minZoom: 2,
                maxZoom: 19,
                backgroundColor: mode == 'sat' ? const Color(0xFF0B1424) : const Color(0xFFDFE7EE),
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                onMapReady: () {
                  ready = true;
                  _fit();
                },
                onPositionChanged: (_, gesture) {
                  if (gesture && follow != null) setState(() => follow = null);
                },
              ),
              children: [
                TileLayer(key: ValueKey('base-$mode'), urlTemplate: mode == 'sat' ? _sat : _osm, tileProvider: _Tiles(), userAgentPackageName: 'my.peera.app', maxNativeZoom: 19),
                if (mode == 'sat') TileLayer(key: const ValueKey('labels'), urlTemplate: _labels, tileProvider: _Tiles(), userAgentPackageName: 'my.peera.app', maxNativeZoom: 19),
                CircleLayer(circles: [
                  for (final r in rows)
                    if (r.approx)
                      CircleMarker(
                        point: LatLng(r.lat, r.lng),
                        radius: 800,
                        useRadiusInMeter: true,
                        color: _zoneCol.withValues(alpha: .18),
                        borderColor: const Color(0xFF8CC0FF),
                        borderStrokeWidth: 1.5,
                      ),
                ]),
                if (h != null && (meRow == null || meRow.approx))
                  MarkerLayer(markers: [
                    Marker(point: LatLng(h.lat, h.lng), width: 22, height: 22, child: const _SelfDot()),
                  ]),
                MarkerLayer(markers: [
                  for (final r in rows)
                    Marker(
                      key: ValueKey('pin-${r.userId}'),
                      point: LatLng(r.lat, r.lng),
                      width: 76,
                      height: 74,
                      alignment: Alignment.topCenter,
                      child: _Pin(r: r, p: _app!.people[r.userId], me: r.userId == _me, followed: follow == r.userId, onTap: () => _peek(r)),
                    ),
                ]),
              ],
            ),
          ),
          // the bar: back, the title, the kind of map
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Row(children: [
                  _Round(child: IconBtn('back', label: 'უკან', onTap: () => Navigator.of(context).maybePop())),
                  const SizedBox(width: 8),
                  _Round(
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text('ლაივ რუკა', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const Spacer(),
                  _Round(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        for (final (k, l) in const [('sat', 'სატელიტი'), ('map', 'რუკა')])
                          GestureDetector(
                            key: ValueKey('map-mode-$k'),
                            onTap: () => setState(() => mode = k),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(color: mode == k ? c.ink : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                              child: Text(l, style: TextStyle(color: mode == k ? c.bg : c.ink, fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          // my place, the whole country
          Positioned(
            right: 12,
            top: MediaQuery.paddingOf(context).top + 70,
            child: Column(children: [
              _Round(child: IconBtn('locate', label: 'ჩემი ადგილი', onTap: _goMe)),
              const SizedBox(height: 8),
              _Round(
                child: IconBtn('globe', label: 'მთელი საქართველო', onTap: () {
                  follow = null;
                  if (ready) map.move(_georgia, 6.6);
                }),
              ),
            ]),
          ),
          // who is on the map, and my own share
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Text(mode == 'sat' ? '© Esri, Maxar · OpenStreetMap' : '© OpenStreetMap',
                        style: TextStyle(color: mode == 'sat' ? Colors.white70 : Colors.black54, fontSize: 10.5)),
                  ),
                  _people(c),
                  const SizedBox(height: 8),
                  _shareBar(c),
                ]),
              ),
            ),
          ),
          if (busy) const Positioned.fill(child: ColoredBox(color: Color(0x33000000), child: Center(child: CircularProgressIndicator()))),
        ]),
      ),
    );
  }

  Widget _people(PeeraColors c) {
    final others = [for (final r in rows) if (r.userId != _me) r];
    final h = here;
    final meRow = rows.where((r) => r.userId == _me).firstOrNull;
    final from = h != null ? (h.lat, h.lng) : (meRow != null ? (meRow.lat, meRow.lng) : null);
    if (!loaded) return const SizedBox.shrink();
    if (others.isEmpty) {
      return _Round(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(children: [
            PIcon(failed ? 'globe' : 'users', size: 22, color: c.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(failed ? 'ვერ ჩაიტვირთა' : 'ჯერ არავინ ჩანს', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  failed
                      ? 'შეამოწმე ინტერნეტი, რუკა თავად განახლდება.'
                      : (mine != null ? 'მეგობრები აქ გამოჩნდებიან, როცა ლოკაციას გააზიარებენ.' : 'გააზიარე შენი ლოკაცია და მეგობრებსაც უთხარი.'),
                  style: TextStyle(color: c.muted, fontSize: 13),
                ),
              ]),
            ),
          ]),
        ),
      );
    }
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: others.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final r = others[i], p = _app!.people[r.userId];
          final km = from == null ? null : geoKm(from.$1, from.$2, r.lat, r.lng);
          return _Round(
            child: InkWell(
              key: ValueKey('map-p-${r.userId}'),
              borderRadius: BorderRadius.circular(27),
              onTap: () => _fly(r),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: r.live ? _liveCol : c.line),
                    child: Avatar(p: p ?? Profile(id: r.userId, name: '…'), size: 34),
                  ),
                  const SizedBox(width: 8),
                  Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_first(p), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text('${_ago(r.updatedAt)}${km != null ? ' · ${fmtKm(km)}' : ''}', style: TextStyle(color: c.muted, fontSize: 12)),
                  ]),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _shareBar(PeeraColors c) {
    final m = mine;
    if (m == null) {
      return Material(
        color: c.accent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const ValueKey('map-share'),
          borderRadius: BorderRadius.circular(18),
          onTap: busy ? null : _share,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              PIcon('locate', size: 24, color: c.onAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ლაივ ლოკაციის გაზიარება', style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w800, fontSize: 15.5)),
                  Text('მეგობრები დაინახავენ, სად ხარ ახლა. აპი დახურულიც ზიარდება', style: TextStyle(color: c.onAccent.withValues(alpha: .85), fontSize: 12.5)),
                ]),
              ),
            ]),
          ),
        ),
      );
    }
    final left = m.left;
    return _Round(
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(children: [
          const _Pulse(),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              key: const ValueKey('map-change'),
              onTap: busy ? null : _share,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('შენი ლოკაცია ჩანს', key: ValueKey('map-on'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text(
                  '${m.device ? 'ფონზეც · ' : ''}${m.audience == 'public' ? 'ყველას' : 'მეგობრებს'}${m.approx ? ' · მიახლოებით' : ''} · ${left != null ? '$left დარჩა' : 'სანამ გათიშავ'}',
                  style: TextStyle(color: c.muted, fontSize: 12.5),
                ),
              ]),
            ),
          ),
          TextButton(
            key: const ValueKey('map-stop'),
            onPressed: busy ? null : _stop,
            style: TextButton.styleFrom(foregroundColor: c.nope),
            child: const Text('გაჩერება', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}

/// a white (dark in dark mode) rounded plate over the map
class _Round extends StatelessWidget {
  const _Round({required this.child, this.radius = 24});
  final Widget child;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Material(
      color: c.surface.withValues(alpha: .96),
      elevation: 3,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// a person on the map: the picture in a ring (green while live, grey when the place is old) and the first name
class _Pin extends StatelessWidget {
  const _Pin({required this.r, required this.p, required this.me, required this.followed, required this.onTap});
  final LiveSpot r;
  final Profile? p;
  final bool me, followed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final ring = me ? c.accent : (r.live ? _liveCol : const Color(0xFF9AA3B5));
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: r.live ? 1 : .75,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ring,
              boxShadow: [BoxShadow(color: followed ? ring : Colors.black38, blurRadius: followed ? 14 : 6)],
            ),
            child: Avatar(p: p ?? Profile(id: r.userId, name: '…'), size: 40),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)]),
            child: Text(me ? 'შენ' : _first(p), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: c.ink)),
          ),
        ]),
      ),
    );
  }
}

/// the blue dot where the phone is
class _SelfDot extends StatelessWidget {
  const _SelfDot();
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF3E8EF7),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x663E8EF7), blurRadius: 10, spreadRadius: 4)],
        ),
      );
}

/// the green dot that says the place is being shared
class _Pulse extends StatelessWidget {
  const _Pulse();
  @override
  Widget build(BuildContext context) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _liveCol,
          boxShadow: [BoxShadow(color: _liveCol.withValues(alpha: .5), blurRadius: 8, spreadRadius: 3)],
        ),
      );
}

/// How to share: who sees it, for how long, how exactly (rough by default when everyone sees it, as on the site).
class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.mine, required this.minor, required this.onStop});
  final MyShare? mine;
  final bool minor;
  final Future<void> Function() onStop;
  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  late String audience = widget.minor ? 'friends' : (widget.mine?.audience ?? 'friends');
  late int minutes = 60;
  late bool approx = widget.mine?.approx ?? false;
  bool touched = false;

  Widget _seg<T>(String group, List<(T, String, bool)> opts, T value, ValueChanged<T> on) {
    final c = context.pc;
    return Row(children: [
      for (var i = 0; i < opts.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: Material(
            color: value == opts[i].$1 ? c.ink : c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: value == opts[i].$1 ? c.ink : c.line)),
            child: InkWell(
              key: ValueKey('ls-$group-${opts[i].$1}'),
              borderRadius: BorderRadius.circular(12),
              onTap: opts[i].$3 ? null : () => setState(() => on(opts[i].$1)),
              child: SizedBox(
                height: 42,
                child: Center(
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(opts[i].$2,
                          style: TextStyle(color: opts[i].$3 ? c.muted : (value == opts[i].$1 ? c.bg : c.ink), fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.pc, on = widget.mine != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        const Text('ლაივ ლოკაცია', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('შენი ადგილი რუკაზე შენთან ერთად იმოძრავებს, აპი დახურულიც. სანამ ჩართულია, ტელეფონის ზედა ზოლში შეტყობინება ჩანს, ღილაკით „გაჩერება“.',
            style: TextStyle(color: c.muted, fontSize: 14, height: 1.4)),
        _label('ვინ დაინახოს'),
        _seg<String>('aud', [('friends', 'მეგობრებმა', false), ('public', 'ყველამ', widget.minor)], audience, (v) {
          audience = v;
          if (!touched) approx = v == 'public';
        }),
        if (widget.minor) ...[
          const SizedBox(height: 6),
          Text('18 წლამდე ლოკაციას მხოლოდ მეგობრებს უზიარებ.', style: TextStyle(color: c.muted, fontSize: 13)),
        ],
        _label('რამდენ ხანს'),
        _seg<int>('min', const [(15, '15 წთ', false), (60, '1 სთ', false), (480, '8 სთ', false), (0, 'სანამ გავთიშავ', false)], minutes, (v) => minutes = v),
        _label('სიზუსტე'),
        _seg<bool>('approx', const [(false, 'ზუსტი', false), (true, 'მიახლოებით, ~1 კმ', false)], approx, (v) {
          approx = v;
          touched = true;
        }),
        const SizedBox(height: 12),
        Text('გაზიარებულ ლოკაციას საიტის ადმინისტრაციაც ხედავს. ისტორია არ ინახება: გათიშვისას შენი ადგილი იშლება.',
            style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('ls-cancel'),
              onPressed: () async {
                Navigator.pop(context);
                if (on) await widget.onStop();
              },
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: on ? c.nope : null),
              child: Text(on ? 'გაჩერება' : 'გაუქმება'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              key: const ValueKey('ls-go'),
              onPressed: () => Navigator.pop<ShareChoice>(context, (audience: audience, minutes: minutes, approx: approx)),
              icon: PIcon('locate', size: 20, color: c.onAccent),
              label: Text(on ? 'შენახვა' : 'გაზიარება'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ),
        ]),
      ]),
    );
  }
}
