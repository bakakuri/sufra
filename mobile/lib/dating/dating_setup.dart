// The dating card: who I am, whom I look for, a few words, up to six interests (js/dating.js datingSetup).
// The first time it turns dating on; later it saves changes, or turns dating off.
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class DatingSetup extends StatefulWidget {
  const DatingSetup({super.key, required this.me, this.edit = false, this.onSaved});
  final DatingMe me;

  /// changing a card that is on (a screen of its own) rather than turning dating on in the tab
  final bool edit;
  final ValueChanged<DatingMe>? onSaved;

  @override
  State<DatingSetup> createState() => _DatingSetupState();
}

class _DatingSetupState extends State<DatingSetup> {
  late String? gender = widget.me.gender;
  late String seeking = widget.me.seeking;
  late final Set<String> picked = {...widget.me.interests};
  late final bio = TextEditingController(text: widget.me.bio);
  bool busy = false;

  bool get dirty =>
      gender != widget.me.gender ||
      seeking != widget.me.seeking ||
      bio.text.trim() != widget.me.bio.trim() ||
      picked.length != widget.me.interests.length ||
      !picked.containsAll(widget.me.interests);

  @override
  void dispose() {
    bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (gender == null) {
      toast(context, 'აირჩიე, ვინ ხარ');
      return;
    }
    final d = widget.me.copyWith(on: true, gender: gender, seeking: seeking, bio: bio.text.trim(), interests: picked.toList());
    setState(() => busy = true);
    final ok = await attempt(context, () => context.app.api.saveDating(d));
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    toast(context, 'გაცნობის პროფილი შენახულია');
    widget.onSaved?.call(d);
    if (widget.edit) Navigator.of(context).pop(d);
  }

  Future<void> _off() async {
    if (!await confirm(context, title: 'გაცნობა გამოვრთოთ?', text: 'შენი ბარათი აღარავის გამოუჩნდება. წყვილები და მიმოწერა დარჩება.', yes: 'გამორთვა', danger: true)) {
      return;
    }
    if (!mounted) return;
    final ok = await attempt(context, () => context.app.api.datingOff());
    if (ok && mounted) Navigator.of(context).pop(widget.me.copyWith(on: false));
  }

  Widget _choice<T>(String group, List<(T, String)> items, T? value, ValueChanged<T> on) {
    final c = context.pc;
    return Row(children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: Material(
            color: value == items[i].$1 ? c.ink : c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: value == items[i].$1 ? c.ink : c.line)),
            child: InkWell(
              key: ValueKey('$group-${items[i].$1}'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => on(items[i].$1)),
              child: SizedBox(
                height: 46,
                child: Center(
                  child: Text(items[i].$2, style: TextStyle(color: value == items[i].$1 ? c.bg : c.ink, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final form = ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
      if (!widget.edit) ...[
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF5F7E), Color(0xFF8B5CF6)]),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('გაიცანი ახალი ადამიანები', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('გაცნობის პროფილი მხოლოდ 18+ მომხმარებლებს უჩანთ, ვინც თავადაც ჩართო გაცნობა. ნებისმიერ დროს შეგიძლია გამორთვა.',
                style: TextStyle(color: Color(0xF2FFFFFF), fontSize: 14, height: 1.45)),
          ]),
        ),
      ],
      _label('მე ვარ'),
      _choice<String>('gender', const [('f', 'ქალი'), ('m', 'კაცი'), ('x', 'სხვა')], gender, (v) => gender = v),
      _label('ვეძებ'),
      _choice<String>('seeking', const [('f', 'ქალს'), ('m', 'კაცს'), ('all', 'ყველას')], seeking, (v) => seeking = v),
      _label('ჩემ შესახებ'),
      TextField(
        key: const ValueKey('dating-bio'),
        controller: bio,
        maxLength: 300,
        minLines: 3,
        maxLines: 6,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: 'რა გიყვარს, რას ეძებ'),
      ),
      Row(children: [
        Expanded(child: _label('ინტერესები')),
        Padding(padding: const EdgeInsets.only(top: 10), child: Text('${picked.length}/6', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700))),
      ]),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final x in datingInterests)
          FilterChip(
            key: ValueKey('interest-$x'),
            label: Text(x),
            selected: picked.contains(x),
            showCheckmark: false,
            onSelected: (on) => setState(() {
              if (!on) {
                picked.remove(x);
              } else if (picked.length < 6) {
                picked.add(x);
              } else {
                toast(context, 'მაქსიმუმ 6 ინტერესი');
              }
            }),
            labelStyle: TextStyle(fontWeight: FontWeight.w700, color: picked.contains(x) ? c.onAccent : c.ink),
            selectedColor: c.accent,
            backgroundColor: c.sunk,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
      ]),
      if (!widget.me.photo) ...[
        const SizedBox(height: 16),
        const Note('რჩევა: დაამატე პროფილის ფოტო, ბარათზე ის გამოჩნდება.', ok: true),
      ],
      const SizedBox(height: 22),
      FilledButton(
        key: const ValueKey('dating-save'),
        onPressed: busy ? null : _save,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        child: Text(widget.edit ? 'შენახვა' : 'გაცნობის ჩართვა'),
      ),
      if (widget.edit) ...[
        const SizedBox(height: 10),
        OutlinedButton(
          key: const ValueKey('dating-off'),
          onPressed: busy ? null : _off,
          style: OutlinedButton.styleFrom(foregroundColor: c.nope, side: BorderSide(color: c.nope.withValues(alpha: .5)), minimumSize: const Size.fromHeight(48)),
          child: const Text('გაცნობის გამორთვა'),
        ),
      ],
    ]);
    if (!widget.edit) return form;
    // changes not saved are asked about before they are thrown away
    return PopScope(
      canPop: !dirty || busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await confirm(context, title: 'ცვლილებები არ შეინახება', text: 'გავიდე შენახვის გარეშე?', yes: 'გასვლა', danger: true)) nav.pop();
      },
      child: Scaffold(appBar: peeraBar(context, title: 'გაცნობის პროფილი'), body: form),
    );
  }
}
