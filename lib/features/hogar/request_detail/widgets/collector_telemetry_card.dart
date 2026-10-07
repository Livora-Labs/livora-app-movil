import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app_theme.dart';

/// Micro-componente que presenta la tarjeta de telemetría y contacto del recolector.
class CollectorTelemetryCard extends StatelessWidget {
  const CollectorTelemetryCard({
    super.key,
    required this.collectorName,
    this.collectorPhone,
    this.transportType,
    this.etaMinutes,
    this.distanceMeters,
  });

  final String collectorName;
  final String? collectorPhone;
  final String? transportType;
  final int? etaMinutes;
  final double? distanceMeters;

  IconData _iconForTransport(String? type) => switch (type?.toUpperCase()) {
        'TRICICLO' => Icons.pedal_bike_rounded,
        'MOTO_FURGON' => Icons.electric_rickshaw_rounded,
        'CAMIONETA' => Icons.local_shipping_rounded,
        _ => Icons.directions_walk_rounded,
      };

  String _labelForTransport(String? type) => switch (type?.toUpperCase()) {
        'TRICICLO' => 'Triciclo Ecológico',
        'MOTO_FURGON' => 'Moto-furgón',
        'CAMIONETA' => 'Camioneta',
        _ => 'Recolector a pie',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: LivoraColors.deep.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: LivoraColors.mint.withValues(alpha: 0.25),
                child: const Icon(Icons.person_rounded, color: LivoraColors.forest, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collectorName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(_iconForTransport(transportType), size: 14, color: LivoraColors.slate),
                        const SizedBox(width: 4),
                        Text(
                          _labelForTransport(transportType),
                          style: const TextStyle(fontSize: 12, color: LivoraColors.slate),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (collectorPhone != null && collectorPhone!.isNotEmpty)
                IconButton(
                  tooltip: 'Llamar al recolector',
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: LivoraColors.forest.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_rounded, color: LivoraColors.forest, size: 20),
                  ),
                  onPressed: () async {
                    final uri = Uri.parse('tel:${collectorPhone!.trim()}');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
            ],
          ),
          if (etaMinutes != null || distanceMeters != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (etaMinutes != null)
                  _TelemetryMetric(
                    icon: Icons.timer_outlined,
                    label: 'Tiempo estimado',
                    value: '$etaMinutes min',
                    color: LivoraColors.forest,
                  ),
                if (distanceMeters != null)
                  _TelemetryMetric(
                    icon: Icons.route_outlined,
                    label: 'Distancia',
                    value: distanceMeters! >= 1000
                        ? '${(distanceMeters! / 1000).toStringAsFixed(1)} km'
                        : '${distanceMeters!.round()} m',
                    color: LivoraColors.blue,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TelemetryMetric extends StatelessWidget {
  const _TelemetryMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: LivoraColors.slate),
        ),
      ],
    );
  }
}
