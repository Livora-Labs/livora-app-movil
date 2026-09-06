import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'core/session.dart';
import 'core/env_config.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shell/home_shell.dart';
import 'services/livora_api.dart';
import 'services/offline_queue_manager.dart';
import 'services/livora_realtime.dart';
import 'dart:ui';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint("Notificación recibida en segundo plano: ${message.notification?.title}");
  } catch (e) {
    debugPrint("Error inicializando Firebase en background: $e");
  }
}

Future<void> main() async {
  SentryWidgetsFlutterBinding.ensureInitialized();

  await SentryFlutter.init(
    (options) {
      options.dsn = EnvConfig.sentryDsn;
      options.tracesSampleRate = 1.0;
    },
    appRunner: () async {
      // Registrar capturadores de excepciones de Flutter y plataforma hacia Sentry
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('FLUTTER ERROR: ${details.exception}\n${details.stack}');
        Sentry.captureException(details.exception, stackTrace: details.stack);
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        debugPrint('PLATFORM ERROR: $error\n$stack');
        Sentry.captureException(error, stackTrace: stack);
        return false;
      };

      final prefs = await SharedPreferences.getInstance();
      final api = ApiClient(prefs);
      await api.migrateLegacyBaseUrl();
      final session = SessionController(api, prefs);
      await session.restore();

      final livoraApi = LivoraApi(api);
      await OfflineQueueManager.init(livoraApi);

      final realtime = LivoraRealtime(api);
      session.onLogout = () => realtime.disconnect();

      try {
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
        debugPrint('FCM no inicializado en entorno local: $e');
      }

      runApp(LivoraApp(
        api: api,
        session: session,
        livoraApi: livoraApi,
        realtime: realtime,
      ));
    },
  );
}

class LivoraApp extends StatelessWidget {
  const LivoraApp({
    super.key,
    required this.api,
    required this.session,
    required this.livoraApi,
    required this.realtime,
  });

  final ApiClient api;
  final SessionController session;
  final LivoraApi livoraApi;
  final LivoraRealtime realtime;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        Provider.value(value: livoraApi),
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: realtime),
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
