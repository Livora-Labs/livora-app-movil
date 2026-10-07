import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/formats.dart';
import '../../../../models/models.dart';

/// Micro-componente con el banner superior de estado y modo de asignación.
class RequestActionsHeader extends StatelessWidget {
  const RequestActionsHeader({
    super.key,
    required this.request,
  });

  final CollectionRequest request;

  (Color, IconData, String) _statusConfig(String status) => switch (status) {
        'PENDING' => (LivoraColors.amber, Icons.hourglass_top_rounded, 'Esperando Recolector'),
        'AUCTION_OPEN' || 'AUCTION_ACTIVE' => (Colors.indigo, Icons.gavel_rounded, 'Subasta Activa de Centros'),
        'AUCTION_ASSIGNED' => (LivoraColors.forest, Icons.storefront_rounded, 'Centro de Acopio Asignado'),
        'ACCEPTED' => (LivoraColors.blue, Icons.assignment_turned_in_rounded, 'Recolector Asignado'),
        'EN_ROUTE' => (LivoraColors.forest, Icons.navigation_rounded, 'Recolector en Camino'),
        'ARRIVED' => (LivoraColors.mint, Icons.door_front_door_rounded, '¡Recolector en el Domicilio!'),
        'COMPLETED' => (LivoraColors.green, Icons.check_circle_rounded, 'Recolección Completada'),
        'CANCELLED' => (LivoraColors.coral, Icons.cancel_rounded, 'Solicitud Cancelada'),
        _ => (LivoraColors.slate, Icons.info_outline_rounded, status),
      };

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon, statusLabel) = _statusConfig(request.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: statusColor == LivoraColors.mint ? LivoraColors.forest : statusColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Código: #${request.shortId} • Creada ${fmtDate(request.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: LivoraColors.slate),
                ),
              ],
            ),
          ),
          if (request.isDonation)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: LivoraColors.mint.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Donación',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: LivoraColors.forest,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
