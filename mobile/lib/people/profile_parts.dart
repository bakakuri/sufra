// Pieces of the profile page, as on the site (js/people.js, js/extras.js): the drawn mountains under a profile with
// no cover, the medals, the "more" menu (gift, share, family tree, report, block), the QR card, and the sheets for
// badges, guests and gifts.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'badges.dart';
import 'coins.dart';

Future<void> openSite(String path) async {
  try {
    await launchUrl(Uri.parse('$siteUrl/$path'), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// a profile's address on the site (what the QR code holds)
String profileLink(String uid) => '$siteUrl/#user-$uid';

/// the phone's own "share" (any app), the site's shareLink
Future<void> shareText(BuildContext context, String text) async {
  try {
    await const MethodChannel('peera/share').invokeMethod('text', {'text': text});
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) toast(context, 'ბმული დაკოპირდა');
  }
}

// ---------- the drawn mountains (lib-icons.js art('mtn', hue + 11)) ----------

/// The site's generated landscape for a profile without a cover: sky, sun and four ridges, the same for the same seed.
class MountainArt extends CustomPainter {
  MountainArt(this.seed);
  final int seed;
  static const _skies = [
    [Color(0xFF0F2A4A), Color(0xFFF2A65A)],
    [Color(0xFF1B1035), Color(0xFFE86F7A)],
    [Color(0xFF4F92CC), Color(0xFFE8F1F7)],
    [Color(0xFF2B1B3F), Color(0xFFF7B267)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // drawn on the site's 560×200 and laid over the box like a photo ("cover")
    const w = 560.0, h = 200.0;
    final k = math.max(size.width / w, size.height / h);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - w * k) / 2, (size.height - h * k) / 2);
    canvas.scale(k);
    var s = (seed * 7919 + 13) % 2147483647;
    if (s <= 0) s += 2147483646;
    double r() {
      s = s * 16807 % 2147483647;
      return s / 2147483647;
    }

    final sky = _skies[seed % _skies.length];
    canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: sky).createShader(const Rect.fromLTWH(0, 0, w, h)));
    final cx = w * (.2 + r() * .6), cy = h * (.16 + r() * .18), cr = math.min(w, h) * (.05 + r() * .04);
    canvas.drawCircle(Offset(cx, cy), cr, Paint()..color = const Color.fromRGBO(255, 238, 205, .88));
    for (var l = 0; l < 4; l++) {
      final base = h * (.42 + l * .11);
      final path = Path()..moveTo(0, h);
      for (var i = 0.0; i <= w + 1; i += w / 14) {
        path.lineTo(i, base - r() * h * .24 * (l == 0 ? 1.3 : 1));
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = HSLColor.fromAHSL(1, (222 + l * 8).toDouble(), (28 + l * 4) / 100, math.max(9, 48 - l * 12) / 100).toColor());
      if (l == 0) canvas.drawRect(Rect.fromLTWH(0, base - h * .32, w, h * .012), Paint()..color = const Color.fromRGBO(255, 255, 255, .35));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MountainArt old) => old.seed != seed;
}

// ---------- medals ----------

const _tierColors = {
  1: [Color(0xFFF6CCA6), Color(0xFFB5693D), Color(0xFF7A3E1F)],
  2: [Color(0xFFFFFFFF), Color(0xFFB3BCCB), Color(0xFF6E7889)],
  3: [Color(0xFFFFF3B0), Color(0xFFF2B705), Color(0xFFA86A00)],
  4: [Color(0xFFE6FCFF), Color(0xFF93A9FF), Color(0xFF6A3FE0)],
};

/// A badge as a little medal of its tier (bronze, silver, gold, diamond); a locked one is grey and faint.
class Medal extends StatelessWidget {
  const Medal(this.code, {super.key, this.size = 22, this.locked = false});
  final String code;
  final double size;
  final bool locked;
  @override
  Widget build(BuildContext context) {
    final b = badgeList[code];
    if (b == null) return const SizedBox.shrink();
    final m = _tierColors[b.$5] ?? _tierColors[1]!;
    Widget w = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: const Alignment(-.55, -1), end: const Alignment(.55, 1), colors: m, stops: const [0, .68, 1]),
        border: Border.all(color: Colors.white.withValues(alpha: .5), width: math.max(1.5, size * .065)),
        boxShadow: const [BoxShadow(color: Color(0x47000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(center: const Alignment(-.4, -.52), radius: .42, colors: [Colors.white.withValues(alpha: .8), Colors.white.withValues(alpha: 0)]),
            ),
          ),
        ),
        Text(b.$1, style: TextStyle(fontSize: size * .5, height: 1)),
      ]),
    );
    if (locked) {
      w = Opacity(
        opacity: .4,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([.2126, .7152, .0722, 0, 0, .2126, .7152, .0722, 0, 0, .2126, .7152, .0722, 0, 0, 0, 0, 0, 1, 0]),
          child: w,
        ),
      );
    }
    return w;
  }
}

/// the one badge a profile shows: the hardest earned, the newest among equals
String? topBadge(List<(String, DateTime)> got) {
  final l = got.where((x) => badgeList.containsKey(x.$1)).toList()
    ..sort((a, b) {
      final t = badgeList[b.$1]!.$5.compareTo(badgeList[a.$1]!.$5);
      return t != 0 ? t : b.$2.compareTo(a.$2);
    });
  return l.isEmpty ? null : l.first.$1;
}

Widget _head(BuildContext context, String t) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    );

Future<T?> _sheet<T>(BuildContext context, Widget Function(BuildContext) body, {bool tall = false}) => showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => AppScope(
        app: context.app,
        me: context.me,
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(s).height * (tall ? .88 : .7)),
            child: body(s),
          ),
        ),
      ),
    );

/// All badges: the best one on top, how many are earned, then each tier (mine: the locked ones too, with how).
Future<void> badgesSheet(BuildContext context, String uid, String name) {
  final app = context.app, mine = uid == app.api.myId;
  return _sheet(
    context,
    tall: true,
    (s) => FutureBuilder<List<(String, DateTime)>>(
      future: app.api.badges(uid),
      builder: (context, snap) {
        final c = context.pc;
        if (!snap.hasData) return const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()));
        final has = {for (final r in snap.data!) if (badgeList.containsKey(r.$1)) r.$1: r.$2};
        final top = topBadge(snap.data!), tt = top == null ? 0 : badgeList[top]!.$5, all = badgeList.keys.toList();
        return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          _head(context, mine ? 'ჩემი ნიშნები' : 'ნიშნები · ${name.split(' ').first}'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              top != null ? Medal(top, size: 72) : const Medal('post1', size: 72, locked: true),
              const SizedBox(width: 14),
              Expanded(
                child: top != null
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('ყველაზე ძვირფასი', style: TextStyle(color: c.muted, fontSize: 12.5)),
                        Text(badgeList[top]!.$2, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(tierNames[tt]!, style: TextStyle(color: (_tierColors[tt] ?? _tierColors[1]!)[2], fontWeight: FontWeight.w700, fontSize: 13)),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('ნიშნები ჯერ არ არის', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        if (mine) Text('ქვემოთ წერია, როგორ მოიპოვო. თითო ნიშანს მონეტებიც მოჰყვება.', style: TextStyle(color: c.muted, fontSize: 13)),
                      ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Text.rich(TextSpan(children: [const TextSpan(text: 'მოპოვებულია '), TextSpan(text: '${has.length}', style: const TextStyle(fontWeight: FontWeight.w800)), TextSpan(text: ' / ${all.length}')]),
              style: TextStyle(color: c.ink, fontSize: 14)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: has.length / all.length, minHeight: 7, backgroundColor: c.line, color: c.gold),
          ),
          for (final tier in const [4, 3, 2, 1])
            if (all.any((k) => badgeList[k]!.$5 == tier && (mine || has.containsKey(k)))) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: _tierColors[tier]![1])),
                  const SizedBox(width: 8),
                  Text(tierNames[tier]!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const Spacer(),
                  Text('${all.where((k) => badgeList[k]!.$5 == tier && has.containsKey(k)).length}/${all.where((k) => badgeList[k]!.$5 == tier && (mine || has.containsKey(k))).length}',
                      style: TextStyle(color: c.muted, fontSize: 13)),
                ]),
              ),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: .72,
                children: [
                  for (final k in all.where((k) => badgeList[k]!.$5 == tier && (mine || has.containsKey(k))))
                    Container(
                      padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
                      decoration: BoxDecoration(
                        color: has.containsKey(k) ? c.surface : c.sunk,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.line),
                      ),
                      child: Column(children: [
                        Medal(k, size: 48, locked: !has.containsKey(k)),
                        const SizedBox(height: 6),
                        Text(badgeList[k]!.$2, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        const SizedBox(height: 2),
                        Expanded(
                          child: Text(has.containsKey(k) ? 'მოპოვებულია ${dayLabel(has[k]!)}' : badgeList[k]!.$3,
                              textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 11, height: 1.25)),
                        ),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('+${badgeList[k]!.$4} ', style: TextStyle(color: c.gold, fontWeight: FontWeight.w800, fontSize: 12)),
                          PIcon('coin', size: 13, color: c.gold),
                        ]),
                      ]),
                    ),
                ],
              ),
            ],
        ]);
      },
    ),
  );
}

// ---------- guests and gifts (mine) ----------

const _guestsKey = 'guests.seen';

/// when I last looked at my guests (new ones are counted from then; a week back the first time)
Future<DateTime> guestsSeenAt() async {
  try {
    final v = (await SharedPreferences.getInstance()).getString(_guestsKey);
    final t = v == null ? null : DateTime.tryParse(v);
    if (t != null) return t;
  } catch (_) {}
  return DateTime.now().subtract(const Duration(days: 7));
}

Future<void> _guestsSeen() async {
  try {
    await (await SharedPreferences.getInstance()).setString(_guestsKey, DateTime.now().toIso8601String());
  } catch (_) {}
}

/// Who came by my page (an invisible visitor is not here), newest first; a tap opens them.
Future<void> guestsSheet(BuildContext context, {required void Function(String uid) open, required bool invisible}) {
  final app = context.app;
  _guestsSeen();
  return _sheet(
    context,
    (s) => FutureBuilder<List<Visit>>(
      future: app.api.guests().then((v) async {
        await app.people.ensure(v.map((x) => x.user));
        return v;
      }),
      builder: (context, snap) {
        final c = context.pc, l = snap.data;
        return ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
          _head(context, 'სტუმრები'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('ვინ ნახა შენი გვერდი${invisible ? '. უხილავი რეჟიმი ჩართულია: შენ სხვების სტუმრებში არ ჩანხარ' : ''}',
                style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.4)),
          ),
          if (l == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (l.isEmpty)
            const Empty(icon: 'eye', title: 'სტუმრები ჯერ არ ყოფილან')
          else
            for (final v in l)
              ListTile(
                key: ValueKey('guest-${v.user}'),
                leading: Avatar(p: app.people[v.user] ?? Profile(id: v.user, name: '…'), size: 44),
                title: NameLine(app.people[v.user] ?? Profile(id: v.user, name: '…'), size: 15),
                subtitle: Text(ago(v.at), style: TextStyle(color: c.muted, fontSize: 13)),
                trailing: PIcon('eye', size: 20, color: c.muted),
                onTap: () {
                  Navigator.of(s).pop();
                  open(v.user);
                },
              ),
        ]);
      },
    ),
  );
}

/// The gifts I got, each with the first name of who sent it.
Future<void> giftsGotSheet(BuildContext context) {
  final app = context.app;
  return _sheet(
    context,
    (s) => FutureBuilder<List<GiftGot>>(
      future: app.api.giftsGot().then((v) async {
        await app.people.ensure(v.map((x) => x.sender));
        return v;
      }),
      builder: (context, snap) {
        final l = snap.data;
        return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), children: [
          _head(context, 'საჩუქრები'),
          if (l == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (l.isEmpty)
            const Empty(icon: 'gift', title: 'საჩუქრები ჯერ არ მიგიღია')
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in l)
                _GiftTile(emoji: g.emoji, label: (app.people[g.sender]?.name ?? '…').split(' ').first),
            ]),
        ]);
      },
    ),
  );
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({super.key, required this.emoji, required this.label, this.price, this.poor = false, this.onTap});
  final String emoji, label;
  final int? price;
  final bool poor;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Opacity(
      opacity: poor ? .45 : 1,
      child: Material(
        color: c.sunk,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 78,
            height: price == null ? 86 : 100,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 4),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: c.muted)),
              if (price != null) Text(grouped(price!), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: c.gold)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------- the "more" menu ----------

/// the gifts and their prices (the server's gift_cost); whoever gets one receives half
const giftList = [
  ('🌷', 'ტიტა', 50, 'fl'), ('🌹', 'ვარდი', 100, 'fl'), ('🌻', 'მზესუმზირა', 150, 'fl'), ('🌸', 'საკურა', 200, 'fl'), ('💐', 'თაიგული', 500, 'fl'),
  ('☕', 'ყავა', 50, 'sw'), ('🍫', 'შოკოლადი', 80, 'sw'), ('🍦', 'ნაყინი', 100, 'sw'), ('🍇', 'ყურძენი', 120, 'sw'), ('🍰', 'ნამცხვარი', 300, 'sw'), ('🎂', 'ტორტი', 1000, 'sw'),
  ('❤️', 'გული', 50, 'lv'), ('💌', 'წერილი', 150, 'lv'), ('🧸', 'დათუნია', 800, 'lv'), ('💍', 'ბეჭედი', 7000, 'lv'),
  ('🎈', 'ბუშტი', 60, 'fe'), ('📚', 'წიგნი', 100, 'fe'), ('🎉', 'ზეიმი', 200, 'fe'), ('⭐', 'ვარსკვლავი', 250, 'fe'), ('🎓', 'დიპლომი', 300, 'fe'), ('🎁', 'საჩუქარი', 400, 'fe'),
  ('🏆', 'თასი', 5000, 'lx'), ('🚗', 'მანქანა', 8000, 'lx'), ('💎', 'ბრილიანტი', 10000, 'lx'), ('🚀', 'რაკეტა', 12000, 'lx'), ('🏰', 'ციხესიმაგრე', 15000, 'lx'),
  ('🦄', 'ერთრქა', 20000, 'lx'), ('👑', 'გვირგვინი', 25000, 'lx'),
];

/// Sending a gift: the balance, the gifts with their prices (the ones I cannot afford faint); a tap sends it.
Future<void> giftSheet(BuildContext context, Profile to) {
  final app = context.app, coins = context.me.coins;
  return _sheet(
    context,
    tall: true,
    (s) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), children: [
      _head(s, 'საჩუქარი · ${to.name}'),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Text('ბალანსი: ${grouped(coins)} მონეტა. საჩუქრის ნახევარი მას ერიცხება.', style: TextStyle(color: s.pc.muted, fontSize: 13.5)),
      ),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final g in giftList)
          Semantics(
            label: '${g.$2}, ${g.$3} მონეტა',
            button: true,
            excludeSemantics: true,
            child: _GiftTile(
              key: ValueKey('gift-${g.$1}'),
              emoji: g.$1,
              label: g.$2,
              price: g.$3,
              poor: g.$3 > coins,
              onTap: () async {
                try {
                  await app.api.sendGift(to.id, g.$1);
                  if (s.mounted) Navigator.of(s).pop();
                  app.refreshMe?.call();
                  if (context.mounted) toast(context, '${g.$1} გაიგზავნა');
                } catch (e) {
                  if (!s.mounted) return;
                  if ('$e'.contains('not_enough')) {
                    toast(s, 'მონეტები არ გყოფნის');
                    openPage(context, const CoinsScreen(), full: true);
                  } else {
                    toast(s, errText(e));
                  }
                }
              },
            ),
          ),
      ]),
    ]),
  );
}

const reportReasons = [
  'სპამი ან რეკლამა',
  'შეურაცხყოფა ან სიძულვილის ენა',
  'შევიწროება ან მუქარა',
  'ყალბი პროფილი',
  'თაღლითობა',
  'შიშველი ან სექსუალური შინაარსი',
  'არასრულწლოვანს ეხება',
  'ძალადობა',
  'სხვა',
];

/// A complaint: what the problem is; the author never learns who sent it.
Future<void> reportSheet(BuildContext context, String type, String id) {
  final app = context.app;
  return _sheet(
    context,
    (s) => ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: [
      _head(s, 'საჩივარი'),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        child: Text('რა არის პრობლემა? ავტორი ვერ გაიგებს, ვინ გაგზავნა საჩივარი.', style: TextStyle(color: s.pc.muted, fontSize: 13.5)),
      ),
      for (final r in reportReasons)
        ListTile(
          key: ValueKey('reason-$r'),
          title: Text(r, style: const TextStyle(fontWeight: FontWeight.w600)),
          onTap: () async {
            try {
              await app.api.report(type, id, r);
              if (s.mounted) Navigator.of(s).pop();
              if (context.mounted) toast(context, 'საჩივარი მიღებულია. მოდერატორი განიხილავს');
            } catch (e) {
              if (s.mounted) toast(s, errText(e));
            }
          },
        ),
    ]),
  );
}

/// Blocking, after saying what it does; true when done.
Future<bool> blockPerson(BuildContext context, Profile p) async {
  final app = context.app;
  if (!await confirm(context,
      title: 'დაბლოკვა', text: '${p.name} ვეღარ დაინახავს შენს პოსტებს, ვეღარ მოგწერს და ვეღარ გამოგიწვევს თამაშში. შენც აღარ დაინახავ მის შინაარსს.', yes: 'დაბლოკვა', danger: true)) {
    return false;
  }
  if (!context.mounted) return false;
  final ok = await attempt(context, () => app.api.block(p.id));
  if (!ok) return false;
  app.friends.load().catchError((_) {});
  if (context.mounted) toast(context, 'დაიბლოკა');
  return true;
}

// ---------- the QR card ----------

/// My (or someone's) QR code: a friend's camera opens the profile; the link can be shared too.
Future<void> qrSheet(BuildContext context, Profile p) {
  final mine = p.id == context.app.api.myId, url = profileLink(p.id);
  return _sheet(
    context,
    tall: true,
    (s) {
      final c = s.pc;
      return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
        _head(s, mine ? 'ჩემი QR კოდი' : 'QR კოდი'),
        Center(
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 6))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              QrImageView(key: const ValueKey('qr'), data: url, size: 220, backgroundColor: Colors.white, padding: EdgeInsets.zero),
              const SizedBox(height: 12),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Avatar(p: p, size: 36),
                const SizedBox(width: 10),
                Text(p.name, style: const TextStyle(color: Color(0xFF1D1320), fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          mine ? 'მეგობარი ტელეფონის კამერით დაასკანერებს და პირდაპირ შენს პროფილზე მოხვდება. Peera-ზე სახელის ძებნა აღარ დაგჭირდებათ.' : 'დაასკანერე ან გაუზიარე სხვას.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.4),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () => shareText(s, url),
              icon: PIcon('share', size: 19, color: c.onAccent),
              label: const Text('ბმულის გაზიარება'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () => showDialog<void>(
                context: s,
                builder: (d) => AlertDialog(
                  title: const Text('QR-ის სკანირება'),
                  content: const Text('გახსენი ტელეფონის კამერა და მიუშვირე მეგობრის QR კოდს. კამერა ბმულს თავად იცნობს: დააჭირე და პროფილი Peera-ზე გაიხსნება.'),
                  actions: [TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('კარგი'))],
                ),
              ),
              icon: PIcon('camera', size: 19, color: c.ink),
              label: const Text('სკანირება'),
            ),
          ),
        ]),
      ]);
    },
  );
}

const gameLeagues = [(0, 'ეზოს მოთამაშე'), (1450, 'უბნის ოსტატი'), (1550, 'ქალაქის ჩემპიონი'), (1650, 'კუთხის ჩემპიონი'), (1800, 'საქართველოს ჩემპიონი')];
const ratedGames = [('nardi', 'ნარდი'), ('shashi', 'შაში'), ('chess', 'ჭადრაკი')];

/// the league a rating belongs to
String gameLeague(int r) {
  var n = gameLeagues.first.$2;
  for (final (x, t) in gameLeagues) {
    if (r >= x) n = t;
  }
  return n;
}

/// The games card (games-core.js): the picture, the rating of each game with its league, Joker, and for me the way to play.
Future<void> gamesCard(BuildContext context, Profile who, JokerLine? joker, {required bool mine}) {
  final app = context.app;
  final rows = app.api.gameRatings(who.id).then<List<(String, int, int, int)>?>((r) => r, onError: (_) => null);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) {
      final c = s.pc;
      Widget cell(String key, String big, String name, String league, [String? record]) => Expanded(
            child: Container(
              key: ValueKey(key),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Text(big, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(league, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(color: c.accent, fontSize: 11, fontWeight: FontWeight.w700, height: 1.25)),
                if (record != null) Text(record, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(color: c.muted, fontSize: 11, height: 1.25)),
              ]),
            ),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('სათამაშო ბარათი', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Center(child: Avatar(p: who, size: 84)),
            const SizedBox(height: 8),
            Text(who.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            FutureBuilder<List<(String, int, int, int)>?>(
              future: rows,
              builder: (s, snap) {
                if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)));
                final got = snap.data;
                if (got == null) {
                  final r = who.rating ?? 1500;
                  return Row(children: [cell('gc-all', '$r', 'რეიტინგი', gameLeague(r))]);
                }
                return IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (final (g, n) in ratedGames)
                      () {
                        final r = got.where((x) => x.$1 == g).firstOrNull;
                        final rt = r?.$2 ?? 1500;
                        return cell('gc-$g', '$rt', n, gameLeague(rt), r != null && r.$3 > 0 ? '${r.$3} პარტია, ${r.$4} მოგება' : 'ჯერ არ უთამაშია');
                      }(),
                  ]),
                );
              },
            ),
            if (joker != null) ...[
              const SizedBox(height: 10),
              Container(
                key: const ValueKey('gc-joker'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  PIcon('cards', size: 22, color: c.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('ჯოკერი: ${joker.rating != null ? '${joker.rating} რეიტინგი · ' : ''}${joker.games} თამაში · ${joker.wins} მოგება',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ],
            if (mine) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('gc-play'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () {
                  Navigator.of(s).pop();
                  app.goTab?.call('joker');
                },
                icon: PIcon('play', size: 18, color: c.onAccent),
                label: const Text('თამაში'),
              ),
            ],
          ]),
        ),
      );
    },
  );
}
