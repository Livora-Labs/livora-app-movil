import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/location_service.dart';
import '../../../widgets/common.dart';
import '../../../widgets/interactive_map_picker_modal.dart';

export '../../../widgets/interactive_map_picker_modal.dart';

/// Barra de selección de dirección activa estilo Rappi para el Hogar.
class HogarActiveAddressBar extends StatelessWidget {
  const HogarActiveAddressBar({
    super.key,
    required this.address,
    required this.onTap,
  });

  final String? address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAddress = address != null && address!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LivoraColors.forest.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: LivoraColors.forest,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Dirección de recojo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasAddress ? address! : 'Fijar dirección de recojo...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: hasAddress ? LivoraColors.deep : LivoraColors.slate,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: LivoraColors.mint.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasAddress ? 'Cambiar' : 'Fijar',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: LivoraColors.deep,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal inferior para seleccionar la dirección mediante GPS, mapa o búsqueda.
class AddressSelectorBottomSheet extends StatelessWidget {
  const AddressSelectorBottomSheet({super.key, this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LivoraColors.forest.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: LivoraColors.forest,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dirección de recojo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                    Text(
                      'Fija la ubicación para tus solicitudes de recolección',
                      style: TextStyle(
                        fontSize: 12,
                        color: LivoraColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (user?.address != null && user!.address!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: LivoraColors.forest, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dirección actual guardada:',
                          style: TextStyle(fontSize: 11, color: LivoraColors.slate),
                        ),
                        Text(
                          user!.address!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: LivoraColors.deep,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Opción 1: GPS Actual
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: LivoraColors.mint.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.my_location_rounded,
                color: LivoraColors.deep,
                size: 20,
              ),
            ),
            title: const Text(
              'Usar mi ubicación GPS actual',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'Detectar automáticamente vía sensor del teléfono',
              style: TextStyle(fontSize: 11.5),
            ),
            onTap: () async {
              final enabled = await LocationService.isLocationServiceEnabled();
              if (!enabled) {
                if (!context.mounted) return;
                final choice = await showDialog<String>(
                  context: context,
                  builder: (dlgCtx) => AlertDialog(
                    icon: const Icon(Icons.location_off_outlined, color: LivoraColors.forest, size: 36),
                    title: const Text('Ubicación desactivada', style: TextStyle(fontWeight: FontWeight.w700)),
                    content: const Text(
                      'Para detectar tu posición satelital automáticamente, activa el GPS del dispositivo. También puedes buscar tu dirección en el mapa.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dlgCtx, 'MANUAL'),
                        child: const Text('Elegir en el mapa'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          LocationService.openLocationSettings();
                          Navigator.pop(dlgCtx);
                        },
                        child: const Text('Abrir Ajustes'),
                      ),
                    ],
                  ),
                );
                if (choice != 'MANUAL') return;
              }

              var permission = await LocationService.checkPermission();
              if (permission == LocationPermission.denied) {
                permission = await LocationService.requestPermission();
              }
              if (permission == LocationPermission.deniedForever) {
                if (!context.mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (dlgCtx) => AlertDialog(
                    icon: const Icon(Icons.settings_outlined, color: LivoraColors.forest, size: 36),
                    title: const Text('Permiso de ubicación denegado', style: TextStyle(fontWeight: FontWeight.w700)),
                    content: const Text(
                      'Livora requiere acceso a tu ubicación para geolocalizar tu domicilio de recojo. Por favor, habilítalo en los ajustes de la aplicación.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dlgCtx),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dlgCtx);
                          LocationService.openAppSettings();
                        },
                        child: const Text('Abrir Ajustes'),
                      ),
                    ],
                  ),
                );
                return;
              }

              if (permission != LocationPermission.always &&
                  permission != LocationPermission.whileInUse) {
                if (context.mounted) {
                  showAppSnack(context, 'Permiso de ubicación denegado.', error: true);
                }
                return;
              }

              final pos = await LocationService.getCurrentPosition();
              if (pos == null) {
                if (context.mounted) {
                  showAppSnack(
                    context,
                    'No se pudo obtener el GPS actual. Intenta nuevamente o ingresa tu dirección en el mapa.',
                    error: true,
                  );
                }
                return;
              }
              final street = await LocationService.reverseGeocode(
                pos.latitude,
                pos.longitude,
              );
              if (context.mounted) {
                Navigator.pop(context, {
                  'address': street ?? 'Ubicación GPS (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})',
                  'latitude': pos.latitude,
                  'longitude': pos.longitude,
                });
              }
            },
          ),
          const SizedBox(height: 10),

          // Opción 2: Elegir en el mapa interactivo
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: LivoraColors.forest.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.map_outlined,
                color: LivoraColors.forest,
                size: 20,
              ),
            ),
            title: const Text(
              'Elegir en el mapa interactivo',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'Buscar por calle, mover el mapa y fijar pin exacto',
              style: TextStyle(fontSize: 11.5),
            ),
            onTap: () async {
              final res = await showModalBottomSheet<Map<String, dynamic>>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => InteractiveMapPickerModal(
                  initialLat: user?.latitude,
                  initialLng: user?.longitude,
                ),
              );
              if (res != null && context.mounted) {
                Navigator.pop(context, res);
              }
            },
          ),
          const SizedBox(height: 10),

          // Opción 3: Escribir manualmente
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Colors.orange,
                size: 20,
              ),
            ),
            title: const Text(
              'Escribir y buscar dirección',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'Ingresar calle y ubicar automáticamente en el mapa',
              style: TextStyle(fontSize: 11.5),
            ),
            onTap: () async {
              final res = await showModalBottomSheet<Map<String, dynamic>>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => InteractiveMapPickerModal(
                  initialLat: user?.latitude,
                  initialLng: user?.longitude,
                  initialAddressQuery: user?.address,
                  focusSearch: true,
                ),
              );
              if (res != null && context.mounted) {
                Navigator.pop(context, res);
              }
            },
          ),
        ],
      ),
    );
  }
}
