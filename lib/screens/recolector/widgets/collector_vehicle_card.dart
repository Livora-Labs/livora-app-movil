import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/livora_api.dart';
import '../kyc_screen.dart';

/// Tarjeta especializada de Gestión Operativa para el perfil del Recolector.
/// Muestra tipo de vehículo, placa de rodaje, reputación en estrellas y acceso
/// a la actualización de credenciales operativas.
class CollectorVehicleCard extends StatefulWidget {
  const CollectorVehicleCard({
    super.key,
    required this.user,
    required this.kycStatus,
  });

  final AuthUser user;
  final KycStatus kycStatus;

  @override
  State<CollectorVehicleCard> createState() => _CollectorVehicleCardState();
}

class _CollectorVehicleCardState extends State<CollectorVehicleCard> {
  KycApplication? _kycApp;
  CollectorReputation? _reputation;

  @override
  void initState() {
    super.initState();
    _loadKycAndReputation();
  }

  Future<void> _loadKycAndReputation() async {
    final api = context.read<LivoraApi>();
    try {
      final results = await Future.wait([
        api.kycApplication().catchError((_) => KycApplication(status: 'NOT_SUBMITTED')),
        api.collectorReputation().catchError(
              (_) => CollectorReputation(score: 5.0, totalPickups: 0, ratingCount: 0, badge: 'BRONCE'),
            ),
      ]);
      if (mounted) {
        setState(() {
          _kycApp = results[0] as KycApplication;
          _reputation = results[1] as CollectorReputation;
        });
      }
    } catch (_) {}
  }

  IconData _transportIcon(String? type) {
    switch (type) {
      case 'TRICICLO':
        return Icons.pedal_bike_rounded;
      case 'MOTO_CARGA':
        return Icons.two_wheeler_rounded;
      case 'CAMIONETA':
      case 'FURGONETA':
        return Icons.local_shipping_rounded;
      default:
        return Icons.local_shipping_rounded;
    }
  }

  String _transportLabel(String? type) {
    switch (type) {
      case 'TRICICLO':
        return 'Triciclo a pedal';
      case 'MOTO_CARGA':
        return 'Motocarga 200cc';
      case 'CAMIONETA':
      case 'FURGONETA':
        return 'Furgoneta de Carga';
      default:
        return 'Vehículo de Recolección';
    }
  }

  @override
  Widget build(BuildContext context) {
    final transportType = _kycApp?.transportType ?? 'MOTO_CARGA';
    final vehiclePlate = _kycApp?.vehiclePlate;
    final ratingScore = _reputation?.score ?? 5.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: LivoraColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: LivoraColors.forest.withValues(alpha: 0.12),
                  child: Icon(
                    _transportIcon(transportType),
                    color: LivoraColors.forest,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gestión Operativa (Recolector)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.deep,
                        ),
                      ),
                      Text(
                        _transportLabel(transportType),
                        style: const TextStyle(
                          fontSize: 12,
                          color: LivoraColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge de Verificación
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.kycStatus == KycStatus.approved
                        ? LivoraColors.green.withValues(alpha: 0.1)
                        : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.kycStatus == KycStatus.approved
                          ? LivoraColors.green.withValues(alpha: 0.3)
                          : Colors.amber.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.kycStatus == KycStatus.approved
                            ? Icons.verified_user_rounded
                            : Icons.shield_outlined,
                        size: 13,
                        color: widget.kycStatus == KycStatus.approved
                            ? LivoraColors.green
                            : Colors.amber.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.kycStatus == KycStatus.approved ? 'Verificado' : 'En revisión',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.kycStatus == KycStatus.approved
                              ? LivoraColors.forest
                              : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tarjetas de Métricas de Reputación y Placa
            Row(
              children: [
                // Reputación
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: LivoraColors.paper,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reputación',
                          style: TextStyle(fontSize: 11, color: LivoraColors.slate),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              ratingScore.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: LivoraColors.deep,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Placa de rodaje (si aplica)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: LivoraColors.paper,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Placa Vehicular',
                          style: TextStyle(fontSize: 11, color: LivoraColors.slate),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vehiclePlate?.isNotEmpty == true
                              ? vehiclePlate!.toUpperCase()
                              : (transportType == 'TRICICLO' ? 'Sin placa (Pedal)' : 'No registrada'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: LivoraColors.deep,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Botón para actualizar documentos de vehículo
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const KycScreen()),
                  );
                },
                icon: const Icon(Icons.badge_outlined, size: 16),
                label: const Text('Actualizar vehículo y documentos KYC'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
