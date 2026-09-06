import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/formats.dart';
import '../core/stellar.dart';
import '../services/livora_api.dart';
import 'common.dart';

/// Modal BottomSheet deslizable para visualizar el detalle de un cobro POS / canje en tienda.
class StoreRedemptionDetailModal extends StatelessWidget {
  const StoreRedemptionDetailModal({super.key, required this.redemption});

  final dynamic redemption;

  static Future<void> show(BuildContext context, {required dynamic redemption}) async {
    await HapticFeedback.lightImpact();
    if (!context.mounted) return;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StoreRedemptionDetailModal(redemption: redemption),
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

  Future<void> _handleRefund(BuildContext context, String redemptionId, double tokenAmount) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Anular Canje',
      message:
          '¿Estás seguro de que deseas anular este canje de ${tokenAmount.toStringAsFixed(2)} EcoTokens?\n\n'
          'Los tokens serán debitados de tu balance comercial y restituidos a la billetera del cliente.',
      confirmLabel: 'Sí, anular canje',
      cancelLabel: 'Volver',
    );
    if (!confirmed || !context.mounted) return;

    try {
      await context.read<LivoraApi>().refundRedemption(redemptionId);
      if (context.mounted) {
        showAppSnack(context, 'Canje anulado y EcoTokens restituidos al cliente');
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        showAppSnack(context, e.message, error: true);
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnack(context, 'Error al procesar la anulación del canje', error: true);
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
    final rawStatus = redemption['status']?.toString().toUpperCase() ?? 'PENDING';
    final isConfirmed = rawStatus == 'CONFIRMED' || rawStatus == 'COMPLETED';
    final isExpired = rawStatus == 'EXPIRED';
    final isRefunded = rawStatus == 'REFUNDED';
    final createdAtStr = redemption['createdAt']?.toString();
    final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
    final isWithin24h = createdAt != null && DateTime.now().difference(createdAt).inHours < 24;
    final redemptionId = redemption['id']?.toString() ?? '';

    final amountRaw = redemption['tokenAmount']?.toString() ?? '0.00';
    final amountNum = double.tryParse(amountRaw) ?? 0.0;
    final qrRef = redemption['qrCodeRef']?.toString() ?? '—';
    final cleanRef = qrRef.replaceAll(RegExp(r'^LIVORA-QR-|^LIV-'), '');
    final shortRef = cleanRef.length > 8 ? cleanRef.substring(0, min(8, cleanRef.length)) : cleanRef;
    final customerName = formatCustomerTicket(redemption);
    final txHash = redemption['txHash']?.toString();
    final hasValidTx = txHash != null && txHash.isNotEmpty && Stellar.isValidTxHash(txHash);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
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
                      child: const Icon(Icons.point_of_sale_rounded, color: LivoraColors.forest, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cobro POS #$shortRef',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: LivoraColors.deep,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDateTime(redemption['createdAt']?.toString()),
                            style: TextStyle(
                              fontSize: 12,
                              color: LivoraColors.ink.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: isRefunded
                          ? 'Anulado'
                          : isConfirmed
                              ? 'Cobrado'
                              : isExpired
                                  ? 'Expirado'
                                  : 'Pendiente',
                      color: isRefunded
                          ? Colors.grey.shade700
                          : isConfirmed
                              ? LivoraColors.green
                              : isExpired
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
                        '+$amountRaw ECO',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: LivoraColors.forest,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '≈ S/ ${amountNum.toStringAsFixed(2)} PEN',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.deep,
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

                // DESGLOSE Y METADATOS COMERCIALES
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
                          'Datos de la Operación',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: LivoraColors.deep,
                          ),
                        ),
                        const Divider(height: 20),

                        // Código QR Referencia
                        _detailRow(
                          label: 'Referencia QR',
                          valueWidget: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  qrRef,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Copiar referencia',
                                icon: const Icon(Icons.copy_rounded, size: 16, color: LivoraColors.forest),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  await HapticFeedback.lightImpact();
                                  await Clipboard.setData(ClipboardData(text: qrRef));
                                  if (context.mounted) {
                                    showAppSnack(context, 'Referencia copiada al portapapeles');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Cliente Identificado
                        _detailRow(
                          label: 'Consumidor',
                          valueWidget: Text(
                            customerName,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Tipo de Transacción
                        _detailRow(
                          label: 'Tipo',
                          valueWidget: const Text(
                            'Canje presencial POS',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Fecha de creación
                        _detailRow(
                          label: 'Registrado',
                          valueWidget: Text(
                            _formatDateTime(redemption['createdAt']?.toString()),
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),

                        // Fecha de actualización / confirmación
                        if (redemption['updatedAt'] != null && isConfirmed) ...[
                          const SizedBox(height: 10),
                          _detailRow(
                            label: 'Cobrado',
                            valueWidget: Text(
                              _formatDateTime(redemption['updatedAt']?.toString()),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: LivoraColors.forest,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // REGISTRO Y TRAZABILIDAD WEB3 STELLAR
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
                            Icon(Icons.hub_outlined, color: LivoraColors.forest, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Trazabilidad Blockchain Stellar',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: LivoraColors.deep,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (hasValidTx) ...[
                          Text(
                            'Hash de Transacción:',
                            style: TextStyle(fontSize: 11.5, color: LivoraColors.ink.withValues(alpha: 0.7)),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    txHash,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copiar hash',
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: LivoraColors.forest),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    await HapticFeedback.lightImpact();
                                    await Clipboard.setData(ClipboardData(text: txHash));
                                    if (context.mounted) {
                                      showAppSnack(context, 'Hash copiado al portapapeles');
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 42),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              await HapticFeedback.lightImpact();
                              final url = 'https://stellar.expert/explorer/testnet/tx/$txHash';
                              if (context.mounted) {
                                await _openExternal(context, url);
                              }
                            },
                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                            label: const Text('Verificar en Stellar Expert', style: TextStyle(fontSize: 12.5)),
                          ),
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lock_clock_outlined, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isConfirmed
                                      ? 'Operación confirmada en ledger Soroban. La sincronización del hash se asocia a la conciliación del lote.'
                                      : 'Pendiente de escaneo y firma delegada por parte del comprador.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: LivoraColors.ink.withValues(alpha: 0.7),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (isRefunded) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.undo_rounded, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Este canje fue revertido. Los tokens fueron devueltos a la billetera del cliente.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else if (isConfirmed && isWithin24h) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _handleRefund(context, redemptionId, amountNum),
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('Anular Canje (Reversión)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                ],

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
