import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../media/player.dart';
import '../media/video_tools.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

String mmss(double s) {
  final t = s.round();
  return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
}

String mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

/// A new clip: a video from the phone (made lighter when it is big), a few words, one button.
/// The video is chosen as the screen opens; nothing chosen, the screen closes again.
class ClipComposer extends StatefulWidget {
  const ClipComposer({super.key});
  @override
  State<ClipComposer> createState() => _ClipComposerState();
}

class _ClipComposerState extends State<ClipComposer> {
  final field = TextEditingController();
  VideoReady? video;
  Player? preview;
  double? preparing;
  bool busy = false;
  String? stage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick(first: true));
  }

  @override
  void dispose() {
    if (preparing != null) cancelVideoPrep();
    preview?.dispose();
    field.dispose();
    super.dispose();
  }

  Future<void> _pick({bool first = false}) async {
    String? path;
    try {
      path = await videoPicker();
    } catch (_) {
      if (mounted) toast(context, 'ვიდეო ვერ გავხსენი');
    }
    if (!mounted) return;
    if (path == null) {
      if (first && video == null) Navigator.of(context).pop();
      return;
    }
    setState(() => preparing = 0);
    try {
      final v = await videoPrep(path, (x) {
        if (mounted) setState(() => preparing = x);
      });
      if (!mounted) return;
      preview?.dispose();
      final pl = makePlayer(v.path)..mute(true);
      setState(() {
        video = v;
        preview = pl;
        preparing = null;
      });
      pl.play();
    } catch (e) {
      if (!mounted) return;
      setState(() => preparing = null);
      toast(context, e is VideoTooBig ? e.toString() : 'ვიდეო ვერ მომზადდა');
      if (video == null && first) Navigator.of(context).pop();
    }
  }

  Future<void> _publish() async {
    final v = video;
    if (v == null || busy) return;
    final app = context.app;
    setState(() {
      busy = true;
      stage = 'იტვირთება · ${mb(v.bytes)} მბ…';
    });
    preview?.pause();
    try {
      final m = await app.api.uploadVideo(v);
      if (mounted) setState(() => stage = 'ქვეყნდება…');
      final p = await app.api.createClip(field.text.trim(), m);
      if (mounted) Navigator.of(context).pop(p);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        stage = null;
      });
      toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, v = video, pl = preview;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: c.surface,
        appBar: AppBar(
          toolbarHeight: 60,
          titleSpacing: 0,
          leading: IconBtn('x', label: 'დახურვა', onTap: busy ? null : () => Navigator.of(context).maybePop()),
          title: const Text('ახალი კლიპი'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: v == null || busy || preparing != null ? null : _publish,
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
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420, maxWidth: 300),
                  child: AspectRatio(
                    aspectRatio: v != null && v.w > 0 && v.h > 0 ? (v.w / v.h).clamp(.5, 1.8).toDouble() : 9 / 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: preparing != null || pl == null
                          ? ColoredBox(
                              color: Colors.black,
                              child: Center(
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  SizedBox.square(
                                    dimension: 34,
                                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white, value: preparing == null || preparing == 0 ? null : preparing),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(preparing == null ? 'აირჩიე ვიდეო' : 'მზადდება · ${(preparing! * 100).round()}%',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            )
                          : Stack(fit: StackFit.expand, children: [
                              VideoBox(player: pl, poster: null, fit: BoxFit.cover),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: ListenableBuilder(
                                  listenable: pl,
                                  builder: (_, __) => _Round(
                                    icon: _muted ? 'voloff' : 'vol',
                                    label: _muted ? 'ხმის ჩართვა' : 'ხმის გამორთვა',
                                    onTap: () => setState(() {
                                      _muted = !_muted;
                                      pl.mute(_muted);
                                    }),
                                  ),
                                ),
                              ),
                            ]),
                    ),
                  ),
                ),
              ),
              if (v != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: Text([if (v.dur > 0) mmss(v.dur), '${mb(v.bytes)} მბ', if (v.w > 0) '${v.w}×${v.h}'].join(' · '),
                      style: TextStyle(color: c.muted, fontSize: 13.5)),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: busy || preparing != null ? null : () => _pick(),
                    icon: PIcon('repost', size: 18, color: c.accent),
                    label: const Text('სხვა ვიდეო'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: field,
                enabled: !busy,
                minLines: 2,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'რაზეა კლიპი? #ჰეშთეგები'),
              ),
              if (stage != null) Text(stage!, style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }

  bool _muted = true;
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.label, required this.onTap});
  final String icon, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0x88000000), shape: BoxShape.circle),
            child: PIcon(icon, size: 20, color: Colors.white),
          ),
        ),
      );
}
