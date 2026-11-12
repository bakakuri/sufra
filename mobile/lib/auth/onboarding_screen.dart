import 'package:flutter/material.dart';

import '../profile/profile.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'auth_api.dart';

/// After the first sign-in: name, a username, the birthday (13 or older) and the city — the site's onboarding.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.api, required this.me, required this.onDone});
  final AuthApi api;
  final Profile me;
  final VoidCallback onDone;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

const _months = ['იანვარი', 'თებერვალი', 'მარტი', 'აპრილი', 'მაისი', 'ივნისი', 'ივლისი', 'აგვისტო', 'სექტემბერი', 'ოქტომბერი', 'ნოემბერი', 'დეკემბერი'];
String kaDate(DateTime d) => '${d.day} ${_months[d.month - 1]}, ${d.year}';

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.me.name);
  late final _user = TextEditingController(text: widget.me.username ?? '');
  late final _city = TextEditingController(text: widget.me.city ?? '');
  DateTime? birthday;
  bool busy = false, tried = false;
  String? msg;

  @override
  void dispose() {
    _name.dispose();
    _user.dispose();
    _city.dispose();
    super.dispose();
  }

  DateTime get _latest {
    final n = DateTime.now();
    return DateTime(n.year - 13, n.month, n.day);
  }

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: birthday ?? DateTime(_latest.year - 5, 1, 1),
      firstDate: DateTime(1900),
      lastDate: _latest,
      helpText: 'დაბადების თარიღი',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (d != null) setState(() => birthday = d);
  }

  Future<void> _go() async {
    setState(() => tried = true);
    if (busy || !(_form.currentState?.validate() ?? false) || birthday == null) return;
    setState(() {
      busy = true;
      msg = null;
    });
    try {
      await widget.api.completeOnboarding(name: _name.text.trim(), birthday: birthday!, username: _user.text.trim(), city: _city.text.trim());
      widget.onDone();
    } catch (e) {
      if (mounted) setState(() => msg = authErr(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      appBar: peeraBar(context, title: 'მოგესალმებით Peera-ზე'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('რამდენიმე რამ შენზე, რომ მეგობრებმა გიპოვონ.', style: TextStyle(color: c.muted, fontSize: 15)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'სახელი', counterText: ''),
                validator: (v) => (v ?? '').trim().isEmpty ? 'ჩაწერე სახელი' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _user,
                maxLength: 24,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'მომხმარებლის სახელი', hintText: 'მაგ. nino.beridze', prefixText: '@', counterText: ''),
                validator: (v) => RegExp(r'^[a-z0-9_.]{3,24}$').hasMatch((v ?? '').trim())
                    ? null
                    : '3-დან 24 სიმბოლომდე: ლათინური პატარა ასოები, ციფრები, „_“ და „.“',
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: 'დაბადების თარიღი',
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pick,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'დაბადების თარიღი',
                      errorText: tried && birthday == null ? 'აირჩიე დაბადების თარიღი' : null,
                      suffixIcon: Padding(padding: const EdgeInsets.all(12), child: PIcon('chev', size: 20, color: c.muted)),
                    ),
                    child: Text(birthday == null ? 'აირჩიე' : kaDate(birthday!), style: TextStyle(color: birthday == null ? c.muted : c.ink, fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _city,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'ქალაქი', hintText: 'მაგ. თბილისი', counterText: ''),
              ),
              if (msg != null) ...[const SizedBox(height: 14), Note(msg!)],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : _go,
                child: busy ? SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.onAccent)) : const Text('დაწყება'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
