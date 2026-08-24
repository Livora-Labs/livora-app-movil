import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formats.dart';
import '../../core/session.dart';
import '../../services/livora_realtime.dart';
import '../acopio/center_batches_screen.dart';
import '../common/notifications_screen.dart';
import '../common/wallet_screen.dart';
import '../hogar/hogar_dashboard.dart';
import '../recolector/available_requests_screen.dart';
import '../recolector/my_batch_screen.dart';
import '../tienda/inventory_screen.dart';

class _TabSpec {
  const _TabSpec(this.label, this.icon, this.body);

  final String label;
  final IconData icon;
  final Widget body;
}

/// Contenedor principal: elige las pestañas según el rol del usuario.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Al entrar a la zona autenticada abrimos el socket; se cierra al salir
    // (logout) porque el shell se desmonta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LivoraRealtime>().connect();
    });
  }

  @override
  void dispose() {
    context.read<LivoraRealtime>().disconnect();
    super.dispose();
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
          _TabSpec('Mi lote', Icons.inventory_2_outlined, MyBatchScreen()),
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
          wallet,
          alerts,
        ],
      Roles.almacen => const [
          _TabSpec('Inventario', Icons.storefront_outlined, InventoryScreen()),
          wallet,
          alerts,
        ],
      _ => const [wallet, alerts],
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    if (user == null) return const SizedBox.shrink();

    final tabs = _tabsFor(user.role);
    final index = _index < tabs.length ? _index : 0;

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [for (final tab in tabs) tab.body],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}
