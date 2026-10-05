import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../services/location_service.dart';
import '../../services/livora_realtime.dart';
import '../../widgets/active_route_hero_card.dart';
import '../../widgets/collection_request_detail_bottom_sheet.dart';
import '../../widgets/common.dart';
import '../../widgets/live_indicator.dart';
import '../../widgets/livora_map_tile_layer.dart';
import '../../widgets/collector_request_marker.dart';
import '../../widgets/livora_shimmer.dart';
import '../../widgets/livora_empty_state.dart';
import '../common/wallet_screen.dart';
import 'kyc_screen.dart';
import 'widgets/collector_first_steps_dialog.dart';
import 'widgets/collector_kyc_status_banner.dart';
import 'widgets/collector_radar_filters_bar.dart';
import 'widgets/collector_request_card.dart';

/// Pantalla principal del Recolector: Radar GPS y Solicitudes Disponibles
/// Arquitectura 'Map-Sheet' (Mapa interactivo de fondo + Panel deslizable inferior)
/// con selección ágil de pedidos, decisión en < 3s y Zero-Data-Leakage.
class AvailableRequestsScreen extends StatefulWidget {
  const AvailableRequestsScreen({super.key});

  @override
  State<AvailableRequestsScreen> createState() =>
      _AvailableRequestsScreenState();
}

class _AvailableRequestsScreenState extends State<AvailableRequestsScreen> {
  double? _userLat;
  double? _userLng;
  double _selectedRadiusKm = 5.0;
  bool _locatingGps = false;

  String? _selectedCenterId;
  bool _onlyActiveBatches = false;
  List<Batch> _openBatches = [];

  List<CollectionRequest>? _requests;
  List<CollectionRequest> _inRouteRequests = [];
  double _walletEcoBalance = 0.0;
  String? _error;
  String? _acceptingId;
  final MapController _mapController = MapController();
  StreamSubscription<Map<String, dynamic>>? _liveSubscription;
  StreamSubscription<Map<String, dynamic>>? _updateSubscription;
  int? _lastBatchesVersion;
  bool _loadInProgress = false;

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
    _initLocationAndLoad();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        CollectorFirstStepsDialog.checkAndShow(context);
      }
    });
  }

  void _subscribeRealtime() {
    final realtime = context.read<LivoraRealtime>();
    _liveSubscription = realtime
        .on(RealtimeEvents.collectionCreated)
        .listen(_onCollectionCreated);
    _updateSubscription = realtime
        .on(RealtimeEvents.collectionUpdated)
        .listen((_) {
      if (mounted && !_loadInProgress) _load();
    });
  }

  Future<void> _activateGps({bool silentIfAlreadyLocated = false}) async {
    final enabled = await LocationService.isLocationServiceEnabled();
    if (!enabled && mounted) {
      final proceed = await showLivoraDialog<bool>(
        context,
        icon: Icons.location_off_outlined,
        iconColor: LivoraColors.forest,
        title: 'GPS requerido para el radar',
        content:
            'Para calcular distancias precisas y listar solicitudes dentro de tu radio de recolección, activa el servicio de ubicación del dispositivo.',
        primaryActionLabel: 'Activar GPS',
        onPrimaryAction: () {
          Navigator.pop(context, true);
          LocationService.openLocationSettings();
        },
        secondaryActionLabel: 'Cancelar',
        onSecondaryAction: () => Navigator.pop(context, false),
      );
      if (proceed != true) return;
    }

    var permission = await LocationService.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever && mounted) {
      final openSettings = await showLivoraDialog<bool>(
        context,
        icon: Icons.settings_outlined,
        iconColor: LivoraColors.forest,
        title: 'Permiso de ubicación denegado',
        content:
            'Livora necesita acceso a tu ubicación para centrar el radar y mostrar las solicitudes cercanas a tu vehículo. Habilítalo en los ajustes de la aplicación.',
        primaryActionLabel: 'Abrir Ajustes',
        onPrimaryAction: () {
          Navigator.pop(context, true);
          LocationService.openAppSettings();
        },
        secondaryActionLabel: 'Cancelar',
        onSecondaryAction: () => Navigator.pop(context, false),
      );
      if (openSettings != true) return;
    }

    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      if (!silentIfAlreadyLocated && mounted) {
        showAppSnack(
          context,
          'Permiso de ubicación no concedido. No se puede calcular el radar.',
          error: true,
        );
      }
      return;
    }

    setState(() => _locatingGps = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (mounted) {
        if (pos != null) {
          setState(() {
            _userLat = pos.latitude;
            _userLng = pos.longitude;
          });
          _mapController.move(LatLng(pos.latitude, pos.longitude), 15.0);
          _load();
        } else if (!silentIfAlreadyLocated) {
          showAppSnack(
            context,
            'No se pudo obtener la posición GPS actual. Verifica que tu señal satelital esté activa.',
            error: true,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _locatingGps = false);
    }
  }

  Future<void> _recenterOnUser() async {
    HapticFeedback.lightImpact();
    if (_userLat != null && _userLng != null) {
      _mapController.move(LatLng(_userLat!, _userLng!), 15.0);
    }
    await _activateGps(silentIfAlreadyLocated: _userLat != null);
  }

  Future<void> _initLocationAndLoad() async {
    HapticFeedback.lightImpact();
    setState(() => _locatingGps = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (mounted && pos != null) {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _locatingGps = false);
      _load();
    }
  }

  void _onCollectionCreated(Map<String, dynamic> data) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    showAppSnack(
      context,
      '¡Nueva solicitud de reciclaje cercana en el radar!',
      actionLabel: 'Ver',
      onAction: _load,
    );
    _load();
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    _updateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    final api = context.read<LivoraApi>();
    final session = context.read<SessionController>();

    final lat = _userLat ?? -12.0464;
    final lng = _userLng ?? -77.0428;

    try {
      final Future<List<CollectionRequest>> fetchReqs;
      if (_userLat != null && _userLng != null) {
        fetchReqs = api.availableCollectionRequests(
          lat: lat,
          lng: lng,
          radiusKm: _selectedRadiusKm,
          centerId: _selectedCenterId,
          onlyActiveBatches: _onlyActiveBatches,
        );
      } else {
        fetchReqs = api.collectionRequests(lat: lat, lng: lng, radiusKm: _selectedRadiusKm);
      }

      final results = await Future.wait([
        fetchReqs,
        api.openBatches().catchError((_) => <Batch>[]),
        api.walletBalance().catchError((_) => '0.00'),
        session.refreshKycStatus(api),
      ]);

      if (!mounted) return;
      final allAvailable = results[0] as List<CollectionRequest>;
      final openBatches = results[1] as List<Batch>;
      final balanceStr = results[2] as String;
      final balanceVal = double.tryParse(balanceStr.replaceAll(',', '.')) ?? 0.0;

      final inRoute = openBatches
          .expand((b) => b.requests)
          .where((r) =>
              r.status == 'ACCEPTED' ||
              r.status == 'EN_ROUTE' ||
              r.status == 'ARRIVED')
          .toList();

      final activeAcopioIds = openBatches
          .map((b) => b.destinationCenterId)
          .whereType<String>()
          .toSet();

      List<CollectionRequest> filtered = allAvailable;
      if (_onlyActiveBatches && activeAcopioIds.isNotEmpty) {
        filtered = filtered
            .where((r) =>
                r.assignedCenterId != null &&
                activeAcopioIds.contains(r.assignedCenterId))
            .toList();
      }

      setState(() {
        _requests = filtered;
        _inRouteRequests = inRoute;
        _openBatches = openBatches;
        _walletEcoBalance = balanceVal;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron sincronizar las solicitudes');
    } finally {
      _loadInProgress = false;
    }
  }

  Future<void> _accept(CollectionRequest request) async {
    HapticFeedback.lightImpact();
    final session = context.read<SessionController>();
    if (session.kycStatus != KycStatus.approved) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const KycScreen()),
      );
      return;
    }

    final hasEnoughEscrow = _walletEcoBalance >= request.requiredEscrow;
    if (!hasEnoughEscrow && !request.isDonation) {
      _showInsufficientEscrowDialog(request);
      return;
    }

    setState(() => _acceptingId = request.id);
    try {
      await context
          .read<LivoraApi>()
          .updateCollectionStatus(request.id, 'ACCEPTED');
      if (!mounted) return;
      showAppSnack(context, '¡Solicitud asignada a tu vehículo!');
      context.read<SessionController>().notifyBatchesChanged();
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) showAppSnack(context, 'Error al aceptar la solicitud', error: true);
    } finally {
      if (mounted) setState(() => _acceptingId = null);
    }
  }

  void _showInsufficientEscrowDialog(CollectionRequest request) {
    showLivoraDialog<void>(
      context,
      icon: Icons.shield_outlined,
      iconColor: LivoraColors.blue,
      title: 'Garantía Temporal Requerida',
      content:
          'Para aceptar esta orden requieres contar con ${request.requiredEscrow.toStringAsFixed(2)} LIVO en tu billetera como garantía temporal de cumplimiento.\n\nEsta garantía se desbloquea y se te compensa en Soles (PEN) al entregar el lote en el Centro de Acopio.',
      primaryActionLabel: 'Recargar LIVO',
      primaryIcon: Icons.account_balance_wallet_outlined,
      onPrimaryAction: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
        );
      },
      secondaryActionLabel: 'Entendido',
      onSecondaryAction: () => Navigator.pop(context),
    );
  }

  void _openDetail(CollectionRequest request, KycStatus kycStatus) {
    HapticFeedback.lightImpact();
    CollectionRequestDetailBottomSheet.show(
      context,
      request: request,
      walletBalance: _walletEcoBalance,
      kycStatus: kycStatus,
      onAccept: () => _accept(request),
      onRechargeNeeded: () => _showInsufficientEscrowDialog(request),
    );
  }

  Future<void> _showReputation(BuildContext context) async {
    try {
      final rep = await context.read<LivoraApi>().collectorReputation();
      if (!context.mounted) return;
      await showLivoraDialog<void>(
        context,
        icon: Icons.star_rounded,
        iconColor: Colors.amber,
        title: 'Tu Reputación Operativa',
        bodyWidget: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  rep.score.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: LivoraColors.deep,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.star_rounded, color: Colors.amber, size: 32),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Basado en ${rep.ratingCount} calificaciones ciudadanas',
              style: const TextStyle(fontSize: 12.5, color: LivoraColors.slate),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: LivoraColors.mint.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${rep.totalPickups} servicios completados exitosamente',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: LivoraColors.forest,
                ),
              ),
            ),
          ],
        ),
        primaryActionLabel: 'Entendido',
        onPrimaryAction: () => Navigator.pop(context),
      );
    } catch (_) {
      if (context.mounted) showAppSnack(context, 'No se pudo cargar la reputación.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final currentVersion = session.batchesVersion;
    if (_lastBatchesVersion != null &&
        _lastBatchesVersion != currentVersion &&
        !_loadInProgress) {
      _lastBatchesVersion = currentVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    } else {
      _lastBatchesVersion ??= currentVersion;
    }

    final requests = _requests;
    final inRouteRequests = _inRouteRequests;
    final kycStatus = session.kycStatus;

    final centerPos = LatLng(_userLat ?? -12.0464, _userLng ?? -77.0428);

    // Marcadores para el mapa
    final markers = <Marker>[
      // Marcador de posición del recolector
      if (_userLat != null && _userLng != null)
        Marker(
          point: centerPos,
          width: 36,
          height: 36,
          child: Container(
            decoration: BoxDecoration(
              color: LivoraColors.forest,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const Icon(Icons.navigation, color: Colors.white, size: 18),
          ),
        ),

      // Marcadores de solicitudes
      if (requests != null)
        ...requests.map(
          (req) => Marker(
            point: LatLng(req.latitude, req.longitude),
            width: 44,
            height: 44,
            child: CollectorRequestMarker(
              request: req,
              onTap: () => _openDetail(req, kycStatus),
            ),
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar de Recolección'),
        actions: [
          const LiveIndicator(),
          IconButton(
            tooltip: 'Mi reputación',
            onPressed: () => _showReputation(context),
            icon: const Icon(Icons.star_outline_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. CAPA INFERIOR: Mapa Interactivo a Pantalla Completa (aislado en RepaintBoundary)
          RepaintBoundary(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: centerPos,
                initialZoom: 14.0,
                maxZoom: 18.0,
                minZoom: 10.0,
              ),
              children: [
                const LivoraMapTileLayer(),

                // Anillo de radio radar en metros
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: centerPos,
                      radius: _selectedRadiusKm * 1000,
                      useRadiusInMeter: true,
                      color: LivoraColors.forest.withValues(alpha: 0.08),
                      borderColor: LivoraColors.forest.withValues(alpha: 0.4),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),

                // Marcadores agrupados por cluster
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 45,
                    size: const Size(40, 40),
                    markers: markers,
                    builder: (context, clusterMarkers) {
                      return Container(
                        decoration: BoxDecoration(
                          color: LivoraColors.forest,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            clusterMarkers.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 2. BARRA FLOTANTE SUPERIOR: Filtros de Radio y Acopio
          Positioned(
            top: 10,
            left: 14,
            right: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarjeta de Ruta Activa (Hero Banner) si hay pedidos en curso
                if (inRouteRequests.isNotEmpty) ...[
                  ActiveRouteHeroCard(
                    requests: inRouteRequests,
                    userLat: _userLat,
                    userLng: _userLng,
                    onVerificationCompleted: _load,
                  ),
                  const SizedBox(height: 8),
                ],

                // Filtros de Radio y Acopio en contenedor semitransparente
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: CollectorRadarFiltersBar(
                    selectedRadiusKm: _selectedRadiusKm,
                    onRadiusChanged: (r) {
                      setState(() => _selectedRadiusKm = r);
                      _load();
                    },
                    selectedCenterId: _selectedCenterId,
                    onlyActiveBatches: _onlyActiveBatches,
                    openBatches: _openBatches,
                    availableRequests: requests,
                    onCenterFilterChanged: (cid, onlyBatches) {
                      setState(() {
                        _selectedCenterId = cid;
                        _onlyActiveBatches = onlyBatches;
                      });
                      _load();
                    },
                    locatingGps: _locatingGps,
                    onCalibrateGps: _activateGps,
                  ),
                ),
              ],
            ),
          ),

          // 3. BOTÓN FLOTANTE DE CENTRADO GPS
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.38 + 16,
            child: FloatingActionButton.small(
              heroTag: 'recenter_gps_fab',
              backgroundColor: Colors.white,
              foregroundColor: LivoraColors.forest,
              elevation: 3,
              tooltip: 'Centrar en mi ubicación',
              onPressed: _locatingGps ? null : _recenterOnUser,
              child: _locatingGps
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: LivoraColors.forest,
                      ),
                    )
                  : Icon(
                      _userLat != null
                          ? Icons.my_location
                          : Icons.location_searching,
                    ),
            ),
          ),

          // 4. PANEL INFERIOR DESLIZABLE (DraggableScrollableSheet - Estilo Conductor)
          DraggableScrollableSheet(
            initialChildSize: 0.38,
            minChildSize: 0.16,
            maxChildSize: 0.88,
            snap: true,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: LivoraColors.paper,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  children: [
                    // Tirador de arrastre (Grab Handle)
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cabecera: Título y Contador
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Solicitudes Disponibles',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: LivoraColors.deep,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (requests != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: LivoraColors.forest.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${requests.length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: LivoraColors.forest,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          tooltip: 'Actualizar solicitudes',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _load();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Banner de estado KYC y acceso directo (solo si no está aprobado)
                    CollectorKycStatusBanner(kycStatus: kycStatus),

                    // Estado de Carga o Lista de Tarjetas
                    if (_error != null)
                      LivoraEmptyState(
                        icon: Icons.cloud_off,
                        title: 'No se pudieron sincronizar las solicitudes',
                        message: _error!,
                        onAction: _load,
                        actionLabel: 'Reintentar',
                      )
                    else if (requests == null)
                      const LivoraShimmerList(itemCount: 4, padding: EdgeInsets.zero)
                    else if (requests.isEmpty)
                      LivoraEmptyState(
                        icon: Icons.radar_outlined,
                        title: 'No hay pedidos en este radio',
                        message:
                            'Prueba ampliando el radio a 10 km o 20 km en la barra superior. Te notificaremos cuando un hogar solicite recolección.',
                        actionLabel: 'Ampliar a 10 km',
                        onAction: () {
                          setState(() => _selectedRadiusKm = 10.0);
                          _load();
                        },
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                      )
                    else
                      ...requests.map(
                        (req) => CollectorRequestCard(
                          request: req,
                          walletBalance: _walletEcoBalance,
                          kycStatus: kycStatus,
                          accepting: _acceptingId == req.id,
                          onAccept: () => _accept(req),
                          onRechargeNeeded: () => _showInsufficientEscrowDialog(req),
                          onKycNeeded: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(builder: (_) => const KycScreen()),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
