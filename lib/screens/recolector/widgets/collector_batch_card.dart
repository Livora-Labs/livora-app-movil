import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_theme.dart';
import '../../../core/formats.dart';
import '../../../models/models.dart';
import '../../../widgets/batch_detail_modal.dart';
import '../../../widgets/common.dart';

/// Tarjeta operativa de sub-lote agrupado por Centro de Acopio de destino.
/// Incluye:
/// - Métricas de peso acumulado vs capacidad vehicular estimada.
/// - Botón directo de navegación 'Cómo llegar al Acopio' vía Google Maps / Waze.
/// - Despacho ágil en báscula con código de alto contraste.
class CollectorBatchCard extends StatelessWidget {
  const CollectorBatchCard({
    super.key,
    required this.batch,
    required this.onVerifyPin,
    required this.onDeliver,
    this.vehicleCapacityKg = 300.0,
  });

  final Batch batch;
  final void Function(CollectionRequest request) onVerifyPin;
  final VoidCallback onDeliver;
  final double vehicleCapacityKg;

  Future<void> _openNavigationToAcopio(BuildContext context) async {
    final address = batch.destinationCenterAddress;
    final name = batch.destinationCenterName ?? 'Centro de Acopio';
    final query = Uri.encodeComponent(
      address != null && address.isNotEmpty ? '$name, $address' : name,
    );
    final googleMapsUri = Uri.parse('google.navigation:q=$query&mode=d');
    final webMapsUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$query');

    try {
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri);
      } else {
        await launchUrl(webMapsUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnack(context, 'No se pudo abrir la app de navegación.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final centerName = sanitizedCenterName(
      batch.destinationCenterName,
      batch.destinationCenterEmail,
      defaultLabel: 'Centro de Acopio Destino',
    );
    final totalKg = batch.totalEstimatedKg;
    final progress = (totalKg / vehicleCapacityKg).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: LivoraColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Centro Comprador y Estado
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: LivoraColors.forest.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: LivoraColors.forest,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        centerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: LivoraColors.deep,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (batch.destinationCenterAddress?.isNotEmpty == true)
                        Text(
                          batch.destinationCenterAddress!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: LivoraColors.slate,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Botón Cómo Llegar
                IconButton(
                  tooltip: 'Cómo llegar al Centro de Acopio',
                  icon: const Icon(Icons.directions_outlined, color: LivoraColors.blue),
                  onPressed: () => _openNavigationToAcopio(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Barra de Ocupación Vehicular
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Carga acumulada: ${fmtKg(totalKg)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: LivoraColors.deep,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}% de capacidad',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: progress > 0.85 ? Colors.amber.shade800 : LivoraColors.slate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: LivoraColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress > 0.85 ? Colors.amber.shade700 : LivoraColors.forest,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Resumen de Materiales
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: LivoraColors.paper,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.recycling_rounded, size: 16, color: LivoraColors.forest),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      materialsSummary(batch.estimatedMaterials),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LivoraColors.deep,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Solicitudes del lote (Stops)
            if (batch.requests.isNotEmpty) ...[
              Text(
                'Paradas en este sub-lote (${batch.requests.length}):',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: LivoraColors.slate,
                ),
              ),
              const SizedBox(height: 6),
              ...batch.requests.take(3).map((req) {
                final isCompleted = req.status == 'COMPLETED';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        isCompleted ? Icons.check_circle_rounded : Icons.pending_outlined,
                        size: 14,
                        color: isCompleted ? LivoraColors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${req.householdName ?? 'Hogar'} · ${fmtKg(req.totalEstimatedKg)}',
                          style: const TextStyle(fontSize: 12, color: LivoraColors.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isCompleted)
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () => onVerifyPin(req),
                          child: const Text('Validar PIN', style: TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                );
              }),
              if (batch.requests.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+ ${batch.requests.length - 3} paradas adicionales',
                    style: const TextStyle(fontSize: 11, color: LivoraColors.slate),
                  ),
                ),
              const SizedBox(height: 14),
            ],

            // Botones de Acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => BatchDetailModal.show(context, batch: batch),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Ver detalle'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: LivoraColors.forest,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onDeliver,
                    icon: const Icon(Icons.qr_code_rounded, size: 18),
                    label: const Text(
                      'Despachar a Acopio',
                      style: TextStyle(fontWeight: FontWeight.w800),
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
}
