import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

/// Tarjeta individual para mostrar un comercio aliado en el listado.
class StoreListItemCard extends StatelessWidget {
  const StoreListItemCard({
    super.key,
    required this.store,
    required this.distanceMeters,
    required this.onTap,
    required this.onRedeemTap,
  });

  final Map<String, dynamic> store;
  final double? distanceMeters;
  final VoidCallback onTap;
  final VoidCallback onRedeemTap;

  IconData _iconForCategory(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('alimento') || cat.contains('vívere') || cat.contains('bodega')) {
      return Icons.restaurant_rounded;
    }
    if (cat.contains('bio') || cat.contains('orgánico') || cat.contains('eco')) {
      return Icons.eco_rounded;
    }
    if (cat.contains('ferreter') || cat.contains('hogar')) {
      return Icons.build_rounded;
    }
    if (cat.contains('café') || cat.contains('panader')) {
      return Icons.local_cafe_rounded;
    }
    if (cat.contains('super')) {
      return Icons.local_grocery_store_rounded;
    }
    return Icons.storefront_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final name = store['name']?.toString() ??
        store['businessName']?.toString() ??
        'Comercio Aliado';
    final category = store['category']?.toString() ?? 'Comercio General';
    final address = store['address']?.toString() ?? 'Lima, Perú';
    final perk = store['description']?.toString() ??
        'Canje directo de compras y beneficios con saldo LIVO';
    final icon = _iconForCategory(category);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: LivoraColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: LivoraColors.forest.withValues(alpha: 0.12),
                    child: Icon(icon, color: LivoraColors.forest, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: LivoraColors.deep,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              category,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: LivoraColors.slate,
                              ),
                            ),
                            if (distanceMeters != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '· ${(distanceMeters! / 1000).toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: LivoraColors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: LivoraColors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 13, color: LivoraColors.green),
                        SizedBox(width: 4),
                        Text(
                          'Aliado',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: LivoraColors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: LivoraColors.ink.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: LivoraColors.ink.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: LivoraColors.paper,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: LivoraColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer_outlined, size: 13, color: LivoraColors.forest),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        perk,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: LivoraColors.deep,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: LivoraColors.forest.withValues(alpha: 0.08),
                    foregroundColor: LivoraColors.forest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onRedeemTap,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                  label: const Text(
                    'Pagar aquí (Escanear QR)',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
