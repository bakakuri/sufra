// Backgammon's page (opened from the games tab): the game going on, a new one against one of the four computer
// players, and the rules.
import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../ui/icons.dart';
import '../ui/look.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'character.dart';
import 'engine.dart';
import 'nardi_screen.dart';
import 'session.dart';
import 'table_model.dart';

/// my character: the look I chose on the site, else one in my colour
CharacterLook myLook(BuildContext context) {
  final me = context.me;
  final shirt = HSLColor.fromAHSL(1, (me.hue % 360).toDouble(), .55, .45).toColor().toARGB32();
  return CharacterLook.fromJson(me.look, shirt: shirt);
}

class NardiTab extends StatefulWidget {
  const NardiTab({super.key});
  @override
  State<NardiTab> createState() => _NardiTabState();
}

class _NardiTabState extends State<NardiTab> {
  NardiSession? _s;
  NardiSession get s => _s!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_s != null) return;
    final api = context.app.api;
    _s = NardiSession(onOver: (won) async => won ? (await api.gameResult('nardi', true)).reward : 0, myName: context.me.name, myLook: myLook(context))..load();
  }

  @override
  void dispose() {
    _s?.dispose();
    super.dispose();
  }

  Future<void> _play({bool fresh = false}) async {
    if (fresh || !s.playing) s.start();
    await openNardi(context, s);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final still = MediaQuery.disableAnimationsOf(context) || ecoMode.value;
    return Scaffold(
      appBar: peeraBar(context, title: 'ნარდი'),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 32), children: [
          if (s.playing)
            PCard(
              key: const ValueKey('nd-current'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(children: [
                CharacterView(look: s.bot.look, mood: Mood.idle, size: 64, still: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('მიმდინარე თამაში', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Text('${s.bot.name} · ${s.g!.turn == 0 ? 'შენი სვლაა' : 'მისი სვლაა'} · ${s.g!.board.pips(0)}:${s.g!.board.pips(1)} პიპი', style: TextStyle(color: c.muted, fontSize: 13)),
                  ]),
                ),
                FilledButton(key: const ValueKey('nd-continue'), onPressed: () => _play(), child: const Text('გაგრძელება')),
              ]),
            ),
          if (s.playing) const SizedBox(height: 16),
          Text(s.playing ? 'ახალი თამაში' : 'ვისთან ითამაშებ?', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('ოთხი მოთამაშე, სუსტიდან ძლიერამდე. აირჩიე და დაიწყე.', style: TextStyle(color: c.muted, fontSize: 13.5)),
          const SizedBox(height: 10),
          for (final b in bots) ...[
            Pressable(
              key: ValueKey('nd-bot-${b.level}'),
              onTap: () => s.setLevel(b.level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: s.level == b.level ? c.accent : c.line, width: s.level == b.level ? 1.8 : 1),
                ),
                child: Row(children: [
                  CharacterView(look: b.look, mood: s.level == b.level ? Mood.happy : Mood.idle, size: 66, still: still || s.level != b.level),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(b.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
                        const SizedBox(width: 8),
                        Row(children: [for (var i = 0; i < 4; i++) PIcon('star', size: 12, color: i < b.level ? const Color(0xFFF5B300) : c.line)]),
                      ]),
                      const SizedBox(height: 2),
                      Text(b.about, style: TextStyle(color: c.muted, fontSize: 12.5)),
                    ]),
                  ),
                  if (s.level == b.level) PIcon('check', size: 20, color: c.accent),
                ]),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          FilledButton.icon(
            key: const ValueKey('nd-start'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () => _play(fresh: true),
            icon: const PIcon('dice', size: 20, color: Colors.white),
            label: Text(s.playing ? 'ახალი თამაში ${s.bot.name}-თან' : 'თამაშის დაწყება', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          const SizedBox(height: 16),
          PCard(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const ValueKey('nd-rules'),
                shape: const Border(),
                leading: PIcon('dice', size: 22, color: c.accent),
                title: const Text('წესები', style: TextStyle(fontWeight: FontWeight.w700)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [Text(nardiRules.trim(), style: TextStyle(color: c.muted, fontSize: 14, height: 1.5))],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
