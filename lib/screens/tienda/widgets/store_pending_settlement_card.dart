import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';

/// Tarjeta visible en el Dashboard cuando el comercio tiene una solicitud de liquidación en proceso.
class StorePendingSettlementCard extends StatelessWidget {
  const StorePendingSettlementCard({
    super.key,
    required this.settlement,
    required this.onTap,
  });

  final Map<String, dynamic> settlement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rawStatus = settlement['status']?.toString().toUpperCase() ?? 'PENDING';
    final isApproved = rawStatus == 'APPROVED_PENDING_PAYMENT';
    final tokenAmount = settlement['tokenAmount']?.toString() ?? '0.00';
    final amountNum = double.tryParse(tokenAmount) ?? 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isApproved ? LivoraColors.blue : const Color(0xFFF59E0B),
          width: 1.5,
        ),
      ),
      color: (isApproved ? LivoraColors.blue : const Color(0xFFF59E0B)).withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isApproved ? LivoraColors.blue : const Color(0xFFF59E0B))
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isApproved ? Icons.schedule_rounded : Icons.hourglass_top_rounded,
                      color: isApproved ? LivoraColors.blue : const Color(0xFFD97706),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Retiro Bancario en Proceso',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: LivoraColors.deep,
                          ),
                        ),
                        Text(
                          isApproved
                              ? 'Aprobado: Transfiriendo a cuenta bancaria (CCE)'
                              : 'Solicitado: En revisión de tesorería',
                          style: TextStyle(
                            fontSize: 11,
                            color: isApproved ? LivoraColors.blue : const Color(0xFFD97706),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: LivoraColors.slate),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Monto en liquidación:',
                    style: TextStyle(fontSize: 12, color: LivoraColors.slate),
                  ),
                  Text(
                    'S/ ${amountNum.toStringAsFixed(2)} PEN',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: LivoraColors.deep,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
