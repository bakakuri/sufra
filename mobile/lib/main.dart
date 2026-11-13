import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_api.dart';
import 'auth/auth_gate.dart';
import 'config.dart';
import 'data/api.dart';
import 'push/push.dart';
import 'ui/look.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supaUrl, anonKey: supaAnonKey);
  await loadLook();
  runApp(PeeraApp(home: AuthGate(api: SupaAuthApi(), data: SupaApi.new, push: FcmPush.new)));
}

/// The app's frame: Georgian, the site's colours, light or dark as chosen in the settings (or as the phone is set),
/// the text as big as chosen. [mode] fixes it (the pictures of the screens).
class PeeraApp extends StatelessWidget {
  const PeeraApp({super.key, required this.home, this.mode});
  final Widget home;
  final ThemeMode? mode;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([themeChoice, textZoom]),
        builder: (context, _) => MaterialApp(
          title: 'Peera',
          debugShowCheckedModeBanner: false,
          theme: peeraTheme(Brightness.light),
          darkTheme: peeraTheme(Brightness.dark),
          themeMode: mode ?? themeChoice.value,
          locale: const Locale('ka'),
          supportedLocales: const [Locale('ka'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) {
            final z = mode == null ? textZoom.value : 1.0;
            if (z == 1) return child!;
            final mq = MediaQuery.of(context);
            return MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * z)), child: child!);
          },
          home: home,
        ),
      );
}
