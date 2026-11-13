// What can be done with a post (feed.js A.share, A.pmore and the rest): sharing it (a repost, with my own words, to
// my story, in a message, its link), editing my own, hiding one from my feed, a complaint, putting a saved one in a
// folder, and the moderators' hiding for everyone.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../data/models.dart';
import '../data/photos.dart';
import '../data/stores.dart';
import '../media/photo_edit.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/mentions.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'place_pick.dart';

/// Changes to posts made here that every card should show at once: edited posts, posts hidden from my feed, and the
/// moderators' hiding.
class PostOverrides extends ChangeNotifier {
  final edited = <int, Post>{};
  final hidden = <int>{};
  final modHidden = <int, bool>{};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      hidden.addAll((p.getStringList('hiddenPosts') ?? const []).map(int.tryParse).whereType<int>());
      notifyListeners();
    } catch (_) {}
  }

  void edit(Post p) {
    edited[p.id] = p;
    notifyListeners();
  }

  Future<void> hide(int id) async {
    hidden.add(id);
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      final keep = hidden.toList();
      await p.setStringList('hiddenPosts', [for (final x in keep.skip(keep.length > 500 ? keep.length - 500 : 0)) '$x']);
    } catch (_) {}
  }

  void modHide(int id, bool on) {
    modHidden[id] = on;
    notifyListeners();
  }

  /// for the tests: a clean start
  void reset() {
    edited.clear();
    hidden.clear();
    modHidden.clear();
    _loaded = false;
  }
}

final postOverrides = PostOverrides();

String postLink(int id) => '$siteUrl/#post-$id';

bool isStaff(BuildContext context) => context.me.role == 'admin' || context.me.role == 'moderator';

String _repostErr(Object e) {
  final m = '$e';
  if (RegExp('duplicate|unique', caseSensitive: false).hasMatch(m)) return 'უკვე გაზიარებული გაქვს';
  if (m.contains('not_found')) return 'პოსტი აღარ არის ხელმისაწვდომი';
  if (m.contains('not_allowed')) return 'ჯგუფის პოსტის გაზიარება არ შეიძლება';
  if (m.contains('blocked')) return 'ვერ გააზიარებ';
  return errText(e);
}

Future<T?> _sheet<T>(BuildContext context, Widget Function(BuildContext s) body) {
  final app = context.app, me = context.me;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => AppScope(
      app: app,
      me: me,
      child: SafeArea(child: ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(s).height * .85), child: Builder(builder: body))),
    ),
  );
}

Widget _title(BuildContext s, String t) =>
    Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)));

/// "გაზიარება": a repost (or taking it back), with my words, to my story, in a message, the link.
Future<void> shareSheet(BuildContext context, Post p) async {
  final app = context.app, own = p.author == context.me.id;
  final canRepost = p.groupName == null && !own && !p.hidden;
  (int, int?) rs = (0, null);
  try {
    rs = (await app.api.repostStats([p.id]))[p.id] ?? (0, null);
  } catch (_) {}
  if (!context.mounted) return;
  final (n, mine) = rs;
  final pick = await _sheet<String>(context, (s) {
    final c = s.pc;
    Widget tile(String k, String icon, String label, {bool on = false}) => SizedBox(
          width: 82,
          child: InkWell(
            key: ValueKey('sh-$k'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(s).pop(k),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: on ? c.accent : c.sunk, shape: BoxShape.circle),
                  child: Center(child: PIcon(icon, size: 24, color: on ? Colors.white : c.ink)),
                ),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        _title(s, 'გაზიარება'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Wrap(alignment: WrapAlignment.center, runSpacing: 4, children: [
            if (canRepost) ...[
              tile(mine != null ? 'unrepost' : 'repost', 'repost', mine != null ? 'გაუქმება' : 'რეპოსტი', on: mine != null),
              tile('quote', 'edit', 'ციტირებით'),
            ],
            if (p.groupName == null) tile('story', 'story', 'ისტორიაში'),
            tile('send', 'send', 'მესიჯით'),
            tile('link', 'copy', 'ბმული'),
          ]),
        ),
        if (n > 0 || own)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              n > 0 ? '$n ადამიანმა გააზიარა' : 'საკუთარ პოსტს რეპოსტს ვერ გაუკეთებ, მაგრამ ისტორიაში ან მესიჯით გაზიარება შეგიძლია.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
          ),
      ]),
    );
  });
  if (pick == null || !context.mounted) return;
  switch (pick) {
    case 'repost':
      try {
        await app.api.repost(p.id);
        if (context.mounted) toast(context, 'გაზიარდა შენს მეგობრებთან');
      } catch (e) {
        if (context.mounted) toast(context, _repostErr(e));
      }
    case 'unrepost':
      if (mine == null) return;
      if (await attempt(context, () => app.api.unrepost(mine)) && context.mounted) toast(context, 'რეპოსტი გაუქმდა');
    case 'quote':
      await openPage<Post>(context, QuoteScreen(original: p), full: true);
    case 'story':
      await storyFromPost(context, p);
    case 'send':
      await sendPostSheet(context, p);
    case 'link':
      await Clipboard.setData(ClipboardData(text: postLink(p.id)));
      if (context.mounted) toast(context, 'ბმული დაკოპირდა');
  }
}

/// Sharing with my own words above the post.
class QuoteScreen extends StatefulWidget {
  const QuoteScreen({super.key, required this.original});
  final Post original;
  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  final field = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    field.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final t = field.text.trim();
    if (t.isEmpty || busy) return;
    setState(() => busy = true);
    try {
      final p = await context.app.api.createPost(t, const [], repostOf: widget.original.id);
      p.original = widget.original;
      if (!mounted) return;
      toast(context, 'გაზიარდა');
      Navigator.of(context).pop(p);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, _repostErr(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, me = context.me, o = widget.original, who = o.ap ?? Profile(id: o.author, name: '');
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: c.surface,
        appBar: AppBar(
          toolbarHeight: 60,
          titleSpacing: 0,
          leading: IconBtn('x', label: 'დახურვა', onTap: busy ? null : () => Navigator.of(context).maybePop()),
          title: const Text('ციტირება'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                key: const ValueKey('q-go'),
                onPressed: field.text.trim().isEmpty || busy ? null : _go,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 18)),
                child: const Text('გაზიარება'),
              ),
            ),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                Avatar(p: me, size: 44),
                const SizedBox(width: 10),
                Expanded(child: NameLine(me, size: 15.5)),
              ]),
              TextField(
                key: const ValueKey('q-text'),
                controller: field,
                autofocus: true,
                minLines: 3,
                maxLines: null,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 18, height: 1.45),
                decoration: const InputDecoration(
                  hintText: 'დაამატე შენი აზრი…',
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Avatar(p: who, size: 24), const SizedBox(width: 6), Flexible(child: NameLine(who, size: 13.5))]),
                  if (o.body.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(o.body.trim(), maxLines: 4, overflow: TextOverflow.ellipsis)),
                  if (o.media.isNotEmpty && (!o.media.first.isVideo || o.media.first.poster != null))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(height: 120, child: PImage(o.media.first.isVideo ? (o.media.first.poster ?? '') : o.media.first.small, radius: 10)),
                    ),
                ]),
              ),
            ]),
          ),
          MentionSuggest(field: field),
        ]),
      ),
    );
  }
}

/// "მესიჯით": the post as a card in one of my conversations.
Future<void> sendPostSheet(BuildContext context, Post p) async {
  final app = context.app;
  if (!app.chats.loaded) await app.chats.load();
  if (!context.mounted) return;
  final sent = <int>{};
  await _sheet<void>(context, (s) {
    final c = s.pc, list = app.chats.chats.where((x) => !x.archived).take(40).toList();
    return StatefulBuilder(
      builder: (s, set) => ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: [
        _title(s, 'მესიჯით გაგზავნა'),
        if (list.isEmpty) const Empty(icon: 'msg', title: 'საუბრები ჯერ არ გაქვს', text: 'მიწერე მეგობარს და აქ გამოჩნდება.'),
        for (final ch in list)
          Builder(builder: (_) {
            final other = ch.isGroup || ch.members.isEmpty ? null : app.people[ch.members.first];
            final name = ch.isGroup ? ((ch.title ?? '').isEmpty ? 'ჯგუფი' : ch.title!) : (other?.name ?? '');
            final done = sent.contains(ch.convId);
            return ListTile(
              key: ValueKey('sp-${ch.convId}'),
              leading: other != null
                  ? Avatar(p: other, size: 42)
                  : CircleAvatar(radius: 21, backgroundColor: c.accentSoft, child: PIcon('users', size: 20, color: c.accent)),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: done
                  ? Text('გაიგზავნა', style: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: 13))
                  : PIcon('send', size: 20, color: c.accent),
              onTap: done
                  ? null
                  : () async {
                      final who = p.ap?.name ?? '', m = p.media.firstOrNull;
                      try {
                        await app.api.send(ch.convId, body: postLink(p.id), media: {
                          'post': {
                            'id': p.id,
                            'by': who.length > 60 ? who.substring(0, 60) : who,
                            't': p.body.length > 140 ? p.body.substring(0, 140) : p.body,
                            'img': m == null ? '' : (m.isVideo ? (m.poster ?? '') : m.small),
                          },
                        });
                        set(() => sent.add(ch.convId));
                      } catch (e) {
                        if (s.mounted) toast(s, errText(e));
                      }
                    },
            );
          }),
      ]),
    );
  });
}

/// The picture a post becomes in a story (feed.js postCardImage): the photo on a white card with the author, on a
/// gradient of their colour, 1080×1920 JPEG (the tests put in their own).
Future<Uint8List> Function(BuildContext context, Post p) storyCard = makeStoryCard;

Future<ui.Image?> _load(String? url) async {
  if (url == null || url.isEmpty) return null;
  final done = Completer<ui.Image?>();
  final stream = netImage(url).resolve(ImageConfiguration.empty);
  late final ImageStreamListener l;
  l = ImageStreamListener((info, _) {
    if (!done.isCompleted) done.complete(info.image);
    stream.removeListener(l);
  }, onError: (_, __) {
    if (!done.isCompleted) done.complete(null);
    stream.removeListener(l);
  });
  stream.addListener(l);
  return done.future.timeout(const Duration(seconds: 9), onTimeout: () => null);
}

Future<Uint8List> makeStoryCard(BuildContext context, Post p) async {
  const W = 1080.0, H = 1920.0;
  final font = DefaultTextStyle.of(context).style;
  final who = p.ap ?? Profile(id: p.author, name: '');
  final hue = ((who.hue % 360) + 360) % 360;
  final m = p.media.where((x) => !x.isVideo).firstOrNull ?? p.media.where((x) => x.poster != null).firstOrNull;
  final pic = await _load(m == null ? null : (m.isVideo ? m.poster : m.mid));
  final avi = await _load(who.avatarUrl);
  final rec = ui.PictureRecorder();
  final cv = Canvas(rec);
  cv.drawRect(
    const Rect.fromLTWH(0, 0, W, H),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(W, H), [
        HSLColor.fromAHSL(1, hue.toDouble(), .42, .24).toColor(),
        HSLColor.fromAHSL(1, ((hue + 40) % 360).toDouble(), .48, .09).toColor(),
      ]),
  );
  TextPainter tp(String t, double size, FontWeight w, Color col, {double? maxW, int? lines}) => TextPainter(
        text: TextSpan(text: t, style: font.copyWith(fontSize: size, fontWeight: w, color: col, height: 1.4, decoration: TextDecoration.none)),
        textDirection: TextDirection.ltr,
        maxLines: lines,
        ellipsis: lines == null ? null : '…',
      )..layout(maxWidth: maxW ?? W);
  const cw = 920.0, cx = (W - cw) / 2;
  var ih = 0.0;
  if (pic != null) ih = ((cw - 48) * pic.height / pic.width).clamp(520.0, 1040.0).toDouble().roundToDouble();
  final body = p.body.trim().isEmpty ? null : tp(p.body.trim(), 42, FontWeight.w500, const Color(0xFF2A2030), maxW: cw - 96, lines: pic != null ? 3 : 10);
  final double ch = 150.0 + (pic != null ? ih + 20 : 0.0) + (body != null ? body.height + 40 : 20.0);
  final cy = ((H - ch) / 2 - 30).clamp(120.0, H).toDouble();
  final card = RRect.fromRectAndRadius(Rect.fromLTWH(cx, cy, cw, ch), const Radius.circular(44));
  cv.drawRRect(card.shift(const Offset(0, 24)), Paint()
    ..color = Colors.black.withValues(alpha: .45)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
  cv.drawRRect(card, Paint()..color = Colors.white);
  final ac = Offset(cx + 86, cy + 78);
  cv.save();
  cv.clipPath(Path()..addOval(Rect.fromCircle(center: ac, radius: 38)));
  if (avi != null) {
    paintImage(canvas: cv, rect: Rect.fromCircle(center: ac, radius: 38), image: avi, fit: BoxFit.cover);
  } else {
    cv.drawCircle(ac, 38, Paint()..color = HSLColor.fromAHSL(1, hue.toDouble(), .55, .45).toColor());
    final l = tp(who.name.isEmpty ? '?' : who.name.characters.first, 36, FontWeight.w700, Colors.white);
    l.paint(cv, ac - Offset(l.width / 2, l.height / 2));
  }
  cv.restore();
  tp(who.name.length > 26 ? who.name.substring(0, 26) : who.name, 38, FontWeight.w700, const Color(0xFF1D1420), maxW: cw - 180, lines: 1).paint(cv, Offset(cx + 144, cy + 36));
  tp(p.byPage ? 'არხი Peera-ზე' : 'პოსტი Peera-ზე', 30, FontWeight.w400, const Color(0xFF7A6D78)).paint(cv, Offset(cx + 144, cy + 88));
  var y = cy + 150;
  if (pic != null) {
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(cx + 24, y, cw - 48, ih), const Radius.circular(28));
    cv.save();
    cv.clipRRect(r);
    paintImage(canvas: cv, rect: r.outerRect, image: pic, fit: BoxFit.cover);
    cv.restore();
    y += ih + 20;
  }
  body?.paint(cv, Offset(cx + 48, y + 8));
  final brand = tp('Peera', 40, FontWeight.w800, Colors.white.withValues(alpha: .86));
  brand.paint(cv, Offset(W / 2 - brand.width / 2, H - 170));
  final picture = rec.endRecording();
  final im = await picture.toImage(W.toInt(), H.toInt());
  final raw = await im.toByteData(format: ui.ImageByteFormat.rawRgba);
  im.dispose();
  return compute(_jpeg, (raw!.buffer.asUint8List(), W.toInt(), H.toInt()));
}

Uint8List _jpeg((Uint8List, int, int) a) =>
    img.encodeJpg(img.Image.fromBytes(width: a.$2, height: a.$3, bytes: a.$1.buffer, numChannels: 4, order: img.ChannelOrder.rgba), quality: 90);

/// "ისტორიაში": the post's card added to my story.
Future<void> storyFromPost(BuildContext context, Post p) async {
  final app = context.app;
  toast(context, 'ისტორია მზადდება…');
  try {
    final bytes = await storyCard(context, p);
    final url = await app.api.uploadStoryPhoto(PreparedPhoto(bytes, 1080, 1920));
    await app.api.addStory(url, postId: p.id);
    if (context.mounted) toast(context, 'დაემატა შენს ისტორიაში');
    app.stories.load().catchError((_) {});
  } catch (e) {
    if (context.mounted) toast(context, errText(e));
  }
}

/// A saved post into a folder: "without one", my folders, or a new one.
Future<void> folderPick(BuildContext context, int postId) async {
  final app = context.app;
  List<(int, String)> folders = const [];
  try {
    folders = await app.api.saveFolders();
  } catch (_) {}
  if (!context.mounted) return;
  final name = TextEditingController();
  await _sheet<void>(context, (s) {
    final c = s.pc;
    Future<void> put(int? f, String label) async {
      try {
        await app.api.saveToFolder(postId, f);
        if (s.mounted) Navigator.of(s).pop();
        if (context.mounted) toast(context, f == null ? 'შენახულია საქაღალდის გარეშე' : 'ჩაიდო საქაღალდეში „$label“');
      } catch (e) {
        if (s.mounted) toast(s, errText(e));
      }
    }

    return ListView(shrinkWrap: true, padding: EdgeInsets.only(bottom: 12 + MediaQuery.viewInsetsOf(s).bottom), children: [
      _title(s, 'საქაღალდეში შენახვა'),
      ListTile(key: const ValueKey('fold-none'), leading: PIcon('grid', color: c.muted), title: const Text('საქაღალდის გარეშე'), onTap: () => put(null, '')),
      for (final (id, n) in folders) ListTile(key: ValueKey('fold-$id'), leading: PIcon('folder', color: c.accent), title: Text(n), onTap: () => put(id, n)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              key: const ValueKey('fold-name'),
              controller: name,
              maxLength: 40,
              decoration: const InputDecoration(hintText: 'ახალი საქაღალდე, მაგ. კონსპექტები', counterText: ''),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const ValueKey('fold-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
            onPressed: () async {
              final n = name.text.trim();
              if (n.isEmpty) return;
              try {
                final (id, label) = await app.api.newFolder(n);
                await put(id, label);
              } catch (e) {
                if (s.mounted) toast(s, errText(e));
              }
            },
            child: const Text('შექმნა'),
          ),
        ]),
      ),
    ]);
  });
}

/// After saving: "შენახულია", and a touch puts it in a folder.
void savedNotice(BuildContext context, int postId) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: const Text('შენახულია'),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(label: 'საქაღალდეში', onPressed: () => folderPick(context, postId)),
    ));
}

/// Changing my post: its words, which photos stay, and the place. A poll stays as it is, so no vote is lost.
class EditPostScreen extends StatefulWidget {
  const EditPostScreen({super.key, required this.post});
  final Post post;
  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late final field = TextEditingController(text: widget.post.body);
  late final media = [...widget.post.media];
  late (int, String)? place = widget.post.placeId == null ? null : (widget.post.placeId!, widget.post.placeName ?? '');
  bool busy = false;

  bool get _changed =>
      field.text != widget.post.body || media.length != widget.post.media.length || place?.$1 != widget.post.placeId;

  @override
  void initState() {
    super.initState();
    field.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = widget.post, body = field.text.trim();
    if (p.repostOf != null && body.isEmpty) {
      toast(context, 'ციტირებას ტექსტი სჭირდება');
      return;
    }
    if (p.repostOf == null && body.isEmpty && media.isEmpty && p.poll == null && place == null) {
      toast(context, 'პოსტი ცარიელი ვერ დარჩება');
      return;
    }
    setState(() => busy = true);
    try {
      final n = await context.app.api.updatePost(p.id, body,
          media: p.repostOf == null ? media : null, placeId: place?.$1, setPlace: p.repostOf == null);
      n.original ??= p.original;
      postOverrides.edit(n);
      if (!mounted) return;
      toast(context, 'შესწორდა');
      Navigator.of(context).pop(n);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e));
    }
  }

  Future<void> _leave() async {
    if (busy) return;
    if (!_changed || await confirm(context, title: 'ცვლილებები არ შეინახება', text: 'გასვლისას შესწორებები დაიკარგება.', yes: 'გასვლა', danger: true)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, p = widget.post;
    return PopScope(
      canPop: !_changed && !busy,
      onPopInvokedWithResult: (did, _) {
        if (!did) _leave();
      },
      child: Scaffold(
        backgroundColor: c.surface,
        appBar: AppBar(
          toolbarHeight: 60,
          titleSpacing: 0,
          leading: IconBtn('x', label: 'დახურვა', onTap: _leave),
          title: const Text('პოსტის რედაქტირება'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                key: const ValueKey('ep-save'),
                onPressed: busy || !_changed ? null : _save,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 18)),
                child: const Text('შენახვა'),
              ),
            ),
          ],
        ),
        body: Column(children: [
          if (busy) LinearProgressIndicator(minHeight: 3, color: c.accent, backgroundColor: c.accentSoft),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              TextField(
                key: const ValueKey('ep-text'),
                controller: field,
                enabled: !busy,
                minLines: 4,
                maxLines: null,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 17, height: 1.45),
                decoration: const InputDecoration(hintText: 'ტექსტი', counterText: ''),
              ),
              if (media.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (var i = 0; i < media.length; i++)
                    SizedBox.square(
                      dimension: 96,
                      child: Stack(fit: StackFit.expand, children: [
                        PImage(media[i].isVideo ? (media[i].poster ?? '') : media[i].small, radius: 12),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: InkWell(
                              key: ValueKey('ep-rm-$i'),
                              customBorder: const CircleBorder(),
                              onTap: busy ? null : () => setState(() => media.removeAt(i)),
                              child: const Padding(padding: EdgeInsets.all(5), child: PIcon('x', size: 15, color: Colors.white, stroke: 2.4)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                ]),
              ],
              if (p.repostOf == null) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (place != null)
                    InputChip(
                      key: const ValueKey('ep-place'),
                      label: Text('📍 ${place!.$2}'),
                      onDeleted: busy ? null : () => setState(() => place = null),
                    ),
                  OutlinedButton.icon(
                    key: const ValueKey('ep-place-pick'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: busy
                        ? null
                        : () async {
                            final pl = await pickPlace(context);
                            if (pl != null && mounted) setState(() => place = pl);
                          },
                    icon: PIcon('pin', size: 18, color: c.ink),
                    label: Text(place == null ? 'ადგილის მითითება' : 'ადგილის შეცვლა'),
                  ),
                ]),
              ],
              if (p.poll != null)
                Padding(padding: const EdgeInsets.only(top: 12), child: Text('გამოკითხვა არ იცვლება, რომ მიცემული ხმები არ დაიკარგოს.', style: TextStyle(color: c.muted, fontSize: 13))),
              Padding(padding: const EdgeInsets.only(top: 8), child: Text('რედაქტირებულ პოსტთან გამოჩნდება „რედაქტირებული“.', style: TextStyle(color: c.muted, fontSize: 13))),
            ]),
          ),
          MentionSuggest(field: field),
        ]),
      ),
    );
  }
}

/// A photo picked for a post, edited first when asked (the editor's result, or the photo as it was).
Future<Uint8List> editPicked(BuildContext context, Uint8List src) async => await photoEdit(context, src) ?? src;
