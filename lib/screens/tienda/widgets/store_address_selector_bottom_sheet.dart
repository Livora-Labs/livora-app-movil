import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/app_theme.dart';
import '../../../services/livora_api.dart';
import '../../../services/location_service.dart';
import '../../../widgets/common.dart';
import '../../../widgets/interactive_map_picker_modal.dart';

/// Modal interactivo para seleccionar o calibrar la ubicación física del local comercial (Tienda).
/// Soporta georreferenciación GPS automática con geocodificación inversa,
/// mapa interactivo con pin arrastrable y búsqueda predictiva de calles.
class StoreAddressSelectorBottomSheet extends StatefulWidget {
  const StoreAddressSelectorBottomSheet({
    super.key,
    this.initialAddress,
    this.initialLat,
    this.initialLng,
  });

  final String? initialAddress;
  final double? initialLat;
  final double? initialLng;

  @override
  State<StoreAddressSelectorBottomSheet> createState() =>
      _StoreAddressSelectorBottomSheetState();
}

class _StoreAddressSelectorBottomSheetState
    extends State<StoreAddressSelectorBottomSheet> {
  bool _locatingGps = false;

  Future<void> _handleGpsLocation() async {
    HapticFeedback.lightImpact();
    final api = context.read<LivoraApi>();
    setState(() => _locatingGps = true);

    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) {
        if (mounted) {
          setState(() => _locatingGps = false);
          showAppSnack(
            context,
            'No se pudo obtener la posición satelital del local. Puedes buscar tu calle o fijarla en el mapa.',
            error: true,
          );
        }
        return;
      }

      final street = await LocationService.reverseGeocode(
        pos.latitude,
        pos.longitude,
        api: api,
      );

      if (mounted) {
        setState(() => _locatingGps = false);
        Navigator.pop(context, {
          'address': street ?? 'Ubicación comercial detectada por GPS',
          'latitude': pos.latitude,
          'longitude': pos.longitude,
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _locatingGps = false);
        showAppSnack(context, 'Error al georreferenciar el local comercial', error: true);
      }
    }
  }

  Future<void> _openInteractiveMap({bool focusSearch = false}) async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InteractiveMapPickerModal(
        initialLat: widget.initialLat,
        initialLng: widget.initialLng,
        initialAddressQuery: widget.initialAddress,
        focusSearch: focusSearch,
        title: 'Ubicación del Local Comercial',
        instructionText: 'Mueve el mapa para situar el pin con exactitud en la entrada de tu tienda.',
        pinIcon: Icons.storefront_rounded,
      ),
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasInitial = widget.initialAddress != null &&
        widget.initialAddress!.trim().isNotEmpty;

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
          // Drag handle
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

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LivoraColors.forest.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: LivoraColors.forest,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ubicación del Establecimiento',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Fija el punto exacto de atención para que los hogares canjeen en tu local',
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

          // Dirección actual registrada
          if (hasInitial) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LivoraColors.mint.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: LivoraColors.forest, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dirección actual ingresada:',
                          style: TextStyle(fontSize: 11, color: LivoraColors.slate, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.initialAddress!,
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

          const SizedBox(height: 18),

          // Opción 1: GPS Automático
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LivoraColors.forest.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: _locatingGps
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: LivoraColors.forest),
                    )
                  : const Icon(Icons.my_location_rounded, color: LivoraColors.forest, size: 20),
            ),
            title: const Text(
              'Detectar ubicación actual por GPS',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            subtitle: const Text(
              'Obtiene tu posición satelital y completa el nombre de calle y distrito',
              style: TextStyle(fontSize: 11.5, color: LivoraColors.slate),
            ),
            trailing: _locatingGps
                ? null
                : const Icon(Icons.chevron_right_rounded, color: LivoraColors.slate),
            onTap: _locatingGps ? null : _handleGpsLocation,
          ),
          const SizedBox(height: 10),

          // Opción 2: Elegir en el mapa
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LivoraColors.forest.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.map_outlined, color: LivoraColors.forest, size: 20),
            ),
            title: const Text(
              'Elegir en el mapa interactivo',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            subtitle: const Text(
              'Mueve el mapa y ubica el pin en la fachada de tu establecimiento',
              style: TextStyle(fontSize: 11.5, color: LivoraColors.slate),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: LivoraColors.slate),
            onTap: () => _openInteractiveMap(focusSearch: false),
          ),
          const SizedBox(height: 10),

          // Opción 3: Buscar por avenida o calle
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LivoraColors.forest.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_rounded, color: LivoraColors.forest, size: 20),
            ),
            title: const Text(
              'Buscar por calle o avenida',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            subtitle: const Text(
              'Escribe el nombre de tu vía para autocompletar la dirección',
              style: TextStyle(fontSize: 11.5, color: LivoraColors.slate),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: LivoraColors.slate),
            onTap: () => _openInteractiveMap(focusSearch: true),
          ),
        ],
      ),
    );
  }
}
