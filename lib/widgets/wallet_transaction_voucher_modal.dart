import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../core/formats.dart';
import '../core/stellar.dart';
import '../models/models.dart';
import 'common.dart';

/// Modal BottomSheet tipo Voucher / Recibo Digital de Transacción Financiera y Web3.
class WalletTransactionVoucherModal extends StatelessWidget {
  const WalletTransactionVoucherModal({
    super.key,
    required this.transaction,
  });

  final WalletTransaction transaction;

  static Future<void> show(
    BuildContext context, {
    required WalletTransaction transaction,
  }) async {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => WalletTransactionVoucherModal(transaction: transaction),
    );
  }

  Future<void> _openStellarExpert(BuildContext context, String txHash) async {
    HapticFeedback.lightImpact();
    final url = Uri.parse('https://stellar.expert/explorer/testnet/tx/$txHash');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          showAppSnack(context, 'No se pudo abrir el explorador de Stellar', error: true);
        }
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnack(context, 'Error al abrir Stellar Expert', error: true);
      }
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    showAppSnack(context, '$label copiado al portapapeles');
  }

  String _txTypeLabel(String type) => switch (type) {
        'RECOMPENSA_RECICLAJE' => 'Recompensa por Reciclaje',
        'PAGO_TIENDA' => 'Canje en Tienda Aliada',
        'TRANSFERENCIA_EXTERNA' => 'Transferencia Stellar P2P',
        'RECARGA_NIUBIZ' => 'Recarga Saldo Niubiz',
        'GARANTIA_ESCROW' => 'Retención de Garantía Escrow',
        _ => type.replaceAll('_', ' '),
      };

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final isIncoming = tx.isIncoming;
    final sign = isIncoming ? '+' : '-';
    final themeColor = isIncoming ? LivoraColors.green : const Color(0xFFC0392B);
    final themeBg = isIncoming
        ? LivoraColors.green.withValues(alpha: 0.12)
        : const Color(0xFFC0392B).withValues(alpha: 0.12);

    final cleanRecipient = sanitizedName(tx.recipientName, fallback: 'Usuario Livora');
    final hasValidTx = tx.txHash != null && Stellar.isValidTxHash(tx.txHash!);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.90,
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
                // Cabecera Héroe de Transacción
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: themeBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isIncoming
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          color: themeColor,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$sign${tx.amount.toStringAsFixed(2)} ECO',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: themeColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '≈ S/ ${tx.amountPen.toStringAsFixed(2)} PEN',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: LivoraColors.deep,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StatusChip(
                        label: hasValidTx ? 'Confirmado en Stellar' : 'Completado',
                        color: hasValidTx ? LivoraColors.forest : LivoraColors.blue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Ficha de Metadata Transaccional
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: LivoraColors.paper,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LivoraColors.border),
                  ),
                  child: Column(
                    children: [
                      _VoucherRow(
                        label: 'Concepto:',
                        value: _txTypeLabel(tx.type),
                        isBold: true,
                      ),
                      const Divider(height: 18),
                      _VoucherRow(
                        label: isIncoming ? 'Origen:' : 'Destino:',
                        value: cleanRecipient,
                      ),
                      const Divider(height: 18),
                      _VoucherRow(
                        label: 'Fecha y hora:',
                        value: fmtDate(tx.createdAt),
                      ),
                      const Divider(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ID Operación:',
                            style: TextStyle(fontSize: 12.5, color: LivoraColors.ink),
                          ),
                          InkWell(
                            onTap: () => _copyToClipboard(context, tx.id, 'ID de operación'),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                children: [
                                  Text(
                                    tx.id.length > 14
                                        ? '${tx.id.substring(0, 8)}...${tx.id.substring(tx.id.length - 4)}'
                                        : tx.id,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: LivoraColors.deep,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.copy, size: 14, color: LivoraColors.forest),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Sección de Trazabilidad Blockchain (Stellar Expert)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.hub_outlined, color: LivoraColors.cyan, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Registro Stellar / Soroban',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (hasValidTx) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Hash: ${Stellar.short(tx.txHash!)}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: LivoraColors.paper,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copiar Hash',
                              icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
                              onPressed: () => _copyToClipboard(context, tx.txHash!, 'Hash de transacción'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: LivoraColors.cyan,
                              foregroundColor: LivoraColors.deep,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _openStellarExpert(context, tx.txHash!),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text(
                              'Ver en Stellar Expert',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined, color: LivoraColors.cyan, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Operación procesada mediante balance contable interno o pasarela Niubiz.',
                                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherRow extends StatelessWidget {
  const _VoucherRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: LivoraColors.ink),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: LivoraColors.deep,
            ),
          ),
        ),
      ],
    );
  }
}
