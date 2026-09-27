import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'notification_router.dart';

/// Servicio unificado de Notificaciones Locales y Push para Android e iOS.
/// Gestiona canales nativos, sonidos personalizados, heads-up banners y deep linking.
class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static int _notificationCounter = 1000;

  // Canales canónicos de Android
  static const String channelUrgent = 'livora_collections_urgent';
  static const String channelWallet = 'livora_wallet_ledger';
  static const String channelLegal = 'livora_legal_security';
  static const String channelAuctions = 'livora_auctions';
  static const String channelMarketing = 'livora_engagement_marketing';

  /// Inicializa los canales y receptores de notificaciones nativas en el dispositivo
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          'LIVORA_NOTIFICATION',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain('OPEN_ACTION', 'Ver detalle'),
          ],
        ),
      ],
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifs.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onSelectNotification,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    // Crear canales en Android mediante el plugin para garantizar compatibilidad
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _localNotifs.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            channelUrgent,
            'Operaciones en Campo y Recolección',
            description:
                'Alertas inmediatas sobre llegada de recolector, cambios de ruta y validaciones.',
            importance: Importance.max,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('alert_tone'),
            enableVibration: true,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            channelWallet,
            'Billetera, Tokens y Canjes',
            description:
                'Confirmación de transacciones en la red Stellar y acreditación de LIVOs.',
            importance: Importance.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('transaction_tone'),
            enableVibration: true,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            channelLegal,
            'Seguridad, Privacidad y Reclamos',
            description:
                'Alertas de seguridad, normativas Indecopi y Libro de Reclamaciones.',
            importance: Importance.high,
            enableVibration: true,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            channelAuctions,
            'Subastas y Asignaciones',
            description:
                'Nuevas solicitudes disponibles y propuestas de centros de acopio.',
            importance: Importance.defaultImportance,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            channelMarketing,
            'Impacto Ambiental y Novedades',
            description:
                'Resumen de reciclaje mensual, metas e impacto ambiental.',
            importance: Importance.low,
          ),
        );
      }
    }

    // Configurar comportamiento en Foreground de FCM
    try {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: false, // Delegamos la presentación a flutter_local_notifications para evitar duplicados
        badge: true,
        sound: false,
      );
    } catch (e) {
      debugPrint('[PushNotificationService] Error configurando foreground presentation: $e');
    }

    _initialized = true;
    debugPrint('[PushNotificationService] Servicio inicializado correctamente.');
  }

  /// Muestra una notificación local nativa con canal, sonido y acción correspondiente
  static Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final channelId = data?['channelId']?.toString() ?? channelUrgent;
    final soundName = data?['sound']?.toString();

    AndroidNotificationDetails androidDetails;
    if (channelId == channelWallet) {
      androidDetails = const AndroidNotificationDetails(
        channelWallet,
        'Billetera, Tokens y Canjes',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('transaction_tone'),
        icon: '@mipmap/ic_launcher',
      );
    } else if (channelId == channelLegal) {
      androidDetails = const AndroidNotificationDetails(
        channelLegal,
        'Seguridad, Privacidad y Reclamos',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
    } else if (channelId == channelAuctions) {
      androidDetails = const AndroidNotificationDetails(
        channelAuctions,
        'Subastas y Asignaciones',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      );
    } else if (channelId == channelMarketing) {
      androidDetails = const AndroidNotificationDetails(
        channelMarketing,
        'Impacto Ambiental y Novedades',
        importance: Importance.low,
        priority: Priority.low,
        icon: '@mipmap/ic_launcher',
      );
    } else {
      androidDetails = const AndroidNotificationDetails(
        channelUrgent,
        'Operaciones en Campo y Recolección',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alert_tone'),
        fullScreenIntent: true,
        icon: '@mipmap/ic_launcher',
      );
    }

    final resolvedSound = soundName ??
        (channelId == channelWallet
            ? 'transaction_tone'
            : channelId == channelUrgent
                ? 'alert_tone'
                : null);

    DarwinNotificationDetails darwinDetails;
    if (resolvedSound != null && resolvedSound.isNotEmpty) {
      final cleanSound = resolvedSound.replaceAll(RegExp(r'\.(caf|mp3|wav)$'), '');
      darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: '$cleanSound.wav',
        categoryIdentifier: 'LIVORA_NOTIFICATION',
      );
    } else {
      darwinDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'LIVORA_NOTIFICATION',
      );
    }

    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final notifId = _notificationCounter++;
    final payload = data != null ? jsonEncode(data) : null;

    await _localNotifs.show(
      id: notifId,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: payload,
    );
  }

  /// Suscripción a tópicos geográficos de FCM (ej: zone_miraflores, collectors_all)
  static Future<void> subscribeToTopic(String topic) async {
    try {
      final cleanTopic = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
      await FirebaseMessaging.instance.subscribeToTopic(cleanTopic);
      debugPrint('[PushNotificationService] Suscrito al tópico FCM: $cleanTopic');
    } catch (e) {
      debugPrint('[PushNotificationService] Error suscribiendo al tópico $topic: $e');
    }
  }

  /// Desuscripción de tópicos geográficos de FCM
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      final cleanTopic = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
      await FirebaseMessaging.instance.unsubscribeFromTopic(cleanTopic);
      debugPrint('[PushNotificationService] Desuscrito del tópico FCM: $cleanTopic');
    } catch (e) {
      debugPrint('[PushNotificationService] Error desuscribiendo del tópico $topic: $e');
    }
  }

  /// Manejador al tocar una notificación nativa
  @pragma('vm:entry-point')
  static void _onSelectNotification(NotificationResponse response) {
    final rawPayload = response.payload;
    if (rawPayload != null && rawPayload.isNotEmpty) {
      try {
        final Map<String, dynamic> data = jsonDecode(rawPayload);
        NotificationRouter.handlePayload(data: data);
      } catch (e) {
        debugPrint('[PushNotificationService] Error decodificando payload: $e');
        NotificationRouter.handlePayload(data: {});
      }
    } else {
      NotificationRouter.handlePayload(data: {});
    }
  }

  /// Callback para interacción en background
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    debugPrint('[PushNotificationService] Acción de notificación en background: ${response.id}');
  }
}
