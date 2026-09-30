import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/session.dart';
import '../../services/livora_api.dart';
import '../../widgets/cash_out_modal.dart';
import '../../widgets/livora_shimmer.dart';
import '../../widgets/store_redemption_detail_modal.dart';
import '../../widgets/store_settlement_detail_modal.dart';
import '../common/notifications_screen.dart';
import '../common/profile.dart';
import '../../models/models.dart';
import '../shell/home_shell.dart';
import 'store_onboarding_screen.dart';
import 'widgets/store_counter_qr_flyer_dialog.dart';
import 'widgets/store_metrics_hero_card.dart';
import 'widgets/store_pending_settlement_card.dart';
import 'widgets/store_quick_actions_bar.dart';

/// Centro de control comercial y panel de operaciones para el rol TIENDA.
class StoreDashboard extends StatefulWidget {
  const StoreDashboard({super.key});

  @override
  State<StoreDashboard> createState() => _StoreDashboardState();
}

class _StoreDashboardState extends State<StoreDashboard> {
  bool _loading = true;
  String? _balance;
  Map<String, dynamic>? _storeProfile;
  List<dynamic> _recentRedemptions = [];
  Map<String, dynamic>? _pendingSettlement;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _loading = true);
    try {
      final api = context.read<LivoraApi>();
      await context.read<SessionController>().refreshKycStatus(api);
      final results = await Future.wait([
        api.walletBalance(),
        api.getStoreProfile(),
        api.storeRedemptions(page: 1, limit: 10),
        api.storeSettlements(page: 1, limit: 5),
      ]);

      if (mounted) {
        final settlements = results[3] as List<dynamic>? ?? [];
        Map<String, dynamic>? activeSettlement;
        for (final item in settlements) {
          if (item is Map<String, dynamic>) {
            final st = item['status']?.toString().toUpperCase();
            if (st == 'PENDING' || st == 'APPROVED_PENDING_PAYMENT') {
              activeSettlement = item;
              break;
            }
          }
        }

        setState(() {
          _balance = results[0] as String?;
          _storeProfile = results[1] as Map<String, dynamic>?;
          _recentRedemptions = results[2] as List<dynamic>? ?? [];
          _pendingSettlement = activeSettlement;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _availableBalanceNumber {
    return double.tryParse(_balance ?? '0') ?? 0.0;
  }

  double get _todaySalesTotal {
    final now = DateTime.now();
    double total = 0.0;
    for (final item in _recentRedemptions) {
      if (item is Map<String, dynamic>) {
        final st = item['status']?.toString().toUpperCase();
        if (st == 'CONFIRMED' || st == 'COMPLETED') {
          final dtStr = item['createdAt']?.toString();
          if (dtStr != null) {
            final dt = DateTime.tryParse(dtStr);
            if (dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day) {
              final amt = double.tryParse(item['tokenAmount']?.toString() ?? '0') ?? 0.0;
              total += amt;
            }
          }
        }
      }
    }
    return total;
  }

  int get _todayTransactionsCount {
    final now = DateTime.now();
    int count = 0;
    for (final item in _recentRedemptions) {
      if (item is Map<String, dynamic>) {
        final st = item['status']?.toString().toUpperCase();
        if (st == 'CONFIRMED' || st == 'COMPLETED') {
          final dtStr = item['createdAt']?.toString();
          if (dtStr != null) {
            final dt = DateTime.tryParse(dtStr);
            if (dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day) {
              count++;
            }
          }
        }
      }
    }
    return count;
  }

  void _openCounterQrFlyer() {
    final user = context.read<SessionController>().user;
    final businessName = _storeProfile?['businessName']?.toString() ?? user?.name ?? 'Mi Comercio';
    final walletAddress = user?.walletAddress ?? '';
    final ruc = _storeProfile?['ruc']?.toString() ?? '';
    final address = _storeProfile?['address']?.toString() ?? '';

    StoreCounterQrFlyerDialog.show(
      context,
      businessName: businessName,
      walletAddress: walletAddress,
      ruc: ruc,
      address: address,
    );
  }

  Future<void> _openCashOut() async {
    final success = await CashOutModal.show(
      context,
      availableBalance: _availableBalanceNumber,
      initialBankAccount: _storeProfile?['bankAccount']?.toString(),
    );
    if (success && mounted) {
      _loadDashboardData();
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '—';
    try {
      final date = DateTime.parse(isoString);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    final hasUnread = session.hasUnreadNotifications;
    final businessName = _storeProfile?['businessName']?.toString() ?? user?.name ?? 'Mi Comercio';

    final kycStatus = user?.kycStatus ?? KycStatus.unverified;
    final isApproved = kycStatus == KycStatus.approved;
    final isPending = kycStatus == KycStatus.pending;
    final isObserved = kycStatus == KycStatus.observed;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    businessName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: LivoraColors.deep,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  isApproved
                      ? Icons.verified_rounded
                      : isPending
                          ? Icons.schedule_rounded
                          : isObserved
                              ? Icons.warning_amber_rounded
                              : Icons.storefront_rounded,
                  size: 16,
                  color: isApproved
                      ? LivoraColors.green
                      : isPending
                          ? LivoraColors.amber
                          : isObserved
                              ? LivoraColors.coral
                              : LivoraColors.slate,
                ),
              ],
            ),
            Text(
              isApproved
                  ? 'Comercio Aliado Verificado'
                  : isPending
                      ? 'Evaluación en Proceso (24-48h)'
                      : isObserved
                          ? 'Afiliación Observada'
                          : 'Panel Comercial Aliado',
              style: TextStyle(
                fontSize: 11.5,
                color: isApproved
                    ? LivoraColors.forest
                    : isPending
                        ? const Color(0xFFD97706)
                        : isObserved
                            ? LivoraColors.coral
                            : LivoraColors.slate,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          // Icono de Notificaciones en AppBar con contador de no leídos
          IconButton(
            tooltip: 'Notificaciones',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined, size: 24),
                if (hasUnread)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          const ProfileButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: LivoraColors.forest,
        child: _loading && _balance == null
            ? const LivoraShimmerList(itemCount: 4, padding: EdgeInsets.all(16))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                children: [
                  // Estado de Onboarding o Evaluación Administrativa
                  if (_isProfileIncomplete) ...[
                    _buildSetupBanner(),
                  ] else if (isPending) ...[
                    _buildEvaluationPendingBanner(),
                  ] else if (isObserved) ...[
                    _buildObservedBanner(),
                  ],

                  // Tarjeta Hero con métricas del día
                  StoreMetricsHeroCard(
                    todayLivos: _todaySalesTotal,
                    todayTransactionsCount: _todayTransactionsCount,
                    availableBalance: _availableBalanceNumber,
                    loading: _loading,
                    onRefresh: _loadDashboardData,
                  ),
                  const SizedBox(height: 16),

                  // Barra de accesos directos rápidos con gating de seguridad
                  StoreQuickActionsBar(
                    onCobrarTap: isApproved
                        ? () => HomeShell.switchTab(context, 1)
                        : () => _showLockedFeatureDialog('Cobro POS con QR'),
                    onCartelQrTap: isApproved
                        ? _openCounterQrFlyer
                        : () => _showLockedFeatureDialog('Cartel QR de Mostrador'),
                    onCashOutTap: isApproved
                        ? _openCashOut
                        : () => _showLockedFeatureDialog('Liquidación Bancaria CCE'),
                    onHistorialTap: () => HomeShell.switchTab(context, 2),
                  ),
                  const SizedBox(height: 16),

                  // Tarjeta de Liquidación en curso (si existe)
                  if (_pendingSettlement != null) ...[
                    StorePendingSettlementCard(
                      settlement: _pendingSettlement!,
                      onTap: () {
                        StoreSettlementDetailModal.show(
                          context,
                          settlement: _pendingSettlement,
                          bankAccount: _storeProfile?['bankAccount']?.toString(),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Sección: Cobros Recientes de Hoy
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cobros Recientes en Caja',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.deep,
                        ),
                      ),
                      TextButton(
                        onPressed: () => HomeShell.switchTab(context, 2),
                        child: const Text('Ver todos', style: TextStyle(fontSize: 12.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (_recentRedemptions.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: LivoraColors.border),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.point_of_sale_outlined,
                            size: 36,
                            color: LivoraColors.slate.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Aún no registras cobros hoy',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: LivoraColors.deep,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Usa el botón Cobrar POS o coloca tu cartel QR en el mostrador para empezar a recibir LIVOs.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: LivoraColors.slate),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: LivoraColors.forest,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => HomeShell.switchTab(context, 1),
                            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                            label: const Text('Cobrar en POS', style: TextStyle(fontSize: 12.5)),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ..._recentRedemptions.take(5).map((item) {
                      final rawStatus = item['status']?.toString().toUpperCase() ?? 'PENDING';
                      final isConfirmed = rawStatus == 'CONFIRMED' || rawStatus == 'COMPLETED';
                      final isRefunded = rawStatus == 'REFUNDED';
                      final amountRaw = item['tokenAmount']?.toString() ?? '0.00';
                      final amountNum = double.tryParse(amountRaw) ?? 0.0;
                      final timeStr = _formatTime(item['createdAt']?.toString());
                      final qrRef = item['qrCodeRef']?.toString() ?? '';
                      final shortRef = qrRef.replaceAll(RegExp(r'^LIVORA-QR-|^LIV-'), '');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: LivoraColors.border),
                        ),
                        child: ListTile(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            StoreRedemptionDetailModal.show(context, redemption: item);
                          },
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: isRefunded
                                ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                                : isConfirmed
                                    ? LivoraColors.forest.withValues(alpha: 0.12)
                                    : Colors.amber.withValues(alpha: 0.12),
                            child: Icon(
                              isRefunded
                                  ? Icons.undo_rounded
                                  : isConfirmed
                                      ? Icons.check_circle_rounded
                                      : Icons.schedule_rounded,
                              color: isRefunded
                                  ? const Color(0xFFEF4444)
                                  : isConfirmed
                                      ? LivoraColors.forest
                                      : const Color(0xFFD97706),
                              size: 18,
                            ),
                          ),
                          title: Text(
                            isRefunded
                                ? 'Cobro Anulado (#${shortRef.length > 8 ? shortRef.substring(0, 8) : shortRef})'
                                : 'Cobro POS (#${shortRef.length > 8 ? shortRef.substring(0, 8) : shortRef})',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                          subtitle: Text(
                            'Hora: $timeStr · ${isConfirmed ? 'Confirmado' : isRefunded ? 'Reembolsado' : 'Pendiente'}',
                            style: const TextStyle(fontSize: 11.5, color: LivoraColors.slate),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isRefunded ? '-' : '+'}S/ ${amountNum.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                  color: isRefunded ? const Color(0xFFEF4444) : LivoraColors.forest,
                                ),
                              ),
                              Text(
                                '${amountNum.toStringAsFixed(2)} LIVO',
                                style: const TextStyle(fontSize: 11, color: LivoraColors.slate),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
      ),
    );
  }

  bool get _isProfileIncomplete {
    final ruc = _storeProfile?['ruc']?.toString().trim();
    final address = _storeProfile?['address']?.toString().trim();
    return _storeProfile == null || (ruc == null || ruc.isEmpty) || (address == null || address.isEmpty);
  }

  Widget _buildSetupBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LivoraColors.green.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LivoraColors.forest.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded, color: LivoraColors.forest, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configura tu Comercio Aliado',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Registra tu RUC y dirección comercial para recibir pagos y liquidaciones.',
                      style: TextStyle(
                        fontSize: 12,
                        color: LivoraColors.slate,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: LivoraColors.forest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text(
                'Completar Afiliación Comercial',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StoreOnboardingScreen()),
                );
                _loadDashboardData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationPendingBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.schedule_rounded, color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evaluación Comercial en Proceso',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Expediente en revisión administrativa (24 a 48h hábiles)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Los datos de tu RUC y fotografía de fachada están siendo validados por el equipo de Livora. Las opciones de cobro POS y cartel QR se activarán automáticamente una vez que tu cuenta sea aprobada.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Color(0xFF78350F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObservedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Documentación Comercial Observada',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Se requiere corregir datos para activar tu comercio',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text(
                'Corregir y Reenviar Expediente',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StoreOnboardingScreen()),
                );
                _loadDashboardData();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showLockedFeatureDialog(String featureTitle) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: Color(0xFFD97706), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                featureTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: const Text(
          'Esta función estará activa en tu panel tan pronto como el equipo administrativo de Livora apruebe la validación de tu RUC y establecimiento físico.\n\nTiempo estimado de respuesta: 24h a 48h hábiles.',
          style: TextStyle(fontSize: 13, height: 1.5, color: LivoraColors.slate),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: LivoraColors.forest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

