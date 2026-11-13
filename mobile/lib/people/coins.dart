// My coins (coins.js PG.coins): the balance, the promotion, the seven-day bonus, today's earnings against the day's
// limit, how each page pays, and the history. Cashing out in lari and the shop stay on the site.
import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'namedays.dart';

/// today as the server counts it (Tbilisi)
String tbilisiToday() => DateTime.now().toUtc().add(const Duration(hours: 4)).toIso8601String().substring(0, 10);

/// whether today's bonus is still waiting for me
bool bonusWaits(String? lastBonus) => lastBonus != tbilisiToday();

/// rule page → name and icon
const _pages = {
  'home': ('ფიდი', 'home'),
  'chat': ('შეტყობინებები', 'msg'),
  'stories': ('ისტორიები', 'story'),
  'clips': ('კლიპები', 'clips'),
  'groups': ('ჯგუფები', 'users'),
  'friends': ('მეგობრები', 'user'),
  'sport': ('სპორტი', 'trophy'),
  'games': ('თამაშები', 'dice'),
  'recipes': ('სამზარეულო', 'note'),
  'help': ('დახმარება', 'heart'),
  'places': ('ადგილები', 'pin'),
  'albums': ('ალბომები', 'image'),
  'events': ('შეხვედრები', 'cal'),
  'toasts': ('სადღეგრძელოები', 'star'),
  'market': ('ბაზრობა', 'coin'),
  'jobs': ('ვაკანსიები', 'work'),
  'rides': ('მგზავრობა', 'pin'),
  'tree': ('ოჯახის ხე', 'tree'),
  'schedule': ('ლექციების ცხრილი', 'school'),
  'exams': ('დავალებები', 'clock'),
  'me': ('პროფილი', 'user'),
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

  @override
  Widget build(BuildContext context) {
    final c = context.pc, m = my;
    if (m == null) {
      return Scaffold(
        appBar: peeraBar(context, title: 'მონეტები'),
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
    final until = DateTime.tryParse('${m['until'] ?? ''}');
    final left = until == null ? 0 : (until.difference(DateTime.now()).inHours / 24).ceil().clamp(0, 9999);
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in rules) {
      if (r['active'] == true && asInt0(r['amount']) > 0 && r['page'] != 'coins') (groups['${r['page']}'] ??= []).add(r);
    }
    String gel(int n) => (n / rate).toStringAsFixed(2);
    Widget section(Widget child, {Color? bg}) => Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: bg ?? c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
          child: child,
        );
    Widget bar(double v) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: v.clamp(0, 1).toDouble(), minHeight: 8, backgroundColor: c.sunk, color: c.gold),
        );
    return Scaffold(
      appBar: peeraBar(context, title: 'მონეტები'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
          section(
            Column(children: [
              Text('შენი ბალანსი', style: TextStyle(color: c.muted, fontSize: 13.5)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                PIcon('coin', size: 28, color: c.gold),
                const SizedBox(width: 8),
                Text(grouped(all), key: const ValueKey('coins-balance'), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
              const SizedBox(height: 2),
              Text('≈ ${gel(all)} ₾ · ${grouped(rate)} მონეტა = 1 ₾', style: TextStyle(color: c.muted, fontSize: 12.5)),
            ]),
            bg: Color.alphaBlend(c.gold.withValues(alpha: .1), c.surface),
          ),
          section(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(promo ? '🎉' : '⏳', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(promo ? 'აქცია მიმდინარეობს' : 'აქცია ახლა არ მიდის', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  promo
                      ? 'ყველა მონეტა ითვლება და ლარად გადის: ${grouped(rate)} მონეტა = 1 ₾.${until != null ? ' ბოლო დღე: ${until.day} ${monthNames[until.month - 1]} (დარჩა $left დღე).' : ''}'
                      : 'მონეტები გროვდება და იხარჯება საჩუქრებზე, მაღაზიაში და სტილებზე. ლარად გატანა აქციის დროს იხსნება.',
                  style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.4),
                ),
              ]),
            ),
          ])),
          section(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              for (var i = 1; i <= 7; i++)
                Expanded(
                  child: Container(
                    height: 40,
                    margin: EdgeInsets.only(right: i < 7 ? 5 : 0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i <= filled ? c.gold : c.sunk,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: i == next ? c.gold : Colors.transparent, width: 2),
                    ),
                    child: FittedBox(
                      child: Text(i == 7 ? '+15' : '+5',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: i <= filled ? const Color(0xFF1A1205) : c.ink)),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            got
                ? OutlinedButton(onPressed: null, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)), child: const Text('დღევანდელი ბონუსი აღებულია'))
                : FilledButton(
                    key: const ValueKey('coins-bonus'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    onPressed: busy ? null : _bonus,
                    child: Text('აიღე დღიური ბონუსი: +${next == 7 ? 15 : 5}'),
                  ),
            const SizedBox(height: 8),
            Text('ყოველდღე +5. მე-7 დღეს ზედიზედ დამატებით +10.', textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12.5)),
          ])),
          section(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('დღეს გამოიმუშავე ${grouped(today)} / ${grouped(max)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text(today >= max ? 'დღის ლიმიტი შევსებულია. ხვალ ისევ.' : 'ყველა აქტივობა ერთად, ბონუსის გარდა', style: TextStyle(color: c.muted, fontSize: 13)),
            const SizedBox(height: 10),
            bar(today / max),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(16, 22, 16, 4), child: Text('როგორ გამოიმუშავო', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('თითქმის ყველა გვერდზე. წაშლილი ან დამალული პოსტის, კომენტარის და სხვა მონეტები 24 საათში უკან ბრუნდება.', style: TextStyle(color: c.muted, fontSize: 13, height: 1.4)),
          ),
          for (final (i, e) in groups.entries.indexed)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
              child: Material(
                type: MaterialType.transparency,
                child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey('crgrp-${e.key}'),
                  initiallyExpanded: i < 2,
                  leading: PIcon((_pages[e.key] ?? (e.key, 'coin')).$2, size: 20, color: c.accent),
                  title: Text((_pages[e.key] ?? (e.key, 'coin')).$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: Builder(builder: (context) {
                    final earned = e.value.fold<int>(0, (a, r) => a + asInt0(by[r['action']]));
                    final cap = e.value.fold<int>(0, (a, r) => a + (r['once'] == true ? (done.contains(r['action']) ? 0 : asInt0(r['amount'])) : (asInt0(r['day_cap']) > 0 ? asInt0(r['day_cap']) : asInt0(r['amount']))));
                    return Text(earned > 0 ? '+$earned დღეს' : (cap > 0 ? '+$cap-მდე' : ''), style: TextStyle(color: earned > 0 ? c.vine : c.muted, fontSize: 12.5, fontWeight: FontWeight.w700));
                  }),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  children: [
                    for (final r in e.value)
                      Builder(builder: (context) {
                        final earned = asInt0(by[r['action']]), cap = asInt0(r['day_cap']);
                        final isDone = r['once'] == true ? done.contains(r['action']) : cap > 0 && earned >= cap;
                        return Opacity(
                          opacity: isDone ? .55 : 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${r['label'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  if ('${r['hint'] ?? ''}'.isNotEmpty) Text('${r['hint']}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                                ]),
                              ),
                              const SizedBox(width: 8),
                              if (r['once'] == true)
                                isDone ? PIcon('check', size: 16, color: c.vine) : Text('ერთხელ', style: TextStyle(color: c.muted, fontSize: 12))
                              else if (cap > 0)
                                isDone ? PIcon('check', size: 16, color: c.vine) : Text('$earned/$cap', style: TextStyle(color: c.muted, fontSize: 12)),
                              const SizedBox(width: 10),
                              Text('+${asInt0(r['amount'])}', style: TextStyle(color: c.gold, fontWeight: FontWeight.w800)),
                            ]),
                          ),
                        );
                      }),
                  ],
                ),
              )),
            ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('ისტორია', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          if (log.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('ჯერ ცარიელია.', style: TextStyle(color: c.muted)))
          else
            for (final r in log)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Row(children: [
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: '${r['label'] ?? ''}'),
                      if (asInt0(r['n']) > 1) TextSpan(text: ' ×${asInt0(r['n'])}', style: TextStyle(color: c.muted, fontSize: 12)),
                      TextSpan(text: '  ${ago(DateTime.tryParse('${r['created_at']}')?.toLocal() ?? DateTime.now())}', style: TextStyle(color: c.muted, fontSize: 12)),
                    ])),
                  ),
                  Text('${asInt0(r['amount']) > 0 ? '+' : ''}${grouped(asInt0(r['amount']))}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: asInt0(r['amount']) > 0 ? c.vine : c.nope)),
                ]),
              ),
        ]),
      ),
    );
  }
}
