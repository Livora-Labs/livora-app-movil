import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/location_service.dart';
import '../../../widgets/center_picker_pin.dart';
import '../../../widgets/common.dart';
import '../../../widgets/livora_map_tile_layer.dart';

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

/// Selector interactivo con mapa OpenStreetMap y búsqueda en vivo
class InteractiveMapPickerModal extends StatefulWidget {
  const InteractiveMapPickerModal({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddressQuery,
    this.focusSearch = false,
  });

  final double? initialLat;
  final double? initialLng;
  final String? initialAddressQuery;
  final bool focusSearch;

  @override
  State<InteractiveMapPickerModal> createState() =>
      _InteractiveMapPickerModalState();
}

class _InteractiveMapPickerModalState extends State<InteractiveMapPickerModal> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late double _lat;
  late double _lng;
  String _address = 'Buscando dirección...';
  bool _isDragging = false;
  bool _geocoding = false;

  Timer? _debounceTimer;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat ?? -12.0864; // Miraflores default
    _lng = widget.initialLng ?? -77.0351;
    if (widget.initialAddressQuery != null && widget.initialAddressQuery!.isNotEmpty) {
      _searchController.text = widget.initialAddressQuery!;
      _address = widget.initialAddressQuery!;
    }
    _resolveAddress(_lat, _lng);

    if (widget.focusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final clean = query.trim();
    if (clean.length < 3) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      final results = await LocationService.searchAddress(clean);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  void _selectSearchResult(Map<String, dynamic> item) {
    final lat = (item['latitude'] as num).toDouble();
    final lng = (item['longitude'] as num).toDouble();
    final addr = item['address'] as String;

    _searchFocusNode.unfocus();
    setState(() {
      _lat = lat;
      _lng = lng;
      _address = addr;
      _searchController.text = addr;
      _searchResults = [];
    });

    _mapController.move(LatLng(lat, lng), 17);
    HapticFeedback.lightImpact();
  }

  Future<void> _resolveAddress(double lat, double lng) async {
    setState(() => _geocoding = true);
    try {
      final street = await LocationService.reverseGeocode(lat, lng);
      if (mounted) {
        setState(() {
          _address = street ??
              'Ubicación seleccionada (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
          if (!_searchFocusNode.hasFocus) {
            _searchController.text = _address;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _address =
            'Coordenadas: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}');
      }
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  bool _locatingGps = false;

  Future<void> _recenterOnGps() async {
    HapticFeedback.lightImpact();
    final enabled = await LocationService.isLocationServiceEnabled();
    if (!enabled) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dlgCtx) => AlertDialog(
          icon: const Icon(Icons.location_off_outlined, color: LivoraColors.forest, size: 36),
          title: const Text('GPS desactivado', style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text(
            'Para centrar el mapa en tu posición exacta, activa el servicio de ubicación del dispositivo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dlgCtx, true);
                LocationService.openLocationSettings();
              },
              child: const Text('Activar GPS'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    var permission = await LocationService.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await LocationService.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dlgCtx) => AlertDialog(
          icon: const Icon(Icons.settings_outlined, color: LivoraColors.forest, size: 36),
          title: const Text('Permiso de ubicación denegado', style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text(
            'Livora requiere acceso a la ubicación para posicionar el pin en tu domicilio. Por favor, habilítalo en los ajustes.',
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
      if (mounted) {
        showAppSnack(context, 'Permiso de ubicación denegado.', error: true);
      }
      return;
    }

    setState(() => _locatingGps = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _mapController.move(LatLng(_lat, _lng), 17);
        _resolveAddress(_lat, _lng);
      } else if (mounted) {
        showAppSnack(context, 'No se pudo obtener la posición satelital en este momento.', error: true);
      }
    } finally {
      if (mounted) setState(() => _locatingGps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: LivoraColors.forest),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Fijar ubicación de recojo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: LivoraColors.deep,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              decoration: livoraInput(
                'Buscar dirección o avenida',
                hint: 'Ej: Av. Larco 450, Miraflores',
                icon: Icons.search,
              ).copyWith(
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: LivoraColors.forest),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                          )
                        : null,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(_lat, _lng),
                    initialZoom: 16,
                    maxZoom: 18,
                    minZoom: 10,
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture && !_isDragging) {
                        setState(() => _isDragging = true);
                      }
                    },
                    onMapEvent: (event) {
                      if (event is MapEventMoveEnd) {
                        if (_isDragging) {
                          setState(() => _isDragging = false);
                          HapticFeedback.lightImpact();
                          final center = _mapController.camera.center;
                          _lat = center.latitude;
                          _lng = center.longitude;
                          _resolveAddress(_lat, _lng);
                        }
                      }
                    },
                  ),
                  children: const [
                    LivoraMapTileLayer(),
                  ],
                ),
                CenterPickerPin(isDragging: _isDragging),
                Positioned(
                  top: 10,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        if (_geocoding)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: LivoraColors.forest,
                            ),
                          )
                        else
                          const Icon(Icons.place, color: LivoraColors.forest, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _address,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: LivoraColors.deep,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 64,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: LivoraColors.mint.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.touch_app_outlined, size: 18, color: LivoraColors.deep),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mueve el mapa para situar el pin con exactitud en la puerta de tu domicilio.',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: LivoraColors.deep,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'map_picker_gps_fab',
                    backgroundColor: Colors.white,
                    foregroundColor: LivoraColors.forest,
                    tooltip: 'Centrar en mi ubicación GPS',
                    onPressed: _locatingGps ? null : _recenterOnGps,
                    child: _locatingGps
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: LivoraColors.forest,
                            ),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white,
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined, color: LivoraColors.forest, size: 20),
                            title: Text(
                              item['address'] as String,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectSearchResult(item),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text(
                  'Confirmar esta ubicación',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onPressed: () {
                  Navigator.pop(context, {
                    'address': _address,
                    'latitude': _lat,
                    'longitude': _lng,
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
