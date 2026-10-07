import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../widgets/transparent_economic_breakdown_card.dart';

/// Micro-widget para visualizar el impacto ecológico y la recompensa estimada,
/// con acordeón interactivo de desglose económico transparente (25% Hogar / 70% Recolector / 5% Livora).
class CreateQuoteSummaryCard extends StatelessWidget {
  const CreateQuoteSummaryCard({
    super.key,
    required this.totalKg,
    required this.estimatedPen,
    required this.estimatedLivo,
    required this.co2Kg,
    required this.waterLiters,
    this.isDonation = false,
  });

  final double totalKg;
  final double estimatedPen;
  final double estimatedLivo;
  final double co2Kg;
  final double waterLiters;
  final bool isDonation;

  @override
  Widget build(BuildContext context) {
    // Cálculo exacto del split 25% Hogar / 70% Recolector (95% en donación) / 5% Livora
    final collectorPen = isDonation ? estimatedPen * 0.95 : estimatedPen * 0.70;
    final livoraFeePen = estimatedPen * 0.05;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDonation
                ? const Color(0xFFFDF2F8)
                : LivoraColors.mint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDonation
                  ? const Color(0xFFF472B6).withValues(alpha: 0.4)
                  : LivoraColors.forest.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDonation ? 'Modo Solidario' : 'Tu Recompensa Estimada',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDonation ? const Color(0xFF9D174D) : LivoraColors.forest,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isDonation ? '0.00 LIVOs' : '~${estimatedLivo.toStringAsFixed(2)} LIVOs',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDonation ? const Color(0xFFBE185D) : LivoraColors.forest,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDonation
                            ? const Color(0xFFF472B6).withValues(alpha: 0.4)
                            : LivoraColors.forest.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      isDonation
                          ? 'Donación solidaria'
                          : 'Tokens LIVO',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isDonation ? const Color(0xFFBE185D) : LivoraColors.forest,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_outlined, size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 4),
                      Text(
                        '${co2Kg.toStringAsFixed(1)} kg CO₂',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.water_drop_outlined, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        '${waterLiters.toStringAsFixed(0)} L Agua',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Componente Colapsable con Flecha Animada
        TransparentEconomicBreakdownCard(
          totalGrossPEN: estimatedPen,
          hogarLivo: estimatedLivo,
          collectorPEN: collectorPen,
          livoraFeePEN: livoraFeePen,
          isDonation: isDonation,
          initiallyExpanded: false,
        ),
      ],
    );
  }
}
