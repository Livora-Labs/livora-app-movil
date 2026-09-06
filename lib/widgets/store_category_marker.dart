import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';

/// Marcador estilizado por categoría de comercio aliado en el mapa de tiendas.
class StoreCategoryMarker extends StatelessWidget {
  const StoreCategoryMarker({
    super.key,
    required this.store,
    required this.onTap,
  });

  final Map<String, dynamic> store;
  final VoidCallback onTap;

  Color _getCategoryColor(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('bio') || cat.contains('eco') || cat.contains('granel')) {
      return LivoraColors.green;
    } else if (cat.contains('super') || cat.contains('ferreter') || cat.contains('comercio')) {
      return LivoraColors.blue;
    } else if (cat.contains('caf') || cat.contains('alimento') || cat.contains('pan')) {
      return LivoraColors.cyan;
    }
    return LivoraColors.forest;
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('bio') || cat.contains('eco')) {
      return Icons.eco_rounded;
    } else if (cat.contains('ferreter')) {
      return Icons.handyman_rounded;
    } else if (cat.contains('caf')) {
      return Icons.coffee_rounded;
    } else if (cat.contains('super')) {
      return Icons.shopping_cart_rounded;
    } else if (cat.contains('alimento')) {
      return Icons.restaurant_rounded;
    }
    return Icons.storefront_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final category = store['category']?.toString() ?? '';
    final name = store['name']?.toString() ?? store['businessName']?.toString() ?? 'Tienda';
    final color = _getCategoryColor(category);
    final icon = _getCategoryIcon(category);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nombre compacto de la tienda
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            constraints: const BoxConstraints(maxWidth: 90),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: LivoraColors.deep,
              ),
            ),
          ),
          const SizedBox(height: 2),

          // Pin circular con icono temático
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
