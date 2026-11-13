// My CV (jobs.js PG.cv): headline, about me, work and study rows, skills and languages, a phone, and whether everyone
// sees it on my profile. Leaving with unsaved changes asks first.
import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const _expHints = ['პოზიცია', 'კომპანია', 'პერიოდი, მაგ. 2021–2024'];
const _eduHints = ['სასწავლებელი', 'სპეციალობა', 'წლები'];

class _Row {
  _Row([Map? m]) : ctl = [for (final k in const ['a', 'b', 'c']) TextEditingController(text: '${m?[k] ?? ''}')];
  final List<TextEditingController> ctl;
  Map<String, String> get value => {'a': ctl[0].text.trim(), 'b': ctl[1].text.trim(), 'c': ctl[2].text.trim()};
  bool get empty => ctl[0].text.trim().isEmpty && ctl[1].text.trim().isEmpty;
  void dispose() {
    for (final c in ctl) {
      c.dispose();
    }
  }
}

class CvEditScreen extends StatefulWidget {
  const CvEditScreen({super.key});
  @override
  State<CvEditScreen> createState() => _CvEditScreenState();
}

class _CvEditScreenState extends State<CvEditScreen> {
  final head = TextEditingController(), sum = TextEditingController(), skills = TextEditingController(), langs = TextEditingController(), phone = TextEditingController();
  final exp = <_Row>[], edu = <_Row>[];
  bool visible = false, loaded = false, busy = false, dirty = false, _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    for (final c in [head, sum, skills, langs, phone]) {
      c.dispose();
    }
    for (final r in [...exp, ...edu]) {
      r.dispose();
    }
    super.dispose();
  }

  List<String> _list(Object? v) => v is List ? [for (final x in v) if ('$x'.trim().isNotEmpty) '$x'] : const [];

  Future<void> _load() async {
    final app = context.app;
    Map<String, dynamic>? cv;
    try {
      cv = await app.api.cv(app.api.myId);
    } catch (_) {}
    if (!mounted) return;
    head.text = '${cv?['headline'] ?? ''}';
    sum.text = '${cv?['summary'] ?? ''}';
    skills.text = _list(cv?['skills']).join(', ');
    langs.text = cv == null ? 'ქართული' : _list(cv['languages']).join(', ');
    phone.text = '${cv?['phone'] ?? ''}';
    visible = cv?['visible'] == true;
    for (final (k, list) in [('experience', exp), ('education', edu)]) {
      final v = cv?[k];
      final rows = v is List ? [for (final x in v) if (x is Map) _Row(x)] : <_Row>[];
      list.addAll(rows.isEmpty ? [_Row()] : rows);
    }
    for (final c in [head, sum, skills, langs, phone, for (final r in [...exp, ...edu]) ...r.ctl]) {
      c.addListener(_touch);
    }
    setState(() => loaded = true);
  }

  void _touch() {
    if (!dirty) setState(() => dirty = true);
  }

  void _addRow(List<_Row> list) {
    final r = _Row();
    for (final c in r.ctl) {
      c.addListener(_touch);
    }
    setState(() {
      list.add(r);
      dirty = true;
    });
  }

  void _removeRow(List<_Row> list, _Row r) {
    setState(() {
      list.remove(r);
      dirty = true;
    });
    r.dispose();
  }

  List<String> _split(String v, int max) => v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).take(max).toList();

  Future<void> _save() async {
    if (busy) return;
    setState(() => busy = true);
    final ok = await attempt(
      context,
      () => context.app.api.saveCv({
        'headline': head.text.trim(),
        'summary': sum.text.trim(),
        'experience': [for (final r in exp) if (!r.empty) r.value].take(15).toList(),
        'education': [for (final r in edu) if (!r.empty) r.value].take(15).toList(),
        'skills': _split(skills.text, 30),
        'languages': _split(langs.text, 30),
        'phone': phone.text.trim(),
        'visible': visible,
      }),
    );
    if (!mounted) return;
    setState(() {
      busy = false;
      if (ok) dirty = false;
    });
    if (ok) {
      toast(context, 'CV შენახულია');
      Navigator.of(context).pop(true);
    }
  }

  Widget _rows(String title, String kind, List<_Row> list, List<String> hints) {
    final c = context.pc;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      const SizedBox(height: 8),
      for (final (i, r) in list.indexed)
        Container(
          key: ValueKey('cv-$kind-$i'),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(14)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(children: [
                for (var k = 0; k < 3; k++)
                  TextField(
                    controller: r.ctl[k],
                    maxLength: k == 2 ? 40 : 120,
                    style: TextStyle(fontWeight: k == 0 ? FontWeight.w700 : FontWeight.w400),
                    decoration: InputDecoration(hintText: hints[k], counterText: '', isDense: true, border: InputBorder.none, filled: false),
                  ),
              ]),
            ),
            IconBtn('x', label: 'წაშლა', size: 20, onTap: () => _removeRow(list, r)),
          ]),
        ),
      if (list.length < 15)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: ValueKey('cv-add-$kind'),
            onPressed: () => _addRow(list),
            icon: PIcon('plus', size: 18, color: c.accent),
            label: const Text('დამატება'),
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    InputDecoration dec(String label, [String? hint]) => InputDecoration(labelText: label, hintText: hint, counterText: '');
    return PopScope(
      canPop: !dirty || busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await confirm(context, title: 'ცვლილებები არ შეინახება', text: 'გავიდე შენახვის გარეშე?', yes: 'გასვლა', danger: true)) nav.pop();
      },
      child: Scaffold(
        appBar: peeraBar(context, title: 'ჩემი CV', actions: [
          if (loaded)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: TextButton(key: const ValueKey('cv-save'), onPressed: busy ? null : _save, child: const Text('შენახვა', style: TextStyle(fontWeight: FontWeight.w800))),
            ),
        ]),
        body: !loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
                TextField(key: const ValueKey('cv-head'), controller: head, maxLength: 120, decoration: dec('სათაური', 'მაგ. გამოცდილი ბარისტა, Junior დეველოპერი')),
                const SizedBox(height: 12),
                TextField(controller: sum, maxLength: 2000, minLines: 3, maxLines: 8, decoration: dec('ჩემ შესახებ')),
                const SizedBox(height: 18),
                _rows('გამოცდილება', 'experience', exp, _expHints),
                const SizedBox(height: 14),
                _rows('განათლება', 'education', edu, _eduHints),
                const SizedBox(height: 14),
                TextField(controller: skills, maxLength: 400, decoration: dec('უნარები (მძიმით)', 'Excel, მომხმარებელთან ურთიერთობა, React')),
                const SizedBox(height: 12),
                TextField(controller: langs, maxLength: 200, decoration: dec('ენები (მძიმით)')),
                const SizedBox(height: 12),
                TextField(controller: phone, maxLength: 30, keyboardType: TextInputType.phone, decoration: dec('ტელეფონი', '+995 5XX XX XX XX')),
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const ValueKey('cv-visible'),
                  contentPadding: EdgeInsets.zero,
                  value: visible,
                  onChanged: (v) => setState(() {
                    visible = v;
                    dirty = true;
                  }),
                  title: const Text('CV ყველასთვის ჩანდეს პროფილზე', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('გამორთულის შემთხვევაში მხოლოდ დამსაქმებლები ნახავენ, ვისაც გამოეხმაურები.', style: TextStyle(color: c.muted, fontSize: 12.5)),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const ValueKey('cv-ok'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  onPressed: busy ? null : _save,
                  icon: PIcon('check', size: 18, color: c.onAccent),
                  label: Text(busy ? 'ინახება…' : 'შენახვა'),
                ),
              ]),
      ),
    );
  }
}
