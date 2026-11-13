import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../feed/post_screen.dart';
import '../media/player.dart';
import '../media/video_tools.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// The row of stories at the top of the feed: yours first (or "+" to add one), then everyone's, the unseen ones ringed.
class StoriesBar extends StatelessWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app, me = context.me;
    return ListenableBuilder(
      listenable: Listenable.merge([app.stories, app.people]),
      builder: (context, _) {
        final st = app.stories, mine = st.mine, others = st.others;
        return SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
            children: [
              _Ring(
                key: const ValueKey('story-me'),
                p: me,
                label: mine == null ? 'დამატება' : 'შენი',
                state: mine == null ? _RingState.none : (mine.seen ? _RingState.seen : _RingState.fresh),
                plus: true,
                onTap: () => mine == null ? addStory(context) : openStories(context, [mine, ...others], 0),
                onPlus: () => addStory(context),
              ),
              for (var i = 0; i < others.length; i++)
                _Ring(
                  key: ValueKey('story-${others[i].author}'),
                  p: app.people[others[i].author] ?? Profile(id: others[i].author, name: '…'),
                  label: (app.people[others[i].author]?.name ?? '…').split(' ').first,
                  state: others[i].seen ? _RingState.seen : _RingState.fresh,
                  onTap: () => openStories(context, others, i),
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _RingState { none, fresh, seen }

class _Ring extends StatelessWidget {
  const _Ring({super.key, required this.p, required this.label, required this.state, required this.onTap, this.plus = false, this.onPlus});
  final Profile p;
  final String label;
  final _RingState state;
  final bool plus;
  final VoidCallback onTap;
  final VoidCallback? onPlus;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 76,
          child: Column(children: [
            SizedBox.square(
              dimension: 66,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 66,
                  height: 66,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: state == _RingState.fresh ? LinearGradient(begin: Alignment.bottomLeft, end: Alignment.topRight, colors: [c.gold, const Color(0xFFE5486F), c.accent]) : null,
                    border: state == _RingState.seen ? Border.all(color: c.line, width: 2) : null,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
                    child: Avatar(p: p, size: 54),
                  ),
                ),
                if (plus)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: GestureDetector(
                      onTap: onPlus,
                      child: Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle, border: Border.all(color: c.bg, width: 2.5)),
                        child: PIcon('plus', size: 14, color: c.onAccent, stroke: 2.8),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 5),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.ink, fontWeight: state == _RingState.fresh ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }
}

/// Whether a photo story moves on by itself after five seconds (the tests hold it still).
bool storyClock = true;

/// Opens the stories over everything, from person [start]; back closes them in one step.
Future<void> openStories(BuildContext context, List<StoryGroup> groups, int start, {String? title, int? highlight}) =>
    Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => AppScope(app: context.app, me: context.me, child: StoryViewer(groups: groups, start: start, title: title, highlight: highlight)),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .94, end: 1.0).animate(a), child: child)),
    ));

/// Adding a story: a photo from the phone or the camera, or a video. It is uploaded and shows in the bar.
Future<void> addStory(BuildContext context) async {
  final app = context.app;
  String? kind;
  await showChoices(context, [
    SheetItem('image', 'ფოტო გალერეიდან', () => kind = 'photo'),
    SheetItem('camera', 'გადაღება', () => kind = 'camera'),
    SheetItem('clips', 'ვიდეო', () => kind = 'video'),
  ]);
  if (kind == null || !context.mounted) return;
  try {
    if (kind == 'video') {
      final path = await videoPicker();
      if (path == null || !context.mounted) return;
      toast(context, 'ვიდეო მზადდება…');
      final v = await videoPrep(path, (_) {});
      if (context.mounted) toast(context, 'იტვირთება…');
      final m = await app.api.uploadVideo(v);
      await app.api.addStory(m.url, video: true);
    } else {
      final got = await photoSource(kind == 'camera');
      if (got.isEmpty || !context.mounted) return;
      toast(context, 'იტვირთება…');
      final url = await app.api.uploadStoryPhoto(await photoPrep(got.first));
      await app.api.addStory(url);
    }
    await app.stories.load();
    if (context.mounted) toast(context, 'ისტორია გამოქვეყნდა');
  } catch (e) {
    if (context.mounted) toast(context, e is VideoTooBig ? e.toString() : errText(e));
  }
}

/// Stories over the whole screen: bars for each one, five seconds a photo, a video to its end; a tap on the right
/// goes on, on the left back, a held finger pauses, a pull down closes. Others' stories take a reaction or an answer
/// (it goes to the chat); your own show who saw them and can be deleted.
class StoryViewer extends StatefulWidget {
  const StoryViewer({super.key, required this.groups, this.start = 0, this.title, this.highlight});
  final List<StoryGroup> groups;
  final int start;

  /// kept stories (a highlight, or one from my archive): shown under this name, not counted as seen, no answers
  final String? title;

  /// the highlight they are from (mine: a story can be taken out of it)
  final int? highlight;
  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  late int gi = widget.start;
  late int si = widget.groups[widget.start].firstUnseen;
  late final clock = AnimationController(vsync: this, duration: const Duration(seconds: 5))..addStatusListener(_done);
  Player? video;
  final reply = TextEditingController();
  final focus = FocusNode();
  final _sent = <String>{};
  bool held = false;
  double drag = 0;

  /// a short line in the middle ("❤️ გაეგზავნა"), so nothing covers the answer field
  String? note;
  Timer? _noteTimer;

  void _flash(String t) {
    _noteTimer?.cancel();
    setState(() => note = t);
    _noteTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => note = null);
    });
  }
  late final AppState app;
  bool _started = false;

  StoryGroup get g => widget.groups[gi];
  Story get s => g.list[si];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    app = context.app;
    focus.addListener(() => focus.hasFocus ? _hold(true) : _hold(false));
    _show();
  }

  @override
  void dispose() {
    _noteTimer?.cancel();
    clock.dispose();
    video?.removeListener(_videoTick);
    video?.dispose();
    reply.dispose();
    focus.dispose();
    super.dispose();
  }

  void _done(AnimationStatus st) {
    if (st == AnimationStatus.completed) _step(1);
  }

  void _show() {
    video?.removeListener(_videoTick);
    video?.dispose();
    video = null;
    clock.stop();
    clock.value = 0;
    if (widget.title == null) app.stories.seen(s);
    if (s.video) {
      final v = makePlayer(s.url, loop: false)..mute(false);
      v.addListener(_videoTick);
      video = v;
      if (!held) v.play();
    } else {
      clock.duration = const Duration(seconds: 5);
      if (!held && storyClock) clock.forward(from: 0);
    }
    setState(() {});
  }

  void _videoTick() {
    final v = video;
    if (v == null || !mounted) return;
    final d = v.duration.inMilliseconds;
    if (d > 0) clock.value = (v.position.inMilliseconds / d).clamp(0.0, .999).toDouble();
    if (v.ended || v.failed) {
      v.removeListener(_videoTick);
      Future.delayed(v.failed ? const Duration(seconds: 2) : Duration.zero, () {
        if (mounted && video == v) _step(1);
      });
    }
  }

  void _step(int d) {
    if (!mounted) return;
    var a = gi, b = si + d;
    if (b >= g.list.length) {
      a++;
      b = 0;
    } else if (b < 0) {
      a--;
      if (a < 0) {
        a = 0;
        b = 0;
      } else {
        b = widget.groups[a].list.length - 1;
      }
    }
    if (a >= widget.groups.length) {
      Navigator.of(context).maybePop();
      return;
    }
    if (a != gi && d > 0) b = widget.groups[a].firstUnseen;
    gi = a;
    si = b;
    _show();
  }

  void _hold(bool on) {
    held = on;
    if (on) {
      clock.stop();
      video?.pause();
    } else {
      if (s.video) {
        video?.play();
      } else if (clock.value < 1 && storyClock) {
        clock.forward();
      }
    }
  }

  Future<void> _react(String e) async {
    HapticFeedback.lightImpact();
    if (!_sent.add('${s.id}$e')) {
      _flash('${reactionGlyph(e)} უკვე გაგზავნილია');
      return;
    }
    final ok = await attempt(context, () => app.api.reactStory(s, e));
    if (!ok) {
      _sent.remove('${s.id}$e');
    } else if (mounted) {
      _flash('${reactionGlyph(e)} გაეგზავნა — ნახავ ჩატში');
    }
  }

  Future<void> _reply() async {
    final t = reply.text.trim();
    if (t.isEmpty) return;
    reply.clear();
    focus.unfocus();
    if (await attempt(context, () => app.api.replyStory(s, t)) && mounted) _flash('პასუხი გაიგზავნა — ნახავ ჩატში');
  }

  Future<void> _viewers() async {
    _hold(true);
    final story = s;
    final c = context.pc;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (sheet) => FutureBuilder<List<StoryWatcher>>(
        future: app.api.storyViewers(story.id).then((v) async {
          await app.people.ensure(v.map((x) => x.user));
          return v;
        }),
        builder: (context, snap) {
          final list = snap.data;
          return SafeArea(
            child: SizedBox(
              height: 380,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(list == null ? 'ნახვები' : 'ნახვები · ${list.length}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                Expanded(
                  child: list == null
                      ? (snap.hasError ? Center(child: Text(errText(snap.error!))) : const Center(child: CircularProgressIndicator(strokeWidth: 2.4)))
                      : list.isEmpty
                          ? Center(child: Text('ჯერ არავის უნახავს', style: TextStyle(color: c.muted)))
                          : ListView(children: [
                              for (final v in list)
                                ListTile(
                                  leading: Avatar(p: app.people[v.user] ?? Profile(id: v.user, name: '…'), size: 42),
                                  title: NameLine(app.people[v.user] ?? Profile(id: v.user, name: '…'), size: 15),
                                  trailing: v.reaction == null ? null : Text(reactionGlyph(v.reaction!), style: const TextStyle(fontSize: 22)),
                                ),
                            ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
    if (mounted) _hold(false);
  }

  Future<void> _delete() async {
    _hold(true);
    final story = s;
    if (!await confirm(context, title: 'წაიშალოს ისტორია?', yes: 'წაშლა', danger: true) || !mounted) {
      if (mounted) _hold(false);
      return;
    }
    if (!await attempt(context, () => app.api.deleteStory(story.id)) || !mounted) {
      if (mounted) _hold(false);
      return;
    }
    app.stories.removed(story.id);
    g.list.removeWhere((x) => x.id == story.id);
    toast(context, 'ისტორია წაიშალა');
    if (g.list.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    if (si >= g.list.length) si = g.list.length - 1;
    held = false;
    _show();
  }

  /// out of this highlight (it stays in the archive)
  Future<void> _unkeep() async {
    _hold(true);
    final story = s, item = story.itemId;
    if (item == null) return;
    if (!await confirm(context, title: 'რჩეულიდან ამოღება', text: 'ისტორია არქივში დარჩება, მხოლოდ ამ რჩეულიდან ამოიღება.', yes: 'ამოღება', danger: true) || !mounted) {
      if (mounted) _hold(false);
      return;
    }
    if (!await attempt(context, () => app.api.removeHighlightItem(item)) || !mounted) {
      if (mounted) _hold(false);
      return;
    }
    toast(context, 'ამოღებულია');
    Navigator.of(context).maybePop();
  }

  /// a story of mine into a highlight
  Future<void> _keep() async {
    _hold(true);
    final story = s;
    await pickHighlight(context, story.id);
    if (mounted) _hold(false);
  }

  Future<void> _post() async {
    final id = s.postId;
    if (id == null) return;
    _hold(true);
    final p = await app.api.post(id).catchError((_) => null);
    if (!mounted) return;
    if (p == null) {
      toast(context, 'ეს პოსტი აღარ არის ხელმისაწვდომი');
      _hold(false);
      return;
    }
    await app.posts.load([p]);
    if (mounted) await openPage(context, PostScreen(post: p), full: true);
    if (mounted) _hold(false);
  }

  @override
  Widget build(BuildContext context) {
    final mine = g.author == app.api.myId;
    final who = mine ? context.me : (app.people[g.author] ?? Profile(id: g.author, name: '…'));
    final pad = MediaQuery.paddingOf(context);
    final v = video;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: Transform.translate(
          offset: Offset(0, drag),
          child: Opacity(
            opacity: (1 - drag / 500).clamp(.3, 1.0).toDouble(),
            child: Stack(fit: StackFit.expand, children: [
              if (s.video && v != null) VideoBox(player: v, fit: BoxFit.contain) else PImage(s.url, fit: BoxFit.contain, background: Colors.black),
              // tap right: on; left: back; hold: pause; pull down: close
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _step(d.localPosition.dx < MediaQuery.sizeOf(context).width / 3 ? -1 : 1),
                onLongPressStart: (_) => _hold(true),
                onLongPressEnd: (_) => _hold(false),
                onVerticalDragUpdate: (d) => setState(() => drag = (drag + d.delta.dy).clamp(0.0, 400.0).toDouble()),
                onVerticalDragEnd: (d) {
                  if (drag > 110 || (d.primaryVelocity ?? 0) > 700) {
                    Navigator.of(context).maybePop();
                  } else {
                    setState(() => drag = 0);
                  }
                },
              ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x88000000), Color(0x00000000), Color(0x00000000), Color(0x88000000)], stops: [0, .2, .75, 1]),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: pad.top + 6,
                child: Column(children: [
                  // one bar for each story of this person
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: AnimatedBuilder(
                      animation: clock,
                      builder: (_, __) => Row(children: [
                        for (var k = 0; k < g.list.length; k++)
                          Expanded(
                            child: Container(
                              height: 2.6,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2)),
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: k < si ? 1 : (k == si ? clock.value : 0),
                                child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
                    child: Row(children: [
                      Avatar(p: who, size: 36),
                      const SizedBox(width: 9),
                      Flexible(
                        child: widget.title != null
                            ? Text(widget.title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))
                            : NameLine(who, size: 15, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(widget.title != null ? dayLabel(s.createdAt) : ago(s.createdAt), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const Spacer(),
                      if (widget.title != null) ...[
                        if (mine && widget.highlight != null && s.itemId != null)
                          IconBtn('trash', key: const ValueKey('hl-remove'), label: 'რჩეულიდან ამოღება', color: Colors.white, onTap: _unkeep),
                      ] else if (mine) ...[
                        IconBtn('eye', key: const ValueKey('story-views'), label: 'ვინ ნახა', color: Colors.white, onTap: _viewers),
                        IconBtn('star', key: const ValueKey('story-keep'), label: 'რჩეულებში დამატება', color: Colors.white, onTap: _keep),
                        IconBtn('trash', label: 'წაშლა', color: Colors.white, onTap: _delete),
                      ],
                      IconBtn('x', label: 'დახურვა', color: Colors.white, onTap: () => Navigator.of(context).maybePop()),
                    ]),
                  ),
                ]),
              ),
              if (note != null)
                Positioned(
                  left: 24,
                  right: 24,
                  top: MediaQuery.sizeOf(context).height * .42,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(20)),
                        child: Text(note!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                    ),
                  ),
                ),
              if (s.postId != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: pad.bottom + (mine || widget.title != null ? 28 : 128),
                  child: Center(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 42), backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 18)),
                      onPressed: _post,
                      icon: const PIcon('image', size: 19, color: Colors.black),
                      label: const Text('პოსტის ნახვა'),
                    ),
                  ),
                ),
              if (!mine && widget.title == null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                          for (final e in storyReactions)
                            Semantics(
                              button: true,
                              label: e == '🍷' ? 'კარგი იდეა' : e,
                              excludeSemantics: true,
                              child: GestureDetector(
                                key: ValueKey('story-react-$e'),
                                onTap: () => _react(e),
                                child: Padding(padding: const EdgeInsets.all(6), child: Text(reactionGlyph(e), style: const TextStyle(fontSize: 28))),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: reply,
                              focusNode: focus,
                              style: const TextStyle(color: Colors.white),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _reply(),
                              decoration: InputDecoration(
                                hintText: 'უპასუხე ${who.name}-ს…',
                                hintStyle: const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: const Color(0x33FFFFFF),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.white38)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.white)),
                              ),
                            ),
                          ),
                          IconBtn('send', key: const ValueKey('story-send'), label: 'გაგზავნა', color: Colors.white, onTap: _reply),
                        ]),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Into a highlight: one of mine, or a new one by name (people.js hlPick).
Future<void> pickHighlight(BuildContext context, int storyId) async {
  final app = context.app;
  List<Highlight> mine = const [];
  try {
    mine = await app.api.highlights(app.api.myId);
  } catch (_) {}
  if (!context.mounted) return;
  final name = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) {
      final c = s.pc;
      Future<void> add(int id, String title) async {
        try {
          final n = await app.api.addToHighlight(id, storyId);
          if (s.mounted) Navigator.of(s).pop();
          if (context.mounted) toast(context, n ? 'დაემატა რჩეულში „$title“' : 'ეს ისტორია უკვე ამ რჩეულშია');
        } catch (e) {
          if (s.mounted) toast(s, errText(e));
        }
      }

      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(s).bottom),
        child: SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
            const Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 10), child: Text('რჩეულებში დამატება', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            for (final h in mine)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: ClipOval(
                  child: SizedBox.square(
                    dimension: 42,
                    child: (h.cover ?? '').isNotEmpty ? PImage(h.cover!) : ColoredBox(color: c.sunk, child: Center(child: PIcon('star', size: 18, color: c.muted))),
                  ),
                ),
                title: Text(h.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: PIcon('plus', size: 20, color: c.accent),
                onTap: () => add(h.id, h.title),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('hl-new'),
                  controller: name,
                  maxLength: 24,
                  decoration: const InputDecoration(hintText: 'ახალი რჩეული, მაგ. ზღვა, კლასი', counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('hl-create'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () async {
                  final t = name.text.trim();
                  if (t.isEmpty) {
                    toast(s, 'დაარქვი სახელი');
                    return;
                  }
                  try {
                    final id = await app.api.newHighlight(t, mine.length);
                    await add(id, t);
                  } catch (e) {
                    if (s.mounted) toast(s, errText(e));
                  }
                },
                child: const Text('შექმნა'),
              ),
            ]),
          ]),
        ),
      );
    },
  );
}
