// The site's stickers (js/stickers.js) drawn on the phone, and the picker: a row of smileys to put into the words and
// the stickers that go as they are (a comment or a message of their own).
import 'package:flutter/material.dart';

import 'mini_svg.dart';
import 'sticker_data.dart';
import 'theme.dart';

export 'sticker_data.dart' show stickers, stickerLabel, stickerSvg;

/// One sticker, [size] across.
class StickerView extends StatelessWidget {
  const StickerView(this.k, {super.key, this.size = 120});
  final String k;
  final double size;
  @override
  Widget build(BuildContext context) {
    final svg = stickerSvg(k);
    return Semantics(
      image: true,
      label: stickerLabel(k) ?? 'სტიკერი',
      child: SizedBox.square(dimension: size, child: svg == null ? Center(child: Text('✨', style: TextStyle(fontSize: size * .5))) : MiniSvg(svg, view: const Size(120, 120))),
    );
  }
}

/// smileys offered above the stickers (the phone's keyboard has the rest)
const quickEmoji = ['😀', '😂', '🥰', '😍', '😎', '🤔', '😢', '😡', '👍', '👏', '🙏', '❤️', '🔥', '🎉', '💯', '🌹', '🍷', '🥟', '🇬🇪', '✨'];

/// What was picked: a smiley to add to the words, or a sticker to send.
typedef StickerPick = ({String? emoji, String? sticker});

/// The smileys and stickers; null when closed (back closes it).
Future<StickerPick?> pickSticker(BuildContext context, {bool emoji = true}) => showModalBottomSheet<StickerPick>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) {
        final c = s.pc;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(s).height * .7),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (emoji) ...[
                  const Padding(padding: EdgeInsets.fromLTRB(6, 0, 6, 6), child: Text('სმაილები', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                  Wrap(children: [
                    for (final e in quickEmoji)
                      InkResponse(
                        key: ValueKey('emo-$e'),
                        radius: 24,
                        onTap: () => Navigator.of(s).pop((emoji: e, sticker: null)),
                        child: SizedBox.square(dimension: 46, child: Center(child: Text(e, style: const TextStyle(fontSize: 27)))),
                      ),
                  ]),
                  const SizedBox(height: 10),
                ],
                const Padding(padding: EdgeInsets.fromLTRB(6, 0, 6, 8), child: Text('სტიკერები', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  children: [
                    for (final st in stickers)
                      Material(
                        color: c.sunk,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          key: ValueKey('stk-${st.$1}'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.of(s).pop((emoji: null, sticker: st.$1)),
                          child: Padding(padding: const EdgeInsets.all(6), child: StickerView(st.$1)),
                        ),
                      ),
                  ],
                ),
              ]),
            ),
          ),
        );
      },
    );
