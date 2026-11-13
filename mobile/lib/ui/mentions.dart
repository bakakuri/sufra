// @mentions (feed.js mentionable): typing "@" in a post, a comment or a message offers friends and then people by
// their username; a touch writes "@username " in place of what was typed.
import 'dart:async';

import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../profile/profile.dart';
import 'theme.dart';
import 'widgets.dart';

final _at = RegExp(r'(^|[^A-Za-z0-9_.@])@([A-Za-z0-9_.]{0,24})$');

/// The people to mention, in a row over the field; nothing while no "@" is being typed.
class MentionSuggest extends StatefulWidget {
  const MentionSuggest({super.key, required this.field});
  final TextEditingController field;
  @override
  State<MentionSuggest> createState() => _MentionSuggestState();
}

class _MentionSuggestState extends State<MentionSuggest> {
  List<Profile> list = const [];
  String? _pre;
  Timer? _wait;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    widget.field.addListener(_changed);
  }

  @override
  void dispose() {
    widget.field.removeListener(_changed);
    _wait?.cancel();
    super.dispose();
  }

  /// what is typed after "@" just before the cursor, or null
  String? _token() {
    final v = widget.field.value;
    final at = v.selection.isValid ? v.selection.baseOffset.clamp(0, v.text.length) : v.text.length;
    return _at.firstMatch(v.text.substring(0, at))?.group(2);
  }

  void _changed() {
    final pre = _token()?.toLowerCase();
    if (pre == _pre) return;
    _pre = pre;
    _wait?.cancel();
    if (pre == null) {
      if (list.isNotEmpty) setState(() => list = const []);
      return;
    }
    final app = context.app, me = context.me.id;
    final friends = app.friends.friends.toSet();
    bool fits(Profile p) => (p.username ?? '').isNotEmpty && p.id != me && ((p.username ?? '').toLowerCase().startsWith(pre) || p.name.toLowerCase().split(' ').any((w) => w.startsWith(pre)));
    final local = [for (final id in friends) if (app.people[id] case final p? when fits(p)) p];
    setState(() => list = local.take(6).toList());
    if (pre.length < 2) return;
    final g = ++_gen;
    _wait = Timer(const Duration(milliseconds: 250), () async {
      try {
        final r = await app.api.mentionPeople(pre);
        if (!mounted || g != _gen) return;
        final all = [...local];
        for (final p in r) {
          app.people.put(p);
          if (!all.any((x) => x.id == p.id)) all.add(p);
        }
        setState(() => list = all.take(6).toList());
      } catch (_) {}
    });
  }

  void _pick(Profile p) {
    final v = widget.field.value;
    final at = v.selection.isValid ? v.selection.baseOffset.clamp(0, v.text.length) : v.text.length;
    final before = v.text.substring(0, at).replaceFirst(RegExp(r'@([A-Za-z0-9_.]{0,24})$'), '@${p.username} ');
    widget.field.value = TextEditingValue(text: before + v.text.substring(at), selection: TextSelection.collapsed(offset: before.length));
    _pre = null;
    setState(() => list = const []);
  }

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return const SizedBox.shrink();
    final c = context.pc;
    return Container(
      key: const ValueKey('mentions'),
      height: 58,
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7), children: [
        for (final p in list)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: c.sunk,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                key: ValueKey('ment-${p.id}'),
                borderRadius: BorderRadius.circular(22),
                onTap: () => _pick(p),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Avatar(p: p, size: 34),
                    const SizedBox(width: 7),
                    Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('@${p.username}', style: TextStyle(color: c.muted, fontSize: 11.5)),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
