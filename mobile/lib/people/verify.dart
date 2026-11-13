// Verification (settings.js PG.verify): a selfie with two fingers up, sent to a moderator who compares it with the
// profile picture. The selfie goes to a closed store only moderators can open.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});
  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  String? last;
  bool loaded = false, sending = false, _started = false;
  Uint8List? selfie;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    String? s;
    try {
      s = await context.app.api.verification();
    } catch (_) {}
    if (mounted) {
      setState(() {
        last = s;
        loaded = true;
      });
    }
  }

  Future<void> _take() async {
    try {
      final got = await photoSource(true);
      if (got.isEmpty) return;
      final p = await photoPrep(got.first);
      if (mounted) setState(() => selfie = p.full);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  Future<void> _send() async {
    final s = selfie;
    if (s == null || sending) return;
    setState(() => sending = true);
    final ok = await attempt(context, () => context.app.api.requestVerification(s));
    if (!mounted) return;
    setState(() => sending = false);
    if (ok) {
      toast(context, 'გაიგზავნა');
      setState(() => selfie = null);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, me = context.me;
    Widget card(List<Widget> children) => Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        );
    Widget body;
    if (!loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (me.verified) {
      body = ListView(children: [
        card([
          const Center(child: Verified(size: 48)),
          const SizedBox(height: 12),
          const Text('პროფილი ვერიფიცირებულია', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('შენს სახელთან ლურჯი ნიშანი ჩანს.', textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
        ]),
      ]);
    } else if (last == 'pending') {
      body = ListView(children: [
        card([
          const Text('განაცხადი განხილვაშია', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('მოდერატორი შეადარებს სელფის შენს პროფილის ფოტოს. შედეგს შეტყობინებით მიიღებ.', style: TextStyle(color: c.muted, height: 1.4)),
        ]),
      ]);
    } else {
      body = ListView(children: [
        card([
          const Text('დაადასტურე, რომ ფოტოებზე შენ ხარ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (last == 'rejected') ...[
            const SizedBox(height: 8),
            Text('წინა განაცხადი ვერ დადასტურდა. სცადე ახალი, მკაფიო სელფით.', style: TextStyle(color: c.nope, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 8),
          Text('ლურჯი ნიშანი ჩანს პოსტებთან, მესიჯებში და გაცნობის ბარათზე.${(me.avatarUrl ?? '').isEmpty ? ' ჯერ დაამატე პროფილის ფოტო, რომ მოდერატორმა შეადაროს.' : ''}',
              style: TextStyle(color: c.muted, height: 1.4)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Text('✌️', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('პოზა: აწიე ორი თითი', style: TextStyle(fontWeight: FontWeight.w800)),
                  Text('სახე კარგად უნდა ჩანდეს, სათვალის და ქუდის გარეშე.', style: TextStyle(color: c.muted, fontSize: 13)),
                ]),
              ),
            ]),
          ),
          if (selfie != null) ...[
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(selfie!, height: 280, fit: BoxFit.cover)),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('verify-take'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                onPressed: sending ? null : _take,
                icon: PIcon('camera', size: 18, color: c.onAccent),
                label: Text(selfie == null ? 'სელფის გადაღება' : 'თავიდან'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('verify-send'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                onPressed: selfie == null || sending ? null : _send,
                child: Text(sending ? 'იგზავნება…' : 'გაგზავნა'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text('სელფი ინახება დახურულ საცავში. მას მხოლოდ მოდერატორი ხედავს და მხოლოდ ვერიფიკაციისთვის.', style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4)),
        ]),
      ]);
    }
    return Scaffold(appBar: peeraBar(context, title: 'ვერიფიკაცია'), body: body);
  }
}
