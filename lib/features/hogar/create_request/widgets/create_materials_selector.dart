import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_theme.dart';
import '../../../../screens/hogar/widgets/material_slider_card.dart';

/// Selector interactivo y dinámico de materiales a reciclar.
/// Muestra los materiales disponibles en una barra superior con '+' para agregarlos uno a uno.
/// Cada tarjeta agregada maneja el peso con mínimo estricto de 0.5 kg y botón de tacho para eliminar.
class CreateMaterialsSelector extends StatelessWidget {
  const CreateMaterialsSelector({
    super.key,
    required this.materials,
    required this.onWeightChanged,
  });

  final Map<String, double> materials;
  final void Function(String material, double weight) onWeightChanged;

  @override
  Widget build(BuildContext context) {
    final allKeys = kMaterialSpecs.keys.toList();
    final activeMaterials = materials.entries
        .where((e) => e.value >= 0.5 && kMaterialSpecs.containsKey(e.key))
        .toList();
    final addedKeys = activeMaterials.map((e) => e.key).toSet();
    final availableToAdd = allKeys.where((k) => !addedKeys.contains(k)).toList();

    final totalKg = activeMaterials.fold<double>(0.0, (s, e) => s + e.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera de la sección con resumen de peso
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
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
                  color: totalKg >= 0.5
                      ? LivoraColors.mint.withValues(alpha: 0.2)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${totalKg.toStringAsFixed(1)} kg total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: totalKg >= 0.5 ? LivoraColors.forest : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Barra horizontal de Materiales Disponibles con botón '+'
        if (availableToAdd.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'Toca para agregar (+):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: availableToAdd.map((key) {
                final spec = kMaterialSpecs[key]!;
                final displayName = spec.name.split('(').first.trim();

                return Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onWeightChanged(key, 0.5);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: spec.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: spec.color.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(spec.icon, size: 16, color: spec.color),
                            const SizedBox(width: 6),
                            Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: spec.color,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: spec.color,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
        ],

        // Estado Vacío: Si no se ha agregado ningún material todavía
        if (activeMaterials.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LivoraColors.mint.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_shopping_cart_rounded,
                    size: 32,
                    color: LivoraColors.forest,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ningún residuo agregado aún',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: LivoraColors.deep,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Selecciona uno de los materiales disponibles arriba para ajustar los kilogramos (mínimo 0.5 kg).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

        // Listado de Tarjetas de Materiales Agregados
        ...activeMaterials.map((entry) {
          final spec = kMaterialSpecs[entry.key]!;
          final currentWeight = entry.value;

          return _ActiveMaterialCard(
            spec: spec,
            weightKg: currentWeight,
            onWeightChanged: (newWeight) => onWeightChanged(entry.key, newWeight),
            onRemove: () {
              HapticFeedback.mediumImpact();
              onWeightChanged(entry.key, 0.0);
            },
          );
        }),
      ],
    );
  }
}

/// Tarjeta dedicada de un material activo con slider, botones +/- (mínimo 0.5 kg)
/// y botón de tacho rojo para remover el material.
class _ActiveMaterialCard extends StatelessWidget {
  const _ActiveMaterialCard({
    required this.spec,
    required this.weightKg,
    required this.onWeightChanged,
    required this.onRemove,
  });

  final MaterialSpec spec;
  final double weightKg;
  final ValueChanged<double> onWeightChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final estimatedValuePEN = weightKg * spec.avgMarketRatePerKg;
    final livoReward = estimatedValuePEN * 0.25;
    final penReward = livoReward;
    final co2Saved = weightKg * spec.co2FactorPerKg;

    // Regla estricta: Mínimo 0.5 kg, no se puede bajar más
    final canDecrease = weightKg > 0.51;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: spec.color.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: spec.color.withValues(alpha: 0.08),
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
            // Cabecera: Icono, nombre, badge de peso y TACHO DE BASURA
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
                        '≈ ${co2Saved.toStringAsFixed(1)} kg CO₂ evitados',
                        style: const TextStyle(
                          fontSize: 11,
                          color: LivoraColors.forest,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Indicador de Peso
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: spec.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${weightKg.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: spec.color,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Botón de tacho para eliminar tarjeta
                IconButton(
                  tooltip: 'Quitar ${spec.name}',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 22,
                  ),
                  onPressed: onRemove,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Slider Continuo de 0.5 a 40 kg
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
                value: weightKg.clamp(0.5, 40.0),
                min: 0.5,
                max: 40.0,
                divisions: 79, // Cada 0.5 kg comenzando en 0.5
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  onWeightChanged(double.parse(val.toStringAsFixed(1)));
                },
              ),
            ),

            // Controles de ajuste fino (+/- 0.5kg) y botones rápidos (+1kg, +5kg)
            Row(
              children: [
                // Botón menos (-) con tope mínimo de 0.5 kg
                _StepButton(
                  icon: Icons.remove_rounded,
                  enabled: canDecrease,
                  onTap: () {
                    if (canDecrease) {
                      HapticFeedback.lightImpact();
                      final next = (weightKg - 0.5).clamp(0.5, 50.0);
                      onWeightChanged(double.parse(next.toStringAsFixed(1)));
                    }
                  },
                ),
                const SizedBox(width: 6),
                // Botón más (+)
                _StepButton(
                  icon: Icons.add_rounded,
                  enabled: weightKg < 40.0,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final next = (weightKg + 0.5).clamp(0.5, 50.0);
                    onWeightChanged(double.parse(next.toStringAsFixed(1)));
                  },
                ),
                const SizedBox(width: 10),
                _QuickAddButton(
                  label: '+1 kg',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final next = (weightKg + 1.0).clamp(0.5, 50.0);
                    onWeightChanged(double.parse(next.toStringAsFixed(1)));
                  },
                ),
                const SizedBox(width: 6),
                _QuickAddButton(
                  label: '+5 kg',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final next = (weightKg + 5.0).clamp(0.5, 50.0);
                    onWeightChanged(double.parse(next.toStringAsFixed(1)));
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Recompensa en tokens LIVO y Soles
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
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Recompensa est.: ${livoReward.toStringAsFixed(2)} LIVO',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: LivoraColors.forest,
                          ),
                        ),
                        TextSpan(
                          text: ' (≈ S/ ${penReward.toStringAsFixed(2)})',
                          style: TextStyle(
                            fontSize: 11,
                            color: LivoraColors.ink.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? Colors.grey.shade100 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? Colors.grey.shade300 : Colors.grey.shade200,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? LivoraColors.deep : Colors.grey.shade400,
        ),
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: LivoraColors.deep,
          ),
        ),
      ),
    );
  }
}
