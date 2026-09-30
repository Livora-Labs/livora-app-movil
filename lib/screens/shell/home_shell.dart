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
import '../acopio/center_batches_screen.dart';
import '../acopio/center_prices_screen.dart';
import '../common/notifications_screen.dart';
import '../common/wallet_screen.dart';
import '../hogar/hogar_dashboard.dart';
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
  bool _showOfflineBanner = false;
  Timer? _offlineDebounceTimer;
  LivoraRealtime? _realtime;

  void setTabIndex(int index) {
    if (mounted) {
      setState(() => _index = index);
    }
  }

  void _onRealtimeConnectionChanged() {
    final connected = _realtime?.isConnected ?? false;
    if (connected) {
      _offlineDebounceTimer?.cancel();
      if (_showOfflineBanner && mounted) {
        setState(() => _showOfflineBanner = false);
      }
    } else {
      _offlineDebounceTimer?.cancel();
      _offlineDebounceTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted && !(_realtime?.isConnected ?? false)) {
          setState(() => _showOfflineBanner = true);
        }
      });
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
        _realtime?.addListener(_onRealtimeConnectionChanged);
        _realtime?.connect();
        _onRealtimeConnectionChanged();
        context.read<SessionController>().checkUnreadNotifications(context.read<LivoraApi>());

        _realtimeNotifSub?.cancel();
        _realtimeNotifSub = _realtime?.on(RealtimeEvents.notificationCreated).listen((data) {
          if (mounted) {
            context.read<SessionController>().checkUnreadNotifications(context.read<LivoraApi>());
            final title = data['title'] as String? ?? 'Nueva notificación';
            final body = data['body'] as String? ?? '';
            NotificationRouter.showInAppToast(
              title: title,
              body: body,
              data: data,
            );
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
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offlineDebounceTimer?.cancel();
    _realtime?.removeListener(_onRealtimeConnectionChanged);
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
            top: _showOfflineBanner ? MediaQuery.paddingOf(context).top + 8 : -80,
            left: 16,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showOfflineBanner ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showOfflineBanner,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFD97706),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Modo sin conexión • Reintentando enlace...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
                  : Icon(tab.icon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
