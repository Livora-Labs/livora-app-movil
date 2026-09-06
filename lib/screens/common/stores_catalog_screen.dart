import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_theme.dart';
import '../../services/location_service.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../../widgets/livora_map_tile_layer.dart';
import '../../widgets/view_toggle_segmented_button.dart';
import '../../widgets/store_category_marker.dart';
import 'qr_scanner_view.dart';

/// Catálogo interactivo completo de comercios aliados donde el Hogar
/// puede canjear sus EcoTokens por productos, descuentos y beneficios.
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
    } catch (err) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo cargar el catálogo de tiendas.';
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

      // Filtro por búsqueda
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

  IconData _iconForCategory(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('alimento') || cat.contains('vívere')) return Icons.restaurant;
    if (cat.contains('bio') || cat.contains('orgánico')) return Icons.eco;
    if (cat.contains('ferreter') || cat.contains('hogar')) return Icons.build;
    if (cat.contains('café') || cat.contains('panader')) return Icons.local_cafe;
    if (cat.contains('super')) return Icons.local_grocery_store;
    return Icons.storefront;
  }

  Future<void> _scanAndRedeem([String? preferredStoreName]) async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerView()),
    );
    if (scannedCode == null || !mounted) return;
    Navigator.pop(context, scannedCode);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredStores;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiendas Aliadas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _loadStores,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanAndRedeem,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Escanear QR en Tienda'),
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
                prefixIcon: const Icon(Icons.search, color: LivoraColors.forest),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
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
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final selected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  selectedColor: LivoraColors.forest,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? Colors.white : LivoraColors.deep,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // Selector Dual: Lista vs Mapa de Comercios
          ViewToggleSegmentedButton(
            selectedMode: _viewMode,
            onChanged: (mode) => setState(() => _viewMode = mode),
            mapLabel: 'Mapa de Comercios',
            listLabel: 'Lista',
          ),
          const SizedBox(height: 4),

          // Listado o Mapa de Comercios
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? EmptyState(
                        icon: Icons.cloud_off,
                        title: 'No se pudo conectar',
                        message: _error!,
                        actions: [
                          FilledButton.icon(
                            onPressed: _loadStores,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      )
                    : _viewMode == MapListViewMode.map
                        ? _buildStoresMap(filtered)
                        : filtered.isEmpty
                            ? EmptyState(
                                icon: Icons.storefront_outlined,
                                title: 'No encontramos comercios',
                                message: _searchController.text.isNotEmpty
                                    ? 'No hay tiendas aliadas que coincidan con "${_searchController.text}".'
                                    : 'No hay tiendas disponibles en la categoría seleccionada.',
                              )
                            : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final store = filtered[index];
                              final name = store['name']?.toString() ?? store['businessName']?.toString() ?? 'Comercio Aliado';
                              final category = store['category']?.toString() ?? 'General';
                              final address = store['address']?.toString() ?? 'Lima, Perú';
                              final perk = store['description']?.toString() ?? 'Canje de productos con saldo EcoTokens';
                              final icon = _iconForCategory(category);
                              final dist = _distanceMeters(store);

                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
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
                                                    if (dist != null) ...[
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        '· ${(dist / 1000).toStringAsFixed(1)} km',
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
                                                Icon(Icons.verified, size: 12, color: LivoraColors.green),
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
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: () => _scanAndRedeem(name),
                                          icon: const Icon(Icons.qr_code_scanner, size: 16),
                                          label: const Text('Canjear aquí (Escanear QR)', style: TextStyle(fontSize: 12.5)),
                                         ),
                                       ),
                                     ],
                                   ),
                                 ),
                               );
                             },
                           ),
           ),
         ],
       ),
     );
   }

  Widget _buildStoresMap(List<Map<String, dynamic>> stores) {
    final centerLat = _userLat ?? -12.0864;
    final centerLng = _userLng ?? -77.0351;
    final centerPoint = LatLng(centerLat, centerLng);

    final storesWithCoords = stores.where((s) {
      final lat = double.tryParse(s['latitude']?.toString() ?? '');
      final lng = double.tryParse(s['longitude']?.toString() ?? '');
      return lat != null && lng != null && lat != 0 && lng != 0;
    }).toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: centerPoint,
            initialZoom: 13.5,
            maxZoom: 18,
            minZoom: 10,
          ),
          children: [
            const LivoraMapTileLayer(),
            MarkerLayer(
              markers: [
                // Marcador del usuario
                Marker(
                  point: centerPoint,
                  width: 38,
                  height: 38,
                  child: Container(
                    decoration: BoxDecoration(
                      color: LivoraColors.blue.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(
                        color: LivoraColors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),

                // Marcadores de tiendas aliadas
                ...storesWithCoords.map((store) {
                  final lat = double.parse(store['latitude'].toString());
                  final lng = double.parse(store['longitude'].toString());
                  return Marker(
                    point: LatLng(lat, lng),
                    width: 90,
                    height: 60,
                    child: StoreCategoryMarker(
                      store: store,
                      onTap: () => _showStoreDetail(store),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),

        // Botón flotante para centrar en mi posición GPS
        Positioned(
          top: 12,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: 'recenter_stores_map_fab',
            backgroundColor: Colors.white,
            foregroundColor: LivoraColors.forest,
            elevation: 3,
            onPressed: () {
              HapticFeedback.lightImpact();
              _mapController.move(centerPoint, 14.0);
            },
            child: const Icon(Icons.my_location_rounded, size: 20),
          ),
        ),

        // Atribución OpenStreetMap
        const Positioned(
          bottom: 0,
          right: 0,
          child: OsmAttributionWidget(),
        ),
      ],
    );
  }

  void _showStoreDetail(Map<String, dynamic> store) {
    HapticFeedback.selectionClick();
    final name = store['name']?.toString() ?? store['businessName']?.toString() ?? 'Comercio Aliado';
    final category = store['category']?.toString() ?? 'General';
    final address = store['address']?.toString() ?? 'Lima, Perú';
    final perk = store['description']?.toString() ?? 'Canje de productos con saldo EcoTokens';
    final icon = _iconForCategory(category);
    final dist = _distanceMeters(store);

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                CircleAvatar(
                  radius: 22,
                  backgroundColor: LivoraColors.forest.withValues(alpha: 0.12),
                  child: Icon(icon, color: LivoraColors.forest, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
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
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: LivoraColors.slate,
                            ),
                          ),
                          if (dist != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '· ${(dist / 1000).toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 11.5,
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
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: LivoraColors.ink.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(
                      fontSize: 12,
                      color: LivoraColors.ink.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LivoraColors.paper,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: LivoraColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_offer_outlined, size: 15, color: LivoraColors.forest),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      perk,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LivoraColors.deep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: LivoraColors.forest,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(bottomSheetContext);
                  _scanAndRedeem(name);
                },
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text(
                  'Canjear aquí (Escanear QR)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
