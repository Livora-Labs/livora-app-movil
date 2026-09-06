import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Modal de confirmación legal y delegación de firma para transacciones Web3
/// en la blockchain Stellar / Soroban (Ley N° 29733 / Indecopi).
class Web3ConfirmModal extends StatelessWidget {
  const Web3ConfirmModal({
    super.key,
    required this.tokenAmount,
    required this.destinationName,
    this.tokenSymbol = 'ECO',
    this.destinationAddress,
    this.actionDescription = 'Canje de EcoTokens en Comercio Aliado',
    this.concept,
    this.warningText =
        'Al confirmar, autorizas a Livora a firmar la transacción en la blockchain Stellar. Esta acción es irreversible.',
    this.isLoading = false,
    required this.onConfirm,
    required this.onCancel,
  });

  final double tokenAmount;
  final String tokenSymbol;
  final String destinationName;
  final String? destinationAddress;
  final String actionDescription;
  final String? concept;
  final String warningText;
  final bool isLoading;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1B2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF1E293B)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.gpp_maybe_outlined,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Confirmar Transacción Blockchain',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF8FAFC),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: isLoading ? null : onCancel,
                  icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tarjeta de Monto y Destino
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A192F),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Monto a debitar',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tokenAmount.toStringAsFixed(2)} $tokenSymbol',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF1E293B), height: 1),
                  const SizedBox(height: 12),
                  _buildDetailRow('Destino / Comercio:', destinationName, isBold: true),
                  if (destinationAddress != null) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Billetera Stellar:',
                      destinationAddress!.length > 16
                          ? '${destinationAddress!.substring(0, 8)}...${destinationAddress!.substring(destinationAddress!.length - 8)}'
                          : destinationAddress!,
                      isMonospace: true,
                      color: const Color(0xFF06B6D4),
                    ),
                  ],
                  if (concept != null && concept!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow('Concepto:', concept!),
                  ],
                  const SizedBox(height: 8),
                  _buildDetailRow('Operación:', actionDescription),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Comisión de Red:',
                    '0.00 ECO (Cubierto por Livora)',
                    color: const Color(0xFF10B981),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Banner legal obligatorio
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warningText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFDE68A),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF8FAFC),
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: FilledButton(
                    onPressed: isLoading ? null : onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: const Color(0xFF0A192F),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF0A192F),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Confirmar',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward, size: 16),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    bool isMonospace = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              fontFamily: isMonospace ? 'monospace' : null,
              color: color ?? const Color(0xFFF8FAFC),
            ),
          ),
        ),
      ],
    );
  }
}

/// Muestra el modal de confirmación Web3 y devuelve `true` si el usuario aceptó y firmó.
Future<bool> showWeb3ConfirmModal(
  BuildContext context, {
  required double tokenAmount,
  required String destinationName,
  String tokenSymbol = 'ECO',
  String? destinationAddress,
  String actionDescription = 'Canje de EcoTokens en Comercio Aliado',
  String? concept,
  String warningText =
      'Al confirmar, autorizas a Livora a firmar la transacción en la blockchain Stellar. Esta acción es irreversible.',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Web3ConfirmModal(
      tokenAmount: tokenAmount,
      destinationName: destinationName,
      tokenSymbol: tokenSymbol,
      destinationAddress: destinationAddress,
      actionDescription: actionDescription,
      concept: concept,
      warningText: warningText,
      onConfirm: () => Navigator.pop(dialogContext, true),
      onCancel: () => Navigator.pop(dialogContext, false),
    ),
  );
  return result ?? false;
}
