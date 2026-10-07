import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/app_theme.dart';
import '../../../../widgets/livora_map_tile_layer.dart';

/// Micro-widget para renderizar el lienzo cartográfico interactivo de navegación.
class RouteNavigationMap extends StatelessWidget {
  const RouteNavigationMap({
    super.key,
    required this.mapController,
    required this.destination,
    this.collectorPos,
    this.heading = 0.0,
    this.polylinePoints = const [],
    this.isLoadingRoute = false,
  });

  final MapController mapController;
  final LatLng destination;
  final LatLng? collectorPos;
  final double heading;
  final List<LatLng> polylinePoints;
  final bool isLoadingRoute;

  @override
  Widget build(BuildContext context) {
    final center = collectorPos ?? destination;

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            const LivoraMapTileLayer(),
            if (polylinePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints,
                    strokeWidth: 5.0,
                    color: LivoraColors.forest,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                // Marcador Destino Hogar
                Marker(
                  point: destination,
                  width: 44,
                  height: 44,
                  child: const Icon(
                    Icons.location_pin,
                    size: 40,
                    color: LivoraColors.coral,
                  ),
                ),
                // Marcador Recolector
                if (collectorPos != null)
                  Marker(
                    point: collectorPos!,
                    width: 38,
                    height: 38,
                    child: Transform.rotate(
                      angle: (heading * 3.1415926535) / 180,
                      child: Container(
                        decoration: BoxDecoration(
                          color: LivoraColors.forest,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (isLoadingRoute)
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Trazando mejor ruta OSRM...',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
