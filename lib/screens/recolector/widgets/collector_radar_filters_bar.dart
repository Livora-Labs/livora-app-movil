import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';
import '../../../core/formats.dart';
import '../../../models/models.dart';

/// Barra de filtros compacta y ergonómica para el Radar del Recolector.
/// Permite alternar rápidamente el radio de búsqueda (2km, 5km, 10km, 20km)
/// y segmentar por Centro de Acopio comprador con sus tarifas por kilogramo.
class CollectorRadarFiltersBar extends StatelessWidget {
  const CollectorRadarFiltersBar({
    super.key,
    required this.selectedRadiusKm,
    required this.onRadiusChanged,
    required this.selectedCenterId,
    required this.onlyActiveBatches,
    required this.openBatches,
    required this.availableRequests,
    required this.onCenterFilterChanged,
    this.locatingGps = false,
    this.onCalibrateGps,
  });

  final double selectedRadiusKm;
  final ValueChanged<double> onRadiusChanged;
  final String? selectedCenterId;
  final bool onlyActiveBatches;
  final List<Batch> openBatches;
  final List<CollectionRequest>? availableRequests;
  final void Function(String? centerId, bool onlyBatches) onCenterFilterChanged;
  final bool locatingGps;
  final VoidCallback? onCalibrateGps;

  static const List<double> radiusPresets = [2.0, 5.0, 10.0, 20.0];

  @override
  Widget build(BuildContext context) {
    // Extraer centros de acopio disponibles con tarifas
    final availableCenters = <String, ({String name, double rate})>{};

    if (availableRequests != null) {
      for (final req in availableRequests!) {
        final cid = req.assignedCenterId;
        if (cid != null && cid.isNotEmpty) {
          final cName = sanitizedCenterName(
            req.assignedCenterName,
            req.assignedCenterEmail,
            defaultLabel: 'Acopio',
          );
          availableCenters[cid] = (
            name: cName,
            rate: req.averageRatePerKg,
          );
        }
      }
    }

    for (final b in openBatches) {
      final cid = b.destinationCenterId;
      if (cid != null && cid.isNotEmpty && !availableCenters.containsKey(cid)) {
        final cName = sanitizedCenterName(
          b.destinationCenterName,
          b.destinationCenterEmail,
          defaultLabel: 'Acopio',
        );
        availableCenters[cid] = (
          name: cName,
          rate: 1.0,
        );
      }
    }

    final isAllSelected = selectedCenterId == null && !onlyActiveBatches;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila 1: Filtro de Radio y Botón GPS
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              if (onCalibrateGps != null) ...[
                ActionChip(
                  avatar: locatingGps
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: LivoraColors.forest,
                          ),
                        )
                      : const Icon(Icons.my_location, size: 14, color: LivoraColors.forest),
                  label: Text(locatingGps ? 'Calibrando...' : 'Mi GPS'),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: LivoraColors.border),
                  labelStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: LivoraColors.forest,
                  ),
                  onPressed: onCalibrateGps,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
              ],
              ...radiusPresets.map((r) {
                final isSelected = selectedRadiusKm == r;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${r.toInt()} km'),
                    selected: isSelected,
                    selectedColor: LivoraColors.forest,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? LivoraColors.forest : LivoraColors.border,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : LivoraColors.deep,
                    ),
                    onSelected: (sel) {
                      if (sel) {
                        HapticFeedback.lightImpact();
                        onRadiusChanged(r);
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Fila 2: Centros de Acopio Compradores
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // Chip [Todos los Acopios]
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: const Text('Todos los Acopios'),
                selected: isAllSelected,
                selectedColor: LivoraColors.forest,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isAllSelected ? LivoraColors.forest : LivoraColors.border,
                ),
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isAllSelected ? Colors.white : LivoraColors.deep,
                ),
                onSelected: (sel) {
                  if (sel) {
                    HapticFeedback.lightImpact();
                    onCenterFilterChanged(null, false);
                  }
                },
              ),
              const SizedBox(width: 6),

              // Chip [Mis Acopios en Ruta] (si hay lotes abiertos)
              if (openBatches.isNotEmpty) ...[
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.route_outlined, size: 14),
                  label: Text('En mi vehículo (${openBatches.length})'),
                  selected: onlyActiveBatches,
                  selectedColor: LivoraColors.forest,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: onlyActiveBatches ? LivoraColors.forest : LivoraColors.border,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: onlyActiveBatches ? Colors.white : LivoraColors.deep,
                  ),
                  onSelected: (sel) {
                    HapticFeedback.lightImpact();
                    onCenterFilterChanged(null, sel);
                  },
                ),
                const SizedBox(width: 6),
              ],

              // Chips de cada Centro con Tarifa S/
              ...availableCenters.entries.map((entry) {
                final isCenterSelected = selectedCenterId == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${entry.value.name} · S/ ${entry.value.rate.toStringAsFixed(2)}/kg'),
                    selected: isCenterSelected,
                    selectedColor: LivoraColors.forest,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isCenterSelected ? LivoraColors.forest : LivoraColors.border,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isCenterSelected ? Colors.white : LivoraColors.deep,
                    ),
                    onSelected: (sel) {
                      HapticFeedback.lightImpact();
                      onCenterFilterChanged(sel ? entry.key : null, false);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
