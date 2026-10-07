import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/formats.dart';
import '../../../../core/stellar.dart';
import '../../../../models/models.dart';
import '../../../../widgets/transparent_economic_breakdown_card.dart';

/// Micro-componente que presenta el desglose de materiales, pesaje y balance ecológico.
class RequestMaterialsSection extends StatelessWidget {
  const RequestMaterialsSection({
    super.key,
    required this.request,
  });

  final CollectionRequest request;

  @override
  Widget build(BuildContext context) {
    final actual = request.actualWeights;
    final estimated = request.itemsEstimated;
    final isCompleted = request.status == 'COMPLETED';

    final totalKg = isCompleted && request.totalActualKg > 0
        ? request.totalActualKg
        : request.totalEstimatedKg;

    final co2Saved = totalKg * 2.5;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: LivoraColors.slate.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Materiales a Reciclar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: LivoraColors.deep,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: LivoraColors.mint.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${totalKg.toStringAsFixed(1)} kg totales',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: LivoraColors.forest,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Lista de materiales
          ...estimated.entries.map((entry) {
            final matKey = entry.key;
            final estWeight = entry.value;
            final actWeight = actual?[matKey];

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: LivoraColors.mint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.recycling_rounded, color: LivoraColors.forest, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      materialLabel(matKey),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: LivoraColors.deep,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        actWeight != null ? '${actWeight.toStringAsFixed(1)} kg real' : '${estWeight.toStringAsFixed(1)} kg est.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: actWeight != null ? LivoraColors.forest : LivoraColors.deep,
                        ),
                      ),
                      if (actWeight != null && actWeight != estWeight)
                        Text(
                          'Est: ${estWeight.toStringAsFixed(1)} kg',
                          style: const TextStyle(fontSize: 10.5, color: LivoraColors.slate),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),

          // Huella ecológica
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _EcoImpactBadge(
                icon: Icons.eco_rounded,
                value: '${co2Saved.toStringAsFixed(1)} kg',
                label: 'CO2 evitado',
                color: LivoraColors.forest,
              ),
              _EcoImpactBadge(
                icon: Icons.park_rounded,
                value: (co2Saved / 10).toStringAsFixed(1),
                label: 'Árboles equiv.',
                color: LivoraColors.mint,
              ),
              _EcoImpactBadge(
                icon: isCompleted ? Icons.verified_rounded : Icons.monetization_on_rounded,
                value: request.isDonation
                    ? 'Donación'
                    : isCompleted
                        ? '+${(request.householdRewardEarned > 0 ? request.householdRewardEarned : request.hogarEstimatedEarningsPEN).toStringAsFixed(2)} LIVO'
                        : '${request.hogarEstimatedEarningsPEN.toStringAsFixed(2)} LIVO',
                label: request.isDonation
                    ? 'Solidario'
                    : isCompleted
                        ? 'LIVO Acreditado'
                        : 'Ganancia Est.',
                color: isCompleted ? LivoraColors.green : LivoraColors.blue,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Desglose Económico Transparente (25% Hogar / 70% Recolector / 5% Livora)
          TransparentEconomicBreakdownCard(
            totalGrossPEN: request.totalEstimatedValuePEN,
            hogarLivo: request.householdRewardEarned > 0
                ? request.householdRewardEarned
                : request.hogarEstimatedEarningsPEN,
            collectorPEN: request.collectorMarginPEN,
            livoraFeePEN: request.livoraFeePEN,
            isDonation: request.isDonation,
            title: isCompleted ? 'Liquidación Final del Reciclaje' : 'Desglose Económico del Pedido',
            initiallyExpanded: false,
          ),

          // Enlace directo de auditoría Stellar si la solicitud está completada y tiene txHash
          if (isCompleted && request.txHash != null && request.txHash!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4), // Emerald 50
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LivoraColors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: LivoraColors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recompensa Acreditada en Billetera',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: LivoraColors.deep,
                          ),
                        ),
                        Text(
                          'Tx Stellar: ${request.txHash!.substring(0, request.txHash!.length > 16 ? 16 : request.txHash!.length)}...',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: LivoraColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14, color: LivoraColors.forest),
                    label: const Text(
                      'Ver Tx',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: LivoraColors.forest),
                    ),
                    onPressed: () => Stellar.openTxInExplorer(request.txHash!),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EcoImpactBadge extends StatelessWidget {
  const _EcoImpactBadge({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: LivoraColors.deep,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: LivoraColors.slate),
        ),
      ],
    );
  }
}
