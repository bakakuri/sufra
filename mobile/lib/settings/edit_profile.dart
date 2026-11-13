// Editing my profile, field for field as on the site (js/people.js editprofile): the cover and the picture, name,
// @name, surname, about me, where I live, where I am from, abroad, a business account. Saved in one go; back with
// unsaved changes asks first.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/photos.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'frame_photo.dart';
import 'places.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final name = TextEditingController(), user = TextEditingController(), surname = TextEditingController();
  final bio = TextEditingController(), city = TextEditingController(), place = TextEditingController();
  final cityFocus = FocusNode();
  Map<String, dynamic>? row;
  Object? error;
  String region = '', abroad = '';
  bool business = false, busy = false;
  // a new picture: what it looks like now (still uploading) and where it went once uploaded
  Uint8List? avBytes, coverBytes;
  String? avUrl, coverUrl;
  bool avUp = false, coverUp = false;
  Map<String, Object?> _start = {};
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    for (final c in [name, user, surname, bio, city, place]) {
      c.dispose();
    }
    cityFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final m = await context.app.api.mySettings();
      if (!mounted) return;
      String t(String k) => '${m[k] ?? ''}';
      name.text = t('name');
      user.text = t('username');
      surname.text = t('surname');
      bio.text = t('bio');
      city.text = t('city');
      place.text = t('home_place');
      setState(() {
        row = m;
        region = homeRegions.contains(t('home_region')) ? t('home_region') : '';
        abroad = abroadCountries.contains(t('abroad')) ? t('abroad') : '';
        business = m['is_business'] == true;
        _start = _values();
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Map<String, Object?> _values() => {
        'name': name.text.trim(),
        'username': user.text.trim(),
        'surname': surname.text.trim().replaceAll(RegExp(r'\s+'), ' '),
        'bio': bio.text.trim(),
        'city': city.text.trim(),
        'home_region': region,
        'home_place': place.text.trim(),
        'abroad': abroad,
        'is_business': business,
      };

  bool get dirty {
    if (row == null) return false;
    if (avBytes != null || coverBytes != null) return true;
    final v = _values();
    return v.keys.any((k) => v[k] != _start[k]);
  }

  Future<void> _pick({required bool cover}) async {
    final app = context.app;
    List<Uint8List> got;
    try {
      got = await photoSource(false);
    } catch (_) {
      return;
    }
    if (got.isEmpty || !mounted) return;
    final f = await photoFrame(context, got.first,
        aspect: cover ? 16 / 9 : 1, max: cover ? 1400 : 640, title: cover ? 'ფონის ფოტო' : 'პროფილის ფოტო');
    if (f == null || !mounted) return;
    setState(() {
      if (cover) {
        coverBytes = f.bytes;
        coverUrl = null;
        coverUp = true;
      } else {
        avBytes = f.bytes;
        avUrl = null;
        avUp = true;
      }
    });
    try {
      final m = await app.api.uploadPhoto(PreparedPhoto(f.bytes, f.w, f.h));
      if (!mounted) return;
      setState(() => cover ? coverUrl = m.url : avUrl = m.url);
    } catch (e) {
      if (!mounted) return;
      setState(() => cover ? coverBytes = null : avBytes = null);
      toast(context, errText(e));
    } finally {
      if (mounted) setState(() => cover ? coverUp = false : avUp = false);
    }
  }

  Future<void> _save() async {
    if (busy || row == null) return;
    if (!(_form.currentState?.validate() ?? true)) return;
    if (avUp || coverUp) {
      toast(context, 'ფოტო ჯერ იტვირთება…');
      return;
    }
    final app = context.app, v = _values();
    final upd = <String, dynamic>{
      ...v,
      'name': (v['name'] as String).isEmpty ? '${row!['name'] ?? ''}' : v['name'],
      'username': (v['username'] as String).isEmpty ? null : v['username'],
      if (avUrl != null) 'avatar_url': avUrl,
      if (coverUrl != null) 'cover_url': coverUrl,
    };
    setState(() => busy = true);
    try {
      await app.api.updateMe(upd);
      await app.refreshMe?.call();
      if (!mounted) return;
      // still busy, so the page goes without asking about the changes
      toast(context, 'შენახულია');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, RegExp('unique|duplicate', caseSensitive: false).hasMatch('$e') ? 'ეს მომხმარებლის სახელი დაკავებულია' : errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, m = row;
    Widget body;
    if (m == null) {
      body = error != null
          ? Center(child: Empty(icon: 'user', title: 'ვერ ჩაიტვირთა', text: errText(error!), action: 'თავიდან', onAction: _load))
          : const Center(child: CircularProgressIndicator());
    } else {
      final me = Profile.fromJson(m), h = (me.hue % 360).toDouble();
      final cover = coverBytes != null
          ? Image.memory(coverBytes!, fit: BoxFit.cover, gaplessPlayback: true)
          : (me.coverUrl ?? '').isNotEmpty
              ? PImage(me.coverUrl!)
              : DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [HSLColor.fromAHSL(1, h, .7, .62).toColor(), HSLColor.fromAHSL(1, (h + 50) % 360, .62, .42).toColor()],
                    ),
                  ),
                );
      final avatar = avBytes != null
          ? ClipOval(child: Image.memory(avBytes!, width: 92, height: 92, fit: BoxFit.cover, gaplessPlayback: true))
          : Avatar(p: me, size: 92);
      Widget cam(String label) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const PIcon('camera', size: 16, color: Colors.white),
              if (label.isNotEmpty) ...[const SizedBox(width: 5), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))],
            ]),
          );
      Widget spin() => const Positioned.fill(child: ColoredBox(color: Color(0x55000000), child: Center(child: CircularProgressIndicator(color: Colors.white))));
      Widget head(String t) => Padding(
            padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
            child: Text(t, style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: .2)),
          );
      body = Form(
        key: _form,
        onChanged: () => setState(() {}),
        child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          SizedBox(
            height: 196,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 146,
                child: GestureDetector(
                  key: const ValueKey('ep-cover'),
                  onTap: () => _pick(cover: true),
                  child: Stack(fit: StackFit.expand, children: [
                    cover,
                    Positioned(right: 12, bottom: 10, child: cam('ფონი')),
                    if (coverUp) spin(),
                  ]),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 0,
                child: Semantics(
                  button: true,
                  label: 'პროფილის ფოტოს შეცვლა',
                  child: GestureDetector(
                    key: const ValueKey('ep-avatar'),
                    onTap: () => _pick(cover: false),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
                      child: Stack(children: [
                        avatar,
                        if (avUp) const Positioned.fill(child: ClipOval(child: ColoredBox(color: Color(0x55000000), child: Center(child: CircularProgressIndicator(color: Colors.white))))),
                        Positioned(right: 0, bottom: 0, child: cam('')),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              head('ძირითადი'),
              TextFormField(
                key: const ValueKey('ep-name'),
                controller: name,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'სახელი', counterText: ''),
                validator: (v) => (v ?? '').trim().isEmpty ? 'ჩაწერე სახელი' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('ep-user'),
                controller: user,
                maxLength: 24,
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                inputFormatters: [_UsernameFormatter()],
                decoration: const InputDecoration(labelText: 'მომხმარებლის სახელი', hintText: 'მაგ. giorgi', prefixText: '@', counterText: ''),
                validator: (v) {
                  final s = (v ?? '').trim();
                  return s.isEmpty || RegExp(r'^[a-z0-9_.]{3,24}$').hasMatch(s) ? null : '3-დან 24 სიმბოლომდე: ლათინური პატარა ასოები, ციფრები, „_“ და „.“';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('ep-surname'),
                controller: surname,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'გვარი', hintText: 'გვარის ჯგუფისთვის', counterText: ''),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('ep-bio'),
                controller: bio,
                maxLength: 300,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'ჩემ შესახებ', hintText: 'ორიოდე სიტყვა შენზე', alignLabelWithHint: true),
              ),
              head('სად ვარ'),
              RawAutocomplete<String>(
                textEditingController: city,
                focusNode: cityFocus,
                optionsBuilder: (v) {
                  final q = v.text.trim();
                  if (q.isEmpty) return const <String>[];
                  return georgianCities.where((x) => x.startsWith(q) && x != q).take(6);
                },
                onSelected: (_) => setState(() {}),
                fieldViewBuilder: (context, ctl, focus, submit) => TextFormField(
                  key: const ValueKey('ep-city'),
                  controller: ctl,
                  focusNode: focus,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'ქალაქი', hintText: 'მაგ. თბილისი', counterText: ''),
                  onFieldSubmitted: (_) => submit(),
                ),
                optionsViewBuilder: (context, select, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 6,
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260, maxWidth: 320),
                      child: ListView(padding: const EdgeInsets.symmetric(vertical: 6), shrinkWrap: true, children: [
                        for (final o in options) ListTile(dense: true, title: Text(o, style: const TextStyle(fontSize: 15)), onTap: () => select(o)),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('ep-region'),
                initialValue: region,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'მშობლიური კუთხე'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('—')),
                  for (final r in homeRegions) DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => region = v ?? ''),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('ep-place'),
                controller: place,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'სოფელი ან ქალაქი', hintText: 'მაგ. სიღნაღი', counterText: ''),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('ep-abroad'),
                initialValue: abroad,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'ემიგრაციაში ვარ'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('არა')),
                  for (final r in abroadCountries) DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => abroad = v ?? ''),
              ),
              head('სხვა'),
              Material(
                color: c.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.line)),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  key: const ValueKey('ep-biz'),
                  value: business,
                  onChanged: (v) => setState(() => business = v),
                  title: const Text('ბიზნეს ანგარიში', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('გვერდები და რეკლამა', style: TextStyle(color: c.muted, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 14),
              Text('ონლაინ სტატუსი, ვინ მოგწეროს და შეტყობინებები „პარამეტრებშია“.', style: TextStyle(color: c.muted, fontSize: 13, height: 1.4)),
              const SizedBox(height: 18),
              FilledButton(
                key: const ValueKey('ep-save'),
                onPressed: busy ? null : _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: busy ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2)) : const Text('შენახვა'),
              ),
            ]),
          ),
        ]),
      );
    }
    return PopScope(
      canPop: !dirty || busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await confirm(context, title: 'ცვლილებები არ შეინახება', text: 'გავიდე შენახვის გარეშე?', yes: 'გასვლა', danger: true)) nav.pop();
      },
      child: Scaffold(
        appBar: peeraBar(context, title: 'პროფილის რედაქტირება', actions: [
          if (m != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: TextButton(key: const ValueKey('ep-save-top'), onPressed: busy ? null : _save, child: const Text('შენახვა', style: TextStyle(fontWeight: FontWeight.w800))),
            ),
        ]),
        body: body,
      ),
    );
  }
}

/// @names as the site keeps them: small latin letters, digits, "_" and "."
class _UsernameFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue v) {
    final t = v.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    if (t == v.text) return v;
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}
