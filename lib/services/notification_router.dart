import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/app_theme.dart';
import '../screens/common/notifications_screen.dart';
import '../screens/hogar/request_detail_screen.dart';

/// Enrutador centralizado para notificaciones Push (FCM) y eventos WebSocket en tiempo real.
///
/// Gestiona:
/// 1. Banner superior no bloqueante (Heads-up Toast) de 4.5 segundos en primer plano.
/// 2. Enrutamiento inteligente a pantallas destino (evita apilar vistas duplicadas si ya está abierta).
/// 3. Deep linking al tocar notificaciones en segundo plano o con la app cerrada.
class NotificationRouter {
  NotificationRouter._();

  /// Llave global de navegación para deep linking desde callbacks de Firebase o servicios
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// ID de la solicitud activa que se está visualizando en pantalla actualmente
  static String? currentActiveRequestId;

  static OverlayEntry? _currentToastEntry;
  static Timer? _toastDismissTimer;

  /// Procesa un mensaje de Firebase Messaging
  static void handleRemoteMessage(RemoteMessage message) {
    handlePayload(
      data: message.data,
      fallbackTitle: message.notification?.title,
      fallbackBody: message.notification?.body,
    );
  }

  /// Procesa los datos de la notificación y navega inteligentemente a la vista correspondiente
  static void handlePayload({
    required Map<String, dynamic> data,
    String? fallbackTitle,
    String? fallbackBody,
  }) {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint('[NotificationRouter] Navigator no disponible aún para navegación.');
      return;
    }

    final requestId = data['requestId']?.toString();
    final batchId = data['batchId']?.toString();
    debugPrint('[NotificationRouter] Procesando payload: req=$requestId, batch=$batchId');

    // 1. Notificación vinculada a una Solicitud de Recolección / Subasta
    if (requestId != null && requestId.isNotEmpty) {
      if (currentActiveRequestId == requestId) {
        debugPrint('[NotificationRouter] El usuario ya está visualizando la solicitud #$requestId. Evitando duplicar pantalla.');
        return;
      }
      HapticFeedback.mediumImpact();
      nav.push(
        MaterialPageRoute(
          builder: (_) => RequestDetailScreen(requestId: requestId),
        ),
      );
      return;
    }

    // 2. Fallback a la bandeja de Alertas y Notificaciones
    HapticFeedback.lightImpact();
    nav.push(
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }

  /// Muestra un banner flotante superior (Heads-up Toast) animado por 4.5 segundos.
  /// No bloquea la interacción táctil con el resto de la pantalla y permite navegar al tocarlo.
  static void showInAppToast({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) {
    final nav = navigatorKey.currentState;
    final overlay = nav?.overlay;
    if (overlay == null) return;

    _toastDismissTimer?.cancel();
    _currentToastEntry?.remove();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopHeadsUpToast(
        title: title,
        body: body,
        data: data,
        onDismiss: () {
          entry.remove();
          if (_currentToastEntry == entry) _currentToastEntry = null;
        },
        onTap: () {
          entry.remove();
          if (_currentToastEntry == entry) _currentToastEntry = null;
          handlePayload(
            data: data ?? <String, dynamic>{},
            fallbackTitle: title,
            fallbackBody: body,
          );
        },
      ),
    );

    _currentToastEntry = entry;
    overlay.insert(entry);

    _toastDismissTimer = Timer(const Duration(milliseconds: 4500), () {
      if (_currentToastEntry == entry) {
        entry.remove();
        _currentToastEntry = null;
      }
    });
  }
}

class _TopHeadsUpToast extends StatefulWidget {
  const _TopHeadsUpToast({
    required this.title,
    required this.body,
    this.data,
    required this.onDismiss,
    required this.onTap,
  });

  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  @override
  State<_TopHeadsUpToast> createState() => _TopHeadsUpToastState();
}

class _TopHeadsUpToastState extends State<_TopHeadsUpToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleDismiss() async {
    await _animController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: _offsetAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: LivoraColors.forest.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: LivoraColors.forest.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: LivoraColors.forest,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: LivoraColors.deep,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: LivoraColors.slate,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: LivoraColors.forest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Ver',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: LivoraColors.slate),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _handleDismiss,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
