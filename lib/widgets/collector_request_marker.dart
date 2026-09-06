import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../models/models.dart';

/// Marcador personalizado de alta interactividad para solicitudes de recolección
/// en el mapa radar con badge de ganancia neta en EcoTokens e ícono de material.
class CollectorRequestMarker extends StatelessWidget {
  const CollectorRequestMarker({
    super.key,
    required this.request,
    required this.onTap,
  });

  final CollectionRequest request;
  final VoidCallback onTap;

  IconData _getDominantMaterialIcon() {
    if (request.itemsEstimated.isEmpty) return Icons.recycling_rounded;
    String dominant = 'PET';
    double maxWeight = -1;
    request.itemsEstimated.forEach((mat, weight) {
      if (weight > maxWeight) {
        maxWeight = weight;
        dominant = mat.toUpperCase();
      }
    });

    if (dominant.contains('PET') || dominant.contains('PLASTIC')) {
      return Icons.local_drink_rounded;
    } else if (dominant.contains('CARTON') || dominant.contains('PAPEL')) {
      return Icons.inventory_2_rounded;
    } else if (dominant.contains('VIDRIO') || dominant.contains('GLASS')) {
      return Icons.wine_bar_rounded;
    } else if (dominant.contains('METAL') || dominant.contains('LATA')) {
      return Icons.hardware_rounded;
    }
    return Icons.recycling_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final reward = request.collectorMarginPEN;
    final rewardText = '+${reward.toStringAsFixed(1)} ECO';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge superior de recompensa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: LivoraColors.mint,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: LivoraColors.forest, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              rewardText,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: LivoraColors.forest,
              ),
            ),
          ),
          const SizedBox(height: 2),

          // Pin circular principal
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: LivoraColors.forest,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: LivoraColors.forest.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              _getDominantMaterialIcon(),
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
