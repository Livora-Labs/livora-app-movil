import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'core/session.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shell/home_shell.dart';
import 'services/livora_api.dart';
import 'services/livora_realtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(prefs);
  await api.migrateLegacyBaseUrl();
  final session = SessionController(api, prefs);
  await session.restore();
  runApp(LivoraApp(api: api, session: session));
}

class LivoraApp extends StatelessWidget {
  const LivoraApp({super.key, required this.api, required this.session});

  final ApiClient api;
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        Provider(create: (_) => LivoraApi(api)),
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => LivoraRealtime(api)),
      ],
      child: Consumer<SessionController>(
        builder: (context, session, _) => MaterialApp(
          title: 'Livora Labs',
          debugShowCheckedModeBanner: false,
          theme: LivoraTheme.light(),
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: session.isAuthenticated
              ? const HomeShell()
              : const LoginScreen(),
        ),
      ),
    );
  }
}
