// My coins (coins.js PG.coins): the balance with today's earnings against the day's limit, the seven-day bonus, then
// two parts: how to earn (by kind, today's quick ones first, every page as a card that opens its ways to earn) and the
// history. The rules (the promotion, the limit, what comes back) are a button at the top. Cashing out in lari and the
// shop stay on the site.
import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../home/services.dart';
import '../settings/edit_profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'namedays.dart';

/// today as the server counts it (Tbilisi)
String tbilisiToday() => DateTime.now().toUtc().add(const Duration(hours: 4)).toIso8601String().substring(0, 10);

/// whether today's bonus is still waiting for me
bool bonusWaits(String? lastBonus) => lastBonus != tbilisiToday();

/// a rule's page: its name, icon, colour and a line about it (pages not here are not shown)
const _pages = <String, (String, String, int, String)>{
  'friends': ('მეგობრები', 'users', 0xFF7C5CF0, 'მოიწვიე მეგობრები ან დაიმეგობრე ახლები'),
  'home': ('ფიდი', 'home', 0xFF16A37F, 'წერე, დააკომენტარე და შეაფასე'),
  'me': ('პროფილი', 'ucheck', 0xFF6366F1, 'შეავსე პროფილი სრულად და მიიღე ბონუსი'),
  'sport': ('სპორტი', 'trophy', 0xFFE0A100, 'მიიღე მონაწილეობა სპორტულ პროგნოზებში'),
  'games': ('თამაშები', 'dice', 0xFF10B981, 'მოიგე ბოტებთან ან ონლაინ'),
  'places': ('ადგილები', 'pin', 0xFF16A37F, 'დაამატე და შეაფასე ადგილები'),
  'clips': ('კლიპები', 'clips', 0xFFE5484D, 'ატვირთე კლიპები'),
  'chat': ('შეტყობინებები', 'msg', 0xFF3B82F6, 'იყავი აქტიური მიმოწერაში'),
  'groups': ('ჯგუფები', 'users', 0xFF8B5CF6, 'გაწევრიანდი ჯგუფებში და წერე'),
  'stories': ('ისტორიები', 'story', 0xFFDB2777, 'გააზიარე ყოველდღიური ისტორიები'),
  'jobs': ('ვაკანსიები', 'work', 0xFF0EA5E9, 'გამოაქვეყნე ან გაეცანი ვაკანსიებს'),
  'rides': ('მგზავრობა', 'send', 0xFF14B8A6, 'დაგეგმე საერთო მგზავრობა'),
  'events': ('შეხვედრები', 'cal', 0xFFA855F7, 'შექმენი შეხვედრა ან შეუერთდი'),
  'help': ('დახმარება', 'heart', 0xFFE11D48, 'დაეხმარე სხვებს'),
  'schedule': ('ლექციების ცხრილი', 'school', 0xFF6366F1, 'შეავსე შენი ლექციების ცხრილი'),
  'tree': ('ოჯახის ხე', 'tree', 0xFF059669, 'შეავსე შენი ოჯახის ხე'),
  'albums': ('ალბომები', 'image', 0xFF06B6D4, 'დაამატე ფოტოები ალბომებში'),
  'market': ('ბაზრობა', 'store', 0xFFF59E0B, 'განათავსე განცხადება ბაზრობაზე'),
  'exams': ('დავალებები', 'clock', 0xFF6366F1, 'შეასრულე დავალებები'),
};

/// the kinds the cards are sorted into
const _kinds = <(String, String, Set<String>?)>[
  ('all', 'ყველა', null),
  ('study', 'პროფილი და სწავლა', {'me', 'schedule', 'exams', 'tree'}),
  ('social', 'სოციალური', {'home', 'friends', 'chat', 'groups', 'stories', 'events', 'help'}),
  ('fun', 'გართობა', {'clips', 'games', 'sport', 'albums', 'places'}),
  ('other', 'სხვა', {'market', 'jobs', 'rides'}),
];

/// a way to earn: its own icon, and the word on its button
const _acts = <String, (String, String?)>{
  'verified': ('shield', 'გავლა'),
  'profile_photo': ('camera', 'ატვირთვა'),
  'profile_bio': ('note', 'შევსება'),
  'post': ('edit', null),
  'comment': ('comment', null),
  'react': ('heart', null),
  'grade': ('star', null),
  'got_grade': ('star', null),
  'poll_vote': ('poll', null),
  'invite': ('uadd', 'მოწვევა'),
  'friend': ('users', null),
  'game_win': ('trophy', null),
  'bot_win': ('dice', null),
  'predict': ('trophy', null),
  'predict_win': ('check', null),
  'fx_chat': ('msg', null),
  'place': ('pin', null),
  'place_review': ('star', null),
  'clip': ('clips', null),
  'msg': ('msg', null),
  'group_post': ('edit', null),
  'group_join': ('users', null),
  'story': ('story', null),
  'story_react': ('heart', null),
  'job': ('work', null),
  'job_apply': ('send', null),
  'help_offer': ('help', null),
  'ride': ('route', null),
  'ride_book': ('check', null),
  'event': ('cal', null),
  'rsvp': ('check', null),
  'kin': ('tree', null),
  'lessons': ('school', null),
  'album_photo': ('image', null),
  'listing': ('store', null),
  'task_done': ('check', null),
};

class CoinsScreen extends StatefulWidget {
  const CoinsScreen({super.key});
  @override
  State<CoinsScreen> createState() => _CoinsScreenState();
}

class _CoinsScreenState extends State<CoinsScreen> {
  Map<String, dynamic>? my;
  List<Map<String, dynamic>> rules = const [], log = const [];
  Object? error;
  bool busy = false, _started = false;

  /// 0 how to earn, 1 the history
  int part = 0;
  String kind = 'all';

  /// the page whose ways to earn are open
  String? open;
  final _openKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final api = context.app.api;
    try {
      final m = await api.myCoins();
      final r = await api.coinRules();
      final l = await api.coinLog().catchError((_) => <Map<String, dynamic>>[]);
      if (!mounted) return;
      setState(() {
        my = m;
        rules = r;
        log = l;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _bonus() async {
    if (busy) return;
    setState(() => busy = true);
    final app = context.app;
    try {
      final b = await app.api.dailyBonus();
      if (!mounted) return;
      toast(context, '+${asInt0(b['got'])} მონეტა${asInt0(b['streak']) == 7 ? ' · 7 დღე ზედიზედ!' : ''}');
      await app.refreshMe?.call();
      await _load();
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  static int asInt0(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  /// a page's card opened (its ways to earn shown above the cards), or closed again
  void _pick(String page) {
    setState(() => open = open == page ? null : page);
    if (open == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _openKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic, alignment: .05);
    });
  }

  /// where a page's coins are earned
  Future<void> _go(String page, {String? action}) async {
    final app = context.app;
    switch (action) {
      case 'verified':
        return openService(context, 'verify');
      case 'profile_photo':
      case 'profile_bio':
        await openPage(context, const EditProfileScreen(), full: true);
        return;
    }
    switch (page) {
      case 'home':
      case 'stories':
        app.goHome?.call();
      case 'friends':
        app.goTab?.call('friends');
      case 'chat':
        app.goTab?.call('chats');
      case 'clips':
        app.goTab?.call('clips');
      case 'games':
        app.goTab?.call('joker');
      case 'me':
        app.goTab?.call('me');
      default:
        await openService(context, page);
    }
  }

  void _sheet(String title, List<Widget> body) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (s) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              ...body,
            ]),
          ),
        ),
      );

  Widget _line(String icon, Color color, String title, String text) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Tile(icon: icon, color: color, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text(text, style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.4)),
          ]),
        ),
      ]),
    );
  }

  void _rules(Map<String, dynamic> m) {
    final rate = asInt0(m['rate']) > 0 ? asInt0(m['rate']) : 10000, max = asInt0(m['daily_max']) > 0 ? asInt0(m['daily_max']) : 150;
    final promo = m['promo'] == true, until = DateTime.tryParse('${m['until'] ?? ''}');
    final left = until == null ? 0 : (until.difference(DateTime.now()).inHours / 24).ceil().clamp(0, 9999);
    _sheet('წესები', [
      _line(
        'gift',
        const Color(0xFFE0A100),
        promo ? 'აქცია მიმდინარეობს 🎉' : 'აქცია ახლა არ მიდის',
        promo
            ? 'ყველა მონეტა ითვლება და ლარად გადის: ${grouped(rate)} მონეტა = 1 ₾.${until != null ? ' ბოლო დღე: ${until.day} ${monthNames[until.month - 1]} (დარჩა $left დღე).' : ''}'
            : 'მონეტები გროვდება და იხარჯება საჩუქრებზე და „5+“-ზე. ლარად გატანა აქციის დროს იხსნება.',
      ),
      _line('flame', const Color(0xFFF08C00), 'დღიური ბონუსი', 'ყოველდღე +5. მე-7 დღეს ზედიზედ +15. ერთი დღე თუ გამოტოვე, თავიდან იწყება.'),
      _line('bolt', const Color(0xFF6366F1), 'დღის ლიმიტი: ${grouped(max)}', 'ყველა აქტივობა ერთად, დღიური ბონუსის გარდა. ზოგ გვერდს თავისი დღის ზღვარიც აქვს.'),
      _line('rotate', const Color(0xFFE5484D), 'რა ბრუნდება უკან', 'წაშლილი ან დამალული პოსტის, კომენტარის და სხვა მონეტები 24 საათში უკან ბრუნდება.'),
    ]);
  }

  void _uses(Map<String, dynamic> m) {
    final plus = asInt0(m['plus_cost']);
    _sheet('სად გამოვიყენო', [
      _line('gift', const Color(0xFFE0A100), 'საჩუქრები', 'აჩუქე მეგობარს საჩუქარი პოსტზე ან პროფილზე: გამოჩნდება და მას მონეტებს მოუტანს.'),
      _line('star', const Color(0xFF7C5CF0), '„5+“', 'მეგობრის ფოტოს „5+“ დაუწერე${plus > 0 ? ': ${grouped(plus)} მონეტა' : ''}.'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, m = my;
    Widget rulesBtn() => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Material(
            color: c.sunk,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: const ValueKey('coins-rules'),
              borderRadius: BorderRadius.circular(12),
              onTap: m == null ? null : () => _rules(m),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  PIcon('info', size: 18, color: c.muted),
                  const SizedBox(width: 6),
                  Text('წესები', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
              ),
            ),
          ),
        );
    if (m == null) {
      return Scaffold(
        appBar: peeraBar(context, title: 'მონეტები', actions: [rulesBtn()]),
        body: error != null
            ? Center(child: Empty(icon: 'coin', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'თავიდან', onAction: _load))
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final all = asInt0(m['coins']), rate = asInt0(m['rate']) > 0 ? asInt0(m['rate']) : 10000;
    final by = m['by'] is Map ? m['by'] as Map : const {}, done = {for (final x in (m['done'] is List ? m['done'] as List : const [])) '$x'};
    final max = asInt0(m['daily_max']) > 0 ? asInt0(m['daily_max']) : 150, today = asInt0(m['today']);
    final promo = m['promo'] == true;
    // the seven days of the bonus: taken today, carried on from yesterday, or starting again
    final day = '${m['day'] ?? tbilisiToday()}';
    final dayAt = DateTime.tryParse('${day}T12:00:00Z') ?? DateTime.now();
    final yest = dayAt.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    final got = m['last_bonus'] == day, cont = m['last_bonus'] == yest, streak = asInt0(m['streak']);
    final filled = got ? streak : (cont ? streak % 7 : 0), next = got ? 0 : filled + 1;
    final shownDay = ((got ? filled : next) - 1) % 7 + 1;

    // the pages that pay, the richest first (a page the app no longer has is left out)
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in rules) {
      final p = '${r['page']}';
      if (r['active'] == true && asInt0(r['amount']) > 0 && _pages.containsKey(p)) (groups[p] ??= []).add(r);
    }
    int capOf(Map<String, dynamic> r) => r['once'] == true ? asInt0(r['amount']) : (asInt0(r['day_cap']) > 0 ? asInt0(r['day_cap']) : asInt0(r['amount']));
    int earnedIn(String p) => (groups[p] ?? const []).fold<int>(0, (a, r) => a + asInt0(by[r['action']]));
    int capIn(String p) => (groups[p] ?? const []).fold<int>(0, (a, r) => a + (r['once'] == true && done.contains(r['action']) ? 0 : capOf(r)));
    final pages = groups.keys.toList()..sort((a, b) => capIn(b).compareTo(capIn(a)));
    final top = pages.isEmpty ? null : pages.first;
    final kindSet = _kinds.firstWhere((k) => k.$1 == kind).$3;
    final shown = [for (final p in pages) if (kindSet == null || kindSet.contains(p)) p];
    // today: the pages that already paid, and one quick daily way still open
    final paid = [for (final p in pages) if (earnedIn(p) > 0) p];
    Map<String, dynamic>? quick;
    for (final p in pages.reversed) {
      if (earnedIn(p) > 0 || p == 'friends') continue;
      for (final r in groups[p]!) {
        if (r['once'] != true && asInt0(r['day_cap']) > 0) {
          quick = r;
          break;
        }
      }
      if (quick != null) break;
    }

    return Scaffold(
      appBar: peeraBar(context, title: 'მონეტები', actions: [rulesBtn()]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: [
          // ---------- the balance and today ----------
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.alphaBlend(c.gold.withValues(alpha: .2), c.surface), Color.alphaBlend(c.gold.withValues(alpha: .07), c.surface)],
              ),
              border: Border.all(color: c.gold.withValues(alpha: .35)),
              boxShadow: [BoxShadow(color: c.gold.withValues(alpha: .12), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('შენი ბალანსი', style: TextStyle(color: c.muted, fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(children: [
                      const _CoinBadge(size: 40),
                      const SizedBox(width: 10),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(grouped(all),
                              key: const ValueKey('coins-balance'),
                              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, height: 1.1, fontFeatures: [FontFeature.tabularFigures()])),
                        ),
                      ),
                    ]),
                    if (promo) ...[
                      const SizedBox(height: 4),
                      Text('≈ ${(all / rate).toStringAsFixed(2)} ₾', style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ),
                const SizedBox(width: 10),
                Material(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    key: const ValueKey('coins-use'),
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _uses(m),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: c.gold.withValues(alpha: .4))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          PIcon('gift', size: 17, color: const Color(0xFFD97706)),
                          const SizedBox(width: 6),
                          const Text('გამოყენება', style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w800, fontSize: 14)),
                        ]),
                        const SizedBox(height: 1),
                        Text('საჩუქრები • 5+', style: TextStyle(color: c.muted, fontSize: 12)),
                      ]),
                    ),
                  ),
                ),
              ]),
              Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, color: c.gold.withValues(alpha: .35))),
              Row(children: [
                const PIcon('bolt', size: 18, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                const Expanded(child: Text('დღეს გამოიმუშავე', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.line)),
                  child: Text('${grouped(today)} / ${grouped(max)}', key: const ValueKey('coins-today'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                ),
              ]),
              const SizedBox(height: 10),
              _Bar(v: max == 0 ? 0 : today / max),
              const SizedBox(height: 8),
              Text(today >= max ? 'დღის ლიმიტი შევსებულია. ხვალ ისევ.' : 'ყველა აქტივობა ერთად, დღიური ბონუსის გარდა', style: TextStyle(color: c.muted, fontSize: 12.5)),
            ]),
          ),
          const SizedBox(height: 14),

          // ---------- the daily bonus ----------
          _Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const _Tile(icon: 'flame', color: Color(0xFFF08C00), size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('დღიური ბონუსი', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    Text('ყოველდღე +5 • მე-7 დღეს +15', style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(c.gold.withValues(alpha: .12), c.surface),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.gold.withValues(alpha: .5)),
                  ),
                  child: Text('დღე $shownDay / 7', style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                for (var i = 1; i <= 7; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 7 ? 5 : 0),
                      child: _Day(n: i, on: i <= filled, next: i == next, last: i == 7),
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              got
                  ? Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.vine, width: 1.8)),
                          child: PIcon('check', size: 13, color: c.vine, stroke: 2.4),
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: Text('დღევანდელი ბონუსი აღებულია', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700))),
                      ]),
                    )
                  : FilledButton(
                      key: const ValueKey('coins-bonus'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: const Color(0xFFE0A100),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: busy ? null : _bonus,
                      child: Text('აიღე დღიური ბონუსი: +${next == 7 ? 15 : 5}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
            ]),
          ),
          const SizedBox(height: 16),

          // ---------- how to earn | the history ----------
          _Parts(on: part, count: pages.length, onPick: (i) => setState(() => part = i)),
          const SizedBox(height: 14),
          if (part == 0) ...[
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _kinds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final k = _kinds[i], on = k.$1 == kind;
                  return Material(
                    color: on ? c.ink : c.surface,
                    shape: StadiumBorder(side: BorderSide(color: on ? c.ink : c.line)),
                    child: InkWell(
                      key: ValueKey('coins-kind-${k.$1}'),
                      customBorder: const StadiumBorder(),
                      onTap: () => setState(() => kind = k.$1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(child: Text(k.$2, style: TextStyle(color: on ? c.surface : c.ink, fontWeight: FontWeight.w700, fontSize: 14))),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (kind == 'all' && (quick != null || paid.isNotEmpty)) ...[
              const SizedBox(height: 14),
              _Card(
                key: const ValueKey('coins-today-box'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Expanded(child: Text('დღეს აქტიური', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: c.vine.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
                      child: Text('სწრაფი მონეტები', style: TextStyle(color: c.vine, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ),
                  ]),
                  if (quick != null) ...[
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final r = quick!, p = '${r['page']}', pg = _pages[p]!;
                      final cap = asInt0(r['day_cap']), earned = asInt0(by[r['action']]);
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: ValueKey('coins-quick-$p'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _go(p, action: '${r['action']}'),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
                            child: Row(children: [
                              _Tile(icon: pg.$2, color: Color(pg.$3), size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Flexible(child: Text(pg.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: c.line)),
                                      child: Text('$earned/$cap', style: TextStyle(color: c.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
                                    ),
                                  ]),
                                  const SizedBox(height: 2),
                                  Text('${r['label']} (+${asInt0(r['amount'])} თითოზე)', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5)),
                                ]),
                              ),
                              const SizedBox(width: 8),
                              _Amount('+$cap-მდე'),
                              PIcon('chev', size: 18, color: c.muted),
                            ]),
                          ),
                        ),
                      );
                    }),
                  ],
                  if (paid.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      for (final p in paid)
                        Builder(builder: (context) {
                          return SizedBox(
                            width: (MediaQuery.sizeOf(context).width - 32 - 32 - 10) / 2,
                            child: Material(
                              color: c.vine.withValues(alpha: .07),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                key: ValueKey('coins-paid-$p'),
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _pick(p),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: c.vine.withValues(alpha: .35))),
                                  child: Row(children: [
                                    _Tile(icon: _pages[p]!.$2, color: c.vine, size: 38),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(_pages[p]!.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                        Text('+${earnedIn(p)} დღეს', style: TextStyle(color: c.vine, fontWeight: FontWeight.w700, fontSize: 12.5)),
                                      ]),
                                    ),
                                    PIcon('chev', size: 16, color: c.vine),
                                  ]),
                                ),
                              ),
                            ),
                          );
                        }),
                    ]),
                  ],
                ]),
              ),
            ],
            if (open != null && groups[open] != null) ...[
              const SizedBox(height: 14),
              KeyedSubtree(key: _openKey, child: _openCard(open!, groups[open]!, by, done, capIn(open!))),
            ],
            const SizedBox(height: 18),
            Row(children: [
              const Expanded(child: Text('ყველა კატეგორია', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5))),
              Text('დააჭირე დეტალებისთვის', style: TextStyle(color: c.muted, fontSize: 12.5)),
            ]),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 142),
              itemCount: shown.length,
              itemBuilder: (_, i) {
                final p = shown[i], pg = _pages[p]!, earned = earnedIn(p), cap = capIn(p);
                return _PageCard(
                  key: ValueKey('crgrp-$p'),
                  name: pg.$1,
                  line: pg.$4,
                  icon: pg.$2,
                  color: Color(pg.$3),
                  amount: earned > 0 ? '+$earned დღეს' : (cap > 0 ? '+$cap-მდე' : '✓'),
                  green: earned > 0,
                  top: p == top,
                  on: p == open,
                  onTap: () => _pick(p),
                );
              },
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(16)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                PIcon('rotate', size: 18, color: c.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('თითქმის ყველა გვერდზე. წაშლილი ან დამალული პოსტის, კომენტარის და სხვა მონეტები 24 საათში უკან ბრუნდება.',
                      style: TextStyle(color: c.muted, fontSize: 13, height: 1.4)),
                ),
              ]),
            ),
          ] else ...[
            if (log.isEmpty)
              Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('ჯერ ცარიელია.', style: TextStyle(color: c.muted))))
            else
              for (final (i, r) in log.indexed) _logRow(i, r),
          ],
        ]),
      ),
    );
  }

  /// a page's ways to earn, open above the cards
  Widget _openCard(String p, List<Map<String, dynamic>> rs, Map by, Set<String> done, int cap) {
    final c = context.pc, pg = _pages[p]!, once = rs.every((r) => r['once'] == true);
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          key: ValueKey('coins-open-$p'),
          onTap: () => _pick(p),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(children: [
              _Tile(icon: pg.$2, color: Color(pg.$3), size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(pg.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(8)),
                      child: Text(once ? 'ერთჯერადი' : 'ყოველდღიური', style: TextStyle(color: c.accent, fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(pg.$4, style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.3)),
                ]),
              ),
              const SizedBox(width: 6),
              if (cap > 0) _Amount('+$cap-მდე'),
              PIcon('up', size: 18, color: c.muted),
            ]),
          ),
        ),
        Divider(height: 1, color: c.line),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 12, 8),
          child: Column(children: [
            for (final r in rs)
              Builder(builder: (context) {
                final a = '${r['action']}', act = _acts[a];
                final earned = asInt0(by[a]), dayCap = asInt0(r['day_cap']), amount = asInt0(r['amount']);
                final isDone = r['once'] == true ? done.contains(a) : dayCap > 0 && earned >= dayCap;
                final sub = r['once'] == true
                    ? 'ერთხელ'
                    : [if (dayCap > 0) 'დღეში $dayCap-მდე', if (earned > 0) 'დღეს +$earned', if ('${r['hint'] ?? ''}'.isNotEmpty) '${r['hint']}'].join(' · ');
                return Padding(
                  key: ValueKey('coins-rule-$a'),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Opacity(
                    opacity: isDone ? .6 : 1,
                    child: Row(children: [
                      _Tile(icon: act?.$1 ?? pg.$2, color: Color(pg.$3), size: 38),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${r['label'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                          if (sub.isNotEmpty) Text(sub, style: TextStyle(color: c.muted, fontSize: 12.5)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Text('+$amount', style: const TextStyle(color: Color(0xFFE0A100), fontWeight: FontWeight.w900, fontSize: 15)),
                      const SizedBox(width: 8),
                      if (isDone)
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: c.vine.withValues(alpha: .12), shape: BoxShape.circle),
                          child: PIcon('check', size: 16, color: c.vine, stroke: 2.4),
                        )
                      else
                        Material(
                          color: c.accentSoft,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            key: ValueKey('coins-go-$a'),
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _go(p, action: a),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              child: Text(act?.$2 ?? 'გადასვლა', style: TextStyle(color: c.accent, fontWeight: FontWeight.w800, fontSize: 13)),
                            ),
                          ),
                        ),
                    ]),
                  ),
                );
              }),
          ]),
        ),
      ]),
    );
  }

  Widget _logRow(int i, Map<String, dynamic> r) {
    final c = context.pc, n = asInt0(r['amount']), plus = n > 0;
    return Container(
      key: ValueKey('coins-log-$i'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: (plus ? c.vine : c.nope).withValues(alpha: .12), shape: BoxShape.circle),
          child: PIcon(plus ? 'up' : 'down', size: 18, color: plus ? c.vine : c.nope, stroke: 2.2),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: '${r['label'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
              if (asInt0(r['n']) > 1) TextSpan(text: ' ×${asInt0(r['n'])}', style: TextStyle(color: c.muted, fontSize: 12.5)),
            ])),
            Text(ago(DateTime.tryParse('${r['created_at']}')?.toLocal() ?? DateTime.now()), style: TextStyle(color: c.muted, fontSize: 12)),
          ]),
        ),
        Text('${plus ? '+' : ''}${grouped(n)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: plus ? c.vine : c.nope)),
      ]),
    );
  }
}

/// A white card with the page's line round it.
class _Card extends StatelessWidget {
  const _Card({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.line),
        boxShadow: [BoxShadow(color: const Color(0xFF141830).withValues(alpha: .04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

/// An icon on a soft square of its own colour.
class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.color, this.size = 44});
  final String icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(size * .3)),
        child: PIcon(icon, size: size * .5, color: color),
      );
}

/// the round gold coin
class _CoinBadge extends StatelessWidget {
  const _CoinBadge({this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(center: Alignment(-.3, -.4), colors: [Color(0xFFFFD36B), Color(0xFFE59A07)]),
          border: Border.all(color: const Color(0xFFF7C04A), width: 2),
          boxShadow: const [BoxShadow(color: Color(0x40B45309), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: PIcon('coin', size: size * .58, color: Colors.white, stroke: 2.1),
      );
}

/// the thin gold bar of today's earnings
class _Bar extends StatelessWidget {
  const _Bar({required this.v});
  final double v;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Container(
      height: 8,
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: c.gold.withValues(alpha: .3))),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: v.clamp(0, 1).toDouble(),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFFB020)])),
        ),
      ),
    );
  }
}

/// One day of the seven.
class _Day extends StatelessWidget {
  const _Day({required this.n, required this.on, required this.next, required this.last});
  final int n;
  final bool on, next, last;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final ink = on ? Colors.white : (last ? const Color(0xFFB45309) : c.muted);
    return Container(
      key: ValueKey('coins-day-$n'),
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: on ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF5B300), Color(0xFFE08A00)]) : null,
        color: on ? null : (last ? Color.alphaBlend(c.gold.withValues(alpha: .1), c.surface) : c.sunk),
        border: Border.all(color: next ? const Color(0xFFF5B300) : (last && !on ? c.gold.withValues(alpha: .6) : c.line), width: next ? 2 : 1),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('დღე $n', style: TextStyle(color: ink.withValues(alpha: on ? .9 : 1), fontSize: 11.5, fontWeight: FontWeight.w600)),
            Text(last ? '+15' : '+5', style: TextStyle(color: on ? Colors.white : (last ? const Color(0xFFB45309) : c.ink), fontSize: 16, fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    );
  }
}

/// "+N-მდე" in gold
class _Amount extends StatelessWidget {
  const _Amount(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.gold.withValues(alpha: .14), c.surface),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.gold.withValues(alpha: .45)),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}

/// The switch between how to earn and the history.
class _Parts extends StatelessWidget {
  const _Parts({required this.on, required this.count, required this.onPick});
  final int on, count;
  final ValueChanged<int> onPick;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    Widget part(int i, String icon, String label) {
      final sel = on == i;
      return Expanded(
        child: GestureDetector(
          key: ValueKey('coins-part-$i'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onPick(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 46,
            decoration: BoxDecoration(
              color: sel ? c.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: sel ? [BoxShadow(color: const Color(0xFF141830).withValues(alpha: .1), blurRadius: 8, offset: const Offset(0, 2))] : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  PIcon(icon, size: 19, color: sel ? c.accent : c.muted),
                  const SizedBox(width: 8),
                  Text(label, style: TextStyle(color: sel ? c.ink : c.muted, fontWeight: FontWeight.w800, fontSize: 15)),
                  if (i == 0 && count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(8)),
                      child: Text('$count', style: TextStyle(color: c.accent, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [part(0, 'sparkle', 'გამომუშავება'), part(1, 'history', 'ისტორია')]),
    );
  }
}

/// A page's card: its icon, how much it gives today (or can), its name and a line; the richest one says "ტოპ".
class _PageCard extends StatelessWidget {
  const _PageCard({
    super.key,
    required this.name,
    required this.line,
    required this.icon,
    required this.color,
    required this.amount,
    required this.onTap,
    this.green = false,
    this.top = false,
    this.on = false,
  });
  final String name, line, icon, amount;
  final Color color;
  final VoidCallback onTap;
  final bool green, top, on;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Stack(clipBehavior: Clip.none, children: [
      Positioned.fill(
        child: Material(
          color: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: on ? c.accent : c.line, width: on ? 1.6 : 1)),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Tile(icon: icon, color: color, size: 42),
                  const Spacer(),
                  Flexible(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(color: green ? c.vine.withValues(alpha: .12) : c.sunk, borderRadius: BorderRadius.circular(10)),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(amount, style: TextStyle(color: green ? c.vine : c.ink, fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    ),
                  ),
                ]),
                const Spacer(),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 2),
                Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5)),
              ]),
            ),
          ),
        ),
      ),
      if (top)
        Positioned(
          right: 18,
          top: -9,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.surface, width: 2)),
            child: Text('ტოპ', style: TextStyle(color: c.onAccent, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
        ),
    ]);
  }
}
