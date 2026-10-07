import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../../core/app_theme.dart';

/// Micro-widget que presenta la dirección fijada del domicilio (solo lectura)
/// y permite añadir referencias de llegada (piso, timbre, portón).
class CreateLocationPickerCard extends StatelessWidget {
  const CreateLocationPickerCard({
    super.key,
    required this.mapController,
    required this.latitude,
    required this.longitude,
    required this.addressController,
    required this.referenceController,
    required this.isGeocoding,
    required this.isFetchingGps,
    required this.onGpsPressed,
    required this.onPositionChanged,
    this.onChangeAddressTap,
  });

  final MapController mapController;
  final double latitude;
  final double longitude;
  final TextEditingController addressController;
  final TextEditingController referenceController;
  final bool isGeocoding;
  final bool isFetchingGps;
  final VoidCallback onGpsPressed;
  final void Function(double lat, double lng) onPositionChanged;
  final VoidCallback? onChangeAddressTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on_rounded, color: LivoraColors.forest, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Punto de Recojo Confirmado',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: LivoraColors.deep,
                    ),
                  ),
                ],
              ),
              if (onChangeAddressTap != null)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: LivoraColors.forest,
                  ),
                  onPressed: onChangeAddressTap,
                  child: const Text('Cambiar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4), // Emerald 50
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: LivoraColors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: LivoraColors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: addressController,
                    builder: (context, value, _) {
                      final text = value.text.trim();
                      return Text(
                        text.isNotEmpty ? text : 'Dirección guardada en perfil',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: LivoraColors.deep,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: referenceController,
            decoration: InputDecoration(
              labelText: 'Referencia domiciliaria (opcional)',
              hintText: 'Ej. Piso 3, dpto 302, portón negro, reja blanca',
              prefixIcon: const Icon(Icons.info_outline_rounded, size: 20),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
