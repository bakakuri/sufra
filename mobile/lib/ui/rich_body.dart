import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

final _marks = RegExp(r'(https?://[^\s]+)|(#[\p{L}\p{N}_]+)|(@[a-zA-Z0-9_.]{3,24})', unicode: true);

/// A post's or a comment's words: links open, #topics and @names in colour; long text folds under "მეტი".
class RichBody extends StatefulWidget {
  const RichBody(this.text, {super.key, this.maxLines, this.style});
  final String text;

  /// folded to this many lines until "მეტი"; null shows it all
  final int? maxLines;
  final TextStyle? style;

  @override
  State<RichBody> createState() => _RichBodyState();
}

class _RichBodyState extends State<RichBody> {
  bool open = false;
  final _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  TextSpan _span(TextStyle base, Color accent) {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final out = <InlineSpan>[];
    var at = 0;
    for (final m in _marks.allMatches(widget.text)) {
      if (m.start > at) out.add(TextSpan(text: widget.text.substring(at, m.start)));
      final s = m.group(0)!;
      if (m.group(1) != null) {
        final url = s.replaceFirst(RegExp(r'[.,;:!?)»"]+$'), '');
        final tail = s.substring(url.length);
        final tap = TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        _taps.add(tap);
        out.add(TextSpan(text: url, style: TextStyle(color: accent, decoration: TextDecoration.underline, decorationColor: accent.withValues(alpha: .5)), recognizer: tap));
        if (tail.isNotEmpty) out.add(TextSpan(text: tail));
      } else {
        out.add(TextSpan(text: s, style: TextStyle(color: accent, fontWeight: FontWeight.w600)));
      }
      at = m.end;
    }
    if (at < widget.text.length) out.add(TextSpan(text: widget.text.substring(at)));
    return TextSpan(style: base, children: out);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final base = DefaultTextStyle.of(context).style.merge(TextStyle(fontSize: 15.5, height: 1.45, color: c.ink)).merge(widget.style);
    final span = _span(base, c.accent);
    final max = widget.maxLines;
    if (max == null) return Text.rich(span);
    return LayoutBuilder(builder: (context, box) {
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: base),
        maxLines: max,
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: box.maxWidth);
      final long = tp.didExceedMaxLines;
      tp.dispose();
      if (!long) return Text.rich(span);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(span, maxLines: open ? null : max, overflow: open ? TextOverflow.visible : TextOverflow.ellipsis),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => open = !open),
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(open ? 'მოკლედ' : 'მეტი', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 14.5)),
          ),
        ),
      ]);
    });
  }
}
