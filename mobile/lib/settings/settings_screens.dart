// Settings (js/settings.js): one short page of groups, each opening its own page, so one back comes straight back.
// My profile, coins, dating, verification; notifications (the phone, quiet hours, kinds); privacy (online status,
// "seen", invisible guest, who may write or challenge, the blocked); the look; the rules; signing out.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../dating/dating_setup.dart';
import '../people/coins.dart';
import '../people/verify.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/look.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'edit_profile.dart';
import 'texts.dart';

Future<void> openSettings(BuildContext context) => openPage(context, const SettingsScreen(), full: true);
Future<void> _site(String path) => launchUrl(Uri.parse('$siteUrl/$path'), mode: LaunchMode.externalApplication);

int? ageOf(Object? birthday) {
  final b = DateTime.tryParse('${birthday ?? ''}');
  if (b == null) return null;
  final now = DateTime.now();
  var a = now.year - b.year;
  if (now.month < b.month || (now.month == b.month && now.day < b.day)) a--;
  return a;
}

/// a group of rows under a small title
class SGroup extends StatelessWidget {
  const SGroup({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(title!, style: TextStyle(color: c.muted, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: .2)),
          ),
        // a Material, so the rows' touch ripples show on it
        Material(
          color: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.line)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 60, color: c.line),
              children[i],
            ],
          ]),
        ),
      ]),
    );
  }
}

/// a row that opens something: an icon on a coloured square, a name, what it is set to
class SRow extends StatelessWidget {
  const SRow({super.key, required this.icon, required this.title, this.sub, this.color, this.onTap, this.trailing, this.danger = false});
  final String icon, title;
  final String? sub;
  final Color? color;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, col = danger ? c.nope : (color ?? c.accent);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: col.withValues(alpha: .14), borderRadius: BorderRadius.circular(10)),
            child: PIcon(icon, size: 20, color: col),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: danger ? c.nope : c.ink)),
              if (sub != null && sub!.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(sub!, style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.3)),
              ],
            ]),
          ),
          trailing ?? (onTap != null && !danger ? PIcon('chev', size: 18, color: c.muted) : const SizedBox.shrink()),
        ]),
      ),
    );
  }
}

/// a row with a switch
class SSwitch extends StatelessWidget {
  const SSwitch({super.key, required this.title, this.sub, required this.value, required this.onChanged, this.icon});
  final String title;
  final String? sub, icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.fromLTRB(12, 2, 8, 2),
      secondary: icon == null
          ? null
          : Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
              child: PIcon(icon!, size: 20, color: c.accent),
            ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: sub == null || sub!.isEmpty ? null : Text(sub!, style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.3)),
    );
  }
}

/// a choice of a few, in one line
class SChoice<T> extends StatelessWidget {
  const SChoice({super.key, required this.id, required this.title, required this.options, required this.value, required this.onChanged});
  final String id, title;
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        Row(children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Material(
                color: value == options[i].$1 ? c.ink : c.sunk,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: ValueKey('$id-${options[i].$1}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChanged(options[i].$1),
                  child: SizedBox(
                    height: 40,
                    child: Center(
                      child: FittedBox(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(options[i].$2, style: TextStyle(color: value == options[i].$1 ? c.bg : c.ink, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

// ---------- the main page ----------

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? s;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await context.app.api.mySettings();
      if (mounted) setState(() => s = m);
    } catch (_) {
      if (mounted) setState(() => s = const {});
    }
  }

  Future<void> _go(Widget page) async {
    await openPage(context, page, full: true);
    _load();
  }

  Future<void> _dating() async {
    final app = context.app;
    try {
      final d = await app.api.datingMe();
      if (!mounted) return;
      await openPage(context, DatingSetup(me: d, edit: true), full: true);
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  Future<void> _out() async {
    if (!await confirm(context, title: 'გასვლა', text: 'ანგარიშიდან გახვალ ამ ტელეფონზე.', yes: 'გასვლა', danger: true)) return;
    if (!mounted) return;
    final out = context.app.signOut;
    Navigator.of(context).pop();
    await out?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, m = s ?? const {};
    // the row as it is now (an edit changes it; the screen's own copy of "me" was taken when it opened)
    final me = m['id'] == null ? context.me : Profile.fromJson(m);
    final adult = (ageOf(m['birthday']) ?? 0) >= 18;
    final priv = m['privacy'] is Map ? m['privacy'] as Map : const {};
    final notif = m['notif'] is Map ? m['notif'] as Map : const {};
    final offN = notif['off'] is Map ? (notif['off'] as Map).values.where((v) => v == true).length : 0;
    final quiet = notif['quiet'] is Map && (notif['quiet'] as Map)['on'] == true;
    final coins = m['coins'] == null ? me.coins : asInt(m['coins']);
    return Scaffold(
      appBar: peeraBar(context, title: 'პარამეტრები'),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Material(
            color: c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.line)),
            child: InkWell(
              key: const ValueKey('set-me'),
              borderRadius: BorderRadius.circular(18),
              onTap: () => _go(const EditProfileScreen()),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Avatar(p: me, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(me.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                        if (me.verified) const Verified(),
                      ]),
                      if (me.username != null) Text('@${me.username}', style: TextStyle(color: c.muted, fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text('პროფილის რედაქტირება', style: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: 13.5)),
                    ]),
                  ),
                  PIcon('chev', size: 18, color: c.muted),
                ]),
              ),
            ),
          ),
        ),
        SGroup(title: 'ანგარიში', children: [
          SRow(icon: 'coin', color: c.gold, title: 'მონეტები', sub: 'ბალანსი: ${grouped(coins)}', onTap: () => openPage(context, const CoinsScreen())),
          if (adult) SRow(key: const ValueKey('set-dating'), icon: 'heart', color: c.nope, title: 'გაცნობის პროფილი', sub: m['dating'] == true ? 'ჩართულია' : 'გამორთულია', onTap: _dating),
          SRow(icon: 'check', color: const Color(0xFF3E8EF7), title: 'ვერიფიკაცია', sub: me.verified ? 'დადასტურებულია ✓' : 'მიიღე ლურჯი ნიშანი ერთი სელფით', onTap: () => openPage(context, const VerifyScreen())),
        ]),
        SGroup(title: 'პარამეტრები', children: [
          SRow(
            key: const ValueKey('set-notif'),
            icon: 'bell',
            color: c.vine,
            title: 'შეტყობინებები',
            sub: [offN > 0 ? '$offN ტიპი გამორთულია' : 'ყველა ჩართულია', if (quiet) 'ღამით ჩუმად'].join(' · '),
            onTap: () => _go(const NotifSettingsScreen()),
          ),
          SRow(
            key: const ValueKey('set-privacy'),
            icon: 'lock',
            color: c.accent,
            title: 'კონფიდენციალურობა',
            sub: [priv['online'] == false ? 'ონლაინ სტატუსი დამალულია' : 'ონლაინ სტატუსი ჩანს', priv['dm'] == 'friends' ? 'მოგწერენ მეგობრები' : 'მოგწერს ყველა'].join(' · '),
            onTap: () => _go(const PrivacyScreen()),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([themeChoice, textZoom]),
            builder: (context, _) => SRow(
              key: const ValueKey('set-look'),
              icon: 'eye',
              color: const Color(0xFF3E8EF7),
              title: 'ეკრანი',
              sub: '${const {ThemeMode.system: 'როგორც ტელეფონში', ThemeMode.light: 'ღია', ThemeMode.dark: 'მუქი'}[themeChoice.value]} · ტექსტი: ${_zoomName(textZoom.value)}',
              onTap: () => _go(const LookScreen()),
            ),
          ),
        ]),
        SGroup(title: 'წესები და მონაცემები', children: [
          SRow(icon: 'note', color: c.muted, title: 'საზოგადოების წესები', onTap: () => openPage(context, const TextScreen(title: 'საზოგადოების წესები', sections: rulesText), full: true)),
          SRow(
            icon: 'lock',
            color: c.muted,
            title: 'კონფიდენციალურობის პოლიტიკა',
            onTap: () => openPage(context, const TextScreen(title: 'კონფიდენციალურობის პოლიტიკა', sections: privacyText), full: true),
          ),
          SRow(icon: 'globe', color: c.muted, title: 'ჩემი მონაცემების ჩამოტვირთვა', sub: 'ყველაფერი ერთ ფაილში, საიტზე', onTap: () => _site('#settings')),
        ]),
        SGroup(children: [
          SRow(key: const ValueKey('set-out'), icon: 'out', title: 'გასვლა', danger: true, onTap: _out),
        ]),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            onPressed: () => _site('#settings'),
            child: Text('ანგარიშის წაშლა საიტზე', style: TextStyle(color: c.muted, fontSize: 13.5)),
          ),
        ),
        Center(child: Text('Peera $appVersion', style: TextStyle(color: c.muted, fontSize: 12))),
      ]),
    );
  }
}

String _zoomName(double z) => z >= 1.2 ? 'უფრო დიდი' : (z >= 1.1 ? 'დიდი' : 'ჩვეულებრივი');

// ---------- notifications ----------

const notifKinds = [
  ('study', 'note', 'ლექციები და გამოცდები', 'შეხსენება ლექციამდე 15 წუთით ადრე, გამოცდამდე წინა საღამოს და იმ დილით, ჯგუფის ახალი ვადები'),
  ('reactions', 'heart', 'მოწონებები და რეაქციები', 'პოსტზე, კომენტარზე, მესიჯზე, ისტორიაზე, რეპოსტები'),
  ('comments', 'comment', 'კომენტარები, პასუხები, ხსენებები', 'როცა @სახელით მოგიხსენიებენ'),
  ('friends', 'users', 'მეგობრობა და ოჯახის ხე', 'მოთხოვნები და დადასტურება'),
  ('messages', 'msg', 'მესიჯები', 'მხოლოდ push ითიშება, მესიჯები ჩატში მაინც მოვა'),
  ('celebrations', 'star', 'ანგელოზის და დაბადების დღეები', 'მეგობრების დღესასწაულები'),
  ('live', 'play', 'ლაივები', 'როცა მეგობარი ეთერში გადის'),
  ('rooms', 'clips', 'სასწავლო ოთახისა და დისკუსიის მოსაწვევები', ''),
  ('help', 'heart', 'დახმარების თხოვნები ახლოს', 'დონორი, მოხალისე, დაკარგული ცხოველი'),
  ('dating', 'heart', 'გაცნობა', 'წყვილები და სუპერ მოწონებები'),
  ('gifts', 'star', 'საჩუქრები', ''),
  ('sport', 'star', 'მატჩები და პროგნოზები', ''),
  ('deals', 'pin', 'მგზავრობა და ვაკანსიები', 'ჯავშნები და გამოხმაურებები'),
  ('groups', 'users', 'ჯგუფები', 'მოთხოვნები, დასამტკიცებელი პოსტები'),
  ('events', 'clock', 'ღონისძიებები და ალბომები', 'მოწვევები, შეხსენებები, ახალი ფოტოები'),
  ('promo', 'bell', 'სიახლეები და რეკლამა', 'Peera-ს გუნდის შეტყობინებები ყველასთვის'),
];

class NotifSettingsScreen extends StatefulWidget {
  const NotifSettingsScreen({super.key});
  @override
  State<NotifSettingsScreen> createState() => _NotifSettingsScreenState();
}

class _NotifSettingsScreenState extends State<NotifSettingsScreen> {
  Map<String, bool> off = {};
  bool quiet = false, adult = false, loaded = false;
  int from = 23, to = 8;
  String tz = 'Asia/Tbilisi';
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await context.app.api.mySettings();
      final n = m['notif'] is Map ? m['notif'] as Map : const {};
      final o = n['off'] is Map ? n['off'] as Map : const {};
      final q = n['quiet'] is Map ? n['quiet'] as Map : const {};
      if (!mounted) return;
      setState(() {
        off = {for (final e in o.entries) if (e.value == true) '${e.key}': true};
        quiet = q['on'] == true;
        from = q['from'] == null ? 23 : asInt(q['from']);
        to = q['to'] == null ? 8 : asInt(q['to']);
        if (q['tz'] is String) tz = q['tz'] as String;
        adult = (ageOf(m['birthday']) ?? 0) >= 18;
        loaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => loaded = true);
    }
  }

  Future<void> _save() => attempt(context, () => context.app.api.updateMe({
        'notif': {
          'off': off,
          'quiet': {'on': quiet, 'from': from, 'to': to, 'tz': tz},
        },
      }));

  String _h(int h) => '${h.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    final c = context.pc, push = context.app.push;
    if (!loaded) return Scaffold(appBar: peeraBar(context, title: 'შეტყობინებები'), body: const Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: peeraBar(context, title: 'შეტყობინებები'),
      body: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
        if (push != null)
          SGroup(title: 'ტელეფონზე', children: [
            ValueListenableBuilder<bool?>(
              valueListenable: push.enabled,
              builder: (context, on, _) => SRow(
                icon: 'bell',
                color: on == false ? c.nope : c.vine,
                title: on == false ? 'ტელეფონში გამორთულია' : 'შეტყობინებები ჩართულია',
                sub: 'მოწონებები, კომენტარები, მესიჯები, როცა აპი დახურულია',
                trailing: TextButton(onPressed: push.openSettings, child: Text(on == false ? 'ჩართვა' : 'ტელეფონში')),
              ),
            ),
          ]),
        SGroup(title: 'ღამის საათები', children: [
          SSwitch(
            key: const ValueKey('quiet'),
            icon: 'clock',
            title: 'არ შემაწუხო',
            sub: 'ამ საათებში ტელეფონზე შეტყობინება არ მოვა. სიაში მაინც შეგროვდება და დილით ნახავ',
            value: quiet,
            onChanged: (v) {
              setState(() => quiet = v);
              _save();
            },
          ),
          if (quiet)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  for (final (label, isFrom) in const [('დან', true), ('მდე', false)]) ...[
                    if (!isFrom) const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('quiet-${isFrom ? 'from' : 'to'}'),
                        initialValue: isFrom ? from : to,
                        icon: const _Down(),
                        decoration: InputDecoration(labelText: label),
                        items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text(_h(h)))],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => isFrom ? from = v : to = v);
                          _save();
                        },
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 8),
                Text(from == to ? 'დასაწყისი და დასასრული ერთნაირია, ამიტომ არაფერი ჩუმდება.' : 'ყოველდღე ${_h(from)}-დან ${_h(to)}-მდე შეტყობინებები ჩუმადაა.',
                    style: TextStyle(color: c.muted, fontSize: 13)),
              ]),
            ),
        ]),
        SGroup(title: 'რა შეტყობინებები მივიღო', children: [
          for (final k in notifKinds)
            if (k.$1 != 'dating' || adult)
              SSwitch(
                key: ValueKey('ncat-${k.$1}'),
                icon: k.$2,
                title: k.$3,
                sub: k.$4,
                value: off[k.$1] != true,
                onChanged: (v) {
                  setState(() => v ? off.remove(k.$1) : off[k.$1] = true);
                  _save();
                },
              ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text('გამორთული ტიპის შეტყობინება აღარ მოვა: არც სიაში, არც ტელეფონზე. სისტემური შეტყობინებები (ვერიფიკაცია, რეკლამა, დახმარების პასუხები) ყოველთვის მოდის.',
              style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4)),
        ),
      ]),
    );
  }
}

// ---------- privacy ----------

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});
  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  Map<String, dynamic> priv = {};
  List<String> blocked = [];
  bool loaded = false, minor = false;
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
      final (m, b) = await (app.api.mySettings(), app.api.blocked()).wait;
      await app.people.ensure(b);
      if (!mounted) return;
      setState(() {
        priv = m['privacy'] is Map ? Map<String, dynamic>.from(m['privacy'] as Map) : {};
        blocked = b;
        final a = ageOf(m['birthday']);
        minor = a != null && a < 18;
        loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => loaded = true);
    }
  }

  Future<void> _set(String k, Object v) async {
    setState(() => priv = {...priv, k: v});
    final app = context.app;
    // the invisible-guest switch decides how my visits count, so my own copy is fetched again
    if (await attempt(context, () => app.api.updateMe({'privacy': priv})) && k == 'guest') app.refreshMe?.call();
  }

  Future<void> _unblock(String uid) async {
    final ok = await attempt(context, () => context.app.api.unblock(uid));
    if (ok && mounted) {
      setState(() => blocked = [...blocked]..remove(uid));
      toast(context, 'განიბლოკა');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, people = context.app.people;
    if (!loaded) return Scaffold(appBar: peeraBar(context, title: 'კონფიდენციალურობა'), body: const Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: peeraBar(context, title: 'კონფიდენციალურობა'),
      body: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
        if (minor)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Note(
              '18 წლამდე ხარ, ამიტომ დაცვა ჩართულია: უცნობ ზრდასრულებს არ შეუძლიათ მოგწერონ, მეგობრობა გთხოვონ, საჩუქარი გამოგიგზავნონ ან ძებნაში გიპოვონ. შენთან კავშირი აქვთ მეგობრებს, ოჯახის წევრებს და კლასელებს ან კურსელებს.',
              ok: true,
            ),
          ),
        SGroup(title: 'ვინ რას ხედავს', children: [
          SSwitch(
            key: const ValueKey('priv-online'),
            title: 'ონლაინ სტატუსი',
            sub: 'სხვები ხედავენ, როცა ონლაინ ხარ',
            value: priv['online'] != false,
            onChanged: (v) {
              _set('online', v);
              toast(context, v ? 'ონლაინ სტატუსი ჩანს' : 'ონლაინ სტატუსი დამალულია');
            },
          ),
          SSwitch(
            key: const ValueKey('priv-read'),
            title: '„ნანახია“ და „წერს…“',
            sub: 'გამორთვისას სხვები ვერ ნახავენ, რომ წაიკითხე ან წერ. შენც ვერ დაინახავ მათსას',
            value: priv['read'] != false,
            onChanged: (v) => _set('read', v),
          ),
          SSwitch(
            key: const ValueKey('priv-guest'),
            title: 'უხილავი სტუმარი',
            sub: 'სხვის პროფილს ისე ნახავ, რომ მის სტუმრებში არ გამოჩნდე',
            value: priv['guest'] == true,
            onChanged: (v) => _set('guest', v),
          ),
        ]),
        SGroup(title: 'ვინ დამიკავშირდეს', children: [
          SChoice<String>(id: 'priv-dm', title: 'ვინ მომწეროს', options: const [('all', 'ყველამ'), ('friends', 'მეგობრებმა')], value: '${priv['dm'] ?? 'all'}', onChanged: (v) => _set('dm', v)),
          SChoice<String>(
            id: 'priv-chal',
            title: 'ვინ გამომიწვიოს თამაშში',
            options: const [('all', 'ყველამ'), ('friends', 'მეგობრებმა'), ('none', 'არავინ')],
            value: '${priv['chal'] ?? 'all'}',
            onChanged: (v) => _set('chal', v),
          ),
        ]),
        SGroup(title: 'დაბლოკილები', children: [
          if (blocked.isEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Text('დაბლოკილი არავინ გყავს.', style: TextStyle(color: c.muted)))
          else
            for (final id in blocked)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(children: [
                  Avatar(p: people[id] ?? Profile(id: id, name: '…'), size: 36),
                  const SizedBox(width: 12),
                  Expanded(child: Text(people[id]?.fullName ?? '…', style: const TextStyle(fontWeight: FontWeight.w700))),
                  TextButton(key: ValueKey('unblock-$id'), onPressed: () => _unblock(id), child: const Text('განბლოკვა')),
                ]),
              ),
        ]),
      ]),
    );
  }
}

// ---------- the look ----------

class LookScreen extends StatelessWidget {
  const LookScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: peeraBar(context, title: 'ეკრანი'),
        body: ListenableBuilder(
          listenable: Listenable.merge([themeChoice, textZoom]),
          builder: (context, _) => ListView(padding: const EdgeInsets.only(bottom: 28), children: [
            SGroup(title: 'ფერები', children: [
              SChoice<ThemeMode>(
                id: 'look-theme',
                title: 'თემა',
                options: const [(ThemeMode.system, 'როგორც ტელეფონში'), (ThemeMode.light, 'ღია'), (ThemeMode.dark, 'მუქი')],
                value: themeChoice.value,
                onChanged: setTheme,
              ),
            ]),
            SGroup(title: 'კითხვა', children: [
              SChoice<double>(
                id: 'look-zoom',
                title: 'ტექსტის ზომა',
                options: const [(1.0, 'ჩვეულებრივი'), (1.1, 'დიდი'), (1.2, 'უფრო დიდი')],
                value: textZoom.value,
                onChanged: setZoom,
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text('ეს მხოლოდ ამ ტელეფონზე ინახება.', style: TextStyle(color: context.pc.muted, fontSize: 13)),
            ),
          ]),
        ),
      );
}

// ---------- the rules ----------

class TextScreen extends StatelessWidget {
  const TextScreen({super.key, required this.title, required this.sections});
  final String title;
  final List<(String, String)> sections;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      appBar: peeraBar(context, title: title),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
        for (final s in sections) ...[
          Text(s.$1, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(s.$2, style: TextStyle(fontSize: 15, height: 1.5, color: c.ink)),
          const SizedBox(height: 18),
        ],
      ]),
    );
  }
}

/// the little arrow of a drop-down list, in the app's own icons
class _Down extends StatelessWidget {
  const _Down();
  @override
  Widget build(BuildContext context) => Transform.rotate(angle: 1.5708, child: PIcon('chev', size: 18, color: context.pc.muted));
}
