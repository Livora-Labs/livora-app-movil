import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../services/livora_api.dart';
import '../services/location_service.dart';
import 'center_picker_pin.dart';
import 'common.dart';
import 'livora_map_tile_layer.dart';

/// Modal con mapa interactivo para fijar coordenadas y resolver la dirección en texto.
/// Reutilizable entre Hogar, Tienda y otros roles del sistema.
class InteractiveMapPickerModal extends StatefulWidget {
  const InteractiveMapPickerModal({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddressQuery,
    this.focusSearch = false,
    this.title = 'Fijar ubicación en el mapa',
    this.instructionText = 'Mueve el mapa para situar el pin con exactitud en el punto deseado.',
    this.pinIcon = Icons.location_on,
  });

  final double? initialLat;
  final double? initialLng;
  final String? initialAddressQuery;
  final bool focusSearch;
  final String title;
  final String instructionText;
  final IconData pinIcon;

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
    _lat = widget.initialLat ?? -12.0864; // Lima default
    _lng = widget.initialLng ?? -77.0351;
    if (widget.initialAddressQuery != null && widget.initialAddressQuery!.isNotEmpty) {
      _searchController.text = widget.initialAddressQuery!;
      _address = widget.initialAddressQuery!;
    } else {
      _resolveAddress(_lat, _lng);
    }

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
      LivoraApi? api;
      try {
        api = context.read<LivoraApi>();
      } catch (_) {}

      final street = await LocationService.reverseGeocode(lat, lng, api: api);
      if (mounted) {
        setState(() {
          _address = (street != null && street.trim().isNotEmpty)
              ? street
              : 'Dirección fijada en mapa';
          if (!_searchFocusNode.hasFocus) {
            _searchController.text = _address;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _address = 'Dirección fijada en mapa');
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
            'Livora requiere acceso a la ubicación para posicionar el pin. Por favor, habilítalo en los ajustes.',
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
                Icon(widget.pinIcon, color: LivoraColors.forest),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
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
                    child: Row(
                      children: [
                        const Icon(Icons.touch_app_outlined, size: 18, color: LivoraColors.deep),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.instructionText,
                            style: const TextStyle(
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
