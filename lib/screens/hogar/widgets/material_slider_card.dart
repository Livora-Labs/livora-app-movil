import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';

/// Configuración de cada material reciclable con sus factores de impacto y recompensas estimadas.
class MaterialSpec {
  const MaterialSpec({
    required this.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.co2FactorPerKg,
    required this.waterFactorPerKg,
    required this.avgMarketRatePerKg,
  });

  final String key;
  final String name;
  final IconData icon;
  final Color color;
  final double co2FactorPerKg;
  final double waterFactorPerKg;
  final double avgMarketRatePerKg;
}

const kMaterialSpecs = <String, MaterialSpec>{
  'PET': MaterialSpec(
    key: 'PET',
    name: 'Plástico PET (Botellas)',
    icon: Icons.local_drink_rounded,
    color: LivoraColors.blue,
    co2FactorPerKg: 1.5,
    waterFactorPerKg: 25.0,
    avgMarketRatePerKg: 1.20,
  ),
  'PLASTICO': MaterialSpec(
    key: 'PLASTICO',
    name: 'Plástico Rígido / HDPE',
    icon: Icons.sanitizer_rounded,
    color: LivoraColors.cyan,
    co2FactorPerKg: 1.3,
    waterFactorPerKg: 20.0,
    avgMarketRatePerKg: 1.10,
  ),
  'CARTON': MaterialSpec(
    key: 'CARTON',
    name: 'Cartón y Cajas',
    icon: Icons.inventory_2_rounded,
    color: Color(0xFFB45309), // Marrón cálido
    co2FactorPerKg: 0.9,
    waterFactorPerKg: 15.0,
    avgMarketRatePerKg: 0.60,
  ),
  'PAPEL': MaterialSpec(
    key: 'PAPEL',
    name: 'Papel, Guías y Periódicos',
    icon: Icons.description_rounded,
    color: LivoraColors.slate,
    co2FactorPerKg: 0.8,
    waterFactorPerKg: 18.0,
    avgMarketRatePerKg: 0.50,
  ),
  'ALUMINIO': MaterialSpec(
    key: 'ALUMINIO',
    name: 'Latas de Aluminio',
    icon: Icons.takeout_dining_rounded,
    color: Color(0xFF6B7280),
    co2FactorPerKg: 4.5,
    waterFactorPerKg: 40.0,
    avgMarketRatePerKg: 3.00,
  ),
  'VIDRIO': MaterialSpec(
    key: 'VIDRIO',
    name: 'Botellas de Vidrio',
    icon: Icons.wine_bar_rounded,
    color: LivoraColors.forest,
    co2FactorPerKg: 0.4,
    waterFactorPerKg: 5.0,
    avgMarketRatePerKg: 0.35,
  ),
};

/// Selector detallado por tipo de material con Sliders de Kg y botones de ajuste rápido.
/// Cumple la directiva: LIVO como unidad principal de recompensa y Soles (S/) secundario.
class MaterialSliderCard extends StatelessWidget {
  const MaterialSliderCard({
    super.key,
    required this.spec,
    required this.weightKg,
    required this.onWeightChanged,
  });

  final MaterialSpec spec;
  final double weightKg;
  final ValueChanged<double> onWeightChanged;

  @override
  Widget build(BuildContext context) {
    final hasWeight = weightKg > 0;
    // 40% del valor de mercado para el Hogar:
    final estimatedValuePEN = weightKg * spec.avgMarketRatePerKg;
    final livoReward = estimatedValuePEN * 0.40;
    final penReward = livoReward;
    final co2Saved = weightKg * spec.co2FactorPerKg;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasWeight
              ? spec.color.withValues(alpha: 0.5)
              : Colors.grey.shade200,
          width: hasWeight ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: hasWeight
                ? spec.color.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera del material con icono y peso actual
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: spec.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(spec.icon, color: spec.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: LivoraColors.deep,
                        ),
                      ),
                      Text(
                        hasWeight
                            ? '≈ ${co2Saved.toStringAsFixed(1)} kg CO₂ evitados'
                            : 'Mueve el slider o usa los botones',
                        style: TextStyle(
                          fontSize: 11,
                          color: hasWeight ? LivoraColors.forest : LivoraColors.slate,
                          fontWeight: hasWeight ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                // Indicador de Peso
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasWeight
                        ? spec.color.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${weightKg.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: hasWeight ? spec.color : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Slider Continuo de 0 a 40 kg
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: spec.color,
                inactiveTrackColor: spec.color.withValues(alpha: 0.15),
                thumbColor: spec.color,
                overlayColor: spec.color.withValues(alpha: 0.2),
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: weightKg.clamp(0.0, 40.0),
                min: 0.0,
                max: 40.0,
                divisions: 80, // Cada 0.5 kg
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  onWeightChanged(double.parse(val.toStringAsFixed(1)));
                },
              ),
            ),

            // Botones de Ajuste Rápido (+1kg, +5kg, Limpiar)
            Row(
              children: [
                _QuickButton(
                  label: '+0.5 kg',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onWeightChanged((weightKg + 0.5).clamp(0.0, 50.0));
                  },
                ),
                const SizedBox(width: 6),
                _QuickButton(
                  label: '+1 kg',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onWeightChanged((weightKg + 1.0).clamp(0.0, 50.0));
                  },
                ),
                const SizedBox(width: 6),
                _QuickButton(
                  label: '+5 kg',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onWeightChanged((weightKg + 5.0).clamp(0.0, 50.0));
                  },
                ),
                const Spacer(),
                if (hasWeight)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onWeightChanged(0.0);
                    },
                    icon: const Icon(Icons.clear, size: 14, color: LivoraColors.slate),
                    label: const Text(
                      'Quitar',
                      style: TextStyle(fontSize: 11, color: LivoraColors.slate),
                    ),
                  ),
              ],
            ),

            // Recompensa del material si tiene peso
            if (hasWeight) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: LivoraColors.paper,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.toll, size: 14, color: LivoraColors.forest),
                    const SizedBox(width: 6),
                    Text(
                      'Recompensa est.: ${livoReward.toStringAsFixed(2)} LIVO',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: LivoraColors.forest,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: LivoraColors.deep,
          ),
        ),
      ),
    );
  }
}
