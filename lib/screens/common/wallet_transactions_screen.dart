import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/paging_controller.dart';
import '../../core/stellar.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/livora_empty_state.dart';
import '../../widgets/paginated_list_view.dart';
import '../../widgets/wallet_transaction_voucher_modal.dart';

/// Pantalla dedicada para consultar el historial completo de movimientos,
/// recompensas y canjes en Stellar / Soles de la billetera.
class WalletTransactionsScreen extends StatefulWidget {
  const WalletTransactionsScreen({super.key});

  @override
  State<WalletTransactionsScreen> createState() =>
      _WalletTransactionsScreenState();
}

class _WalletTransactionsScreenState extends State<WalletTransactionsScreen> {
  late final PagingController<WalletTransaction> _pagingController;
  String? _balance;
  String _selectedFilter = 'TODAS'; // 'TODAS', 'IN', 'OUT'

  @override
  void initState() {
    super.initState();
    _pagingController = PagingController<WalletTransaction>(
      fetcher: (page, limit) => _fetchTransactions(page, limit),
      keySelector: (tx) => tx.id,
      pageSize: 15,
    );
    _pagingController.loadFirstPage();
  }

  Future<List<WalletTransaction>> _fetchTransactions(int page, int limit) async {
    if (page == 1) {
      _loadBalance();
    }
    return context.read<LivoraApi>().walletTransactions(
          page: page,
          limit: limit,
          direction: _selectedFilter == 'TODAS' ? null : _selectedFilter,
        );
  }

  Future<void> _loadBalance() async {
    try {
      final bal = await context.read<LivoraApi>().walletBalance();
      if (mounted) {
        setState(() => _balance = bal);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  void _onFilterChanged(String filter) {
    if (_selectedFilter != filter) {
      HapticFeedback.lightImpact();
      setState(() => _selectedFilter = filter);
      _pagingController.refresh();
    }
  }

  String _txTypeLabel(String type) => switch (type) {
        'RECOMPENSA_RECICLAJE' => 'Recompensa por Reciclaje',
        'PAGO_TIENDA' => 'Canje en Tienda Aliada',
        'TRANSFERENCIA_EXTERNA' => 'Transferencia Stellar P2P',
        'RECARGA_NIUBIZ' => 'Recarga Saldo Niubiz',
        _ => type.replaceAll('_', ' '),
      };

  @override
  Widget build(BuildContext context) {
    final balanceVal = double.tryParse(_balance ?? '0') ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Transacciones'),
      ),
      body: Column(
        children: [
          // Resumen de Saldo
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LivoraColors.brandGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: LivoraColors.forest.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.toll, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saldo Disponible',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _balance ?? '0.00',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'ECO',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '≈ S/ ${balanceVal.toStringAsFixed(2)} PEN',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Filtros de Movimientos
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _selectedFilter == 'TODAS',
                  onSelected: (sel) {
                    if (sel) _onFilterChanged('TODAS');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.arrow_downward, size: 14, color: LivoraColors.green),
                  label: const Text('Entradas / Recompensas'),
                  selected: _selectedFilter == 'IN',
                  onSelected: (sel) {
                    if (sel) _onFilterChanged('IN');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.arrow_upward, size: 14, color: Colors.indigo),
                  label: const Text('Salidas / Canjes'),
                  selected: _selectedFilter == 'OUT',
                  onSelected: (sel) {
                    if (sel) _onFilterChanged('OUT');
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de Transacciones Paginada (60 FPS)
          Expanded(
            child: PaginatedListView<WalletTransaction>(
              controller: _pagingController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              emptyState: LivoraEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Sin movimientos',
                message: _selectedFilter == 'TODAS'
                    ? 'Aún no registras movimientos en tu billetera.'
                    : 'No hay transacciones en esta categoría.',
              ),
              separator: const SizedBox(height: 10),
              itemBuilder: (context, tx, index) {
                final isIncoming = tx.isIncoming;
                final sign = isIncoming ? '+' : '-';
                final color = isIncoming
                    ? LivoraColors.green
                    : const Color(0xFFC0392B);
                final bgColor = isIncoming
                    ? LivoraColors.green.withValues(alpha: 0.12)
                    : const Color(0xFFC0392B).withValues(alpha: 0.12);
                final counterpartyLabel = sanitizedName(
                  tx.recipientName,
                  fallback: 'Usuario Livora',
                );

                return Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: LivoraColors.border),
                  ),
                  child: InkWell(
                    onTap: () => WalletTransactionVoucherModal.show(context, transaction: tx),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isIncoming
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  color: color,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _txTypeLabel(tx.type),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                        color: LivoraColors.deep,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      counterpartyLabel,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: LivoraColors.ink.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$sign${tx.amount.toStringAsFixed(2)} ECO',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14.5,
                                      color: color,
                                    ),
                                  ),
                                  Text(
                                    '≈ S/ ${tx.amountPen.toStringAsFixed(2)} PEN',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: LivoraColors.ink.withValues(alpha: 0.65),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 13,
                                color: LivoraColors.ink.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                fmtDate(tx.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: LivoraColors.ink.withValues(alpha: 0.6),
                                ),
                              ),
                              const Spacer(),
                              if (tx.txHash != null &&
                                  Stellar.isValidTxHash(tx.txHash)) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: LivoraColors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.open_in_new,
                                        size: 11,
                                        color: LivoraColors.blue,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Ver en Stellar',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: LivoraColors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
