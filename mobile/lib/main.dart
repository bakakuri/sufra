import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_api.dart';
import 'auth/auth_gate.dart';
import 'config.dart';
import 'data/api.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supaUrl, anonKey: supaAnonKey);
  runApp(PeeraApp(home: AuthGate(api: SupaAuthApi(), data: SupaApi.new)));
}

/// The app's frame: Georgian, the site's colours, light or dark as the phone is set.
class PeeraApp extends StatelessWidget {
  const PeeraApp({super.key, required this.home, this.mode = ThemeMode.system});
  final Widget home;
  final ThemeMode mode;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Peera',
        debugShowCheckedModeBanner: false,
        theme: peeraTheme(Brightness.light),
        darkTheme: peeraTheme(Brightness.dark),
        themeMode: mode,
        locale: const Locale('ka'),
        supportedLocales: const [Locale('ka'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
      );
}
