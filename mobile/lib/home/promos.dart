// What the admin shows everyone (promo.js): the banner on top of the home page, sponsored posts in the feed and
// sponsored stories in the row, each with the way to hide it; and the links they open.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/stores.dart';
import '../feed/photo_viewer.dart';
import '../feed/post_screen.dart';
import '../data/models.dart';
import '../media/player.dart';
import '../people/person_screen.dart';
import '../profile/profile.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'services.dart';

/// A link from the admin: a page of the site ("#albums", "#post-12") opens here when the app has it, otherwise on
/// the site; a web address opens in the browser.
Future<void> openLink(BuildContext context, String link) async {
  final l = link.trim();
  if (l.startsWith('https://')) {
    try {
      await launchUrl(Uri.parse(l), mode: LaunchMode.externalApplication);
    } catch (_) {}
    return;
  }
  final m = RegExp(r'^#([a-z]+)(?:-(.+))?$').firstMatch(l);
  if (m == null) return;
  final page = m.group(1)!, arg = m.group(2);
  if (page == 'post' && int.tryParse(arg ?? '') != null) {
    final p = await context.app.api.post(int.parse(arg!));
    if (p != null && context.mounted) await openPage(context, PostScreen(post: p), full: true);
    return;
  }
  if ((page == 'user' || page == 'u') && arg != null) {
    await openPage(context, PersonScreen(uid: arg), full: true);
    return;
  }
  if (!context.mounted) return;
  await openService(context, page, arg: arg);
}

// ---------- the banner ----------

int _hash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0xFFFFFFFF;
  }
  return h;
}

String bannerKey(Map<String, dynamic> b) => 'bn${_hash('${b['text']}${b['link'] ?? ''}')}';

/// The admin's banner: its words, its button, a cross that hides that text (a new text shows again).
class HomeBanner extends StatefulWidget {
  const HomeBanner({super.key});
  @override
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> {
  String? hidden;
  bool _read = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() {
          hidden = p.getString('annc');
          _read = true;
        });
      }
    }, onError: (_) => setState(() => _read = true));
  }

  @override
  Widget build(BuildContext context) {
    final home = context.app.home;
    return ListenableBuilder(
      listenable: home,
      builder: (context, _) {
        final b = home.banner;
        if (!_read || b == null || b['on'] != true || '${b['text'] ?? ''}'.trim().isEmpty || hidden == bannerKey(b)) return const SizedBox.shrink();
        final tone = b['tone'] == 'warn' || b['tone'] == 'fest' ? '${b['tone']}' : 'info';
        final (bg, fg, icon) = switch (tone) {
          'warn' => (const Color(0xFFFFF4E5), const Color(0xFFB45309), 'flag'),
          'fest' => (const Color(0xFFFDF2F8), const Color(0xFFBE185D), 'gift'),
          _ => (const Color(0xFFEEF2FF), const Color(0xFF4338CA), 'mega'),
        };
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          key: const ValueKey('banner'),
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          decoration: BoxDecoration(color: dark ? fg.withValues(alpha: .18) : bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: fg.withValues(alpha: .25))),
          child: Row(children: [
            PIcon(icon, size: 20, color: dark ? Colors.white : fg),
            const SizedBox(width: 10),
            Expanded(child: Text('${b['text']}', style: TextStyle(color: dark ? Colors.white : fg, fontWeight: FontWeight.w600, fontSize: 14, height: 1.35))),
            if ('${b['link'] ?? ''}'.isNotEmpty)
              TextButton(
                key: const ValueKey('banner-go'),
                style: TextButton.styleFrom(foregroundColor: dark ? Colors.white : fg, minimumSize: const Size(0, 36)),
                onPressed: () => openLink(context, '${b['link']}'),
                child: Text('${b['cta'] ?? ''}'.isEmpty ? 'ნახვა' : '${b['cta']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            IconBtn('x', key: const ValueKey('banner-x'), label: 'დახურვა', size: 18, color: dark ? Colors.white : fg, onTap: () async {
              final k = bannerKey(b);
              setState(() => hidden = k);
              try {
                await (await SharedPreferences.getInstance()).setString('annc', k);
              } catch (_) {}
            }),
          ]),
        );
      },
    );
  }
}

// ---------- sponsored posts and stories ----------

/// one of the admin's promos (the promos table)
class Promo {
  Promo(this.m);
  final Map<String, dynamic> m;
  int get id => (m['id'] as num?)?.toInt() ?? 0;
  String get kind => '${m['kind'] ?? 'post'}';
  String get brand => '${m['brand'] ?? ''}';
  String? get brandUrl => (m['brand_url'] as String?)?.isEmpty ?? true ? null : m['brand_url'] as String;
  String get title => '${m['title'] ?? ''}';
  String get body => '${m['body'] ?? ''}';
  String? get media => (m['media_url'] as String?)?.isEmpty ?? true ? null : m['media_url'] as String;
  bool get video => m['media_type'] == 'video';
  int get w => (m['w'] as num?)?.toInt() ?? 0;
  int get h => (m['h'] as num?)?.toInt() ?? 0;
  String get link => '${m['link'] ?? ''}';
  String get cta => '${m['cta'] ?? ''}'.isEmpty ? 'გაიგე მეტი' : '${m['cta']}';
  int get every => ((m['every'] as num?)?.toInt() ?? 6).clamp(2, 50);

  /// the house's own (no brand of its own): the Peera mark
  bool get house => brandUrl == null && RegExp(r'^\s*(peera|კურსელები)?\s*$', caseSensitive: false).hasMatch(brand);
}

Future<Set<int>> _ids(String key) async {
  try {
    final v = (await SharedPreferences.getInstance()).getString(key);
    return {for (final x in (v == null ? const [] : jsonDecode(v) as List)) (x as num).toInt()};
  } catch (_) {
    return {};
  }
}

Future<void> _addId(String key, int id) async {
  try {
    final s = (await _ids(key))..add(id);
    final l = s.toList();
    await (await SharedPreferences.getInstance()).setString(key, jsonEncode(l.sublist(l.length > 200 ? l.length - 200 : 0)));
  } catch (_) {}
}

/// the live promos not hidden on this phone, as (posts, stories), and which stories were seen
Future<(List<Promo>, List<Promo>, Set<int>)> loadPromos(BuildContext context) async {
  List<Map<String, dynamic>> rows;
  try {
    rows = await context.app.api.promos();
  } catch (_) {
    return (<Promo>[], <Promo>[], <int>{});
  }
  final hid = await _ids('promoHide'), seen = await _ids('promoSeen');
  final all = [for (final r in rows) Promo(r)].where((p) => !hid.contains(p.id)).toList();
  return (all.where((p) => p.kind == 'post').toList(), all.where((p) => p.kind == 'story').toList(), seen);
}

final _hit = <int>{};

/// counted once a session, as the site does
void promoSeen(BuildContext context, int id) {
  if (!_hit.add(id)) return;
  context.app.api.promoHit(id).catchError((_) {});
}

Future<void> _go(BuildContext context, Promo p) async {
  context.app.api.promoHit(p.id, click: true).catchError((_) {});
  if (p.link.isNotEmpty) {
    await openLink(context, p.link);
  } else if (p.media != null && !p.video) {
    await openPhotos(context, [Media(url: p.media!, w: p.w, h: p.h)]);
  }
}

Widget promoAvatar(Promo p, double size) => p.house
    ? Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
        child: PeeraMark(size: size * .7),
      )
    : Avatar(p: Profile(id: 'promo-${p.id}', name: p.brand, avatarUrl: p.brandUrl, hue: 330), size: size);

/// "რეკლამა": why it is here, and hiding it for good.
Future<void> promoMore(BuildContext context, Promo p, {VoidCallback? hidden}) => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 6), child: Text('რეკლამა', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('ამ რეკლამას Peera-ს გუნდი აჩვენებს. თუ არ გაინტერესებს, დამალე და აღარ გამოჩნდება.', style: TextStyle(color: s.pc.muted, height: 1.4)),
          ),
          ListTile(
            key: const ValueKey('promo-hide'),
            leading: PIcon('eyeoff', size: 22, color: s.pc.ink),
            title: const Text('რეკლამის დამალვა', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () async {
              Navigator.of(s).pop();
              await _addId('promoHide', p.id);
              hidden?.call();
              if (context.mounted) toast(context, 'რეკლამა დაიმალა');
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );

/// A sponsored post in the feed: the brand with "რეკლამა", the title, the words, the picture or video, the button.
class PromoCard extends StatelessWidget {
  const PromoCard({super.key, required this.p, required this.onHidden});
  final Promo p;
  final VoidCallback onHidden;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final ratio = p.w > 0 && p.h > 0 ? (p.w / p.h).clamp(.8, 1.91).toDouble() : 1.0;
    return Container(
      key: ValueKey('promo-${p.id}'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 6),
          child: Row(children: [
            promoAvatar(p, 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(p.brand.isEmpty ? 'Peera' : p.brand, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                  const SizedBox(width: 6),
                  const AdTag(),
                ]),
                Text('სპონსორი', style: TextStyle(color: c.muted, fontSize: 12.5)),
              ]),
            ),
            IconBtn('more', key: ValueKey('promo-more-${p.id}'), label: 'მეტი', onTap: () => promoMore(context, p, hidden: onHidden)),
          ]),
        ),
        if (p.title.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 4), child: Text(p.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.25))),
        if (p.body.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 8), child: Text(p.body, style: const TextStyle(fontSize: 15, height: 1.45))),
        if (p.media != null)
          GestureDetector(
            onTap: () => _go(context, p),
            child: AspectRatio(aspectRatio: ratio, child: p.video ? _PromoVideo(url: p.media!) : PImage(p.media!, fit: BoxFit.cover)),
          ),
        if (p.link.isNotEmpty)
          Material(
            color: c.accent.withValues(alpha: .1),
            child: InkWell(
              key: ValueKey('promo-go-${p.id}'),
              onTap: () => _go(context, p),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(children: [
                  Expanded(child: Text(p.cta, style: TextStyle(color: c.accent, fontWeight: FontWeight.w800, fontSize: 15))),
                  Transform.flip(flipX: true, child: PIcon('back', size: 18, color: c.accent)),
                ]),
              ),
            ),
          )
        else
          const SizedBox(height: 10),
      ]),
    );
  }
}

/// "რეკლამა", the small tag on paid things
class AdTag extends StatelessWidget {
  const AdTag({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: .16), borderRadius: BorderRadius.circular(6)),
        child: const Text('რეკლამა', style: TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

class _PromoVideo extends StatefulWidget {
  const _PromoVideo({required this.url});
  final String url;
  @override
  State<_PromoVideo> createState() => _PromoVideoState();
}

class _PromoVideoState extends State<_PromoVideo> {
  late final Player player = makePlayer(widget.url, loop: true);

  @override
  void initState() {
    super.initState();
    player.mute(true).then((_) => player.play()).catchError((_) {});
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VideoBox(player: player, fit: BoxFit.cover, waiting: false);
}

/// A sponsored story's ring, right after mine: the brand, "რეკლამა" on the ring.
class PromoRing extends StatelessWidget {
  const PromoRing({super.key, required this.p, required this.seen, required this.onTap});
  final Promo p;
  final bool seen;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Semantics(
      button: true,
      label: 'რეკლამა: ${p.brand}',
      child: GestureDetector(
        key: ValueKey('story-promo-${p.id}'),
        onTap: onTap,
        child: SizedBox(
          width: 76,
          child: Column(children: [
            SizedBox.square(
              dimension: 66,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 66,
                  height: 66,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: seen ? null : const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316)]),
                    border: seen ? Border.all(color: c.line, width: 2) : null,
                  ),
                  child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle), child: promoAvatar(p, 54)),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -6,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(999), border: Border.all(color: c.bg, width: 2)),
                      child: const Text('რეკლამა', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 5),
            Text(p.brand.isEmpty ? 'Peera' : p.brand, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: seen ? FontWeight.w400 : FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

/// A sponsored story over everything: its picture or video, the brand, and its button. Back closes it.
Future<void> openPromoStory(BuildContext context, Promo p) async {
  await _addId('promoSeen', p.id);
  if (!context.mounted) return;
  promoSeen(context, p.id);
  await Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
    opaque: true,
    pageBuilder: (_, __, ___) => AppScope(app: context.app, me: context.me, child: _PromoStory(p: p, parent: context)),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

class _PromoStory extends StatelessWidget {
  const _PromoStory({required this.p, required this.parent});
  final Promo p;

  /// the page the story was opened from: its button opens there once the story is closed
  final BuildContext parent;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(fit: StackFit.expand, children: [
            if (p.media != null)
              p.video ? _PromoVideo(url: p.media!) : PImage(p.media!, fit: BoxFit.contain, background: Colors.black)
            else
              Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(p.title.isEmpty ? p.body : p.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)))),
            Positioned(
              left: 12,
              right: 4,
              top: 8,
              child: Row(children: [
                promoAvatar(p, 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.brand.isEmpty ? 'Peera' : p.brand, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    const Text('რეკლამა', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
                IconBtn('more', label: 'მეტი', color: Colors.white, onTap: () => promoMore(context, p, hidden: () => Navigator.of(context).maybePop())),
                IconBtn('x', key: const ValueKey('promo-story-x'), label: 'დახურვა', color: Colors.white, onTap: () => Navigator.of(context).maybePop()),
              ]),
            ),
            if (p.link.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: FilledButton(
                  key: const ValueKey('promo-story-go'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.white, foregroundColor: Colors.black),
                  onPressed: () async {
                    await Navigator.of(context).maybePop();
                    if (parent.mounted) await _go(parent, p);
                  },
                  child: Text(p.cta, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
        ),
      );
}

/// A paid post (ads) in the feed carries the tag; shown once, counted once.
final adsShown = <int>{};
void adSeen(BuildContext context, int adId) {
  if (!adsShown.add(adId)) return;
  context.app.api.adImpression(adId).catchError((_) {});
}
