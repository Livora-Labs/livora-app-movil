import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../screens/hogar/widgets/material_slider_card.dart';
import '../../../../widgets/transparent_economic_breakdown_card.dart';

/// Tarjeta de confirmación previa al envío formal de la solicitud.
/// Muestra un desglose limpio del modo seleccionado, si es donación,
/// los materiales totales y la dirección de recojo.
class CreateConfirmationSummaryCard extends StatelessWidget {
  const CreateConfirmationSummaryCard({
    super.key,
    required this.assignmentMode,
    required this.isDonation,
    required this.materials,
    required this.address,
    required this.totalKg,
    required this.estimatedPen,
    required this.estimatedLivo,
    required this.co2Kg,
    this.hasPhoto = false,
  });

  final String assignmentMode;
  final bool isDonation;
  final Map<String, double> materials;
  final String address;
  final double totalKg;
  final double estimatedPen;
  final double estimatedLivo;
  final double co2Kg;
  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    final isAuction = assignmentMode == 'AUCTION';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LivoraColors.mint.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: LivoraColors.forest, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Resumen de tu Pedido',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: LivoraColors.deep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            icon: Icons.alt_route_rounded,
            label: 'Modo:',
            value: isAuction ? 'Subasta Ecológica Inversa' : 'Asignación Automática Rápida',
            valueColor: isAuction ? const Color(0xFFB45309) : LivoraColors.forest,
          ),
          const Divider(height: 18),
          _SummaryRow(
            icon: Icons.volunteer_activism_rounded,
            label: 'Tipo de Entrega:',
            value: isDonation ? 'Donación Solidaria (100% donado)' : 'Canje con Recompensa LIVO',
            valueColor: isDonation ? const Color(0xFFEC4899) : LivoraColors.deep,
          ),
          const Divider(height: 18),
          _SummaryRow(
            icon: Icons.scale_rounded,
            label: 'Materiales (${materials.length}):',
            value: '${totalKg.toStringAsFixed(1)} kg total',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 4, bottom: 4),
            child: Text(
              materials.entries
                  .map((e) {
                    final spec = kMaterialSpecs[e.key];
                    final name = spec != null ? spec.name.split('(').first.trim() : e.key;
                    return '$name: ${e.value.toStringAsFixed(1)} kg';
                  })
                  .join(' · '),
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
          ),
          const Divider(height: 18),
          _SummaryRow(
            icon: Icons.location_on_rounded,
            label: 'Dirección:',
            value: address.isNotEmpty ? address : 'Ubicación seleccionada en mapa',
          ),
          const Divider(height: 18),
          _SummaryRow(
            icon: Icons.photo_camera_rounded,
            label: 'Foto de referencia:',
            value: hasPhoto ? 'Fotografía adjunta' : 'Sin fotografía',
            valueColor: hasPhoto ? LivoraColors.forest : Colors.grey.shade500,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LivoraColors.forest.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recompensa Final Estimada',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: LivoraColors.forest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDonation ? '0.00 LIVO (Donado)' : '${estimatedLivo.toStringAsFixed(2)} LIVO',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: LivoraColors.deep,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.eco_rounded, size: 14, color: LivoraColors.forest),
                      const SizedBox(width: 4),
                      Text(
                        '${co2Kg.toStringAsFixed(1)} kg CO₂',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.forest,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TransparentEconomicBreakdownCard(
            totalGrossPEN: estimatedPen,
            hogarLivo: estimatedLivo,
            collectorPEN: isDonation ? estimatedPen * 0.95 : estimatedPen * 0.70,
            livoraFeePEN: estimatedPen * 0.05,
            isDonation: isDonation,
            title: 'Desglose del Pedido',
            initiallyExpanded: false,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: valueColor ?? LivoraColors.deep,
            ),
          ),
        ),
      ],
    );
  }
}
