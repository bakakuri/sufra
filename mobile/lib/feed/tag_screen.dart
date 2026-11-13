// A #topic's page (home.js PG.tag): every post with it, newest first; following it brings more of it to "შენთვის",
// and "პოსტი" starts one with the tag already written.
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../ui/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'compose_screen.dart';
import 'post_card.dart';

class TagScreen extends StatefulWidget {
  const TagScreen({super.key, required this.tag});
  final String tag;
  @override
  State<TagScreen> createState() => _TagScreenState();
}

class _TagScreenState extends State<TagScreen> {
  List<Post>? posts;
  Object? error;
  bool? follows;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final app = context.app;
    app.api.tagFollows().then((s) {
      if (mounted) setState(() => follows = s.contains(widget.tag));
    }).catchError((_) {
      if (mounted) setState(() => follows = false);
    });
    try {
      final r = await app.api.postsTagged(widget.tag);
      await app.posts.load(r);
      if (mounted) setState(() => posts = r);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _follow() async {
    final on = follows != true, app = context.app;
    setState(() => follows = on);
    try {
      await app.api.followTags([widget.tag], on);
      if (mounted) toast(context, on ? '#${widget.tag} გამოწერილია. მეტს ნახავ „შენთვის“ ფიდში' : 'გამოწერა გაუქმდა');
    } catch (e) {
      if (!mounted) return;
      setState(() => follows = !on);
      toast(context, errText(e));
    }
  }

  Future<void> _write() async {
    final p = await openPage<Post>(context, ComposeScreen(text: ' #${widget.tag}'), full: true);
    if (p != null && mounted && posts != null) setState(() => posts = [p, ...posts!]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, list = posts;
    return Scaffold(
      appBar: peeraBar(context, title: '#${widget.tag}', actions: [
        if (follows != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: follows!
                ? OutlinedButton(
                    key: const ValueKey('tag-follow'),
                    onPressed: _follow,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
                    child: const Text('გამოწერილია'),
                  )
                : FilledButton(
                    key: const ValueKey('tag-follow'),
                    onPressed: _follow,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
                    child: const Text('გამოწერა'),
                  ),
          ),
        IconBtn('plus', key: const ValueKey('tag-write'), label: 'პოსტი ამ ჰეშთეგით', onTap: _write),
        const SizedBox(width: 6),
      ]),
      body: error != null && list == null
          ? Empty(icon: 'hash', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'ხელახლა ცდა', onAction: () {
              setState(() => error = null);
              _load();
            })
          : list == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text('${list.length} პოსტი', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
                    ),
                    if (list.isEmpty)
                      Empty(icon: 'hash', title: 'ჯერ არავის დაუწერია', text: 'იყავი პირველი ამ ჰეშთეგით.', action: 'პოსტის დაწერა', onAction: _write)
                    else
                      for (final p in list)
                        PostCard(
                          key: ValueKey('tagpost-${p.id}'),
                          post: p,
                          onDeleted: () => setState(() => posts = [for (final x in posts!) if (x.id != p.id) x]),
                        ),
                  ]),
                ),
    );
  }
}
