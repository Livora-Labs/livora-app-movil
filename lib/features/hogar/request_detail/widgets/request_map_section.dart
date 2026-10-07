import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/app_theme.dart';
import '../../../../widgets/livora_map_tile_layer.dart';

/// Micro-componente que encapsula el mapa de seguimiento geoespacial y ruta OSRM.
class RequestMapSection extends StatefulWidget {
  const RequestMapSection({
    super.key,
    required this.householdLat,
    required this.householdLng,
    this.collectorPos,
    this.collectorHeading = 0.0,
    this.polylinePoints = const [],
  });

  final double householdLat;
  final double householdLng;
  final LatLng? collectorPos;
  final double collectorHeading;
  final List<LatLng> polylinePoints;

  @override
  State<RequestMapSection> createState() => _RequestMapSectionState();
}

class _RequestMapSectionState extends State<RequestMapSection> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(covariant RequestMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collectorPos != null && oldWidget.collectorPos != widget.collectorPos) {
      _fitBounds();
    }
  }

  void _fitBounds() {
    if (widget.collectorPos == null) return;
    try {
      final bounds = LatLngBounds.fromPoints([
        LatLng(widget.householdLat, widget.householdLng),
        widget.collectorPos!,
      ]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final homePoint = LatLng(widget.householdLat, widget.householdLng);
    final center = widget.collectorPos != null
        ? LatLng(
            (widget.householdLat + widget.collectorPos!.latitude) / 2,
            (widget.householdLng + widget.collectorPos!.longitude) / 2,
          )
        : homePoint;

    return Container(
      height: 240,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: widget.collectorPos != null ? 14.5 : 16.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              const LivoraMapTileLayer(),
              if (widget.polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.polylinePoints,
                      strokeWidth: 4.5,
                      color: LivoraColors.blue,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Marcador de Domicilio
                  Marker(
                    point: homePoint,
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: LivoraColors.deep,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  // Marcador de Recolector en Movimiento
                  if (widget.collectorPos != null)
                    Marker(
                      point: widget.collectorPos!,
                      width: 44,
                      height: 44,
                      child: Transform.rotate(
                        angle: (widget.collectorHeading * 3.1415926535) / 180,
                        child: Container(
                          decoration: BoxDecoration(
                            color: LivoraColors.forest,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black38, blurRadius: 6),
                            ],
                          ),
                          child: const Icon(
                            Icons.navigation_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Botón flotante para recentrar cámara
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: 'recenter_map_btn',
              backgroundColor: Colors.white,
              onPressed: _fitBounds,
              child: const Icon(Icons.my_location_rounded, color: LivoraColors.deep),
            ),
          ),
        ],
      ),
    );
  }
}
