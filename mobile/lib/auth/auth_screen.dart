import 'package:flutter/material.dart';

import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'auth_api.dart';

/// Sign in, sign up, or a new password: the same three as on the site, the same rules (a password of 8 or more).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.api, this.startUp = false});
  final AuthApi api;
  final bool startUp;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Mode { signIn, signUp, reset }

class _AuthScreenState extends State<AuthScreen> {
  late _Mode mode = widget.startUp ? _Mode.signUp : _Mode.signIn;
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _pass = TextEditingController(), _name = TextEditingController();
  bool busy = false, show = false;
  String? msg;
  bool ok = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    super.dispose();
  }

  void _to(_Mode m) => setState(() {
        mode = m;
        msg = null;
        ok = false;
      });

  Future<void> _go() async {
    if (busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      busy = true;
      msg = null;
    });
    final email = _email.text.trim(), pass = _pass.text;
    try {
      if (mode == _Mode.signIn) {
        await widget.api.signIn(email, pass);
      } else if (mode == _Mode.signUp) {
        final ready = await widget.api.signUp(email, pass, _name.text.trim());
        if (!ready && mounted) {
          setState(() {
            ok = true;
            msg = 'თითქმის მზადაა! ელფოსტაზე დადასტურების ბმული გამოგიგზავნეთ. დააჭირე და შემდეგ შედი.';
          });
        }
      } else {
        await widget.api.resetPassword(email);
        if (mounted) {
          setState(() {
            ok = true;
            msg = 'ბმული გაიგზავნა. შეამოწმე ფოსტა, სპამის საქაღალდეც.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          ok = false;
          msg = authErr(e);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final title = switch (mode) { _Mode.signIn => 'შესვლა', _Mode.signUp => 'რეგისტრაცია', _Mode.reset => 'პაროლის აღდგენა' };
    final btn = switch (mode) { _Mode.signIn => 'შესვლა', _Mode.signUp => 'ანგარიშის შექმნა', _Mode.reset => 'ბმულის გაგზავნა' };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Center(child: PeeraLogo(size: 40)),
                  const SizedBox(height: 10),
                  Text('კლასელები, კურსელები და მეგობრები ერთ ადგილას',
                      textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 14.5)),
                  const SizedBox(height: 28),
                  if (mode != _Mode.reset)
                    _Seg(left: 'შესვლა', right: 'რეგისტრაცია', rightOn: mode == _Mode.signUp, onTap: (r) => _to(r ? _Mode.signUp : _Mode.signIn))
                  else
                    Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),
                  if (mode == _Mode.signUp) ...[
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 60,
                      decoration: const InputDecoration(labelText: 'სახელი', counterText: '', prefixIcon: _Pre('user')),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'ჩაწერე სახელი' : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'ელფოსტა', prefixIcon: _Pre('mail')),
                    validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'ელფოსტის მისამართი არასწორია',
                  ),
                  if (mode != _Mode.reset) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pass,
                      obscureText: !show,
                      autofillHints: [mode == _Mode.signUp ? AutofillHints.newPassword : AutofillHints.password],
                      onFieldSubmitted: (_) => _go(),
                      decoration: InputDecoration(
                        labelText: 'პაროლი',
                        prefixIcon: const _Pre('lock'),
                        suffixIcon: IconButton(
                          tooltip: show ? 'დამალვა' : 'ჩვენება',
                          onPressed: () => setState(() => show = !show),
                          icon: PIcon(show ? 'eyeoff' : 'eye', size: 22, color: c.muted),
                        ),
                      ),
                      validator: (v) => mode == _Mode.signUp && (v ?? '').length < 8
                          ? 'პაროლი მინიმუმ 8 სიმბოლო უნდა იყოს'
                          : (v ?? '').isEmpty
                              ? 'ჩაწერე პაროლი'
                              : null,
                    ),
                  ],
                  if (msg != null) ...[const SizedBox(height: 14), Note(msg!, ok: ok)],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: busy ? null : _go,
                    child: busy ? SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.onAccent)) : Text(btn),
                  ),
                  const SizedBox(height: 8),
                  if (mode == _Mode.signIn)
                    TextButton(onPressed: () => _to(_Mode.reset), child: const Text('პაროლი დაგავიწყდა?'))
                  else if (mode == _Mode.reset)
                    TextButton(onPressed: () => _to(_Mode.signIn), child: const Text('უკან, შესვლაზე')),
                  if (mode == _Mode.signUp)
                    Text('რეგისტრაციით ეთანხმები Peera-ს წესებს. 13 წლამდე რეგისტრაცია არ შეიძლება.',
                        textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12.5)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pre extends StatelessWidget {
  const _Pre(this.name);
  final String name;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(13), child: PIcon(name, size: 22, color: context.pc.muted));
}

/// Two halves, one chosen: the site's .seg
class _Seg extends StatelessWidget {
  const _Seg({required this.left, required this.right, required this.rightOn, required this.onTap});
  final String left, right;
  final bool rightOn;
  final ValueChanged<bool> onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    Widget half(String t, bool on, bool r) => Expanded(
          child: Semantics(
            button: true,
            selected: on,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? c.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: on ? [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 8, offset: const Offset(0, 2))] : null,
                ),
                child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: on ? c.ink : c.muted)),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [half(left, !rightOn, false), half(right, rightOn, true)]),
    );
  }
}
