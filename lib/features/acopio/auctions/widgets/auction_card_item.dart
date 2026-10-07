import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/formats.dart';
import '../../../../models/models.dart';

/// Tarjeta individual para mostrar una solicitud en subasta y permitir postulación de ofertas.
class AuctionCardItem extends StatelessWidget {
  final CollectionRequest request;
  final bool isClaiming;
  final VoidCallback onBid;

  const AuctionCardItem({
    super.key,
    required this.request,
    required this.isClaiming,
    required this.onBid,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: LivoraColors.border),
      ),
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
                    color: LivoraColors.forest.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.gavel_rounded, color: LivoraColors.forest, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subasta #${request.shortId}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        request.householdAddress ?? 'Ubicación Lima',
                        style: const TextStyle(fontSize: 12, color: LivoraColors.slate),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'EN SUBASTA',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Peso Estimado: ${fmtKg(request.totalEstimatedKg)}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: LivoraColors.forest,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: request.itemsEstimated.entries.map((entry) {
                return Chip(
                  label: Text('${entry.key}: ${fmtKg(entry.value)}'),
                  backgroundColor: LivoraColors.paper,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: LivoraColors.forest),
                onPressed: isClaiming ? null : onBid,
                icon: isClaiming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.local_offer_outlined, size: 18),
                label: const Text('Enviar Oferta / Postular'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
