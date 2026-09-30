import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app_theme.dart';
import '../../../../widgets/common.dart';

/// Modal BottomSheet deslizable con la información completa de la tienda aliada,
/// navegación GPS hacia el local ("Cómo llegar") y botón de pago con LIVOs.
class StoreDetailBottomSheet extends StatelessWidget {
  const StoreDetailBottomSheet({
    super.key,
    required this.store,
    required this.distanceMeters,
    required this.onPayTap,
  });

  final Map<String, dynamic> store;
  final double? distanceMeters;
  final VoidCallback onPayTap;

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> store,
    double? distanceMeters,
    required VoidCallback onPayTap,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StoreDetailBottomSheet(
        store: store,
        distanceMeters: distanceMeters,
        onPayTap: onPayTap,
      ),
    );
  }

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

  Future<void> _openDirections(BuildContext context) async {
    final lat = double.tryParse(store['latitude']?.toString() ?? '');
    final lng = double.tryParse(store['longitude']?.toString() ?? '');
    if (lat == null || lng == null) {
      showAppSnack(context, 'Coordenadas del local no disponibles', error: true);
      return;
    }

    final googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          showAppSnack(context, 'No se pudo abrir la aplicación de mapas', error: true);
        }
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnack(context, 'Error al abrir servicio de navegación', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = store['name']?.toString() ??
        store['businessName']?.toString() ??
        'Comercio Aliado';
    final category = store['category']?.toString() ?? 'Comercio General';
    final address = store['address']?.toString() ?? 'Lima, Perú';
    final perk = store['description']?.toString() ??
        'Canje directo de productos de consumo con saldo LIVOs.';
    final icon = _iconForCategory(category);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tirador táctil
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Encabezado del comercio
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: LivoraColors.forest.withValues(alpha: 0.12),
                  child: Icon(icon, color: LivoraColors.forest, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 17,
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
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: LivoraColors.slate,
                            ),
                          ),
                          if (distanceMeters != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '· ${(distanceMeters! / 1000).toStringAsFixed(1)} km de ti',
                              style: const TextStyle(
                                fontSize: 12,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: LivoraColors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 14, color: LivoraColors.green),
                      SizedBox(width: 4),
                      Text(
                        'Verificado',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: LivoraColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Fila de Dirección y botón de "Cómo llegar"
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LivoraColors.paper,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LivoraColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: LivoraColors.forest,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: LivoraColors.deep,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: LivoraColors.forest),
                      foregroundColor: LivoraColors.forest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _openDirections(context),
                    icon: const Icon(Icons.directions_rounded, size: 15),
                    label: const Text('Cómo llegar', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Beneficio / Descuento del comercio
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LivoraColors.forest.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.local_offer_rounded, size: 16, color: LivoraColors.forest),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Beneficio Comercial Activo',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: LivoraColors.forest,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          perk,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: LivoraColors.deep,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Paridad oficial: 1 LIVO = S/ 1.00 PEN aplicable en caja',
                          style: TextStyle(
                            fontSize: 11,
                            color: LivoraColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Aviso Legal Indecopi / ANPD
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: LivoraColors.ink.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'La entrega de mercadería y emisión de boleta de venta en Soles corresponde directamente a la tienda aliada bajo normativa peruana.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: LivoraColors.ink.withValues(alpha: 0.55),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Botón de Pago Principal
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: LivoraColors.forest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onPayTap();
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                label: const Text(
                  'Pagar en esta tienda (Escanear QR)',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
