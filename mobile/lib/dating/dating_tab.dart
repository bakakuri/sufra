// Dating (გაცნობა), as on the site (js/dating.js): adults only and opt-in. Cards to swipe (right: I like, left: no,
// the star: a super like for 5 coins), how many like me, and the pairs, each one tap from a conversation.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../profile/profile.dart';
import '../shell/tab_bar.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'dating_setup.dart';

const _likeCol = Color(0xFF2FBF80), _superCol = Color(0xFF3E8EF7), _nopeCol = Color(0xFFF0506E);
const superCost = 5;

class DatingTab extends StatefulWidget {
  const DatingTab({super.key});
  @override
  State<DatingTab> createState() => _DatingTabState();
}

class _DatingTabState extends State<DatingTab> {
  DatingMe? me;
  Object? error;
  int seg = 0, likes = 0;
  List<DatingCard>? deck;
  List<String>? pairs;
  bool _likesFirst = false, _started = false;
  AppState? _app;

  static final _index = tabs.indexWhere((t) => t.id == 'date');

  /// nothing is asked of the server until the tab is first opened
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_app != null) return;
    _app = context.app..tab.addListener(_opened);
    _opened();
  }

  void _opened() {
    if (_started || _app?.tab.value != _index) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    _app?.tab.removeListener(_opened);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final m = await context.app.api.datingMe();
      if (!mounted) return;
      setState(() {
        me = m;
        error = null;
      });
      if (m.adult && m.on) {
        _count();
        if (seg == 0) _deck();
        if (seg == 2) _pairs();
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _count() async {
    try {
      final n = await context.app.api.likesMeCount();
      if (mounted) setState(() => likes = n);
    } catch (_) {}
  }

  Future<void> _deck() async {
    setState(() => deck = null);
    try {
      final d = await context.app.api.datingFeed();
      if (_likesFirst) {
        // stable: the ones who like me first, the rest as they came
        final a = [for (final x in d) if (x.likedMe) x], b = [for (final x in d) if (!x.likedMe) x];
        d
          ..clear()
          ..addAll([...a, ...b]);
        _likesFirst = false;
      }
      if (mounted) setState(() => deck = d);
    } catch (e) {
      if (mounted) {
        setState(() => deck = const []);
        toast(context, errText(e));
      }
    }
  }

  Future<void> _pairs() async {
    try {
      final ids = await context.app.api.matches();
      if (!mounted) return;
      await context.app.people.ensure(ids);
      if (mounted) setState(() => pairs = ids);
    } catch (e) {
      if (mounted) setState(() => pairs = const []);
    }
  }

  void _seg(int i) {
    if (i == seg) return;
    setState(() => seg = i);
    if (i == 0 && deck == null) _deck();
    if (i == 1) _count();
    if (i == 2) _pairs();
  }

  Future<void> _settings() async {
    final m = me;
    if (m == null) return;
    final r = await openPage<DatingMe>(context, DatingSetup(me: m, edit: true));
    if (r == null || !mounted) return;
    setState(() => me = r);
    if (r.on) {
      _deck();
    } else {
      setState(() {
        deck = null;
        pairs = null;
        seg = 0;
      });
    }
  }

  /// the top card has left: [kind] 'like', 'nope' or 'super'; a pair is shown at once
  Future<void> _swiped(DatingCard p, String kind) async {
    setState(() => deck = [...?deck]..remove(p));
    try {
      final paired = await context.app.api.swipe(p.id, kind);
      if (!mounted) return;
      if (kind == 'super') toast(context, 'სუპერ მოწონება გაიგზავნა · −$superCost მონეტა');
      if (paired) await _pairSheet(p);
    } catch (e) {
      if (!mounted) return;
      // not sent (no coins, no connection): the card comes back on top
      setState(() => deck = [p, ...?deck]);
      toast(context, errText(e));
    }
  }

  Future<void> _pairSheet(DatingCard p) async {
    final go = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(child: _PairSheet(me: context.me, p: p)),
    );
    if (go == true && mounted) await _chat(p.id);
  }

  Future<void> _chat(String uid) async {
    final app = context.app;
    try {
      final conv = await app.api.startDm(uid);
      if (mounted) await openChat(context, conv);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = me;
    final on = m != null && m.adult && m.on;
    return Scaffold(
      appBar: peeraBar(context, title: 'გაცნობა', actions: [
        if (on) IconBtn('gear', label: 'გაცნობის პროფილი', onTap: _settings),
      ]),
      body: _body(),
    );
  }

  Widget _body() {
    final m = me;
    if (m == null) {
      if (!_started) return const SizedBox.shrink();
      return error != null
          ? Center(child: Empty(icon: 'heart', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'თავიდან', onAction: _load))
          : const Center(child: CircularProgressIndicator());
    }
    if (!m.adult) {
      return const Center(
        child: Empty(icon: 'heart', title: 'გაცნობა მხოლოდ 18+ მომხმარებლებისთვისაა', text: 'ეს ნაწილი შენთვის დახურულია. Peera-ს სხვა ფუნქციები ჩვეულებრივ მუშაობს.'),
      );
    }
    if (!m.on) {
      return DatingSetup(
        me: m,
        onSaved: (d) {
          setState(() => me = d);
          _count();
          _deck();
        },
      );
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Row(children: [
          for (final (i, t) in const [(0, 'სვაიპი'), (1, 'მოსწონხარ'), (2, 'წყვილები')].indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _SegBtn(key: ValueKey('dseg-${t.$1}'), text: t.$2, n: t.$1 == 1 ? likes : 0, on: seg == t.$1, onTap: () => _seg(t.$1))),
          ],
        ]),
      ),
      Expanded(
        child: switch (seg) {
          0 => _swipe(),
          1 => _likesView(),
          _ => _pairsView(),
        },
      ),
    ]);
  }

  Widget _swipe() {
    final d = deck;
    if (d == null) return const Center(child: CircularProgressIndicator());
    if (d.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Empty(
            icon: 'heart',
            title: 'ახლა ახალი ადამიანები აღარ არის',
            text: 'მოგვიანებით შემოიხედე. რაც მეტი ადამიანი ჩართავს გაცნობას, მით მეტ ბარათს ნახავ.',
            action: 'განახლება',
            onAction: _deck,
          ),
        ),
      );
    }
    return _Deck(
      key: ValueKey('deck-${d.first.id}'),
      cards: d.take(3).toList(),
      canSwipe: (p, kind) {
        if (kind == 'super' && context.me.coins < superCost) {
          toast(context, 'სუპერ მოწონებას $superCost მონეტა სჭირდება');
          return false;
        }
        return true;
      },
      onGone: _swiped,
    );
  }

  Widget _likesView() {
    final c = context.pc;
    return RefreshIndicator(
      onRefresh: _count,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 24, 16, 32), children: [
        if (likes == 0)
          const Empty(icon: 'heart', title: 'ახალი მოწონებები ჯერ არ არის', text: 'გააგრძელე სვაიპი, ხშირად შემოიხედე.')
        else
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: c.line)),
            child: Column(children: [
              Stack(alignment: Alignment.center, children: [
                Container(width: 84, height: 84, decoration: BoxDecoration(shape: BoxShape.circle, color: _likeCol.withValues(alpha: .14))),
                const PIcon('heartfill', size: 40, color: _likeCol),
              ]),
              const SizedBox(height: 14),
              Text('$likes ადამიანს მოსწონხარ', key: const ValueKey('likes-n'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('ვინაობას გაიგებ, როცა მათ ბარათს მოიწონებ და წყვილი გახდებით.',
                  textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 14.5, height: 1.4)),
              const SizedBox(height: 18),
              FilledButton(
                key: const ValueKey('likes-first'),
                onPressed: () {
                  _likesFirst = true;
                  setState(() => seg = 0);
                  _deck();
                },
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('ჯერ ისინი მაჩვენე'),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _pairsView() {
    final ids = pairs;
    if (ids == null) return const Center(child: CircularProgressIndicator());
    if (ids.isEmpty) {
      return RefreshIndicator(
        onRefresh: _pairs,
        child: ListView(children: const [Empty(icon: 'heart', title: 'წყვილები ჯერ არ გაქვს', text: 'როცა ორივე მოიწონებთ ერთმანეთს, აქ გამოჩნდება.')]),
      );
    }
    final people = context.app.people;
    return RefreshIndicator(
      onRefresh: _pairs,
      child: ListenableBuilder(
        listenable: people,
        builder: (context, _) => GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .74),
          itemCount: ids.length,
          itemBuilder: (context, i) {
            final p = people[ids[i]];
            return _PairTile(key: ValueKey('pair-${ids[i]}'), id: ids[i], p: p, onTap: () => _chat(ids[i]));
          },
        ),
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  const _SegBtn({super.key, required this.text, required this.n, required this.on, required this.onTap});
  final String text;
  final int n;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? c.ink : c.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: on ? c.ink : c.line)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(text, style: TextStyle(color: on ? c.bg : c.ink, fontWeight: FontWeight.w700, fontSize: 14)),
              if (n > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: c.nope, borderRadius: BorderRadius.circular(10)),
                  child: Text(grouped(n), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// The cards in a pile: the top one follows the finger and flies off to a side (or up, for a super like);
/// the buttons under it do the same. [canSwipe] answers false when the move cannot be made (the card comes back);
/// [onGone] is told once the card is off the screen.
class _Deck extends StatefulWidget {
  const _Deck({super.key, required this.cards, required this.canSwipe, required this.onGone});
  final List<DatingCard> cards;
  final bool Function(DatingCard p, String kind) canSwipe;
  final void Function(DatingCard p, String kind) onGone;
  @override
  State<_Deck> createState() => _DeckState();
}

class _DeckState extends State<_Deck> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  Offset _drag = Offset.zero, _from = Offset.zero, _to = Offset.zero;
  String? _going;

  Offset get _pos => _a.isAnimating || _going != null ? Offset.lerp(_from, _to, Curves.easeOut.transform(_a.value))! : _drag;

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  Future<void> _fly(String kind, Size box) async {
    if (_going != null || widget.cards.isEmpty) return;
    final p = widget.cards.first;
    if (!widget.canSwipe(p, kind)) {
      _back();
      return;
    }
    setState(() => _going = kind);
    _from = _drag;
    _to = kind == 'super' ? Offset(_drag.dx, -box.height * 1.3) : Offset((kind == 'like' ? 1 : -1) * box.width * 1.5, _drag.dy + 40);
    await _a.forward(from: 0);
    if (mounted) widget.onGone(p, kind);
  }

  void _back() {
    _from = _drag;
    _to = Offset.zero;
    _drag = Offset.zero;
    _a.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      return Column(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: AnimatedBuilder(
              animation: _a,
              builder: (context, _) {
                final pos = _pos, t = math.max(-1.0, math.min(1.0, pos.dx / 110)), lift = math.min(1.0, pos.distance / 120);
                return Stack(clipBehavior: Clip.none, children: [
                  // the ones underneath, a little smaller
                  for (var i = math.min(cards.length, 3) - 1; i >= 1; i--)
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(0, 10.0 * i - (i == 1 ? 10 * lift : 0)),
                        child: Transform.scale(scale: 1 - .04 * i + (i == 1 ? .04 * lift : 0), child: _CardView(p: cards[i])),
                      ),
                    ),
                  Positioned.fill(
                    child: GestureDetector(
                      key: ValueKey('dcard-${cards.first.id}'),
                      onPanUpdate: _going != null ? null : (d) => setState(() => _drag += Offset(d.delta.dx, d.delta.dy * .4)),
                      onPanEnd: _going != null
                          ? null
                          : (d) {
                              final v = d.velocity.pixelsPerSecond.dx;
                              if (_drag.dx.abs() > 110 || (v.abs() > 900 && _drag.dx.abs() > 50 && v.sign == _drag.dx.sign)) {
                                _fly((_drag.dx + v / 10) > 0 ? 'like' : 'nope', size);
                              } else {
                                _back();
                              }
                            },
                      child: Transform.translate(
                        offset: pos,
                        child: Transform.rotate(
                          angle: pos.dx / 18 * math.pi / 180,
                          child: _CardView(p: cards.first, like: math.max(0.0, t), nope: math.max(0.0, -t), sup: _going == 'super' ? 1 : 0),
                        ),
                      ),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _RoundBtn(key: const ValueKey('date-nope'), icon: 'x', color: _nopeCol, size: 62, label: 'გამოტოვება', onTap: () => _fly('nope', size)),
            const SizedBox(width: 18),
            _RoundBtn(key: const ValueKey('date-super'), icon: 'star', color: _superCol, size: 50, label: 'სუპერ მოწონება, $superCost მონეტა', onTap: () => _fly('super', size)),
            const SizedBox(width: 18),
            _RoundBtn(key: const ValueKey('date-like'), icon: 'heartfill', color: _likeCol, size: 62, label: 'მოწონება', onTap: () => _fly('like', size)),
          ]),
        ),
      ]);
    });
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({super.key, required this.icon, required this.color, required this.size, required this.label, required this.onTap});
  final String icon, label;
  final Color color;
  final double size;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Tooltip(
      message: label,
      child: Material(
        color: c.surface,
        shape: CircleBorder(side: BorderSide(color: color.withValues(alpha: .35), width: 1.5)),
        elevation: 3,
        shadowColor: color.withValues(alpha: .4),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(dimension: size, child: Center(child: PIcon(icon, size: size * .44, color: color, stroke: 2.4))),
        ),
      ),
    );
  }
}

/// One card: the photo (or the colour of the name with its letter), and over its lower part the name, age, city,
/// a few words and the interests. While dragged, a stamp says which way it goes.
class _CardView extends StatelessWidget {
  const _CardView({required this.p, this.like = 0, this.nope = 0, this.sup = 0});
  final DatingCard p;
  final double like, nope, sup;

  Widget _stamp(String text, Color col, double angle, double o) => Opacity(
        opacity: math.min(1.0, math.max(0.0, o)),
        child: Transform.rotate(
          angle: angle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: col, width: 3.5), borderRadius: BorderRadius.circular(10), color: Colors.black.withValues(alpha: .12)),
            child: Text(text, style: TextStyle(color: col, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final h = (p.hue % 360).toDouble();
    final letter = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HSLColor.fromAHSL(1, h, .7, .6).toColor(), HSLColor.fromAHSL(1, (h + 40) % 360, .62, .36).toColor()],
        ),
      ),
      alignment: const Alignment(0, -.25),
      child: Text(p.name.trim().isEmpty ? '?' : p.name.trim().characters.first, style: const TextStyle(color: Colors.white, fontSize: 120, fontWeight: FontWeight.w800)),
    );
    final url = p.avatarUrl;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        if (url == null || url.isEmpty)
          letter
        else
          Image(image: netImage(url), fit: BoxFit.cover, errorBuilder: (_, __, ___) => letter, frameBuilder: (_, child, f, sync) => sync || f != null ? child : letter),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [.45, 1], colors: [Color(0x00000000), Color(0xE0000000)]),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 18,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Flexible(
                child: Text(p.first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1)),
              ),
              if (p.age > 0) ...[
                const SizedBox(width: 8),
                Text('${p.age}', style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 24, fontWeight: FontWeight.w500, height: 1.15)),
              ],
              if (p.verified) const Padding(padding: EdgeInsets.only(bottom: 5), child: Verified(size: 18)),
            ]),
            if (p.city != null && p.city!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const PIcon('pin', size: 16, color: Color(0xE6FFFFFF)),
                const SizedBox(width: 4),
                Text(p.city!, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 14.5, fontWeight: FontWeight.w600)),
              ]),
            ],
            if (p.bio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(p.bio, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
            ],
            if (p.interests.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final x in p.interests)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)),
                    child: Text(x, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ],
          ]),
        ),
        Positioned(top: 28, left: 22, child: _stamp('მომწონს', _likeCol, -.26, like)),
        Positioned(top: 28, right: 22, child: _stamp('არა', _nopeCol, .26, nope)),
        if (sup > 0) Positioned(top: 28, left: 0, right: 0, child: Center(child: _stamp('სუპერ!', _superCol, 0, sup))),
      ]),
    );
  }
}

/// We like each other: both faces, and the first step.
class _PairSheet extends StatelessWidget {
  const _PairSheet({required this.me, required this.p});
  final Profile me;
  final DatingCard p;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('ორმხრივი სიმპათია', style: TextStyle(color: c.accent, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: .4)),
        const SizedBox(height: 4),
        const Text('წყვილი ხართ!', key: ValueKey('pair-title'), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        SizedBox(
          height: 104,
          width: 196,
          child: Stack(children: [
            Positioned(left: 0, child: _ring(Avatar(p: me, size: 96), c)),
            Positioned(right: 0, child: _ring(Avatar(p: p.profile, size: 96), c)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.line)),
                  child: const Center(child: PIcon('heartfill', size: 20, color: _nopeCol)),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Text('შენ და ${p.first} ერთმანეთი მოიწონეთ. პირველი ნაბიჯი შენზეა.', textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 15, height: 1.4)),
        const SizedBox(height: 20),
        FilledButton(
          key: const ValueKey('pair-chat'),
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: const Text('მიწერა'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('სვაიპის გაგრძელება')),
      ]),
    );
  }

  Widget _ring(Widget child, PeeraColors c) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
        child: child,
      );
}

class _PairTile extends StatelessWidget {
  const _PairTile({super.key, required this.id, required this.p, required this.onTap});
  final String id;
  final Profile? p;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final name = (p?.name ?? '').trim().split(' ').first;
    final url = p?.avatarUrl;
    final hue = (p?.hue ?? 200) % 360;
    final online = p?.online == true;
    final letter = Container(
      color: HSLColor.fromAHSL(1, hue.toDouble(), .6, .5).toColor(),
      alignment: Alignment.center,
      child: Text(name.isEmpty ? '?' : name.characters.first, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
    );
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(fit: StackFit.expand, children: [
          if (url == null || url.isEmpty) letter else Image(image: netImage(url), fit: BoxFit.cover, errorBuilder: (_, __, ___) => letter),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [.5, 1], colors: [Color(0x00000000), Color(0xC0000000)]),
            ),
          ),
          if (online)
            Positioned(
              top: 8,
              right: 8,
              child: Container(width: 12, height: 12, decoration: BoxDecoration(color: _likeCol, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
            ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              const Text('მიწერა', style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}
