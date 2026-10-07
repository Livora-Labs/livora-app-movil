import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/formats.dart';
import '../../../../models/models.dart';

/// Micro-widget para la tarjeta individual de lote en el centro de acopio.
class BatchCardItem extends StatelessWidget {
  const BatchCardItem({
    super.key,
    required this.batch,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  final Batch batch;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (batch.status) {
      'RECEIVED' || 'CONSOLIDATED' => LivoraColors.forest,
      'IN_TRANSIT' => const Color(0xFFD97706),
      'FLAGGED_FOR_REVIEW' || 'DISPUTED' => LivoraColors.coral,
      _ => Colors.blueGrey,
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? LivoraColors.forest : Colors.grey.shade200,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Lote #${batch.shortId}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      if (batch.hasDiscrepancy) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            'Discrepancia',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      batchStatusLabel(batch.status),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.scale_rounded, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    '${(batch.totalActualKg > 0 ? batch.totalActualKg : batch.totalEstimatedKg).toStringAsFixed(1)} kg',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (batch.collectorName != null) ...[
                    Icon(Icons.person_pin_rounded, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      batch.collectorName!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
