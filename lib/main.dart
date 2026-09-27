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
import 'screens/common/onboarding_screen.dart';
import 'screens/shell/home_shell.dart';
import 'services/livora_api.dart';
import 'services/offline_queue_manager.dart';
import 'services/livora_realtime.dart';
import 'services/notification_router.dart';
import 'dart:ui';

import 'firebase_options.dart';
import 'services/push_notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint("Notificación recibida en segundo plano: ${message.notification?.title}");
  } catch (e) {
    debugPrint("Error procesando mensaje en background: $e");
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

      // Inicialización robusta de Firebase con credenciales multiplataforma
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        await PushNotificationService.initialize();
      } catch (e) {
        debugPrint('Aviso: Firebase no pudo inicializarse en este entorno: $e');
      }

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
        final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationRouter.handleRemoteMessage(initialMessage);
          });
        }
      } catch (e) {
        debugPrint('Error leyendo getInitialMessage de FCM: $e');
      }

      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

      runApp(LivoraApp(
        api: api,
        session: session,
        livoraApi: livoraApi,
        realtime: realtime,
        hasSeenOnboarding: hasSeenOnboarding,
      ));
    },
  );
}

class LivoraApp extends StatefulWidget {
  const LivoraApp({
    super.key,
    required this.api,
    required this.session,
    required this.livoraApi,
    required this.realtime,
    required this.hasSeenOnboarding,
  });

  final ApiClient api;
  final SessionController session;
  final LivoraApi livoraApi;
  final LivoraRealtime realtime;
  final bool hasSeenOnboarding;

  @override
  State<LivoraApp> createState() => _LivoraAppState();
}

class _LivoraAppState extends State<LivoraApp> {
  late bool _seenOnboarding;

  @override
  void initState() {
    super.initState();
    _seenOnboarding = widget.hasSeenOnboarding;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: widget.api),
        Provider.value(value: widget.livoraApi),
        ChangeNotifierProvider.value(value: widget.session),
        ChangeNotifierProvider.value(value: widget.realtime),
      ],
      child: Consumer<SessionController>(
        builder: (context, session, _) => MaterialApp(
          navigatorKey: NotificationRouter.navigatorKey,
          title: 'Livora Labs',
          debugShowCheckedModeBanner: false,
          theme: LivoraTheme.light(),
          themeMode: ThemeMode.light,
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: !_seenOnboarding
              ? OnboardingScreen(
                  onComplete: () {
                    setState(() => _seenOnboarding = true);
                  },
                )
              : (session.isAuthenticated
                  ? const HomeShell()
                  : const LoginScreen()),
        ),
      ),
    );
  }
}
