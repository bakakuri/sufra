import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../shell/tab_bar.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/widgets.dart';
import 'clip_composer.dart';
import 'clip_feed.dart';

/// The clips tab: short videos one to a screen; "+" uploads one.
class ClipsTab extends StatefulWidget {
  const ClipsTab({super.key});
  @override
  State<ClipsTab> createState() => _ClipsTabState();
}

class _ClipsTabState extends State<ClipsTab> {
  final posts = <Post>[];
  bool loading = true, more = false, done = false;
  Object? error;
  bool _started = false;
  final visible = ValueNotifier<bool>(false);
  late final AppState app;
  final _feed = GlobalKey<ClipFeedState>();
  int _gen = 0;

  static final _index = tabs.indexWhere((t) => t.id == 'clips');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    app = context.app;
    app.tab.addListener(_tab);
    _tab();
    _load();
  }

  @override
  void dispose() {
    app.tab.removeListener(_tab);
    visible.dispose();
    super.dispose();
  }

  void _tab() => visible.value = app.tab.value == _index;

  Future<void> _load() async {
    final g = ++_gen;
    setState(() {
      loading = posts.isEmpty;
      error = null;
    });
    try {
      final r = await app.api.clips();
      await app.posts.load(r);
      if (!mounted || g != _gen) return;
      setState(() {
        posts
          ..clear()
          ..addAll(r);
        loading = false;
        done = r.length < 12;
      });
    } catch (e) {
      if (mounted && g == _gen) {
        setState(() {
          loading = false;
          error = e;
        });
      }
    }
  }

  Future<void> _more() async {
    if (more || done || posts.isEmpty) return;
    more = true;
    try {
      final r = await app.api.clips(before: posts.last.cursor);
      await app.posts.load(r);
      if (!mounted) return;
      setState(() {
        final have = posts.map((p) => p.id).toSet();
        posts.addAll(r.where((p) => have.add(p.id)));
        done = r.length < 12;
      });
    } catch (_) {}
    more = false;
  }

  Future<void> _upload() async {
    final p = await (_feed.currentState?.cover<Post>(() => openPage<Post>(context, const ClipComposer(), full: true)) ??
        openPage<Post>(context, const ClipComposer(), full: true));
    if (p == null || !mounted) return;
    await app.posts.load([p]);
    setState(() => posts.insert(0, p));
    toast(context, 'კლიპი გამოქვეყნდა');
  }

  @override
  Widget build(BuildContext context) {
    final top = SafeArea(
      bottom: false,
      child: SizedBox(
        height: 52,
        child: Row(children: [
          const SizedBox(width: 16),
          const Text('კლიპები', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 6, color: Colors.black45)])),
          const Spacer(),
          IconBtn('plus', label: 'კლიპის ატვირთვა', color: Colors.white, onTap: _upload),
          const SizedBox(width: 4),
        ]),
      ),
    );
    Widget body;
    if (loading) {
      body = const Center(child: SizedBox.square(dimension: 30, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white)));
    } else if (posts.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const PIcon('clips', size: 48, color: Colors.white70),
            const SizedBox(height: 14),
            Text(error != null ? 'ვერ ჩაიტვირთა' : 'კლიპები ჯერ არ არის',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(error != null ? errText(error!) : 'ატვირთე პირველი მოკლე ვიდეო და აქ გამოჩნდება.',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14.5, height: 1.4)),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 20)),
              onPressed: error != null ? _load : _upload,
              icon: PIcon(error != null ? 'repost' : 'plus', size: 20, color: Colors.white),
              label: Text(error != null ? 'ხელახლა ცდა' : 'კლიპის ატვირთვა'),
            ),
          ]),
        ),
      );
    } else {
      body = ClipFeed(key: _feed, posts: posts, visible: visible, onMore: _more, top: top);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: posts.isEmpty ? Stack(children: [Positioned.fill(child: body), Positioned(left: 0, right: 0, top: 0, child: top)]) : body,
      ),
    );
  }
}
