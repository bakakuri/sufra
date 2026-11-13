// Translation, as the site does it (js/lib-lang.js, core.js tx/translate): the language is told on the phone, and
// words in another language get a "თარგმნა" under them that asks the server's translate function; Georgian
// written in Latin letters ("gamarjoba") is turned into Georgian letters.
import 'package:flutter/material.dart';

import '../data/stores.dart';
import 'icons.dart';
import 'rich_body.dart';
import 'theme.dart';
import 'widgets.dart';

/// the languages' names in Georgian
const langNames = {
  'ka': 'ქართული', 'en': 'ინგლისური', 'ru': 'რუსული', 'de': 'გერმანული', 'tr': 'თურქული', 'uk': 'უკრაინული', 'hy': 'სომხური',
  'az': 'აზერბაიჯანული', 'fr': 'ფრანგული', 'es': 'ესპანური', 'it': 'იტალიური', 'ar': 'არაბული', 'he': 'ებრაული', 'el': 'ბერძნული',
  'zh': 'ჩინური', 'ja': 'იაპონური', 'ka-lat': 'ქართული ლათინური ასოებით', 'xx': 'უცხო ენა',
};

final _stops = {
  for (final e in {
    'en': 'the and is are to of you it for this that with have was be on at what just not my we they there can do your so me no',
    'de': 'der die das und ist ich nicht mit ein eine zu wir auf für sehr auch es sie du mal habe heute',
    'fr': 'le la les et est je pas une des que pour avec très nous vous mais',
    'es': 'el los que es y en muy para con pero gracias por las una hola',
    'it': 'il che è di per sono molto grazie ciao una gli della non',
    'tr': 've bir bu çok ne için ben sen değil var yok merhaba selamlar teşekkürler da de mi',
    'az': 'və bir bu çox nə üçün mən sən deyil var yox salam',
  }.entries)
    e.key: e.value.split(' ').toSet(),
};

final _kaWords = ('gamarjoba gaumarjos rogor xar khar kargad kargi madloba gmadlob ra aris var ar ki sad dges dghes xval khval chven tqven shen vin '
        'ras aqvs maqvs gaq genacvale dzalian sul aq iq mivdivar modixar modis vnaxot kai ho ara didi patara gogo bichi minda ginda mikvars '
        'miyvars vici xo xom yvelas yvela gilocav dabadebis dge lamazi dzmao dzmebo vinme araperi aravin iyo unda sheidzleba shegidzlia chemtan '
        'ertad tovli ukve mosulia gadixar mome rame rato ratom imitom roca sanam ese egrevea nu me')
    .split(' ')
    .toSet();

final _latin = RegExp(r'[A-Za-zÀ-ɏ]');
final _words = RegExp(r"[a-zÀ-ɏ’']+");
final _kaEnd = RegExp(r'(?:eba|oba|ebi|shi|uli|ivar|ixar|ulia)$|^(?:gv|dz|mk|tsk|mts)');

/// The language of [t]: 'ka', 'ka-lat' (Georgian in Latin letters), a code from [langNames], or 'xx'.
String detectLang(String t) {
  var ka = 0, cy = 0, la = 0, hy = 0, ar = 0, he = 0, el = 0, cj = 0;
  for (final r in t.runes) {
    if (r >= 0x10A0 && r <= 0x10FF || r >= 0x1C90 && r <= 0x1CBF) {
      ka++;
    } else if (r >= 0x400 && r <= 0x4FF) {
      cy++;
    } else if (_latin.hasMatch(String.fromCharCode(r))) {
      la++;
    } else if (r >= 0x530 && r <= 0x58F) {
      hy++;
    } else if (r >= 0x600 && r <= 0x6FF) {
      ar++;
    } else if (r >= 0x590 && r <= 0x5FF) {
      he++;
    } else if (r >= 0x370 && r <= 0x3FF) {
      el++;
    } else if (r >= 0x3040 && r <= 0x9FFF) {
      cj++;
    }
  }
  final top = [ka, cy, la, hy, ar, he, el, cj].reduce((a, b) => a > b ? a : b);
  if (top == 0 || top == ka) return 'ka';
  if (top == cy) return RegExp('[іїєґ]', caseSensitive: false).hasMatch(t) ? 'uk' : 'ru';
  if (top == hy) return 'hy';
  if (top == ar) return 'ar';
  if (top == he) return 'he';
  if (top == el) return 'el';
  if (top == cj) return RegExp('[぀-ヿ]').hasMatch(t) ? 'ja' : 'zh';
  final words = _words.allMatches(t.toLowerCase()).map((m) => m.group(0)!).toList();
  var kaHits = 0;
  for (final w in words) {
    if (_kaWords.contains(w) || (RegExp(r'^[a-z]+$').hasMatch(w) && _kaEnd.hasMatch(w))) kaHits++;
  }
  var best = 'xx', bs = 0;
  for (final e in _stops.entries) {
    final n = words.where(e.value.contains).length;
    if (n > bs) {
      bs = n;
      best = e.key;
    }
  }
  if (RegExp('[ğışİ]').hasMatch(t) || (t.contains('ç') && best != 'fr')) {
    best = RegExp('[əƏ]').hasMatch(t) ? 'az' : 'tr';
  } else if (RegExp('[äöüß]').hasMatch(t) && best != 'tr') {
    best = 'de';
  }
  if (kaHits / (words.isEmpty ? 1 : words.length) >= .34 && kaHits >= bs) return 'ka-lat';
  return best;
}

const _tl = {
  'sh': 'შ', 'ch': 'ჩ', 'zh': 'ჟ', 'kh': 'ხ', 'gh': 'ღ', 'ts': 'ც', 'dz': 'ძ', 'ph': 'ფ', 'th': 'თ', 'a': 'ა', 'b': 'ბ', 'g': 'გ', 'd': 'დ',
  'e': 'ე', 'v': 'ვ', 'z': 'ზ', 't': 'თ', 'i': 'ი', 'k': 'კ', 'l': 'ლ', 'm': 'მ', 'n': 'ნ', 'o': 'ო', 'p': 'პ', 'r': 'რ', 's': 'ს', 'u': 'უ',
  'f': 'ფ', 'q': 'ქ', 'y': 'ყ', 'c': 'ც', 'w': 'წ', 'x': 'ხ', 'j': 'ჯ', 'h': 'ჰ',
};

/// Georgian written in Latin letters, in Georgian letters.
String translit(String s) {
  final l = s.toLowerCase(), o = StringBuffer();
  for (var i = 0; i < l.length;) {
    if (i + 2 <= l.length && _tl.containsKey(l.substring(i, i + 2))) {
      o.write(_tl[l.substring(i, i + 2)]);
      i += 2;
      continue;
    }
    o.write(_tl[l[i]] ?? (i < s.length ? s[i] : l[i]));
    i++;
  }
  return o.toString();
}

/// translations already made this session: the words → (the translation, the line under it)
final _done = <String, (String, String)>{};

/// The words in Georgian: the server's translation, or the letters turned for 'ka-lat' when it cannot.
Future<(String, String)> translateText(BuildContext context, String src) async {
  final hit = _done[src];
  if (hit != null) return hit;
  final l = detectLang(src);
  final app = context.app;
  try {
    final (t, from) = await app.api.translate(src, l, 'ka');
    final name = l != 'xx' && langNames[l] != null ? langNames[l]! : (from ?? 'უცხო ენა');
    return _done[src] = (t, '${l == 'ka-lat' ? 'გადაყვანილია ქართულ ასოებზე' : 'თარგმნილია ავტომატურად'} · ორიგინალი: $name');
  } catch (_) {
    if (l == 'ka-lat') return _done[src] = (translit(src), 'გადაყვანილია ქართულ ასოებზე');
    rethrow;
  }
}

/// A post's, a comment's or a message's words, with "თარგმნა" under them when they are not in Georgian.
class TranslatableBody extends StatefulWidget {
  const TranslatableBody(this.text, {super.key, this.maxLines, this.style, this.compact = false});
  final String text;
  final int? maxLines;
  final TextStyle? style;

  /// a small globe beside the words instead of the labelled button (comments, bubbles)
  final bool compact;

  @override
  State<TranslatableBody> createState() => _TranslatableBodyState();
}

class _TranslatableBodyState extends State<TranslatableBody> {
  (String, String)? shown;
  bool busy = false;
  late String lang = detectLang(widget.text);

  @override
  void didUpdateWidget(TranslatableBody old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      lang = detectLang(widget.text);
      shown = null;
    }
  }

  Future<void> _tap() async {
    if (shown != null) {
      setState(() => shown = null);
      return;
    }
    setState(() => busy = true);
    try {
      final r = await translateText(context, widget.text);
      if (mounted) setState(() => shown = r);
    } catch (e) {
      if (mounted) toast(context, 'თარგმნა ახლა ვერ მოხერხდა. სცადე ცოტა ხანში');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = RichBody(shown?.$1 ?? widget.text, maxLines: widget.maxLines, style: widget.style);
    if (lang == 'ka') return body;
    final c = context.pc, on = shown != null;
    final label = on ? 'ორიგინალი' : (busy ? 'ითარგმნება…' : (lang == 'ka-lat' ? 'ქართული ასოებით' : 'თარგმნა'));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      body,
      if (on) Padding(padding: const EdgeInsets.only(top: 4), child: Text(shown!.$2, style: TextStyle(color: c.muted, fontSize: 12, fontStyle: FontStyle.italic))),
      Semantics(
        button: true,
        selected: on,
        label: lang == 'ka-lat' ? 'ქართულ ასოებზე გადაყვანა' : 'თარგმნა · ${langNames[lang] ?? 'უცხო ენა'}',
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey('translate'),
          borderRadius: BorderRadius.circular(8),
          onTap: busy ? null : _tap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: widget.compact ? 3 : 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              PIcon('globe', size: widget.compact ? 13 : 15, color: c.accent),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: widget.compact ? 12 : 13)),
            ]),
          ),
        ),
      ),
    ]);
  }
}
