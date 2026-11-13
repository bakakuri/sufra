// "სად ხარ?" (places.js pickPlace): a place for a post, found by its name or among the ones nearby.
import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// the kinds of places, as the site names them (places.js PKINDS)
const placeKinds = {
  'restaurant': ('რესტორანი', '🍽'), 'cafe': ('კაფე', '☕'), 'bar': ('ბარი', '🍸'), 'winery': ('ბიბლიოთეკა', '📚'), 'hotel': ('სასტუმრო', '🏨'),
  'guesthouse': ('საოჯახო სასტუმრო', '🏡'), 'sight': ('ღირსშესანიშნაობა', '🏛'), 'nature': ('ბუნება', '⛰'), 'shop': ('მაღაზია', '🛍'), 'other': ('სხვა', '📍'),
};

/// The place picked (its id and name), or null.
Future<(int, String)?> pickPlace(BuildContext context) {
  final app = context.app, me = context.me;
  return showModalBottomSheet<(int, String)>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.pc.surface,
    builder: (s) => AppScope(app: app, me: me, child: const _PlacePicker()),
  );
}

class _PlacePicker extends StatefulWidget {
  const _PlacePicker();
  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  final field = TextEditingController();
  List<Map<String, dynamic>>? found;
  Object? error;
  Timer? _wait;
  int _gen = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _run();
  }

  @override
  void dispose() {
    _wait?.cancel();
    field.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final g = ++_gen;
    try {
      final r = await context.app.api.findPlaces(field.text.trim());
      if (mounted && g == _gen) {
        setState(() {
          found = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && g == _gen) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, list = found;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text('სად ხარ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey('pp-q'),
              controller: field,
              textInputAction: TextInputAction.search,
              onChanged: (_) {
                _wait?.cancel();
                _wait = Timer(const Duration(milliseconds: 300), _run);
              },
              decoration: InputDecoration(hintText: 'ადგილის სახელი', prefixIcon: Padding(padding: const EdgeInsets.all(12), child: PIcon('search', size: 20, color: c.muted))),
            ),
          ),
          Expanded(
            child: error != null
                ? Empty(icon: 'pin', title: 'ვერ ჩაიტვირთა', text: errText(error!))
                : list == null
                    ? const Center(child: CircularProgressIndicator())
                    : list.isEmpty
                        ? const Empty(icon: 'pin', title: 'ვერ ვიპოვე', text: 'სცადე სხვა სახელით.')
                        : ListView(padding: const EdgeInsets.only(top: 6, bottom: 12), children: [
                            for (final p in list)
                              Builder(builder: (_) {
                                final k = placeKinds['${p['kind']}'] ?? placeKinds['other']!, km = asNum(p['km']);
                                final sub = [k.$1, if ('${p['city'] ?? ''}'.isNotEmpty) '${p['city']}', if (km != null) km < 1 ? '${(km * 1000).round()} მ' : '${km.toStringAsFixed(1)} კმ'].join(' · ');
                                return ListTile(
                                  key: ValueKey('pp-${p['id']}'),
                                  leading: CircleAvatar(backgroundColor: c.sunk, child: Text(k.$2, style: const TextStyle(fontSize: 20))),
                                  title: Text('${p['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(sub, style: TextStyle(color: c.muted)),
                                  onTap: () => Navigator.of(context).pop((asInt(p['id']), '${p['name'] ?? ''}')),
                                );
                              }),
                          ]),
          ),
        ]),
      ),
    );
  }
}
