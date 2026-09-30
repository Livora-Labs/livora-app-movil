import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/app_theme.dart';
import '../../../../widgets/livora_map_tile_layer.dart';
import '../../../../widgets/store_category_marker.dart';

/// Capa de mapa interactivo con clustering para visualizar comercios aliados en Lima.
class StoreMapView extends StatelessWidget {
  const StoreMapView({
    super.key,
    required this.mapController,
    required this.storesWithCoords,
    this.userLat,
    this.userLng,
    required this.onStoreTap,
    required this.onRecenter,
  });

  final MapController mapController;
  final List<Map<String, dynamic>> storesWithCoords;
  final double? userLat;
  final double? userLng;
  final ValueChanged<Map<String, dynamic>> onStoreTap;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    final centerLat = userLat ?? -12.0864;
    final centerLng = userLng ?? -77.0351;
    final centerPoint = LatLng(centerLat, centerLng);

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
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
              ],
            ),

            // Agrupamiento profesional de comercios (Marker Clustering)
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 45,
                size: const Size(42, 42),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(40),
                maxZoom: 16,
                markers: storesWithCoords.map((store) {
                  final lat = double.parse(store['latitude'].toString());
                  final lng = double.parse(store['longitude'].toString());
                  return Marker(
                    point: LatLng(lat, lng),
                    width: 90,
                    height: 60,
                    child: StoreCategoryMarker(
                      store: store,
                      onTap: () => onStoreTap(store),
                    ),
                  );
                }).toList(),
                builder: (context, markers) {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: LivoraColors.forest,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '${markers.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
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
            onPressed: onRecenter,
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
}
