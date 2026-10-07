import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/app_theme.dart';

import '../../core/formats.dart';
import '../../core/session.dart';
import '../../services/livora_api.dart';
import '../../services/livora_realtime.dart';
import '../../services/notification_router.dart';
import '../../services/push_notification_service.dart';
import '../../services/network_connectivity_service.dart';
import '../../services/offline_queue_manager.dart';
import '../acopio/center_batches_screen.dart';
import '../acopio/center_prices_screen.dart';
import '../common/notifications_screen.dart';
import '../common/profile_screen.dart';
import '../common/wallet_screen.dart';
import '../../widgets/common.dart';
import '../hogar/create_request_screen.dart';
import '../hogar/widgets/hogar_active_address_bar.dart';
import '../hogar/hogar_dashboard.dart';
import '../hogar/gamification/hogar_forest_screen.dart';
import '../recolector/available_requests_screen.dart';
import '../recolector/my_batch_screen.dart';
import '../acopio/inventory_screen.dart';
import '../tienda/store_dashboard.dart';
import '../tienda/store_history_screen.dart';
import '../tienda/store_onboarding_screen.dart';
import '../tienda/store_qr_generator_screen.dart';
import '../tienda/store_wallet_screen.dart';

class _TabSpec {
  const _TabSpec(this.label, this.icon, this.body);

  final String label;
  final IconData icon;
  final Widget body;
}

/// Contenedor principal: elige las pestañas según el rol del usuario.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Permite a cualquier pantalla hija o modal cambiar la pestaña activa del shell
  static void switchTab(BuildContext context, int index) {
    context.findAncestorStateOfType<_HomeShellState>()?.setTabIndex(index);
  }

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  StreamSubscription<RemoteMessage>? _fcmSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<Map<String, dynamic>>? _realtimeNotifSub;
  bool _bannerDismissed = false;
  bool _lastKnownOnline = true;
  LivoraRealtime? _realtime;

  void setTabIndex(int index) {
    if (mounted) {
      setState(() => _index = index);
    }
  }

  int _pendingCenterBatchesCount = 0;

  Future<void> _checkCenterPendingBatches() async {
    final session = context.read<SessionController>();
    if (session.user?.role != Roles.centroAcopio) return;
    try {
      final api = context.read<LivoraApi>();
      final batches = await api.batches();
      if (!mounted) return;
      final count = batches.where((b) => b.status == 'IN_TRANSIT' || b.status == 'FLAGGED_FOR_REVIEW').length;
      if (_pendingCenterBatchesCount != count) {
        setState(() => _pendingCenterBatchesCount = count);
      }
    } catch (_) {
      // Silenciar error en background
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupFcm();
    // Al entrar a la zona autenticada abrimos el socket; se cierra al salir
    // (logout) porque el shell se desmonta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _realtime = context.read<LivoraRealtime>();
        _realtime?.connect();
        context.read<SessionController>().checkUnreadNotifications(context.read<LivoraApi>());
        _checkCenterPendingBatches();

        _realtimeNotifSub?.cancel();
        _realtimeNotifSub = _realtime?.on(RealtimeEvents.notificationCreated).listen((data) {
          if (mounted) {
            final api = context.read<LivoraApi>();
            final session = context.read<SessionController>();
            session.checkUnreadNotifications(api);

            final title = data['title'] as String? ?? 'Nueva notificación';
            final body = data['body'] as String? ?? '';
            final type = data['type']?.toString().toUpperCase();

            // Reactividad en tiempo real: sincronizar estado KYC automáticamente
            if (type == 'KYC_STATUS_UPDATED' ||
                type == 'KYC_APPROVED' ||
                title.toLowerCase().contains('kyc') ||
                title.toLowerCase().contains('verificación') ||
                title.toLowerCase().contains('aprobad')) {
              session.refreshKycStatus(api);
            }

            // Sincronizar lotes y saldos en tiempo real ante transacciones
            if (type == 'REDEMPTION_COMPLETED' ||
                type == 'BATCH_COMPLETED' ||
                type == 'PAYMENT_CONFIRMED' ||
                type == 'BATCH_DISPATCHED') {
              session.notifyBatchesChanged();
              _checkCenterPendingBatches();
            }

            NotificationRouter.showInAppToast(
              title: title,
              body: body,
              data: data,
            );
          }
        });

        _realtime?.on(RealtimeEvents.batchDispatched).listen((_) {
          if (mounted) {
            _checkCenterPendingBatches();
          }
        });
        _realtime?.on(RealtimeEvents.batchCompleted).listen((_) {
          if (mounted) {
            _checkCenterPendingBatches();
          }
        });
        _realtime?.on(RealtimeEvents.batchUpdated).listen((_) {
          if (mounted) {
            _checkCenterPendingBatches();
          }
        });

        // Guard de Onboarding Comercial para Rol Tienda
        final session = context.read<SessionController>();
        if (session.user?.role == Roles.tienda) {
          final api = context.read<LivoraApi>();
          api.getStoreProfile().then((profile) {
            if (mounted) {
              final ruc = profile?['ruc']?.toString().trim();
              final address = profile?['address']?.toString().trim();
              final isComplete = profile != null && (ruc != null && ruc.isNotEmpty) && (address != null && address.isNotEmpty);
              if (!isComplete) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const StoreOnboardingScreen()),
                );
              }
            }
          }).catchError((_) {});
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<LivoraRealtime>().connect();
      context.read<SessionController>().checkUnreadNotifications(context.read<LivoraApi>());
      _checkCenterPendingBatches();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fcmSubscription?.cancel();
    _onMessageOpenedAppSub?.cancel();
    _tokenRefreshSub?.cancel();
    _realtimeNotifSub?.cancel();
    context.read<LivoraRealtime>().disconnect();
    super.dispose();
  }

  Future<void> _setupFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        provisional: false,
        sound: true,
      );
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await messaging.getToken();
        if (token != null && mounted) {
          debugPrint('FCM Token obtenido y registrado');
          final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';
          await context.read<LivoraApi>().registerDeviceToken(token, platform: platform);

          if (!mounted) return;
          // Suscripción automática a tópicos según rol y zona geográfica general
          final role = context.read<SessionController>().user?.role;
          if (role != null) {
            PushNotificationService.subscribeToTopic('role_${role.toLowerCase()}');
          }
          PushNotificationService.subscribeToTopic('zone_lima');
        }
      }

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        if (mounted) {
          final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';
          context.read<LivoraApi>().registerDeviceToken(newToken, platform: platform);
        }
      });

      _onMessageOpenedAppSub?.cancel();
      _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        NotificationRouter.handleRemoteMessage(message);
      });
      
      _fcmSubscription?.cancel();
      _fcmSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (mounted) {
          context.read<SessionController>().checkUnreadNotifications(context.read<LivoraApi>());
          final title = message.notification?.title ?? message.data['title'] ?? 'Livora';
          final body = message.notification?.body ?? message.data['message'] ?? '';

          // 1. Mostrar notificación nativa en la bandeja del SO con sonido y canal
          PushNotificationService.showNotification(
            title: title,
            body: body,
            data: message.data,
          );

          // 2. Banner animado flotante en la UI
          NotificationRouter.showInAppToast(
            title: title,
            body: body,
            data: message.data,
          );
        }
      });
    } catch (e) {
      debugPrint('FCM no disponible en este entorno: $e');
    }
  }

  List<_TabSpec> _tabsFor(String role) {
    const wallet = _TabSpec(
      'Billetera',
      Icons.account_balance_wallet_outlined,
      WalletScreen(),
    );
    const alerts = _TabSpec(
      'Alertas',
      Icons.notifications_outlined,
      NotificationsScreen(),
    );

    return switch (role) {
      Roles.hogar => const [
          _TabSpec('Inicio', Icons.home_rounded, HogarDashboard()),
          _TabSpec('Mi Bosque', Icons.park_rounded, HogarForestScreen()),
          wallet,
          _TabSpec('Mi Perfil', Icons.person_rounded, ProfileScreen()),
        ],
      Roles.recolector => const [
          _TabSpec(
            'Solicitudes',
            Icons.travel_explore_outlined,
            AvailableRequestsScreen(),
          ),
          _TabSpec('Mis lotes', Icons.inventory_2_outlined, MyBatchScreen()),
          wallet,
          alerts,
        ],
      Roles.centroAcopio => const [
          _TabSpec('Lotes', Icons.warehouse_outlined, CenterBatchesScreen()),
          _TabSpec(
            'Inventario',
            Icons.inventory_outlined,
            InventoryScreen(canRegisterSale: true),
          ),
          _TabSpec(
            'Tarifario',
            Icons.price_change_outlined,
            CenterPricesScreen(),
          ),
          alerts,
        ],
      Roles.tienda => const [
          _TabSpec('Inicio', Icons.dashboard_outlined, StoreDashboard()),
          _TabSpec('Cobrar', Icons.qr_code_scanner_outlined, StoreQrGeneratorScreen()),
          _TabSpec('Historial', Icons.history_outlined, StoreHistoryScreen()),
          _TabSpec('Billetera', Icons.account_balance_wallet_outlined, StoreWalletScreen()),
        ],
      _ => const [wallet, alerts],
    };
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    if (user == null) return const SizedBox.shrink();

    final hasUnread = session.hasUnreadNotifications;
    final tabs = _tabsFor(user.role);
    final index = _index < tabs.length ? _index : 0;

    final netService = context.watch<NetworkConnectivityService>();
    final isOnline = netService.isOnline;
    final wasRestored = netService.wasOffline;

    // Al restaurarse el internet tras haber estado offline:
    if (isOnline && !_lastKnownOnline) {
      _bannerDismissed = false;
      _realtime?.connect();
      OfflineQueueManager.processQueue();
    }
    _lastKnownOnline = isOnline;

    final isOffline = !isOnline;
    final isBannerVisible = (isOffline || wasRestored) && !_bannerDismissed;
    final topOffset = MediaQuery.paddingOf(context).top + kToolbarHeight + 6;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: index,
            children: [for (final tab in tabs) tab.body],
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            top: isBannerVisible ? topOffset : -80,
            left: 14,
            right: 14,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: isBannerVisible ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !isBannerVisible,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(10),
                  color: wasRestored
                      ? const Color(0xFF059669) // Emerald 600
                      : const Color(0xFFB45309), // Amber 700
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(
                      children: [
                        Icon(
                          wasRestored
                              ? Icons.check_circle_outline_rounded
                              : Icons.wifi_off_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            wasRestored
                                ? 'Conexión a internet restablecida'
                                : 'Sin conexión a internet • Modo sin conexión',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!wasRestored) ...[
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              netService.checkReachabilityNow();
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh_rounded, size: 13, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text(
                                    'Reintentar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() => _bannerDismissed = true);
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(Icons.close_rounded, size: 15, color: Colors.white70),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: (user.role == Roles.hogar && tabs.length == 4)
              ? _buildHogarNotchedBar(
                  tabs: tabs,
                  currentIndex: index,
                  hasUnread: hasUnread,
                  user: user,
                )
              : _buildStandardFloatingBar(
                  tabs: tabs,
                  currentIndex: index,
                  hasUnread: hasUnread,
                  user: user,
                ),
        ),
      ),
    );
  }

  Future<void> _triggerHogarRecycleAction() async {
    final session = context.read<SessionController>();
    if (session.activeRequest != null) {
      showAppSnack(
        context,
        'Ya cuentas con una solicitud activa. Revisa los detalles en la pantalla principal.',
      );
      if (_index != 0) {
        setState(() => _index = 0);
      }
      return;
    }

    final user = session.user;
    final hasAddress = user?.address != null &&
        user!.address!.trim().isNotEmpty &&
        !user.address!.startsWith('Ubicación GPS');

    if (!hasAddress) {
      showAppSnack(
        context,
        'Por favor, fija tu dirección de recojo antes de solicitar.',
      );
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => AddressSelectorBottomSheet(user: user),
      );
      if (result == null || !mounted) return;

      final newAddress = result['address'] as String?;
      final newLat = result['latitude'] as double?;
      final newLng = result['longitude'] as double?;

      if (newAddress != null && newAddress.trim().isNotEmpty) {
        try {
          final api = context.read<LivoraApi>();
          await api.updateProfile(
            address: newAddress.trim(),
            latitude: newLat,
            longitude: newLng,
          );
          if (session.user != null) {
            await session.updateUser(
              session.user!.copyWith(
                address: newAddress.trim(),
                latitude: newLat,
                longitude: newLng,
              ),
            );
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateRequestScreen()),
    );
  }

  Widget _buildHogarNotchedBar({
    required List<_TabSpec> tabs,
    required int currentIndex,
    required bool hasUnread,
    required dynamic user,
  }) {
    return SizedBox(
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Barra con hendidura cóncava
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 66,
            child: CustomPaint(
              painter: const _NotchedBarPainter(
                color: LivoraColors.forest,
                shadowColor: Colors.black26,
                notchRadius: 32,
              ),
              child: Row(
                children: [
                  // Lado izquierdo: Inicio y Mi Bosque
                  Expanded(
                    child: Row(
                      children: [
                        _buildNavItem(
                          tab: tabs[0],
                          isSelected: currentIndex == 0,
                          hasBadge: false,
                          badgeCount: null,
                          onTap: () => _onTabSelected(0),
                        ),
                        _buildNavItem(
                          tab: tabs[1],
                          isSelected: currentIndex == 1,
                          hasBadge: false,
                          badgeCount: null,
                          onTap: () => _onTabSelected(1),
                        ),
                      ],
                    ),
                  ),

                  // Hendidura central reservada
                  const SizedBox(width: 72),

                  // Lado derecho: Billetera y Mi Perfil
                  Expanded(
                    child: Row(
                      children: [
                        _buildNavItem(
                          tab: tabs[2],
                          isSelected: currentIndex == 2,
                          hasBadge: false,
                          badgeCount: null,
                          onTap: () => _onTabSelected(2),
                        ),
                        _buildNavItem(
                          tab: tabs[3],
                          isSelected: currentIndex == 3,
                          hasBadge: false,
                          badgeCount: null,
                          onTap: () => _onTabSelected(3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Burbuja flotante incitante de reciclaje en la hendidura
          Positioned(
            top: -6,
            child: _buildCenterRecycleBubble(),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterRecycleBubble() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        _triggerHogarRecycleAction();
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF047857)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFFD1FAE5),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF059669).withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.recycling_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }

  void _onTabSelected(int value) {
    if (_index != value) {
      setState(() => _index = value);
      context.read<SessionController>().notifyBatchesChanged();
    }
  }

  Widget _buildStandardFloatingBar({
    required List<_TabSpec> tabs,
    required int currentIndex,
    required bool hasUnread,
    required dynamic user,
  }) {
    return Container(
      height: 66,
      decoration: BoxDecoration(
        color: LivoraColors.forest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++)
            _buildNavItem(
              tab: tabs[i],
              isSelected: currentIndex == i,
              hasBadge: (tabs[i].label == 'Alertas' && hasUnread),
              badgeCount: (tabs[i].label == 'Lotes' && user.role == Roles.centroAcopio && _pendingCenterBatchesCount > 0)
                  ? _pendingCenterBatchesCount
                  : null,
              onTap: () => _onTabSelected(i),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required _TabSpec tab,
    required bool isSelected,
    required bool hasBadge,
    required int? badgeCount,
    required VoidCallback onTap,
  }) {
    final iconWidget = Icon(
      tab.icon,
      size: 22,
      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.65),
    );

    final badgedIcon = hasBadge
        ? Badge(
            backgroundColor: const Color(0xFFEF4444),
            smallSize: 8,
            child: iconWidget,
          )
        : (badgeCount != null && badgeCount > 0)
            ? Badge.count(
                count: badgeCount,
                backgroundColor: const Color(0xFFF59E0B),
                textColor: Colors.white,
                child: iconWidget,
              )
            : iconWidget;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.15),
          highlightColor: Colors.transparent,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 12 : 6,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? LivoraColors.mint.withValues(alpha: 0.24)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  badgedIcon,
                  const SizedBox(height: 3),
                  Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.65),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 10.5,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter para dibujar la barra verde de navegación con hendidura cóncava semicircular superior.
class _NotchedBarPainter extends CustomPainter {
  const _NotchedBarPainter({
    required this.color,
    required this.shadowColor,
    this.notchRadius = 32.0,
  });

  final Color color;
  final Color shadowColor;
  final double notchRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    final path = Path();
    final w = size.width;
    final h = size.height;
    const r = 28.0; // Radio de las esquinas exteriores
    final cx = w / 2;
    final nr = notchRadius;

    // Inicio en esquina superior izquierda
    path.moveTo(r, 0);

    // Borde superior izquierdo hasta el notch
    path.lineTo(cx - nr - 14, 0);

    // Entrada curva suave a la hendidura
    path.cubicTo(
      cx - nr - 4, 0,
      cx - nr, 8,
      cx - nr + 2, 14,
    );

    // Arco cóncavo de la hendidura
    path.arcToPoint(
      Offset(cx + nr - 2, 14),
      radius: Radius.circular(nr + 2),
      clockwise: false,
    );

    // Salida curva suave de la hendidura
    path.cubicTo(
      cx + nr, 8,
      cx + nr + 4, 0,
      cx + nr + 14, 0,
    );

    // Borde superior derecho hasta esquina
    path.lineTo(w - r, 0);
    path.arcToPoint(Offset(w, r), radius: const Radius.circular(r));

    // Borde lateral derecho
    path.lineTo(w, h - r);
    path.arcToPoint(Offset(w - r, h), radius: const Radius.circular(r));

    // Borde inferior
    path.lineTo(r, h);
    path.arcToPoint(Offset(0, h - r), radius: const Radius.circular(r));

    // Borde lateral izquierdo
    path.lineTo(0, r);
    path.arcToPoint(const Offset(r, 0), radius: const Radius.circular(r));

    path.close();

    // Dibujar sombra y barra
    canvas.drawPath(path.shift(const Offset(0, 5)), shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NotchedBarPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.shadowColor != shadowColor ||
      oldDelegate.notchRadius != notchRadius;
}
