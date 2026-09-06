import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../screens/common/wallet_screen.dart';

/// Modal BottomSheet interactivo de marca para advertencia de saldo insuficiente en garantía Escrow.
class InsufficientEscrowBottomSheet extends StatelessWidget {
  const InsufficientEscrowBottomSheet({
    super.key,
    required this.requiredEscrow,
    required this.walletBalance,
    this.onRechargeCompleted,
  });

  final double requiredEscrow;
  final double walletBalance;
  final VoidCallback? onRechargeCompleted;

  static Future<void> show(
    BuildContext context, {
    required double requiredEscrow,
    required double walletBalance,
    VoidCallback? onRechargeCompleted,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) => InsufficientEscrowBottomSheet(
        requiredEscrow: requiredEscrow,
        walletBalance: walletBalance,
        onRechargeCompleted: onRechargeCompleted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final missing = (requiredEscrow - walletBalance).clamp(0.0, double.infinity);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Icon(
                    Icons.lock_clock_rounded,
                    color: Color(0xFFD97706),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Garantía Insuficiente',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.deep,
                        ),
                      ),
                      Text(
                        'Garantía de recolección requerida',
                        style: TextStyle(
                          fontSize: 13,
                          color: LivoraColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: LivoraColors.paper,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LivoraColors.deep.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  _EscrowRow(
                    label: 'Garantía requerida:',
                    value: '${requiredEscrow.toStringAsFixed(2)} ECO',
                    valueColor: LivoraColors.deep,
                    isBold: true,
                  ),
                  const Divider(height: 18),
                  _EscrowRow(
                    label: 'Tu saldo libre:',
                    value: '${walletBalance.toStringAsFixed(2)} ECO',
                    valueColor: walletBalance < requiredEscrow ? const Color(0xFF9E2A2B) : LivoraColors.forest,
                  ),
                  if (missing > 0) ...[
                    const SizedBox(height: 6),
                    _EscrowRow(
                      label: 'Faltante para aceptar:',
                      value: '- ${missing.toStringAsFixed(2)} ECO',
                      valueColor: const Color(0xFF9E2A2B),
                      isBold: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Saldo insuficiente para la garantía. Recarga EcoTokens mediante Niubiz para continuar.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: LivoraColors.deep,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'La garantía se retiene temporalmente y se te reembolsa al entregar los materiales en el centro de acopio.',
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: LivoraColors.slate.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: LivoraColors.forest,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletScreen()),
                ).then((_) {
                  onRechargeCompleted?.call();
                });
              },
              icon: const Icon(Icons.credit_card_rounded, size: 20),
              label: const Text(
                'Recargar vía Niubiz',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: const Text(
                'Entendido, en otro momento',
                style: TextStyle(color: LivoraColors.slate, fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EscrowRow extends StatelessWidget {
  const _EscrowRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: LivoraColors.slate,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
