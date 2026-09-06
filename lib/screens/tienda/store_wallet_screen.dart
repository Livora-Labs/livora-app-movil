import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../core/stellar.dart';
import '../../services/livora_api.dart';
import '../../widgets/cash_out_modal.dart';
import '../../widgets/common.dart';
import '../../widgets/store_settlement_detail_modal.dart';
import '../common/profile.dart';
import 'store_history_screen.dart';
import 'store_profile_screen.dart';

/// Billetera comercial dedicada para comercios aliados (Rol TIENDA).
/// Centraliza la custodia de tokens de cobro POS y la solicitud de liquidación FIAT a cuenta CCI.
class StoreWalletScreen extends StatefulWidget {
  const StoreWalletScreen({super.key});

  @override
  State<StoreWalletScreen> createState() => _StoreWalletScreenState();
}

class _StoreWalletScreenState extends State<StoreWalletScreen> {
  String? _balance;
  Map<String, dynamic>? _storeProfile;
  List<dynamic>? _recentSettlements;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final api = context.read<LivoraApi>();
      final results = await Future.wait([
        api.walletBalance(),
        api.getStoreProfile(),
        api.storeSettlements(),
      ]);

      if (mounted) {
        setState(() {
          _balance = results[0] as String?;
          _storeProfile = results[1] as Map<String, dynamic>?;
          _recentSettlements = results[2] as List<dynamic>?;
        });
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } catch (_) {
      // Ignorar fallos de red silenciosos
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _balanceNumber {
    return double.tryParse(_balance ?? '0') ?? 0.0;
  }

  String? get _bankAccount => _storeProfile?['bankAccount']?.toString();

  Future<void> _openCashOut() async {
    final success = await CashOutModal.show(
      context,
      availableBalance: _balanceNumber,
      initialBankAccount: _bankAccount,
    );
    if (success && mounted) {
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final address = user?.walletAddress;
    final balanceVal = _balanceNumber;
    final cciDigits = _bankAccount?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final hasValidCci = cciDigits.length == 20;

    return Scaffold(
      appBar: livoraAppBar(context, 'Billetera Comercial'),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // TARJETA DE SALDO COMERCIAL
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LivoraColors.brandGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: LivoraColors.forest.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Saldo Disponible de Ventas POS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualizar saldo',
                        onPressed: _loading ? null : _loadAll,
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _loading && _balance == null
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          ),
                        )
                      : Text(
                          _balance ?? '0.00',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                  const SizedBox(height: 2),
                  Text(
                    '≈ S/ ${balanceVal.toStringAsFixed(2)} PEN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '1.00 EcoToken (ECO) = S/ 1.00 Soles (PEN)',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),

                  // Dirección Pública Web3
                  if (address != null) ...[
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        await HapticFeedback.lightImpact();
                        await Clipboard.setData(ClipboardData(text: address));
                        if (context.mounted) {
                          showAppSnack(context, 'Dirección de comercio copiada');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                address,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.copy_rounded, color: Colors.white, size: 15),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          if (!Stellar.isValidAddress(address)) {
                            showAppSnack(context, 'Dirección pública inválida', error: true);
                            return;
                          }
                          final opened = await Stellar.openAccountInExplorer(address);
                          if (!opened && context.mounted) {
                            showAppSnack(
                              context,
                              'No se pudo abrir el explorador de transacciones',
                              error: true,
                            );
                          }
                        },
                        icon: const Icon(Icons.receipt_long_outlined, size: 15),
                        label: const Text(
                          'Ver registros blockchain en Stellar Expert',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // CONTENEDOR PRINCIPAL: SOLICITAR LIQUIDACIÓN A CCI BANCARIO
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: LivoraColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: LivoraColors.forest.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_balance, color: LivoraColors.forest, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Liquidación a Cuenta Bancaria',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: LivoraColors.deep,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                hasValidCci
                                    ? 'Abono directo a: ${formatMaskedCci(_bankAccount)}'
                                    : 'Sin cuenta CCI registrada',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: hasValidCci ? FontWeight.w700 : FontWeight.w500,
                                  color: hasValidCci ? LivoraColors.forest : Colors.amber.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Configuración fiscal y CCI',
                          icon: const Icon(Icons.settings_outlined, color: LivoraColors.ink, size: 20),
                          onPressed: () async {
                            await Navigator.push<void>(
                              context,
                              MaterialPageRoute(builder: (_) => const StoreProfileScreen()),
                            );
                            _loadAll();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Convierte tus EcoTokens en Soles (PEN) sin costo de comisión de retiro. '
                      'Los fondos serán transferidos a tu cuenta CCI registrada.',
                      style: TextStyle(fontSize: 12, color: LivoraColors.ink, height: 1.3),
                    ),
                    const SizedBox(height: 16),
                    BusyButton(
                      label: 'Solicitar Liquidación a CCI Bancario',
                      icon: Icons.payments_outlined,
                      onPressed: _openCashOut,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // SECCIÓN: RESUMEN DE ACTIVIDAD Y ACCESO A HISTORIAL
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Últimas Liquidaciones FIAT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StoreHistoryScreen()),
                      );
                    },
                    child: const Text('Ver historial completo'),
                  ),
                ],
              ),
            ),

            if (_recentSettlements != null && _recentSettlements!.isNotEmpty) ...[
              ...(_recentSettlements!.take(3).map((item) {
                final status = item['status']?.toString().toUpperCase() ?? 'PENDING';
                final isApproved = status == 'APPROVED' || status == 'COMPLETED';
                final amount = item['tokenAmount'] ?? '0.00';
                final date = item['createdAt']?.toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => StoreSettlementDetailModal.show(
                      context,
                      settlement: item,
                      bankAccount: _bankAccount,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: LivoraColors.paper,
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: isApproved ? LivoraColors.forest : Colors.amber.shade800,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Liquidación - $amount ECO',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    subtitle: Text(
                      date != null && date.length >= 10 ? 'Fecha: ${date.substring(0, 10)}' : 'Fecha: —',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: StatusChip(
                      label: isApproved ? 'Aprobado' : 'Procesando',
                      color: isApproved ? LivoraColors.green : Colors.amber,
                    ),
                  ),
                );
              })),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history_toggle_off_rounded,
                            size: 36, color: LivoraColors.ink.withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        const Text(
                          'No registras solicitudes de liquidación pendientes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: LivoraColors.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Acceso rápido a Historial de Ventas POS
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StoreHistoryScreen()),
                );
              },
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text(
                'Ver Historial de Cobros y Ventas POS',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
