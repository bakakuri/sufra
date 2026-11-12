import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../profile/profile.dart';
import '../shell/home_shell.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'auth_api.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';

/// Signed out: the sign-in screen. Signed in: the profile is loaded; not finished: onboarding; otherwise the app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.api});
  final AuthApi api;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _sub;
  Profile? me;
  bool loading = true, signedIn = false;
  String? error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedIn || s.event == AuthChangeEvent.signedOut || s.event == AuthChangeEvent.userUpdated) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final g = ++_gen;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      setState(() {
        signedIn = false;
        me = null;
        loading = false;
        error = null;
      });
      return;
    }
    setState(() {
      signedIn = true;
      loading = me == null;
      error = null;
    });
    try {
      final p = await widget.api.myProfile();
      if (!mounted || g != _gen) return;
      setState(() {
        me = p;
        loading = false;
        error = p == null ? 'პროფილი ვერ ჩაიტვირთა' : null;
      });
    } catch (e) {
      if (!mounted || g != _gen) return;
      setState(() {
        loading = false;
        error = authErr(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Splash();
    if (!signedIn) return AuthScreen(api: widget.api);
    final p = me;
    if (p == null) return _Retry(error: error ?? '', onRetry: _load, onSignOut: widget.api.signOut);
    if (!p.onboarded) return OnboardingScreen(api: widget.api, me: p, onDone: _load);
    return HomeShell(me: p, onSignOut: widget.api.signOut, onRefresh: _load);
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const PeeraLogo(size: 40),
            const SizedBox(height: 26),
            SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: context.pc.accent)),
          ]),
        ),
      );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.error, required this.onRetry, required this.onSignOut});
  final String error;
  final Future<void> Function() onRetry;
  final Future<void> Function() onSignOut;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Center(child: PeeraLogo(size: 36)),
              const SizedBox(height: 24),
              Note(error),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('ხელახლა ცდა')),
              const SizedBox(height: 8),
              TextButton(onPressed: onSignOut, child: const Text('გასვლა')),
            ]),
          ),
        ),
      );
}
