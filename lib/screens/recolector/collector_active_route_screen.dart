import 'package:flutter/material.dart';
import '../../features/recolector/active_route/views/collector_active_route_view.dart';
import '../../models/models.dart';

/// Consola de Navegación Vehicular Turn-by-Turn para el Recolector.
/// Delega de forma transparente en la arquitectura desacoplada [CollectorActiveRouteView] (Clean Architecture MVVM).
class CollectorActiveRouteScreen extends StatelessWidget {
  const CollectorActiveRouteScreen({
    super.key,
    required this.request,
    this.initialCollectorLat,
    this.initialCollectorLng,
  });

  final CollectionRequest request;
  final double? initialCollectorLat;
  final double? initialCollectorLng;

  @override
  Widget build(BuildContext context) {
    return CollectorActiveRouteView(
      request: request,
      initialCollectorLat: initialCollectorLat,
      initialCollectorLng: initialCollectorLng,
    );
  }
}
