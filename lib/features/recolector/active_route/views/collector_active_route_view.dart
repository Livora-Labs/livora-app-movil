import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_theme.dart';
import '../../../../data/repositories/collection_repository.dart';
import '../../../../models/models.dart';
import '../../../../services/livora_api.dart';
import '../../../../services/telemetry_service.dart';
import '../../../../widgets/common.dart';
import '../../../../widgets/verification_otp_modal.dart';
import '../view_model/collector_route_view_model.dart';
import '../widgets/route_hud_card.dart';
import '../widgets/route_navigation_map.dart';

/// Vista desacoplada para la consola de navegación del recolector (<180 líneas).
class CollectorActiveRouteView extends StatelessWidget {
  const CollectorActiveRouteView({
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
    return ChangeNotifierProvider(
      create: (ctx) => CollectorRouteViewModel(
        initialRequest: request,
        repository: CollectionRepository(api: ctx.read<LivoraApi>()),
        telemetryService: TelemetryService(api: ctx.read<LivoraApi>()),
        initialCollectorLat: initialCollectorLat,
        initialCollectorLng: initialCollectorLng,
      ),
      child: const _CollectorActiveRouteContent(),
    );
  }
}

class _CollectorActiveRouteContent extends StatefulWidget {
  const _CollectorActiveRouteContent();

  @override
  State<_CollectorActiveRouteContent> createState() => _CollectorActiveRouteContentState();
}

class _CollectorActiveRouteContentState extends State<_CollectorActiveRouteContent> {
  final MapController _mapController = MapController();

  void _openVerificationModal(BuildContext context, CollectionRequest req) async {
    final success = await VerificationOtpModal.show(context, request: req);
    if (success == true && context.mounted) {
      showAppSnack(context, 'Recolección verificada exitosamente.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CollectorRouteViewModel>();
    final req = vm.request;
    final dest = LatLng(req.latitude, req.longitude);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Navegación en Ruta'),
        actions: [
          IconButton(
            tooltip: 'Recalcular ruta',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => vm.fetchRoute(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Lienzo del Mapa OSRM
          RouteNavigationMap(
            mapController: _mapController,
            destination: dest,
            collectorPos: vm.collectorPos,
            heading: vm.heading,
            polylinePoints: vm.polylinePoints,
            isLoadingRoute: vm.isLoadingRoute,
          ),

          // 2. HUD Superior de Navegación
          Positioned(
            top: 12,
            left: 14,
            right: 14,
            child: RouteHudCard(
              request: req,
              etaMinutes: vm.etaMinutes,
              distanceMeters: vm.distanceMeters,
              transportType: vm.transportType,
            ),
          ),

          // 3. Botones Flotantes Inferiores de Acción
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (vm.isGpsDisabled)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.gps_off_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'GPS desactivado. Activa la ubicación para navegar.',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LivoraColors.forest,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.verified_user_rounded),
                        label: const Text(
                          'Verificar con PIN',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        onPressed: () => _openVerificationModal(context, req),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
