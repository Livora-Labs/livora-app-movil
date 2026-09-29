import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../services/location_service.dart';
import '../../widgets/common.dart';
import '../../widgets/livora_map_tile_layer.dart';
import '../../widgets/verification_otp_modal.dart';
import 'widgets/collector_incident_dialog.dart';

/// Consola de Navegación Vehicular Turn-by-Turn para el Recolector.
///
/// Consume el proxy backend OSRM (/api/v1/routing/route), renderiza la polilínea
/// de aproximación, actualiza la telemetría en tiempo real (10-15s) y gestiona
/// el ciclo de vida del sensor GPS (encendido en EN_ROUTE, apagado en ARRIVED).
class CollectorActiveRouteScreen extends StatefulWidget {
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
  State<CollectorActiveRouteScreen> createState() =>
      _CollectorActiveRouteScreenState();
}

class _CollectorActiveRouteScreenState extends State<CollectorActiveRouteScreen> {
  final MapController _mapController = MapController();

  late CollectionRequest _request;
  LatLng? _collectorPos;
  double _heading = 0.0;
  List<LatLng> _polylinePoints = [];

  bool _loadingRoute = true;
  bool _busy = false;
  int? _etaMinutes;
  double? _distanceMeters;
  bool _isFallback = false;
  bool _isGpsDisabled = false;

  Timer? _routeRefreshTimer;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;
  String _transportType = 'MOTO_CARGA';

  @override
  void initState() {
    super.initState();
    // Prevenir que la pantalla se apague mientras el recolector conduce en ruta
    WakelockPlus.enable();
    _request = widget.request;

    if (widget.initialCollectorLat != null && widget.initialCollectorLng != null) {
      _collectorPos = LatLng(
        widget.initialCollectorLat!,
        widget.initialCollectorLng!,
      );
    }

    _initNavigation();
    _initGpsStatusMonitoring();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _serviceStatusSub?.cancel();
    _routeRefreshTimer?.cancel();
    LocationService.stopCollectorTracking();
    super.dispose();
  }

  Future<void> _initGpsStatusMonitoring() async {
    final enabled = await LocationService.isLocationServiceEnabled();
    if (mounted) {
      setState(() => _isGpsDisabled = !enabled);
    }
    _serviceStatusSub = LocationService.getServiceStatusStream().listen((status) async {
      if (!mounted) return;
      final disabled = (status == ServiceStatus.disabled);
      setState(() => _isGpsDisabled = disabled);
      if (!disabled) {
        // Al reanudar el GPS, recuperar posición actual y recalcular ruta de inmediato
        final pos = await LocationService.getCurrentPosition();
        if (pos != null && mounted) {
          setState(() {
            _collectorPos = LatLng(pos.latitude, pos.longitude);
            _heading = pos.heading;
          });
          _fetchOsrmRoute(silent: true);
        }
      }
    });
  }

  Future<void> _initNavigation() async {
    // 0. Sincronizar estado fresco de la solicitud y KYC del recolector
    try {
      final api = context.read<LivoraApi>();
      final fresh = await api.collectionRequestDetail(_request.id);
      if (mounted) {
        setState(() {
          _request = fresh;
        });
      }
      final kyc = await api.kycApplication();
      if (kyc.transportType != null && mounted) {
        setState(() {
          _transportType = kyc.transportType!;
        });
      }
    } catch (_) {}

    // 1. Obtener posición GPS actual si no se proporcionó
    if (_collectorPos == null) {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() {
          _collectorPos = LatLng(pos.latitude, pos.longitude);
          _heading = pos.heading;
        });
      } else {
        // Fallback a última posición conocida del hardware o backend
        final lastKnown = await LocationService.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          setState(() {
            _collectorPos = LatLng(lastKnown.latitude, lastKnown.longitude);
            _heading = lastKnown.heading;
          });
        } else if (_request.collectorLocation != null && mounted) {
          final loc = _request.collectorLocation!;
          setState(() {
            _collectorPos = LatLng(loc.latitude, loc.longitude);
            _heading = loc.heading;
          });
        }
      }
    }

    // 2. Trazar ruta hacia el destino
    await _fetchOsrmRoute();

    // 3. Si la orden ya está EN_ROUTE, activar sensor de fondo inmediatamente
    if (_request.status == 'EN_ROUTE') {
      _startTrackingLifecycle();
    }
  }

  void _startTrackingLifecycle() {
    final api = context.read<LivoraApi>();

    // Velocidad promedio por medio de transporte (metros/minuto) para fallback
    final speedFactor = switch (_transportType) {
      'A_PIE' => 70,
      'TRICICLO' => 183,
      'BICICLETA' => 250,
      'CAMIONETA' => 500,
      _ => 400,
    };

    LocationService.startCollectorTracking(
      requestId: _request.id,
      api: api,
      getRouteTelemetry: () => {
        'distanceRemainingMeters': _distanceMeters,
        'etaMinutes': _etaMinutes?.toDouble(),
        'transportType': _transportType,
      },
      onPositionUpdate: (Position pos) {
        if (!mounted) return;
        setState(() {
          _collectorPos = LatLng(pos.latitude, pos.longitude);
          _heading = pos.heading;

          // Si aún no tenemos distancia de OSRM o estamos en fallback, calculamos estimado
          if (_distanceMeters == null || _isFallback) {
            _distanceMeters = LocationService.distanceBetween(
              pos.latitude,
              pos.longitude,
              _request.latitude,
              _request.longitude,
            );
            _etaMinutes = max(1, (_distanceMeters! / speedFactor).round());
          }
        });
      },
    );

    // Refresco periódico de ruta completa cada 60s
    _routeRefreshTimer?.cancel();
    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_request.status == 'EN_ROUTE') {
        _fetchOsrmRoute(silent: true);
      }
    });
  }

  Future<void> _fetchOsrmRoute({bool silent = false}) async {
    if (_collectorPos == null) return;
    if (!silent) setState(() => _loadingRoute = true);

    String profile = 'driving';
    if (_transportType == 'A_PIE') {
      profile = 'walking';
    } else if (_transportType == 'BICICLETA' || _transportType == 'TRICICLO') {
      profile = 'cycling';
    }

    try {
      final res = await context.read<LivoraApi>().calculateRoute(
            originLat: _collectorPos!.latitude,
            originLng: _collectorPos!.longitude,
            destLat: _request.latitude,
            destLng: _request.longitude,
            profile: profile,
          );

      final geometry = res['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'] as List<dynamic>?;

      if (coords != null && coords.isNotEmpty && mounted) {
        final points = coords.map((c) {
          final pair = c as List<dynamic>;
          return LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          );
        }).toList();

        setState(() {
          _polylinePoints = points;
          _distanceMeters = (res['distanceMeters'] as num?)?.toDouble();
          _etaMinutes = (res['etaMinutes'] as num?)?.toInt();
          _isFallback = res['isFallback'] == true;
          _loadingRoute = false;
        });

        // Centrar mapa encuadrando ambos puntos
        _fitBounds();

        // Precarga de teselas offline para navegación resiliente en zonas sin cobertura
        LivoraMapTileLayer.prefetchCorridor(points);
      }
    } catch (e) {
      debugPrint('[CollectorRoute] Error calculando ruta OSRM: $e');
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  void _fitBounds() {
    if (_collectorPos == null) return;
    final dest = LatLng(_request.latitude, _request.longitude);
    final bounds = LatLngBounds.fromPoints([_collectorPos!, dest]);
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(top: 80, bottom: 260, left: 40, right: 40),
        ),
      );
    } catch (_) {}
  }

  Future<bool> _ensureGpsAndPermission({
    required String title,
    required String reason,
  }) async {
    final isGpsOn = await LocationService.isLocationServiceEnabled();
    if (!isGpsOn) {
      if (!mounted) return false;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.location_off_outlined, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            reason,
            style: const TextStyle(fontSize: 14, color: LivoraColors.slate),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: LivoraColors.forest),
              onPressed: () {
                Navigator.pop(ctx, true);
                LocationService.openLocationSettings();
              },
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Activar GPS'),
            ),
          ],
        ),
      );
      if (proceed != true) return false;
    }

    var permission = await LocationService.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await LocationService.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.settings_outlined, color: LivoraColors.forest),
              SizedBox(width: 8),
              Text('Permiso de Ubicación', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Livora necesita acceso a la ubicación para calcular la ruta en vivo y transmitir la telemetría al hogar. Por favor, habilítalo en los ajustes.',
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
                LocationService.openAppSettings();
              },
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Abrir Ajustes'),
            ),
          ],
        ),
      );
      return false;
    }

    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      if (mounted) {
        showAppSnack(context, 'Permiso de ubicación denegado.', error: true);
      }
      return false;
    }

    return true;
  }

  Future<void> _onRecenterPressed() async {
    HapticFeedback.lightImpact();
    if (_collectorPos != null) {
      _fitBounds();
      return;
    }

    final hasGpsAndPerm = await _ensureGpsAndPermission(
      title: 'GPS Desactivado',
      reason: 'El servicio de ubicación (GPS) está desactivado. Actívalo para posicionar tu vehículo y calcular la ruta hacia el domicilio.',
    );
    if (!hasGpsAndPerm) return;

    final pos = await LocationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _collectorPos = LatLng(pos.latitude, pos.longitude);
        _heading = pos.heading;
      });
      _fetchOsrmRoute(silent: true);
      _fitBounds();
    } else if (mounted) {
      showAppSnack(context, 'Esperando señal satelital GPS...', error: true);
    }
  }

  Future<void> _startRoute() async {
    final hasGpsAndPerm = await _ensureGpsAndPermission(
      title: 'GPS Requerido',
      reason: 'Para iniciar el viaje vehicular debes tener activado el GPS en tu dispositivo. De esta forma el hogar podrá ver tu llegada en tiempo real.',
    );
    if (!hasGpsAndPerm) return;

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      final updated = await context.read<LivoraApi>().startRoute(_request.id);
      if (mounted) {
        setState(() {
          _request = updated;
          _busy = false;
        });
        showAppSnack(context, '¡Viaje iniciado! El Hogar ahora visualiza tu aproximación.');
        _startTrackingLifecycle();
        context.read<SessionController>().notifyBatchesChanged();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        if (e.message.contains('EN_ROUTE')) {
          // Si ya estaba EN_ROUTE, sincronizar y arrancar tracking
          _initNavigation();
          showAppSnack(context, 'Ruta ya activa. Telemetría transmitiéndose al Hogar.');
        } else {
          showAppSnack(context, e.message, error: true);
        }
      }
    }
  }

  Future<void> _confirmArrival() async {
    HapticFeedback.heavyImpact();
    setState(() => _busy = true);
    try {
      final updated = await context.read<LivoraApi>().confirmArrival(_request.id);
      // Detener sensor GPS de inmediato por privacidad y batería
      LocationService.stopCollectorTracking();
      WakelockPlus.disable();
      _routeRefreshTimer?.cancel();

      if (mounted) {
        setState(() {
          _request = updated;
          _busy = false;
        });
        showAppSnack(
          context,
          'Llegada registrada. El sensor GPS se ha apagado. Solicita el PIN de validación.',
        );
        context.read<SessionController>().notifyBatchesChanged();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAppSnack(context, e.message, error: true);
      }
    }
  }

  Future<void> _openVerificationModal() async {
    final verified = await VerificationOtpModal.show(
      context,
      request: _request,
    );
    if (verified == true && mounted) {
      showAppSnack(context, '¡Recolección validada exitosamente!');
      Navigator.pop(context, true); // Vuelve al radar
    }
  }

  Future<void> _openExternalMap() async {
    final lat = _request.latitude;
    final lng = _request.longitude;
    final uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final fallback = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) showAppSnack(context, 'No se pudo abrir app externa de mapas');
    }
  }

  Future<void> _callHousehold() async {
    final phone = _request.householdPhone;
    if (phone == null || phone.trim().isEmpty) {
      showAppSnack(context, 'El hogar no tiene número telefónico registrado.');
      return;
    }
    final uri = Uri.parse('tel:${phone.trim()}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) showAppSnack(context, 'No se pudo abrir el discador.');
      }
    } catch (_) {
      if (mounted) showAppSnack(context, 'Error al intentar realizar la llamada.');
    }
  }

  Future<void> _openIncidentModal() async {
    final resolved = await CollectorIncidentDialog.show(context, request: _request);
    if (resolved == true && mounted) {
      context.read<SessionController>().notifyBatchesChanged();
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dest = LatLng(_request.latitude, _request.longitude);
    final isEnRoute = _request.status == 'EN_ROUTE';
    final isArrived = _request.status == 'ARRIVED';
    final isAccepted = _request.status == 'ACCEPTED';

    final distKmStr = _distanceMeters != null
        ? (_distanceMeters! >= 1000
            ? '${(_distanceMeters! / 1000).toStringAsFixed(1)} km'
            : '${_distanceMeters!.round()} m')
        : '--';

    final isWithin50m = _distanceMeters != null && _distanceMeters! <= 50;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        context.read<SessionController>().notifyBatchesChanged();
      },
      child: Scaffold(
        body: Stack(
          children: [
          // 1. Lienzo de Mapa OSRM (aislado en RepaintBoundary)
          RepaintBoundary(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _collectorPos ?? dest,
                initialZoom: 15.5,
                maxZoom: 19,
                minZoom: 11,
              ),
              children: [
                const LivoraMapTileLayer(),

                // Geocerca de arribo (50 metros alrededor del hogar)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: dest,
                      radius: 50,
                      useRadiusInMeter: true,
                      color: LivoraColors.forest.withValues(alpha: 0.15),
                      borderColor: LivoraColors.forest,
                      borderStrokeWidth: 2.0,
                    ),
                  ],
                ),

                // Polilínea de ruta OSRM
                if (_polylinePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _polylinePoints,
                        color: _isFallback
                            ? Colors.orange.shade700
                            : const Color(0xFF2E7D32),
                        strokeWidth: 5.0,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ),

                // Marcadores (Recolector y Hogar)
                MarkerLayer(
                  markers: [
                    // Pin del Hogar
                    Marker(
                      point: dest,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFFC53030),
                        size: 44,
                      ),
                    ),

                    // Marcador Vehicular del Recolector con Heading
                    if (_collectorPos != null)
                      Marker(
                        point: _collectorPos!,
                        width: 44,
                        height: 44,
                        child: Transform.rotate(
                          angle: _heading * (pi / 180),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.navigation,
                              color: Color(0xFF2E7D32),
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Barra Superior de Control
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: LivoraColors.deep),
                        onPressed: () {
                          context.read<SessionController>().notifyBatchesChanged();
                          Navigator.pop(context, true);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isArrived
                                  ? Icons.check_circle
                                  : isEnRoute
                                      ? Icons.directions_bike
                                      : Icons.access_time,
                              color: isArrived
                                  ? LivoraColors.forest
                                  : isEnRoute
                                      ? LivoraColors.blue
                                      : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isArrived
                                    ? 'En Domicilio'
                                    : isEnRoute
                                        ? 'En Tránsito hacia el Hogar'
                                        : 'Preparado para Salida',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: LivoraColors.deep,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_loadingRoute)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        tooltip: 'Recentrar ruta',
                        icon: const Icon(Icons.my_location, color: LivoraColors.deep),
                        onPressed: _onRecenterPressed,
                      ),
                    ),
                  ],
                ),
                if (_isGpsDisabled) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_off_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'GPS desactivado · Actívalo para continuar navegando',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => LocationService.openLocationSettings(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFDC2626),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'ACTIVAR',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 3. Consola Flotante Inferior de Conducción Profesional
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Card(
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Fila 1: ETA + Distancia + Llamada Telefónica + GPS Externo
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: LivoraColors.forest.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time_filled,
                                size: 16,
                                color: LivoraColors.forest,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _etaMinutes != null ? '$_etaMinutes min' : '-- min',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: LivoraColors.forest,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: LivoraColors.paper,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            distKmStr,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: LivoraColors.deep,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Spacer(),

                        // Botón de Llamada Telefónica Nativa al Hogar
                        IconButton.filledTonal(
                          tooltip: 'Llamar al Hogar',
                          style: IconButton.styleFrom(
                            backgroundColor: LivoraColors.forest.withValues(alpha: 0.12),
                            foregroundColor: LivoraColors.forest,
                          ),
                          icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                          onPressed: _callHousehold,
                        ),
                        const SizedBox(width: 6),

                        // Botón de Navegación Externa (Google Maps / Waze)
                        IconButton.filledTonal(
                          tooltip: 'Abrir en Google Maps / Waze',
                          style: IconButton.styleFrom(
                            backgroundColor: LivoraColors.blue.withValues(alpha: 0.1),
                            foregroundColor: LivoraColors.blue,
                          ),
                          icon: const Icon(Icons.open_in_new, size: 20),
                          onPressed: _openExternalMap,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Fila 2: Resumen Visual de Materiales a Recoger
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: LivoraColors.mint.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.recycling_rounded, size: 16, color: LivoraColors.forest),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'A recoger: ${materialsSummary(_request.itemsEstimated)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: LivoraColors.forest,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Destino y Contacto
                    Text(
                      _request.householdAddress ?? 'Dirección fijada vía GPS',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Contacto: ${_request.householdName ?? 'Hogar'} · Solicitud #${_request.shortId}',
                      style: const TextStyle(fontSize: 12, color: LivoraColors.slate),
                    ),
                    const SizedBox(height: 16),

                    // Botón Primario según Estado
                    if (isAccepted) ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: LivoraColors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _busy ? null : _startRoute,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.navigation_rounded),
                        label: const Text(
                          'INICIAR VIAJE HACIA EL DOMICILIO',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ] else if (isEnRoute) ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: isWithin50m
                              ? const Color(0xFF2E7D32)
                              : LivoraColors.forest,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _busy ? null : _confirmArrival,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          isWithin50m
                              ? '¡LLEGUÉ AL DOMICILIO! (< 50m)'
                              : 'LLEGUÉ AL DOMICILIO',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ] else if (isArrived) ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: LivoraColors.forest,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _openVerificationModal,
                        icon: const Icon(Icons.pin),
                        label: const Text(
                          'INGRESAR CÓDIGO PIN DEL HOGAR',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),

                    // Botón Secundario: Reportar Incidencia / No responde
                    Center(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: LivoraColors.slate,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.report_problem_outlined, size: 16),
                        label: const Text(
                          'Reportar problema en ruta (Hogar ausente / Cancelar)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: _busy ? null : _openIncidentModal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
