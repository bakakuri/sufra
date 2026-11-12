import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models.dart';
import '../data/photos.dart';
import '../data/stores.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Where the photos come from: the gallery (several) or the camera (one). The tests put in their own.
typedef PhotoSource = Future<List<Uint8List>> Function(bool camera);
PhotoSource photoSource = pickPhotos;

/// How a picked photo is made ready to upload (the tests skip the resizing).
Future<PreparedPhoto> Function(Uint8List) photoPrep = preparePhoto;

Future<List<Uint8List>> pickPhotos(bool camera) async {
  final p = ImagePicker();
  if (camera) {
    final f = await p.pickImage(source: ImageSource.camera, maxWidth: 2048, maxHeight: 2048, imageQuality: 92);
    return f == null ? [] : [await f.readAsBytes()];
  }
  final files = await p.pickMultiImage(maxWidth: 2048, maxHeight: 2048, imageQuality: 92);
  return [for (final f in files.take(maxPhotos)) await f.readAsBytes()];
}

const maxPhotos = 10;

/// Writing a post: words and up to ten photos. "გამოქვეყნება" uploads the photos (made upright and in the
/// site's three sizes) and publishes; the new post comes back to the feed.
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key, this.startWithPhotos = false});
  final bool startWithPhotos;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final field = TextEditingController();
  final photos = <Uint8List>[];
  bool busy = false;
  String? stage;

  @override
  void initState() {
    super.initState();
    field.addListener(() => setState(() {}));
    if (widget.startWithPhotos) WidgetsBinding.instance.addPostFrameCallback((_) => _add(false));
  }

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  bool get _empty => field.text.trim().isEmpty && photos.isEmpty;

  Future<void> _add(bool camera) async {
    if (photos.length >= maxPhotos) {
      toast(context, 'მაქსიმუმ $maxPhotos ფოტო');
      return;
    }
    try {
      final got = await photoSource(camera);
      if (!mounted || got.isEmpty) return;
      setState(() => photos.addAll(got.take(maxPhotos - photos.length)));
    } catch (e) {
      if (mounted) toast(context, 'ფოტო ვერ გავხსენი');
    }
  }

  Future<void> _publish() async {
    if (_empty || busy) return;
    final app = context.app;
    setState(() => busy = true);
    try {
      final media = <Media>[];
      for (var i = 0; i < photos.length; i++) {
        setState(() => stage = photos.length == 1 ? 'ფოტო იტვირთება…' : 'ფოტოები იტვირთება · ${i + 1}/${photos.length}');
        media.add(await app.api.uploadPhoto(await photoPrep(photos[i])));
      }
      setState(() => stage = 'ქვეყნდება…');
      final post = await app.api.createPost(field.text.trim(), media);
      if (!mounted) return;
      Navigator.of(context).pop(post);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        stage = null;
      });
      toast(context, errText(e));
    }
  }

  Future<void> _leave() async {
    if (busy) return;
    if (_empty || await confirm(context, title: 'პოსტი არ გამოქვეყნდება', text: 'დაწერილი და არჩეული ფოტოები წაიშლება.', yes: 'გასვლა', danger: true)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, me = context.me;
    return PopScope(
      canPop: _empty && !busy,
      onPopInvokedWithResult: (did, _) {
        if (!did) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 60,
          titleSpacing: 0,
          leading: IconBtn('x', label: 'დახურვა', onTap: _leave),
          title: const Text('ახალი პოსტი'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: _empty || busy ? null : _publish,
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
              Row(children: [
                Avatar(p: me, size: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    NameLine(me, size: 15.5),
                    Text('ყველა ხედავს, ვისაც შენი პოსტები ჩანს', style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: field,
                enabled: !busy,
                autofocus: !widget.startWithPhotos,
                minLines: 4,
                maxLines: null,
                maxLength: 5000,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 18, height: 1.45),
                decoration: InputDecoration(
                  hintText: 'რას ფიქრობ, ${me.name}?',
                  hintStyle: TextStyle(fontSize: 18, color: c.muted),
                  filled: false,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: photos.length == 1 ? 1 : 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: photos.length == 1 ? 1.25 : 1,
                  children: [
                    for (var i = 0; i < photos.length; i++)
                      Stack(fit: StackFit.expand, children: [
                        ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(photos[i], fit: BoxFit.cover, cacheWidth: 600)),
                        if (!busy)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => setState(() => photos.removeAt(i)),
                                child: const Padding(padding: EdgeInsets.all(5), child: PIcon('x', size: 16, color: Colors.white, stroke: 2.4)),
                              ),
                            ),
                          ),
                      ]),
                  ],
                ),
              ],
              if (stage != null) ...[
                const SizedBox(height: 14),
                Text(stage!, style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
          Container(
            decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(children: [
                  TextButton.icon(
                    onPressed: busy ? null : () => _add(false),
                    icon: PIcon('image', size: 22, color: c.vine),
                    label: Text('ფოტო', style: TextStyle(color: c.ink)),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : () => _add(true),
                    icon: PIcon('camera', size: 22, color: c.accent),
                    label: Text('კამერა', style: TextStyle(color: c.ink)),
                  ),
                  const Spacer(),
                  if (photos.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text('${photos.length}/$maxPhotos', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
                    ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
