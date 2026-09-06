import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../core/formats.dart';
import 'common.dart';

/// Modal BottomSheet deslizable para visualizar el detalle completo de una liquidación bancaria FIAT.
class StoreSettlementDetailModal extends StatelessWidget {
  const StoreSettlementDetailModal({
    super.key,
    required this.settlement,
    this.bankAccount,
  });

  final dynamic settlement;
  final String? bankAccount;

  static Future<void> show(
    BuildContext context, {
    required dynamic settlement,
    String? bankAccount,
  }) async {
    await HapticFeedback.lightImpact();
    if (!context.mounted) return;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StoreSettlementDetailModal(
        settlement: settlement,
        bankAccount: bankAccount,
      ),
    );
  }

  Future<void> _openExternal(BuildContext context, String urlStr) async {
    final uri = Uri.tryParse(urlStr);
    if (uri == null) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        showAppSnack(context, 'No se pudo abrir el enlace', error: true);
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnack(context, 'Error al abrir el navegador', error: true);
      }
    }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '—';
    try {
      final date = DateTime.parse(isoString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawStatus = settlement['status']?.toString().toUpperCase() ?? 'PENDING';
    final isApproved = rawStatus == 'APPROVED' || rawStatus == 'COMPLETED' || rawStatus == 'PAID';
    final isRejected = rawStatus == 'REJECTED';

    final tokenAmountRaw = settlement['tokenAmount']?.toString() ?? '0.00';
    final tokenNum = double.tryParse(tokenAmountRaw) ?? 0.0;
    final fiatAmountRaw = settlement['fiatAmount']?.toString();
    final fiatNum = double.tryParse(fiatAmountRaw ?? '') ?? tokenNum;

    final id = settlement['id']?.toString() ?? '—';
    final shortId = id.length > 8 ? id.substring(0, min(8, id.length)) : id;
    final cci = bankAccount ?? settlement['bankAccount']?.toString();
    final receiptUrl = settlement['receiptUrl']?.toString();

    return DraggableScrollableSheet(
      initialChildSize: 0.80,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (sheetContext, scrollController) => Column(
        children: [
          // Tirador táctil (Drag Handle)
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              children: [
                // Cabecera principal
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: LivoraColors.forest.withValues(alpha: 0.12),
                      child: const Icon(Icons.account_balance_rounded, color: LivoraColors.forest, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Liquidación #$shortId',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: LivoraColors.deep,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDateTime(settlement['createdAt']?.toString()),
                            style: TextStyle(
                              fontSize: 12,
                              color: LivoraColors.ink.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: isApproved
                          ? 'Aprobado'
                          : isRejected
                              ? 'Rechazado'
                              : 'En Proceso',
                      color: isApproved
                          ? LivoraColors.green
                          : isRejected
                              ? Colors.red
                              : Colors.amber,
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // TARJETA HERO FINANCIERA
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: LivoraColors.paper,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LivoraColors.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '-$tokenAmountRaw ECO',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFC0392B),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Abono Neto: S/ ${fiatNum.toStringAsFixed(2)} PEN',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: LivoraColors.forest,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: LivoraColors.forest.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Tasa fija garantizada: 1.00 ECO = S/ 1.00 Soles (PEN)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: LivoraColors.forest,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // DESGLOSE FINANCIERO Y TRANSPARENCIA DE COSTOS
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: LivoraColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Desglose Financiero',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: LivoraColors.deep,
                          ),
                        ),
                        const Divider(height: 20),

                        _detailRow(
                          label: 'Tokens debitados',
                          valueWidget: Text(
                            '$tokenAmountRaw ECO',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 10),

                        _detailRow(
                          label: 'Tasa de liquidación',
                          valueWidget: const Text(
                            '1 ECO = S/ 1.00 PEN',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                        ),
                        const SizedBox(height: 10),

                        _detailRow(
                          label: 'Comisión de transferencia',
                          valueWidget: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: LivoraColors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'S/ 0.00 PEN (Promo)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: LivoraColors.forest,
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 20),

                        _detailRow(
                          label: 'Monto neto a transferir',
                          valueWidget: Text(
                            'S/ ${fiatNum.toStringAsFixed(2)} PEN',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              color: LivoraColors.forest,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // DATOS BANCARIOS DE DESTINO
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: LivoraColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.account_balance, color: LivoraColors.forest, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Cuenta Bancaria de Destino',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: LivoraColors.deep,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        _detailRow(
                          label: 'Entidad Bancaria',
                          valueWidget: Text(
                            formatMaskedCci(cci),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: LivoraColors.deep,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        _detailRow(
                          label: 'Tipo de Operación',
                          valueWidget: const Text(
                            'Transferencia Interbancaria CCI',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 10),

                        _detailRow(
                          label: 'Plazo Estimado',
                          valueWidget: const Text(
                            '12 a 48 hrs hábiles',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // COMPROBANTE DE TRANSFERENCIA (VOUCHER)
                if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: LivoraColors.green),
                    ),
                    color: LivoraColors.paper,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.receipt_long_rounded, color: LivoraColors.forest, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Comprobante Bancario Emitido',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 42),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              await HapticFeedback.lightImpact();
                              if (context.mounted) {
                                await _openExternal(context, receiptUrl);
                              }
                            },
                            icon: const Icon(Icons.file_open_rounded, size: 16),
                            label: const Text('Ver Voucher Oficial de Pago', style: TextStyle(fontSize: 12.5)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // BOTÓN DE CIERRE
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LivoraColors.forest,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: const Text('Cerrar Detalle', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow({required String label, required Widget valueWidget}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: LivoraColors.ink.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: valueWidget,
          ),
        ),
      ],
    );
  }
}
