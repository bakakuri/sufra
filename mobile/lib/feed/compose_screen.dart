import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models.dart';
import '../data/photos.dart';
import '../data/stores.dart';
import '../media/photo_edit.dart';
import '../media/video_tools.dart';
import '../people/namedays.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/mentions.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'place_pick.dart';

/// Where the photos come from: the gallery (several) or the camera (one). The tests put in their own.
typedef PhotoSource = Future<List<Uint8List>> Function(bool camera);
PhotoSource photoSource = pickPhotos;

/// How a picked photo is made ready to upload (the tests skip the resizing).
Future<PreparedPhoto> Function(Uint8List) photoPrep = preparePhoto;

Future<List<Uint8List>> pickPhotos(bool camera) async {
  final p = ImagePicker();
  if (camera) {
    final f = await p.pickImage(source: ImageSource.camera, maxWidth: 2048, maxHeight: 2048, imageQuality: 92);
    return f == null ? [] : [await f.readAsBytes()];
  }
  final files = await p.pickMultiImage(maxWidth: 2048, maxHeight: 2048, imageQuality: 92);
  return [for (final f in files.take(maxPhotos)) await f.readAsBytes()];
}

const maxPhotos = 10;

/// Writing a post: words (with @mentions), up to ten photos (each can be cut, filtered and turned), a video, a poll and
/// a place. "გამოქვეყნება" uploads them (photos made upright and in the site's three sizes) and publishes, and the new
/// post comes back to the feed; the clock button keeps it as a draft or plans it for later.
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key, this.startWithPhotos = false, this.startWithPoll = false, this.text = ''});
  final bool startWithPhotos, startWithPoll;

  /// words to begin with (a first post's idea, a memory shared)
  final String text;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final field = TextEditingController();
  final photos = <Uint8List>[];
  VideoReady? video;
  double? preparing;
  (int, String)? place;
  bool busy = false;
  String? stage;

  /// the poll being written: its question and two to six answers (null: none)
  TextEditingController? pollQ;
  final pollOpts = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    field.text = widget.text;
    // " #tag" from a tag's page: the cursor before it
    field.selection = TextSelection.collapsed(offset: widget.text.startsWith(' #') ? 0 : field.text.length);
    field.addListener(() => setState(() {}));
    if (widget.startWithPoll) _pollOn();
    if (widget.startWithPhotos) WidgetsBinding.instance.addPostFrameCallback((_) => _add(false));
  }

  @override
  void dispose() {
    field.dispose();
    pollQ?.dispose();
    for (final o in pollOpts) {
      o.dispose();
    }
    super.dispose();
  }

  void _pollOn() {
    if (pollQ != null) return;
    setState(() {
      pollQ = TextEditingController();
      pollOpts.addAll([TextEditingController(), TextEditingController()]);
    });
  }

  void _pollOff() {
    final q = pollQ;
    setState(() {
      pollQ = null;
      for (final o in pollOpts) {
        o.dispose();
      }
      pollOpts.clear();
    });
    q?.dispose();
  }

  bool get _empty => field.text.trim().isEmpty && photos.isEmpty && pollQ == null && video == null && place == null;

  Future<void> _add(bool camera) async {
    if (photos.length >= maxPhotos) {
      toast(context, 'მაქსიმუმ $maxPhotos ფოტო');
      return;
    }
    try {
      final got = await photoSource(camera);
      if (!mounted || got.isEmpty) return;
      setState(() => photos.addAll(got.take(maxPhotos - photos.length)));
    } catch (e) {
      if (mounted) toast(context, 'ფოტო ვერ გავხსენი');
    }
  }

  Future<void> _edit(int i) async {
    final out = await photoEdit(context, photos[i]);
    if (out != null && mounted) setState(() => photos[i] = out);
  }

  Future<void> _video() async {
    String? path;
    try {
      path = await videoPicker();
    } catch (_) {}
    if (path == null || !mounted) return;
    setState(() => preparing = 0);
    try {
      final v = await videoPrep(path, (x) {
        if (mounted) setState(() => preparing = x);
      });
      if (mounted) {
        setState(() {
          video = v;
          preparing = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => preparing = null);
      toast(context, e is VideoTooBig ? e.toString() : 'ვიდეო ვერ მომზადდა');
    }
  }

  Future<void> _place() async {
    final pl = await pickPlace(context);
    if (pl != null && mounted) setState(() => place = pl);
  }

  /// the clock: a draft, or a time to publish it
  Future<void> _later() async {
    if (_empty || busy) return;
    final c = context.pc;
    final how = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 6), child: Text('მოგვიანებით', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          ListTile(key: const ValueKey('c-draft'), leading: PIcon('edit', color: s.pc.ink), title: const Text('დრაფტად შენახვა'), onTap: () => Navigator.of(s).pop('draft')),
          ListTile(key: const ValueKey('c-plan'), leading: PIcon('clock', color: s.pc.ink), title: const Text('დაგეგმვა'), subtitle: const Text('აირჩიე დღე და საათი'), onTap: () => Navigator.of(s).pop('plan')),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Text('დრაფტები და დაგეგმილი პოსტები ჩანს „დრაფტებში“.', style: TextStyle(color: s.pc.muted, fontSize: 13)),
          ),
        ]),
      ),
    );
    if (how == null || !mounted) return;
    if (how == 'draft') return _publish(draft: true);
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
    if (t == null || !mounted) return;
    final when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (when.isBefore(DateTime.now().add(const Duration(seconds: 30)))) {
      toast(context, 'აირჩიე მომავალი დრო');
      return;
    }
    await _publish(at: when);
  }

  Future<void> _publish({bool draft = false, DateTime? at}) async {
    if (_empty || busy) return;
    final app = context.app;
    Poll? poll;
    final q = pollQ;
    if (q != null) {
      final opts = [for (final o in pollOpts) if (o.text.trim().isNotEmpty) o.text.trim()];
      if (q.text.trim().isEmpty || opts.length < 2) {
        toast(context, 'გამოკითხვას სჭირდება კითხვა და მინიმუმ 2 პასუხი');
        return;
      }
      poll = Poll(q.text.trim(), opts);
    }
    setState(() => busy = true);
    try {
      final media = <Media>[];
      for (var i = 0; i < photos.length; i++) {
        setState(() => stage = photos.length == 1 ? 'ფოტო იტვირთება…' : 'ფოტოები იტვირთება · ${i + 1}/${photos.length}');
        media.add(await app.api.uploadPhoto(await photoPrep(photos[i])));
      }
      final v = video;
      if (v != null) {
        setState(() => stage = 'ვიდეო იტვირთება · ${(v.bytes / 1048576).toStringAsFixed(1)} მბ…');
        media.add(await app.api.uploadVideo(v));
      }
      setState(() => stage = 'ქვეყნდება…');
      final post = await app.api.createPost(field.text.trim(), media, poll: poll, placeId: place?.$1, draft: draft, publishAt: at);
      if (!mounted) return;
      if (draft || at != null) {
        toast(context, at == null ? 'დრაფტი შენახულია' : 'დაიგეგმა: ${at.day} ${monthNames[at.month - 1]}, ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}');
        Navigator.of(context).pop();
        return;
      }
      Navigator.of(context).pop(post);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        stage = null;
      });
      toast(context, errText(e));
    }
  }

  Future<void> _leave() async {
    if (busy) return;
    if (_empty || await confirm(context, title: 'პოსტი არ გამოქვეყნდება', text: 'დაწერილი და არჩეული ფოტოები წაიშლება.', yes: 'გასვლა', danger: true)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, me = context.me;
    return PopScope(
      canPop: _empty && !busy,
      onPopInvokedWithResult: (did, _) {
        if (!did) _leave();
      },
      child: Scaffold(
        backgroundColor: c.surface,
        appBar: AppBar(
          toolbarHeight: 60,
          titleSpacing: 0,
          leading: IconBtn('x', label: 'დახურვა', onTap: _leave),
          title: const Text('ახალი პოსტი'),
          actions: [
            IconBtn('clock', key: const ValueKey('c-later'), label: 'დრაფტი ან დაგეგმვა', onTap: _empty || busy || preparing != null ? null : _later),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                key: const ValueKey('c-pub'),
                onPressed: _empty || busy || preparing != null ? null : _publish,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 18)),
                child: const Text('გამოქვეყნება'),
              ),
            ),
          ],
        ),
        body: Column(children: [
          if (busy) LinearProgressIndicator(minHeight: 3, color: c.accent, backgroundColor: c.accentSoft),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
              Row(children: [
                Avatar(p: me, size: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    NameLine(me, size: 15.5),
                    Text('ყველა ხედავს, ვისაც შენი პოსტები ჩანს', style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: field,
                enabled: !busy,
                autofocus: !widget.startWithPhotos && !widget.startWithPoll,
                minLines: 4,
                maxLines: null,
                maxLength: 5000,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 18, height: 1.45),
                decoration: InputDecoration(
                  hintText: 'რას ფიქრობ, ${me.name}?',
                  hintStyle: TextStyle(fontSize: 18, color: c.muted),
                  filled: false,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: photos.length < 3 ? photos.length : 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: photos.length == 1 ? 1.25 : 1,
                  children: [
                    for (var i = 0; i < photos.length; i++)
                      Stack(fit: StackFit.expand, children: [
                        GestureDetector(
                          key: ValueKey('c-photo-$i'),
                          onTap: busy ? null : () => _edit(i),
                          child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(photos[i], fit: BoxFit.cover, cacheWidth: 600, gaplessPlayback: true)),
                        ),
                        if (!busy)
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                  PIcon('edit', size: 13, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text('რედაქტირება', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            ),
                          ),
                        if (!busy)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => setState(() => photos.removeAt(i)),
                                child: const Padding(padding: EdgeInsets.all(5), child: PIcon('x', size: 16, color: Colors.white, stroke: 2.4)),
                              ),
                            ),
                          ),
                      ]),
                  ],
                ),
              ],
              if (preparing != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ვიდეო მზადდება… ${((preparing ?? 0) * 100).round()}%', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: preparing, minHeight: 4, color: c.accent, backgroundColor: c.accentSoft),
                  ]),
                ),
              if (video != null) ...[
                const SizedBox(height: 10),
                Container(
                  key: const ValueKey('c-video'),
                  height: 150,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: const Color(0xFF14161E), borderRadius: BorderRadius.circular(12)),
                  child: Stack(fit: StackFit.expand, children: [
                    if (video!.poster != null && File(video!.poster!).existsSync()) Image.file(File(video!.poster!), fit: BoxFit.cover),
                    const Center(child: PIcon('play', size: 40, color: Colors.white)),
                    Positioned(
                      left: 10,
                      bottom: 8,
                      child: Text('${video!.dur.round() ~/ 60}:${(video!.dur.round() % 60).toString().padLeft(2, '0')} · ${(video!.bytes / 1048576).toStringAsFixed(1)} მბ',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ),
                    if (!busy)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            key: const ValueKey('c-video-x'),
                            customBorder: const CircleBorder(),
                            onTap: () => setState(() => video = null),
                            child: const Padding(padding: EdgeInsets.all(5), child: PIcon('x', size: 16, color: Colors.white, stroke: 2.4)),
                          ),
                        ),
                      ),
                  ]),
                ),
              ],
              if (place != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      key: const ValueKey('c-place-chip'),
                      label: Text('📍 ${place!.$2}'),
                      onPressed: busy ? null : _place,
                      onDeleted: busy ? null : () => setState(() => place = null),
                    ),
                  ),
                ),
              if (pollQ != null) ...[
                const SizedBox(height: 10),
                Container(
                  key: const ValueKey('poll-box'),
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
                  decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      PIcon('poll', size: 18, color: c.accent),
                      const SizedBox(width: 6),
                      const Expanded(child: Text('გამოკითხვა', style: TextStyle(fontWeight: FontWeight.w800))),
                      IconBtn('x', key: const ValueKey('poll-rm'), label: 'გამოკითხვის მოხსნა', size: 18, onTap: busy ? null : _pollOff),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextField(
                        key: const ValueKey('poll-q'),
                        controller: pollQ,
                        enabled: !busy,
                        maxLength: 140,
                        decoration: const InputDecoration(hintText: 'კითხვა', counterText: ''),
                      ),
                    ),
                    for (var i = 0; i < pollOpts.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(children: [
                          Expanded(
                            child: TextField(
                              key: ValueKey('poll-o-$i'),
                              controller: pollOpts[i],
                              enabled: !busy,
                              maxLength: 60,
                              decoration: InputDecoration(hintText: 'პასუხი ${i + 1}', counterText: ''),
                            ),
                          ),
                          if (i > 1)
                            IconBtn('x', label: 'წაშლა', size: 18, onTap: busy
                                ? null
                                : () => setState(() {
                                      pollOpts.removeAt(i).dispose();
                                    }))
                          else
                            const SizedBox(width: 8),
                        ]),
                      ),
                    if (pollOpts.length < 6)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const ValueKey('poll-add'),
                          onPressed: busy ? null : () => setState(() => pollOpts.add(TextEditingController())),
                          icon: PIcon('plus', size: 18, color: c.accent),
                          label: const Text('პასუხის დამატება'),
                        ),
                      ),
                  ]),
                ),
              ],
              if (stage != null) ...[
                const SizedBox(height: 14),
                Text(stage!, style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
          MentionSuggest(field: field),
          Container(
            decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        TextButton.icon(
                          onPressed: busy ? null : () => _add(false),
                          icon: PIcon('image', size: 22, color: c.vine),
                          label: Text('ფოტო', style: TextStyle(color: c.ink)),
                        ),
                        TextButton.icon(
                          onPressed: busy ? null : () => _add(true),
                          icon: PIcon('camera', size: 22, color: c.accent),
                          label: Text('კამერა', style: TextStyle(color: c.ink)),
                        ),
                        TextButton.icon(
                          key: const ValueKey('c-vid'),
                          onPressed: busy || preparing != null ? null : _video,
                          icon: PIcon('video', size: 22, color: c.nope),
                          label: Text('ვიდეო', style: TextStyle(color: c.ink)),
                        ),
                        TextButton.icon(
                          key: const ValueKey('c-poll'),
                          onPressed: busy || pollQ != null ? null : _pollOn,
                          icon: PIcon('poll', size: 22, color: c.gold),
                          label: Text('გამოკითხვა', style: TextStyle(color: c.ink)),
                        ),
                        TextButton.icon(
                          key: const ValueKey('c-place'),
                          onPressed: busy ? null : _place,
                          icon: PIcon('pin', size: 22, color: c.accent),
                          label: Text('ადგილი', style: TextStyle(color: c.ink)),
                        ),
                      ]),
                    ),
                  ),
                  if (photos.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text('${photos.length}/$maxPhotos', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
                    ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
