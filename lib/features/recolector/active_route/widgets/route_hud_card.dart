import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/app_theme.dart';
import '../../../../models/models.dart';

/// Micro-widget HUD superior de navegación: ETA, distancia restante y botón de contacto.
class RouteHudCard extends StatelessWidget {
  const RouteHudCard({
    super.key,
    required this.request,
    this.etaMinutes,
    this.distanceMeters,
    this.transportType = 'MOTO_CARGA',
  });

  final CollectionRequest request;
  final int? etaMinutes;
  final double? distanceMeters;
  final String transportType;

  String _formatDistance(double? meters) {
    if (meters == null) return '-- m';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: LivoraColors.forest.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    etaMinutes != null ? '$etaMinutes' : '--',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: LivoraColors.forest,
                    ),
                  ),
                  const Text(
                    'MIN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: LivoraColors.forest,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    request.householdAddress ?? 'Domicilio de recolección',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.straighten_rounded, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        _formatDistance(distanceMeters),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (request.householdPhone != null && request.householdPhone!.isNotEmpty)
              IconButton.filledTonal(
                icon: const Icon(Icons.phone_rounded, color: LivoraColors.forest),
                onPressed: () {
                  final uri = Uri.parse('tel:${request.householdPhone}');
                  launchUrl(uri);
                },
              ),
          ],
        ),
      ),
    );
  }
}
