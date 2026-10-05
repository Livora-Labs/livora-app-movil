import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
import '../common/wallet_screen.dart';
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
          _TabSpec('Inicio', Icons.home_outlined, HogarDashboard()),
          _TabSpec('Mi Bosque', Icons.forest_outlined, HogarForestScreen()),
          wallet,
          alerts,
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          if (_index != value) {
            setState(() => _index = value);
            context.read<SessionController>().notifyBatchesChanged();
          }
        },
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: (tab.label == 'Alertas' && hasUnread)
                  ? Badge(
                      backgroundColor: Colors.red,
                      smallSize: 8,
                      child: Icon(tab.icon),
                    )
                  : (tab.label == 'Lotes' && user.role == Roles.centroAcopio && _pendingCenterBatchesCount > 0)
                      ? Badge.count(
                          count: _pendingCenterBatchesCount,
                          backgroundColor: const Color(0xFFD97706), // Amber 600
                          textColor: Colors.white,
                          child: Icon(tab.icon),
                        )
                      : Icon(tab.icon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
