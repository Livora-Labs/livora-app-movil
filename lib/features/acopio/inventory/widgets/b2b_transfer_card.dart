import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/formats.dart';
import '../../../../models/models.dart';

/// Tarjeta de despacho / recepción B2B entre Centros de Acopio y Plantas de Valorización.
class B2bTransferCard extends StatelessWidget {
  final B2bTransfer transfer;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const B2bTransferCard({
    super.key,
    required this.transfer,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (transfer.status) {
      'PENDING' => Colors.amber.shade800,
      'ACCEPTED' || 'COMPLETED' => LivoraColors.forest,
      'REJECTED' => Colors.red.shade700,
      _ => LivoraColors.slate,
    };

    final statusLabel = switch (transfer.status) {
      'PENDING' => 'Pendiente de Recepción',
      'ACCEPTED' || 'COMPLETED' => 'Recibido en Planta',
      'REJECTED' => 'Rechazado',
      _ => transfer.status,
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: LivoraColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Despacho: ${transfer.buyerLabel}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${fmtKg(transfer.totalWeightKg)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: LivoraColors.forest,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Fecha: ${fmtDate(transfer.createdAt)}',
              style: const TextStyle(fontSize: 12, color: LivoraColors.slate),
            ),
            if (transfer.status == 'PENDING') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                      onPressed: onReject,
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: LivoraColors.forest),
                      onPressed: onAccept,
                      child: const Text('Aceptar Carga'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
