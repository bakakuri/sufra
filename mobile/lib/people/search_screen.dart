import 'dart:async';

import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'person_screen.dart';

/// Finding people by name or @username, as you type.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final field = TextEditingController();
  Timer? _wait;
  List<Profile>? found;
  bool busy = false;
  Object? error;
  int _gen = 0;

  @override
  void dispose() {
    _wait?.cancel();
    field.dispose();
    super.dispose();
  }

  void _changed(String q) {
    _wait?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        found = null;
        busy = false;
        error = null;
      });
      return;
    }
    _wait = Timer(const Duration(milliseconds: 320), () => _run(q.trim()));
  }

  Future<void> _run(String q) async {
    final g = ++_gen;
    setState(() => busy = true);
    try {
      final r = await context.app.api.search(q.startsWith('@') ? q.substring(1) : q);
      if (!mounted || g != _gen) return;
      setState(() {
        found = r;
        busy = false;
        error = null;
      });
    } catch (e) {
      if (!mounted || g != _gen) return;
      setState(() {
        busy = false;
        error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: 0,
        title: TextField(
          controller: field,
          autofocus: true,
          onChanged: _changed,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'სახელი ან @username',
            isDense: true,
            prefixIcon: Padding(padding: const EdgeInsets.all(11), child: PIcon('search', size: 20, color: c.muted)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: c.accent, width: 1.5)),
          ),
        ),
        actions: const [SizedBox(width: 14)],
      ),
      body: Column(children: [
        if (busy) LinearProgressIndicator(minHeight: 2, color: c.accent, backgroundColor: Colors.transparent),
        Expanded(
          child: error != null
              ? Empty(icon: 'search', title: 'ძებნა ვერ მოხერხდა', text: errText(error!))
              : found == null
                  ? Empty(icon: 'search', title: 'ვის ეძებ?', text: 'ჩაწერე სახელი ან მომხმარებლის სახელი.')
                  : found!.isEmpty
                      ? Empty(icon: 'user', title: 'ვერავინ ვიპოვე', text: '„${field.text.trim()}“ — სხვაგვარად სცადე.')
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: found!.length,
                          itemBuilder: (_, i) => PersonRow(p: found![i], onTap: () => openPage(context, PersonScreen(uid: found![i].id, initial: found![i]))),
                        ),
        ),
      ]),
    );
  }
}

/// A person in a list: picture, name, a line under it and something on the right.
class PersonRow extends StatelessWidget {
  const PersonRow({super.key, required this.p, required this.onTap, this.sub, this.trailing, this.size = 50});
  final Profile p;
  final VoidCallback onTap;
  final String? sub;
  final Widget? trailing;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final line = sub ?? [if ((p.username ?? '').isNotEmpty) '@${p.username}', if ((p.city ?? '').isNotEmpty) p.city!].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Avatar(p: p, size: size, online: p.online),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              NameLine(p, size: 15.5),
              if (line.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 13.5)),
                ),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      ),
    );
  }
}
