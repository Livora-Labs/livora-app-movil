import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../services/livora_api.dart';
import '../../services/location_service.dart';
import '../../widgets/common.dart';
import '../../widgets/view_toggle_segmented_button.dart';
import 'qr_scanner_view.dart';
import 'stores/widgets/store_detail_bottom_sheet.dart';
import 'stores/widgets/store_filter_chips_bar.dart';
import 'stores/widgets/store_list_item_card.dart';
import 'stores/widgets/store_map_view.dart';

/// Catálogo interactivo y geolocalizado de comercios aliados donde el Hogar
/// puede canjear sus tokens LIVO por compras y beneficios.
class StoresCatalogScreen extends StatefulWidget {
  const StoresCatalogScreen({super.key});

  @override
  State<StoresCatalogScreen> createState() => _StoresCatalogScreenState();
}

class _StoresCatalogScreenState extends State<StoresCatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  MapListViewMode _viewMode = MapListViewMode.list;

  List<Map<String, dynamic>> _allStores = [];
  String _selectedCategory = 'TODAS';
  bool _loading = true;
  String? _error;
  double? _userLat;
  double? _userLng;

  static const List<String> _categories = [
    'TODAS',
    'Alimentos',
    'BioFerias',
    'Ferreterías',
    'Supermercados',
    'Cafeterías',
  ];

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    final api = context.read<LivoraApi>();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      }

      final stores = await api.fetchAlliedStores();

      if (mounted) {
        setState(() {
          _allStores = stores;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo cargar el directorio de comercios aliados.';
        });
      }
    }
  }

  double? _distanceMeters(Map<String, dynamic> store) {
    if (_userLat == null || _userLng == null) return null;
    final lat = double.tryParse(store['latitude']?.toString() ?? '');
    final lng = double.tryParse(store['longitude']?.toString() ?? '');
    if (lat == null || lng == null) return null;
    return LocationService.distanceBetween(_userLat!, _userLng!, lat, lng);
  }

  List<Map<String, dynamic>> get _filteredStores {
    final query = _searchController.text.trim().toLowerCase();

    return _allStores.where((store) {
      final name = (store['name']?.toString() ?? store['businessName']?.toString() ?? '').toLowerCase();
      final category = (store['category']?.toString() ?? '').toLowerCase();
      final address = (store['address']?.toString() ?? '').toLowerCase();
      final description = (store['description']?.toString() ?? '').toLowerCase();

      // Filtro por categoría
      if (_selectedCategory != 'TODAS') {
        if (!category.contains(_selectedCategory.toLowerCase())) {
          return false;
        }
      }

      // Filtro por texto
      if (query.isNotEmpty) {
        final matchName = name.contains(query);
        final matchCategory = category.contains(query);
        final matchAddress = address.contains(query);
        final matchDesc = description.contains(query);
        if (!matchName && !matchCategory && !matchAddress && !matchDesc) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _recenterOnUser() async {
    HapticFeedback.lightImpact();
    if (_userLat != null && _userLng != null) {
      _mapController.move(LatLng(_userLat!, _userLng!), 14.5);
      return;
    }

    final isGpsOn = await LocationService.isLocationServiceEnabled();
    if (!isGpsOn) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.location_off_outlined, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text('GPS Desactivado', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'El servicio de ubicación (GPS) está desactivado en tu dispositivo. Actívalo para ubicar comercios cercanos en el mapa.',
            style: TextStyle(fontSize: 14, color: LivoraColors.slate),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: LivoraColors.forest),
              onPressed: () {
                Navigator.pop(ctx);
                LocationService.openLocationSettings();
              },
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Activar GPS'),
            ),
          ],
        ),
      );
      return;
    }

    final pos = await LocationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      });
      _mapController.move(LatLng(pos.latitude, pos.longitude), 14.5);
    }
  }

  Future<void> _scanAndRedeem([String? preferredStoreName]) async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerView()),
    );
    if (scannedCode == null || !mounted) return;
    Navigator.pop(context, scannedCode);
  }

  void _showStoreDetail(Map<String, dynamic> store) {
    StoreDetailBottomSheet.show(
      context,
      store: store,
      distanceMeters: _distanceMeters(store),
      onPayTap: () {
        final name = store['name']?.toString() ?? store['businessName']?.toString();
        _scanAndRedeem(name);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredStores;

    final storesWithCoords = filtered.where((s) {
      final lat = double.tryParse(s['latitude']?.toString() ?? '');
      final lng = double.tryParse(s['longitude']?.toString() ?? '');
      return lat != null && lng != null && lat != 0 && lng != 0;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comercios Aliados'),
        actions: [
          IconButton(
            tooltip: 'Actualizar directorio',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStores,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LivoraColors.forest,
        foregroundColor: Colors.white,
        onPressed: _scanAndRedeem,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Escanear QR en Tienda', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Barra de Búsqueda
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar tienda por nombre o distrito…',
                prefixIcon: const Icon(Icons.search_rounded, color: LivoraColors.forest),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: LivoraColors.paper,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: LivoraColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: LivoraColors.border),
                ),
              ),
            ),
          ),

          // Chips de Categorías Horizontales
          StoreFilterChipsBar(
            categories: _categories,
            selectedCategory: _selectedCategory,
            onSelected: (cat) => setState(() => _selectedCategory = cat),
          ),
          const SizedBox(height: 6),

          // Selector Dual: Lista vs Mapa de Comercios
          ViewToggleSegmentedButton(
            selectedMode: _viewMode,
            onChanged: (mode) => setState(() => _viewMode = mode),
            mapLabel: 'Mapa de Tiendas',
            listLabel: 'Lista',
          ),
          const SizedBox(height: 4),

          // Listado o Mapa de Comercios
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'No se pudo conectar',
                        message: _error!,
                        actions: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: LivoraColors.forest),
                            onPressed: _loadStores,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      )
                    : _viewMode == MapListViewMode.map
                        ? StoreMapView(
                            mapController: _mapController,
                            storesWithCoords: storesWithCoords,
                            userLat: _userLat,
                            userLng: _userLng,
                            onStoreTap: _showStoreDetail,
                            onRecenter: _recenterOnUser,
                          )
                        : filtered.isEmpty
                            ? EmptyState(
                                icon: Icons.storefront_outlined,
                                title: 'No encontramos comercios',
                                message: _searchController.text.isNotEmpty
                                    ? 'No hay comercios que coincidan con "${_searchController.text}".'
                                    : 'No hay comercios registrados en esta categoría.',
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final store = filtered[index];
                                  final dist = _distanceMeters(store);
                                  final name = store['name']?.toString() ?? store['businessName']?.toString();

                                  return StoreListItemCard(
                                    store: store,
                                    distanceMeters: dist,
                                    onTap: () => _showStoreDetail(store),
                                    onRedeemTap: () => _scanAndRedeem(name),
                                  );
                                },
                              ),
          ),
        ],
      ),
    );
  }
}
