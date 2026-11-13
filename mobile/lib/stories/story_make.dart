// Making a story (people.js addstory, storytext, storyCompose): who sees it (everyone or my close friends), a text on a
// colour with a poll if wanted, and the last step where stickers are put on it with a finger: a person, a place, a
// countdown and a question box. The viewer draws the same stickers and the poll (stories.dart).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../media/video_tools.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// the text stories' colours (people.js STG)
const storyGradients = [
  (Color(0xFFA8164A), Color(0xFF5B0B2A)),
  (Color(0xFF2C7A55), Color(0xFF0F3D2A)),
  (Color(0xFFC98A12), Color(0xFF7A4A05)),
  (Color(0xFF3E5BD8), Color(0xFF1B2A70)),
  (Color(0xFF7A3FC2), Color(0xFF341565)),
  (Color(0xFF1D1724), Color(0xFF4A3A56)),
];

/// The picture of a text story: 1080×1920 JPEG, the words in the middle (higher with a poll under them). The tests
/// put in their own.
Future<Uint8List> Function(BuildContext context, String text, int colour, bool withPoll) textStoryImage = makeTextStory;

Future<Uint8List> makeTextStory(BuildContext context, String text, int colour, bool withPoll) async {
  const W = 1080.0, H = 1920.0;
  final font = DefaultTextStyle.of(context).style;
  final g = storyGradients[colour % storyGradients.length];
  final rec = ui.PictureRecorder();
  final cv = Canvas(rec);
  cv.drawRect(const Rect.fromLTWH(0, 0, W, H), Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(W * .4, H), [g.$1, g.$2]));
  final dot = Paint()..color = Colors.white.withValues(alpha: .08);
  for (var i = 0; i < 6; i++) {
    cv.drawCircle(Offset(W * (i.isOdd ? .85 : .12), H * (.15 + i * .15)), 120.0 + i * 30, dot);
  }
  if (text.isNotEmpty) {
    final size = text.length > 120 ? 58.0 : (text.length > 60 ? 70.0 : 88.0);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: font.copyWith(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.3,
          decoration: TextDecoration.none,
          shadows: const [Shadow(color: Color(0x40000000), blurRadius: 18)],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 12,
      ellipsis: '…',
    )..layout(maxWidth: W - 160);
    final top = (withPoll ? H * .3 : H / 2) - tp.height / 2;
    tp.paint(cv, Offset((W - tp.width) / 2, top));
  }
  final im = await rec.endRecording().toImage(W.toInt(), H.toInt());
  final raw = await im.toByteData(format: ui.ImageByteFormat.rawRgba);
  im.dispose();
  return compute(_jpeg, (raw!.buffer.asUint8List(), W.toInt(), H.toInt()));
}

Uint8List _jpeg((Uint8List, int, int) a) =>
    img.encodeJpg(img.Image.fromBytes(width: a.$2, height: a.$3, bytes: a.$1.buffer, numChannels: 4, order: img.ChannelOrder.rgba), quality: 90);

/// A text story: the words on a colour, with a poll of two to four answers if wanted. "შემდეგი" goes to the
/// stickers.
class TextStoryScreen extends StatefulWidget {
  const TextStoryScreen({super.key, this.close = false});
  final bool close;
  @override
  State<TextStoryScreen> createState() => _TextStoryScreenState();
}

class _TextStoryScreenState extends State<TextStoryScreen> {
  final text = TextEditingController();
  final q = TextEditingController();
  final opts = [TextEditingController(text: 'კი'), TextEditingController(text: 'არა')];
  int colour = 0;
  bool poll = false, busy = false;

  @override
  void initState() {
    super.initState();
    text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    text.dispose();
    q.dispose();
    for (final o in opts) {
      o.dispose();
    }
    super.dispose();
  }

  Future<void> _next() async {
    final t = text.text.trim();
    Map<String, dynamic>? p;
    if (poll) {
      final o = [for (final x in opts) if (x.text.trim().isNotEmpty) x.text.trim()];
      if (o.length < 2) {
        toast(context, 'გამოკითხვას მინიმუმ 2 პასუხი სჭირდება');
        return;
      }
      p = {'q': q.text.trim(), 'opts': o};
    }
    if (t.isEmpty && p == null) {
      toast(context, 'დაწერე ტექსტი ან დაამატე გამოკითხვა');
      return;
    }
    setState(() => busy = true);
    try {
      final bytes = await textStoryImage(context, t, colour, p != null);
      if (!mounted) return;
      final done = await openPage<bool>(context, StoryComposeScreen(photo: bytes, poll: p, close: widget.close), full: true);
      if (done == true && mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, g = storyGradients[colour];
    return Scaffold(
      appBar: peeraBar(context, title: 'ტექსტი ან გამოკითხვა', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(
            key: const ValueKey('ts-next'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: busy ? null : _next,
            child: const Text('შემდეგი'),
          ),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AspectRatio(
          aspectRatio: 9 / 12,
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [g.$1, g.$2])),
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(text.text.trim().isEmpty ? (poll ? '' : 'დაწერე რამე…') : text.text.trim(),
                  textAlign: TextAlign.center, maxLines: 8, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              if (poll) ...[
                const SizedBox(height: 16),
                StoryPollBox(q: q.text.trim(), opts: [for (final o in opts) o.text.trim()], preview: true),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < storyGradients.length; i++)
            GestureDetector(
              key: ValueKey('ts-g$i'),
              onTap: () => setState(() => colour = i),
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [storyGradients[i].$1, storyGradients[i].$2]),
                  border: Border.all(color: colour == i ? c.ink : Colors.transparent, width: 2.4),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('ts-text'),
          controller: text,
          maxLength: 300,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'რას დაწერ?', counterText: ''),
        ),
        SwitchListTile(
          key: const ValueKey('ts-poll'),
          contentPadding: EdgeInsets.zero,
          value: poll,
          onChanged: (v) => setState(() => poll = v),
          title: const Text('გამოკითხვის დამატება', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        if (poll) ...[
          TextField(key: const ValueKey('ts-q'), controller: q, maxLength: 80, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'კითხვა (არასავალდებულო)', counterText: '')),
          for (var i = 0; i < opts.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('ts-o$i'),
                    controller: opts[i],
                    maxLength: 30,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(hintText: 'პასუხი ${i + 1}', counterText: ''),
                  ),
                ),
                if (i > 1) IconBtn('x', label: 'წაშლა', size: 18, onTap: () => setState(() => opts.removeAt(i).dispose())),
              ]),
            ),
          if (opts.length < 4)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('ts-add'),
                onPressed: () => setState(() => opts.add(TextEditingController())),
                icon: PIcon('plus', size: 18, color: c.accent),
                label: const Text('პასუხის დამატება'),
              ),
            ),
        ],
      ]),
    );
  }
}

/// What a countdown says now: "3 დღე 4 სთ", "40 წთ", or "დადგა! 🎉".
String countText(DateTime at, [DateTime? now]) {
  final d = at.difference(now ?? DateTime.now());
  if (d.inSeconds <= 0) return 'დადგა! 🎉';
  final m = d.inMinutes, dd = m ~/ 1440, h = m % 1440 ~/ 60, mm = m % 60;
  if (dd > 0) return '$dd დღე${h > 0 ? ' $h სთ' : ''}';
  if (h > 0) return '$h სთ${mm > 0 ? ' $mm წთ' : ''}';
  return '${math.max(1, mm)} წთ';
}

/// One sticker on a story. [edit]: on the composer (a question box says where the answers go); [mine]: my own
/// story (no answer field); [onAnswer]: someone answering a question.
class StorySticker extends StatelessWidget {
  const StorySticker({super.key, required this.x, this.edit = false, this.mine = false, this.onAnswer, this.onPerson, this.onFocus});
  final Map<String, dynamic> x;
  final bool edit, mine;
  final void Function(String answer)? onAnswer;
  final void Function(String uid)? onPerson;
  final void Function(bool on)? onFocus;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    const dark = Color(0xFF1D1420);
    Widget chip(Widget child, {Color bg = Colors.white}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 3))]),
          child: child,
        );
    switch (x['t']) {
      case 'mention':
        final u = '${x['u'] ?? ''}';
        final p = app.people[u];
        return GestureDetector(
          onTap: onPerson == null ? null : () => onPerson!(u),
          child: chip(Row(mainAxisSize: MainAxisSize.min, children: [
            const PIcon('user', size: 16, color: Color(0xFF7A3FC2)),
            const SizedBox(width: 5),
            Text('@${(p?.name ?? '…').split(' ').first}', style: const TextStyle(color: Color(0xFF7A3FC2), fontWeight: FontWeight.w800, fontSize: 15)),
          ])),
        );
      case 'place':
        return chip(Row(mainAxisSize: MainAxisSize.min, children: [
          const PIcon('pin', size: 16, color: Color(0xFFE11D48)),
          const SizedBox(width: 5),
          Flexible(child: Text('${x['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: dark, fontWeight: FontWeight.w800, fontSize: 15))),
        ]));
      case 'count':
        final at = DateTime.tryParse('${x['at'] ?? ''}')?.toLocal();
        return chip(
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${x['title'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(color: dark, fontWeight: FontWeight.w800, fontSize: 14)),
            Text(at == null ? '' : countText(at), style: const TextStyle(color: Color(0xFF3E5BD8), fontWeight: FontWeight.w900, fontSize: 20)),
          ]),
        );
      case 'ask':
        return SizedBox(
          width: 240,
          child: chip(
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${x['q'] ?? 'მკითხე რამე'}', textAlign: TextAlign.center, style: const TextStyle(color: dark, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 6),
              if (edit)
                const Text('პასუხს აქ დაწერენ', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7A6D78), fontSize: 12.5))
              else if (mine)
                const Text('პასუხები ჩატში მოგივა', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7A6D78), fontSize: 12.5))
              else
                _AskField(onAnswer: onAnswer, onFocus: onFocus),
            ]),
          ),
        );
    }
    return const SizedBox.shrink();
  }
}

class _AskField extends StatefulWidget {
  const _AskField({this.onAnswer, this.onFocus});
  final void Function(String answer)? onAnswer;
  final void Function(bool on)? onFocus;
  @override
  State<_AskField> createState() => _AskFieldState();
}

class _AskFieldState extends State<_AskField> {
  final f = TextEditingController();
  final focus = FocusNode();

  @override
  void initState() {
    super.initState();
    focus.addListener(() => widget.onFocus?.call(focus.hasFocus));
  }

  @override
  void dispose() {
    f.dispose();
    focus.dispose();
    super.dispose();
  }

  void _go() {
    final t = f.text.trim();
    if (t.isEmpty) return;
    f.clear();
    focus.unfocus();
    widget.onAnswer?.call(t);
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: TextField(
            key: const ValueKey('ask-answer'),
            controller: f,
            focusNode: focus,
            maxLength: 300,
            style: const TextStyle(color: Color(0xFF1D1420), fontSize: 14),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _go(),
            decoration: const InputDecoration(
              hintText: 'დაწერე პასუხი…',
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: Color(0xFFF3EEF2),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide.none),
            ),
          ),
        ),
        IconBtn('send', key: const ValueKey('ask-send'), label: 'გაგზავნა', size: 20, color: const Color(0xFF7A3FC2), onTap: _go),
      ]);
}

/// A story's poll: the answers to tap, or how many chose each once voted (the author always sees them).
class StoryPollBox extends StatelessWidget {
  const StoryPollBox({super.key, required this.q, required this.opts, this.result, this.show = false, this.onVote, this.preview = false});
  final String q;
  final List<String> opts;
  final ({int? mine, int total, List<int> counts})? result;
  final bool show, preview;
  final void Function(int i)? onVote;

  @override
  Widget build(BuildContext context) {
    final r = result, tot = r?.total ?? 0;
    final see = show || r?.mine != null;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 14, offset: Offset(0, 4))]),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(q.isEmpty ? 'გამოკითხვა' : q, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF1D1420), fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        for (var i = 0; i < opts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: see
                ? Container(
                    height: 40,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: const Color(0xFFF3EEF2), borderRadius: BorderRadius.circular(12), border: Border.all(color: r?.mine == i ? const Color(0xFF7A3FC2) : Colors.transparent, width: 1.6)),
                    child: Stack(children: [
                      FractionallySizedBox(
                        widthFactor: tot == 0 || r == null || i >= r.counts.length ? 0 : r.counts[i] / tot,
                        child: Container(color: const Color(0x337A3FC2)),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(children: [
                            Expanded(child: Text(opts[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF1D1420), fontWeight: FontWeight.w700))),
                            Text('${tot == 0 || r == null || i >= r.counts.length ? 0 : (r.counts[i] * 100 / tot).round()}%',
                                style: const TextStyle(color: Color(0xFF7A3FC2), fontWeight: FontWeight.w800)),
                          ]),
                        ),
                      ),
                    ]),
                  )
                : Material(
                    color: const Color(0xFFF3EEF2),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      key: ValueKey('svvote-$i'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: preview || onVote == null ? null : () => onVote!(i),
                      child: SizedBox(
                        height: 40,
                        child: Center(child: Text(opts[i].isEmpty ? '…' : opts[i], style: const TextStyle(color: Color(0xFF1D1420), fontWeight: FontWeight.w700))),
                      ),
                    ),
                  ),
          ),
        if (see) Text('$tot ხმა', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7A6D78), fontSize: 12.5)),
      ]),
    );
  }
}

/// The last step: the picture (or the video's first frame) with stickers put on it with a finger, then
/// "გამოქვეყნება". Pops true when the story went out.
class StoryComposeScreen extends StatefulWidget {
  const StoryComposeScreen({super.key, this.photo, this.video, this.poll, this.close = false});
  final Uint8List? photo;
  final VideoReady? video;
  final Map<String, dynamic>? poll;
  final bool close;
  @override
  State<StoryComposeScreen> createState() => _StoryComposeScreenState();
}

class _StoryComposeScreenState extends State<StoryComposeScreen> {
  final st = <Map<String, dynamic>>[];
  bool busy = false;

  void _add(Map<String, dynamic> x) {
    if (st.length >= 6) {
      toast(context, 'მაქსიმუმ 6 სტიკერი');
      return;
    }
    setState(() => st.add({...x, 'x': .5, 'y': math.min(.82, .28 + st.length * .12)}));
  }

  Future<void> _mention() async {
    final app = context.app;
    if (!app.friends.loaded) await app.friends.load().catchError((_) {});
    await app.people.ensure(app.friends.friends);
    if (!mounted) return;
    final uid = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(s).height * .7),
          child: ListView(shrinkWrap: true, children: [
            const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('ვის მონიშნავ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            for (final id in app.friends.friends)
              ListTile(
                key: ValueKey('sm-$id'),
                leading: Avatar(p: app.people[id] ?? Profile(id: id, name: '…'), size: 38),
                title: Text(app.people[id]?.name ?? '…', style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.of(s).pop(id),
              ),
          ]),
        ),
      ),
    );
    if (uid != null) _add({'t': 'mention', 'u': uid});
  }

  Future<String?> _ask(String title, String initial, String hint, int max) async {
    final f = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(key: const ValueKey('stk-text'), controller: f, autofocus: true, maxLength: max, decoration: InputDecoration(hintText: hint, counterText: '')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('გაუქმება')),
          TextButton(key: const ValueKey('stk-ok'), onPressed: () => Navigator.pop(d, f.text.trim()), child: const Text('დამატება')),
        ],
      ),
    );
  }

  Future<void> _place() async {
    final me = context.me;
    final v = await _ask('ადგილი', me.homePlace ?? me.city ?? '', 'მაგ. საჩხერე, ბათუმის ბულვარი', 40);
    if (v != null && v.isNotEmpty) _add({'t': 'place', 'name': v});
  }

  Future<void> _count() async {
    final title = await _ask('უკუთვლა', '', 'მაგ. ჩვენი ქორწილი', 40);
    if (title == null || !mounted) return;
    if (title.isEmpty) {
      toast(context, 'დაწერე, რას ითვლი');
      return;
    }
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 7)), firstDate: now, lastDate: now.add(const Duration(days: 730)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 12, minute: 0));
    if (t == null || !mounted) return;
    final at = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (!at.isAfter(DateTime.now())) {
      toast(context, 'აირჩიე მომავალი დრო');
      return;
    }
    _add({'t': 'count', 'title': title, 'at': at.toUtc().toIso8601String()});
  }

  Future<void> _question() async {
    final q = await _ask('კითხვა', 'მკითხე რამე', 'მკითხე რამე', 60);
    if (q != null) _add({'t': 'ask', 'q': q.isEmpty ? 'მკითხე რამე' : q});
  }

  Future<void> _publish() async {
    final app = context.app;
    setState(() => busy = true);
    try {
      String url;
      final v = widget.video;
      if (v != null) {
        url = (await app.api.uploadVideo(v)).url;
      } else {
        url = await app.api.uploadStoryPhoto(await photoPrep(widget.photo!));
      }
      await app.api.addStory(url, video: v != null, close: widget.close, poll: widget.poll, stickers: [
        for (final x in st) {...x, 'x': double.parse((x['x'] as double).toStringAsFixed(3)), 'y': double.parse((x['y'] as double).toStringAsFixed(3))},
      ]);
      await app.stories.load();
      if (!mounted) return;
      toast(context, 'ისტორია გამოქვეყნდა');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, e is VideoTooBig ? e.toString() : errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, v = widget.video;
    final poster = v?.poster != null && File(v!.poster!).existsSync() ? File(v.poster!) : null;
    return Scaffold(
      appBar: peeraBar(context, title: 'ისტორია', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            key: const ValueKey('sc-ok'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: busy ? null : _publish,
            icon: PIcon('send', size: 17, color: c.onAccent),
            label: const Text('გამოქვეყნება'),
          ),
        ),
      ]),
      body: Column(children: [
        if (busy) LinearProgressIndicator(minHeight: 3, color: c.accent, backgroundColor: c.accentSoft),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: LayoutBuilder(builder: (context, box) {
                    return Stack(fit: StackFit.expand, children: [
                      Container(color: Colors.black),
                      if (widget.photo != null)
                        Image.memory(widget.photo!, fit: BoxFit.cover, gaplessPlayback: true)
                      else if (poster != null)
                        Image.file(poster, fit: BoxFit.cover)
                      else
                        const Center(child: PIcon('play', size: 48, color: Colors.white)),
                      if (widget.poll != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: box.maxHeight * .55,
                          child: Center(
                            child: Transform.scale(
                              scale: box.maxWidth / 390,
                              child: StoryPollBox(q: '${widget.poll!['q'] ?? ''}', opts: [for (final o in widget.poll!['opts'] as List) '$o'], preview: true),
                            ),
                          ),
                        ),
                      for (var i = 0; i < st.length; i++)
                        Positioned(
                          left: (st[i]['x'] as double) * box.maxWidth - 130,
                          top: (st[i]['y'] as double) * box.maxHeight - 30,
                          width: 260,
                          child: Center(
                            child: GestureDetector(
                              key: ValueKey('sst-$i'),
                              onPanUpdate: (d) => setState(() {
                                st[i]['x'] = ((st[i]['x'] as double) + d.delta.dx / box.maxWidth).clamp(.05, .95).toDouble();
                                st[i]['y'] = ((st[i]['y'] as double) + d.delta.dy / box.maxHeight).clamp(.08, .9).toDouble();
                              }),
                              child: Stack(clipBehavior: Clip.none, children: [
                                StorySticker(x: st[i], edit: true),
                                Positioned(
                                  right: -8,
                                  top: -8,
                                  child: GestureDetector(
                                    key: ValueKey('sst-x-$i'),
                                    onTap: () => setState(() => st.removeAt(i)),
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                      child: const Center(child: PIcon('x', size: 14, color: Colors.white, stroke: 2.6)),
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                    ]);
                  }),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final (k, icon, label, f) in [
                    ('mention', 'user', 'მონიშვნა', _mention),
                    ('place', 'pin', 'ადგილი', _place),
                    ('count', 'timer', 'უკუთვლა', _count),
                    ('ask', 'help', 'კითხვა', _question),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: OutlinedButton.icon(
                        key: ValueKey('sc-$k'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: busy ? null : f,
                        icon: PIcon(icon, size: 17, color: c.ink),
                        label: Text(label),
                      ),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('სტიკერი თითით გადაიტანე. მოსაშორებლად დააჭირე ×-ს.', style: TextStyle(color: c.muted, fontSize: 12.5)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
