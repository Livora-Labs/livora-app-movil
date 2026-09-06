import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/paging_controller.dart';
import '../../services/livora_api.dart';
import '../../widgets/cash_out_modal.dart';
import '../../widgets/common.dart';
import '../../widgets/livora_empty_state.dart';
import '../../widgets/paginated_list_view.dart';
import '../../widgets/store_redemption_detail_modal.dart';
import '../../widgets/store_settlement_detail_modal.dart';
import '../common/profile.dart';

/// Historial comercial de ventas POS y liquidaciones FIAT para la tienda aliada con carga infinita.
class StoreHistoryScreen extends StatefulWidget {
  const StoreHistoryScreen({super.key});

  @override
  State<StoreHistoryScreen> createState() => _StoreHistoryScreenState();
}

class _StoreHistoryScreenState extends State<StoreHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final PagingController<dynamic> _redemptionsController;
  late final PagingController<dynamic> _settlementsController;

  String? _balance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _redemptionsController = PagingController<dynamic>(
      fetcher: (page, limit) => context.read<LivoraApi>().storeRedemptions(
            page: page,
            limit: limit,
          ),
      keySelector: (item) => item['id'] ?? item['qrCodeRef'] ?? UniqueKey(),
      pageSize: 15,
    );

    _settlementsController = PagingController<dynamic>(
      fetcher: (page, limit) => context.read<LivoraApi>().storeSettlements(
            page: page,
            limit: limit,
          ),
      keySelector: (item) => item['id'] ?? UniqueKey(),
      pageSize: 15,
    );

    _redemptionsController.loadFirstPage();
    _settlementsController.loadFirstPage();
    _loadBalance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _redemptionsController.dispose();
    _settlementsController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    try {
      final bal = await context.read<LivoraApi>().walletBalance();
      if (mounted) setState(() => _balance = bal);
    } catch (_) {}
  }

  Future<void> _openCashOutModal() async {
    final balanceVal = double.tryParse(_balance ?? '0') ?? 0.0;
    final success = await CashOutModal.show(
      context,
      availableBalance: balanceVal,
    );
    if (success && mounted) {
      _redemptionsController.refresh();
      _settlementsController.refresh();
      _loadBalance();
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '—';
    try {
      final date = DateTime.parse(isoString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial y Liquidaciones'),
        actions: const [
          ProfileButton(),
          SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: LivoraColors.deep,
          unselectedLabelColor: LivoraColors.ink.withValues(alpha: 0.6),
          indicatorColor: LivoraColors.forest,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          tabs: const [
            Tab(text: 'Ventas POS (Cobros)'),
            Tab(text: 'Liquidaciones FIAT'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRedemptionsTab(),
          _buildSettlementsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LivoraColors.forest,
        foregroundColor: Colors.white,
        onPressed: _openCashOutModal,
        icon: const Icon(Icons.account_balance_rounded),
        label: const Text('Liquidar a FIAT', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildRedemptionsTab() {
    return PaginatedListView<dynamic>(
      controller: _redemptionsController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      emptyState: const LivoraEmptyState(
        icon: Icons.point_of_sale_rounded,
        title: 'Sin cobros registrados',
        message: 'Tus cobros realizados mediante código QR se listarán aquí.',
        padding: EdgeInsets.fromLTRB(24, 24, 24, 80),
      ),
      itemBuilder: (context, item, index) {
        final isConfirmed = item['status'] == 'CONFIRMED' || item['status'] == 'COMPLETED';
        final customerName = formatCustomerTicket(item);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            onTap: () => StoreRedemptionDetailModal.show(context, redemption: item),
            leading: const CircleAvatar(
              backgroundColor: LivoraColors.paper,
              child: Icon(Icons.toll_rounded, color: LivoraColors.forest, size: 20),
            ),
            title: Text(
              customerName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: LivoraColors.deep),
            ),
            subtitle: Text(
              'Fecha: ${_formatDate(item['createdAt'])}',
              style: TextStyle(fontSize: 11.5, color: LivoraColors.ink.withValues(alpha: 0.7)),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${item['tokenAmount']} ECO',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: LivoraColors.forest,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                StatusChip(
                  label: isConfirmed ? 'Cobrado' : 'Pendiente',
                  color: isConfirmed ? LivoraColors.green : Colors.amber,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettlementsTab() {
    return PaginatedListView<dynamic>(
      controller: _settlementsController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      emptyState: LivoraEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Sin liquidaciones solicitadas',
        message: 'Presiona "Liquidar a FIAT" para transferir tus tokens acumulados a tu cuenta bancaria.',
        actionLabel: 'Liquidar a FIAT',
        onAction: _openCashOutModal,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
      ),
      itemBuilder: (context, item, index) {
        final status = item['status']?.toString().toUpperCase() ?? 'PENDING';
        final isApproved = status == 'APPROVED' || status == 'COMPLETED' || status == 'PAID';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            onTap: () => StoreSettlementDetailModal.show(context, settlement: item),
            leading: CircleAvatar(
              backgroundColor: isApproved
                  ? LivoraColors.forest.withValues(alpha: 0.12)
                  : Colors.amber.withValues(alpha: 0.15),
              child: Icon(
                isApproved ? Icons.check_circle_outline : Icons.hourglass_top_rounded,
                color: isApproved ? LivoraColors.forest : Colors.amber.shade800,
                size: 20,
              ),
            ),
            title: Text(
              'S/ ${(item['fiatAmount'] ?? item['tokenAmount'] ?? 0).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: LivoraColors.deep),
            ),
            subtitle: Text(
              'Fecha: ${_formatDate(item['createdAt'])}',
              style: TextStyle(fontSize: 11.5, color: LivoraColors.ink.withValues(alpha: 0.7)),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item['tokenAmount']} ECO',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 3),
                StatusChip(
                  label: switch (status) {
                    'APPROVED' || 'PAID' => 'Pagado',
                    'REJECTED' => 'Rechazado',
                    _ => 'En revisión',
                  },
                  color: switch (status) {
                    'APPROVED' || 'PAID' => LivoraColors.green,
                    'REJECTED' => LivoraColors.coral,
                    _ => Colors.amber,
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
