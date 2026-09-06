import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../services/location_service.dart';
import '../../services/livora_realtime.dart';
import '../../widgets/active_route_hero_card.dart';
import '../../widgets/collection_request_detail_bottom_sheet.dart';
import '../../widgets/common.dart';
import '../../widgets/kyc_status_shield.dart';
import '../../widgets/live_indicator.dart';
import '../../widgets/livora_map_tile_layer.dart';
import '../../widgets/view_toggle_segmented_button.dart';
import '../../widgets/collector_request_marker.dart';
import '../../widgets/livora_shimmer.dart';
import '../../widgets/livora_empty_state.dart';
import '../common/profile.dart';
import '../common/wallet_screen.dart';
import 'kyc_screen.dart';

/// Solicitudes PENDING disponibles para el recolector con radar GPS integrado,
/// control de acceso limpio según máquina de estados KYC/Escrow,
/// tarjeta héroe En Ruta priorizada y Tap-to-Expand para detalles.
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
  bool _nearbyFilter = true;
  bool _locatingGps = false;

  String? _selectedCenterId;
  bool _onlyActiveBatches = false;
  List<Batch> _openBatches = [];

  List<CollectionRequest>? _requests;
  List<CollectionRequest> _inRouteRequests = [];
  int _currentStopIndex = 0;
  double _walletEcoBalance = 0.0;
  String? _error;
  String? _acceptingId;
  MapListViewMode _viewMode = MapListViewMode.list;
  final MapController _mapController = MapController();

  StreamSubscription<Map<String, dynamic>>? _liveSubscription;

  static const List<double> _radiusPresets = [2.0, 5.0, 10.0, 20.0];

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
    _initLocationAndLoad();
  }

  void _subscribeRealtime() {
    _liveSubscription = context
        .read<LivoraRealtime>()
        .on(RealtimeEvents.collectionCreated)
        .listen(_onCollectionCreated);
  }

  Future<void> _activateGps() async {
    final enabled = await LocationService.isLocationServiceEnabled();
    if (!enabled) {
      await LocationService.openLocationSettings();
    } else {
      final perm = await LocationService.checkPermission();
      if (perm == LocationPermission.deniedForever) {
        await LocationService.openAppSettings();
      }
    }
    await _initLocationAndLoad();
  }

  Future<void> _initLocationAndLoad() async {
    HapticFeedback.lightImpact();
    setState(() => _locatingGps = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      }
    } catch (_) {
      // Si falla el GPS, se continúa sin coordenadas para ver la lista completa
    } finally {
      if (mounted) {
        setState(() => _locatingGps = false);
        _load();
      }
    }
  }

  void _onCollectionCreated(Map<String, dynamic> data) {
    if (!mounted) return;
    _load();
    showAppSnack(context, 'Llegó una nueva solicitud al radar');
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<LivoraApi>();
    final session = context.read<SessionController>();
    final lat = (_nearbyFilter && _userLat != null) ? _userLat : null;
    final lng = (_nearbyFilter && _userLng != null) ? _userLng : null;
    final radius = _nearbyFilter ? _selectedRadiusKm : null;

    try {
      Future<List<CollectionRequest>> fetchReqs;
      if (_userLat != null && _userLng != null) {
        fetchReqs = api.availableCollectionRequests(
          lat: _userLat!,
          lng: _userLng!,
          radiusKm: radius,
          centerId: _selectedCenterId,
          onlyActiveBatches: _onlyActiveBatches ? true : null,
        );
      } else {
        fetchReqs = api.collectionRequests(lat: lat, lng: lng, radiusKm: radius);
      }

      final results = await Future.wait([
        fetchReqs,
        api.openBatches().catchError((_) => <Batch>[]),
        api.walletBalance().catchError((_) => '0.00'),
        session.refreshKycStatus(api),
      ]);

      if (!mounted) return;

      final requests = results[0] as List<CollectionRequest>;
      final openBatches = results[1] as List<Batch>;
      final balanceStr = results[2] as String;
      final balanceVal =
          double.tryParse(balanceStr.replaceAll(',', '.')) ?? 0.0;

      final activeStops = openBatches
          .expand((b) => b.requests)
          .where((r) => r.status == 'ACCEPTED' || r.status == 'IN_ROUTE')
          .toList();

      setState(() {
        _requests = requests;
        _openBatches = openBatches;
        _inRouteRequests = activeStops;
        _walletEcoBalance = balanceVal;
        _error = null;
        if (_currentStopIndex >= activeStops.length) {
          _currentStopIndex = 0;
        }
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron sincronizar las solicitudes');
      }
    }
  }

  Future<void> _accept(CollectionRequest request) async {
    HapticFeedback.lightImpact();
    final kycStatus = context.read<SessionController>().kycStatus;
    if (kycStatus != KycStatus.approved) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const KycScreen()),
      );
      return;
    }

    if (_walletEcoBalance < request.requiredEscrow) {
      _showInsufficientEscrowDialog(request);
      return;
    }

    setState(() => _acceptingId = request.id);
    try {
      await context
          .read<LivoraApi>()
          .updateCollectionStatus(request.id, 'ACCEPTED');
      if (!mounted) return;
      showAppSnack(
        context,
        'Recolección aceptada. Se fijó en tu ruta y se agregó a "Mi lote".',
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _acceptingId = null);
    }
  }

  void _showInsufficientEscrowDialog(CollectionRequest request) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 40),
        title: const Text('Garantía Temporal Insuficiente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Para aceptar esta orden requieres contar con ${request.requiredEscrow.toStringAsFixed(2)} ECO de garantía (40% Hogar + 10% Comisión Livora). Al vender el material en el centro de acopio recibirás el 100% en efectivo, recuperando tu adelanto y asegurando tu ganancia del 50%.',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tu saldo disponible:', style: TextStyle(fontSize: 12)),
                  Text(
                    '${_walletEcoBalance.toStringAsFixed(2)} ECO',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: LivoraColors.deep),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Recarga saldo al instante mediante Niubiz con tarjeta de débito/crédito (1 PEN = 1 ECO).',
              style: TextStyle(fontSize: 11.5, color: LivoraColors.slate),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: LivoraColors.blue),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              ).then((_) => _load());
            },
            icon: const Icon(Icons.credit_card, size: 18),
            label: const Text('Recargar vía Niubiz'),
          ),
        ],
      ),
    );
  }

  void _openDetail(CollectionRequest request, KycStatus kycStatus) {
    HapticFeedback.lightImpact();
    CollectionRequestDetailBottomSheet.show(
      context,
      request: request,
      walletBalance: _walletEcoBalance,
      userLat: _userLat,
      userLng: _userLng,
      kycStatus: kycStatus,
      onKycRequired: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const KycScreen()),
        );
      },
      onAccept: () => _accept(request),
      onRechargeNeeded: () => _showInsufficientEscrowDialog(request),
    );
  }

  Widget _buildFilterChipsBar(List<CollectionRequest>? requests) {
    // Extraer centros únicos disponibles
    final Map<String, ({String name, double rate})> availableCenters = {};

    if (requests != null) {
      for (final req in requests) {
        final cid = req.assignedCenterId;
        if (cid != null && cid.isNotEmpty) {
          final cName = sanitizedCenterName(
            req.assignedCenterName,
            req.assignedCenterEmail,
            defaultLabel: 'Acopio',
          );
          availableCenters[cid] = (
            name: cName,
            rate: req.averageRatePerKg,
          );
        }
      }
    }

    // También agregar centros de lotes abiertos
    for (final b in _openBatches) {
      final cid = b.destinationCenterId;
      if (cid != null && cid.isNotEmpty && !availableCenters.containsKey(cid)) {
        final cName = sanitizedCenterName(
          b.destinationCenterName,
          b.destinationCenterEmail,
          defaultLabel: 'Acopio',
        );
        availableCenters[cid] = (
          name: cName,
          rate: 1.0,
        );
      }
    }

    final isAllSelected = _selectedCenterId == null && !_onlyActiveBatches;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Chip 1: [Todos los Acopios]
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              visualDensity: VisualDensity.compact,
              label: const Text('Todos los Acopios'),
              selected: isAllSelected,
              selectedColor: LivoraColors.forest,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isAllSelected ? Colors.white : LivoraColors.deep,
              ),
              onSelected: (sel) {
                if (sel) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedCenterId = null;
                    _onlyActiveBatches = false;
                  });
                  _load();
                }
              },
            ),
          ),

          // Chip 2: [Mis Acopios en Ruta] (solo si hay lotes abiertos en el camión)
          if (_openBatches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.route_outlined, size: 14),
                label: Text('Mis Acopios en Ruta (${_openBatches.length})'),
                selected: _onlyActiveBatches,
                selectedColor: LivoraColors.forest,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _onlyActiveBatches ? Colors.white : LivoraColors.deep,
                ),
                onSelected: (sel) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _onlyActiveBatches = sel;
                    if (sel) _selectedCenterId = null;
                  });
                  _load();
                },
              ),
            ),

          // Chips individuales por Centro de Acopio con su tarifa promedio
          ...availableCenters.entries.map((entry) {
            final isCenterSelected = _selectedCenterId == entry.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: Text('${entry.value.name} · S/ ${entry.value.rate.toStringAsFixed(2)}/kg'),
                selected: isCenterSelected,
                selectedColor: LivoraColors.forest,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isCenterSelected ? Colors.white : LivoraColors.deep,
                ),
                onSelected: (sel) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedCenterId = sel ? entry.key : null;
                    _onlyActiveBatches = false;
                  });
                  _load();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = _requests;
    final inRouteRequests = _inRouteRequests;
    final kycStatus = context.select<SessionController, KycStatus>((s) => s.kycStatus);

    return Scaffold(
      appBar: livoraAppBar(
        context,
        'Solicitudes',
        actions: [
          const LiveIndicator(),
          const KycStatusShield(),
          IconButton(
            tooltip: 'Mi reputación',
            onPressed: () {
              HapticFeedback.lightImpact();
              _showReputation(context);
            },
            icon: const Icon(Icons.star_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // 1. TARJETA HÉROE EN RUTA (Fijada en la cima por encima del radar)
            if (inRouteRequests.isNotEmpty) ...[
              ActiveRouteHeroCard(
                requests: inRouteRequests,
                userLat: _userLat,
                userLng: _userLng,
                onVerificationCompleted: _load,
              ),
              const SizedBox(height: 14),
            ],

            // 2. Barra de Filtros Inteligentes por Acopio
            _buildFilterChipsBar(requests),
            const SizedBox(height: 12),

            // 2. Banner delgado informativo superior (Únicamente en estado PENDING)
            if (kycStatus == KycStatus.pending) ...[
              const _SlimKycPendingBanner(),
              const SizedBox(height: 14),
            ],

            // 3. Radar de Recolección con Control Unificado de GPS
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: LivoraColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: LivoraColors.forest.withValues(alpha: 0.12),
                          child: Icon(
                            _nearbyFilter ? Icons.near_me_rounded : Icons.explore_outlined,
                            color: LivoraColors.forest,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Radar de Recolección',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: LivoraColors.deep,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (_userLat != null && _userLng != null)
                                Text(
                                  'GPS activo · Cobertura ${_selectedRadiusKm.toInt()} km',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: LivoraColors.forest,
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    const Text(
                                      'GPS desactivado',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_locatingGps)
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: LivoraColors.forest,
                                        ),
                                      )
                                    else
                                      InkWell(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          _activateGps();
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: LivoraColors.forest.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.my_location, size: 12, color: LivoraColors.forest),
                                              SizedBox(width: 4),
                                              Text(
                                                'Activar GPS',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: LivoraColors.forest,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        if (_userLat != null && _userLng != null)
                          IconButton(
                            tooltip: 'Recalibrar GPS actual',
                            icon: _locatingGps
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location, size: 20, color: LivoraColors.forest),
                            onPressed: _locatingGps ? null : _initLocationAndLoad,
                          ),
                        Switch(
                          value: _nearbyFilter,
                          activeTrackColor: LivoraColors.forest,
                          onChanged: (val) {
                            HapticFeedback.lightImpact();
                            if (val && _userLat == null) {
                              _activateGps();
                            }
                            setState(() => _nearbyFilter = val);
                            _load();
                          },
                        ),
                      ],
                    ),
                    if (_nearbyFilter) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Radio:',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: LivoraColors.deep,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _radiusPresets.map((r) {
                                  final selected = _selectedRadiusKm == r;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text('${r.toInt()} km'),
                                      selected: selected,
                                      selectedColor: LivoraColors.forest,
                                      labelStyle: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: selected ? Colors.white : LivoraColors.deep,
                                      ),
                                      onSelected: (sel) {
                                        if (sel) {
                                          HapticFeedback.lightImpact();
                                          setState(() => _selectedRadiusKm = r);
                                          _load();
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Selector Dual: Lista vs Mapa Radar
            ViewToggleSegmentedButton(
              selectedMode: _viewMode,
              onChanged: (mode) => setState(() => _viewMode = mode),
            ),
            const SizedBox(height: 10),

            if (_error != null)
              EmptyState(
                icon: Icons.cloud_off,
                title: 'No se pudieron cargar las solicitudes',
                message: _error,
              )
            else if (requests == null)
              const LivoraShimmerList(
                itemCount: 4,
                padding: EdgeInsets.zero,
              )
            else if (_viewMode == MapListViewMode.map) ...[
              _buildRadarMap(requests, kycStatus),
            ] else if (requests.isEmpty)
              const LivoraEmptyState(
                icon: Icons.travel_explore_rounded,
                title: 'No hay solicitudes pendientes',
                message:
                    'Desliza hacia abajo para actualizar o amplía el radio del radar.',
                padding: EdgeInsets.fromLTRB(24, 24, 24, 40),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Disponibles en el área (${requests.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: LivoraColors.deep,
                      ),
                    ),
                    const Text(
                      'Toca para ver detalle',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: LivoraColors.forest,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              for (final request in requests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AvailableCard(
                    request: request,
                    walletBalance: _walletEcoBalance,
                    kycStatus: kycStatus,
                    accepting: _acceptingId == request.id,
                    onDetail: () => _openDetail(request, kycStatus),
                    onAccept: () => _accept(request),
                    onRechargeNeeded: () => _showInsufficientEscrowDialog(request),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRadarMap(List<CollectionRequest> requests, KycStatus kycStatus) {
    final centerLat = _userLat ?? -12.0864;
    final centerLng = _userLng ?? -77.0351;
    final centerPoint = LatLng(centerLat, centerLng);

    final validRequests = requests.where((r) => r.latitude != 0 && r.longitude != 0).toList();

    return Container(
      height: 440,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LivoraColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: centerPoint,
              initialZoom: _getZoomForRadius(_selectedRadiusKm),
              maxZoom: 18,
              minZoom: 9,
            ),
            children: [
              const LivoraMapTileLayer(),

              // Círculo de cobertura del radar
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: centerPoint,
                    radius: _selectedRadiusKm * 1000,
                    useRadiusInMeter: true,
                    color: LivoraColors.forest.withValues(alpha: 0.12),
                    borderColor: LivoraColors.forest.withValues(alpha: 0.6),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),

              // Marcador de posición del Recolector y solicitudes
              MarkerLayer(
                markers: [
                  Marker(
                    point: centerPoint,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: LivoraColors.blue.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: LivoraColors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: LivoraColors.blue.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_pin_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  ...validRequests.map(
                    (req) => Marker(
                      point: LatLng(req.latitude, req.longitude),
                      width: 86,
                      height: 68,
                      child: CollectorRequestMarker(
                        request: req,
                        onTap: () => _openDetail(req, kycStatus),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Botón flotante para recentrar GPS
          Positioned(
            top: 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'recenter_collector_map_fab',
              backgroundColor: Colors.white,
              foregroundColor: LivoraColors.forest,
              elevation: 3,
              onPressed: () {
                HapticFeedback.lightImpact();
                if (_userLat != null && _userLng != null) {
                  _mapController.move(centerPoint, _getZoomForRadius(_selectedRadiusKm));
                } else {
                  _activateGps();
                }
              },
              child: const Icon(Icons.my_location_rounded, size: 20),
            ),
          ),

          // Atribución legal de OpenStreetMap
          const Positioned(
            bottom: 0,
            right: 0,
            child: OsmAttributionWidget(),
          ),
        ],
      ),
    );
  }

  double _getZoomForRadius(double radiusKm) {
    if (radiusKm <= 2.0) return 14.5;
    if (radiusKm <= 5.0) return 13.0;
    if (radiusKm <= 10.0) return 11.8;
    return 10.5;
  }

  Future<void> _showReputation(BuildContext context) async {
    final api = context.read<LivoraApi>();
    try {
      final reputation = await api.collectorReputation();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.star, color: Color(0xFFE0A400), size: 36),
          title: Text('Reputación: ${reputation.score}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InfoRow(
                label: 'Recolecciones',
                value: '${reputation.totalPickups}',
              ),
              InfoRow(
                label: 'Calificaciones',
                value: '${reputation.ratingCount}',
              ),
              InfoRow(
                label: 'Insignia',
                value: reputation.badge == 'VERIFIED_COLLECTOR'
                    ? 'Recolector verificado'
                    : reputation.badge,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (context.mounted) showAppSnack(context, error.message, error: true);
    }
  }
}

/// Banner delgado informativo superior exclusivo para estado PENDING
class _SlimKycPendingBanner extends StatelessWidget {
  const _SlimKycPendingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, size: 18, color: Color(0xFF1D4ED8)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Documentos en proceso de validación',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const KycScreen()),
              );
            },
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                'Ver estado',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D4ED8),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



/// Tarjeta de solicitud disponible con Tap-to-Expand para detalle completo
/// y reacción limpia de máquina de estados (UNVERIFIED, PENDING, INSUFFICIENT_BALANCE, APPROVED).
class _AvailableCard extends StatelessWidget {
  const _AvailableCard({
    required this.request,
    required this.walletBalance,
    required this.kycStatus,
    required this.accepting,
    required this.onDetail,
    required this.onAccept,
    required this.onRechargeNeeded,
  });

  final CollectionRequest request;
  final double walletBalance;
  final KycStatus kycStatus;
  final bool accepting;
  final VoidCallback onDetail;
  final VoidCallback onAccept;
  final VoidCallback onRechargeNeeded;

  @override
  Widget build(BuildContext context) {
    final distance = request.distanceMeters;
    final hasEnoughEscrow = walletBalance >= request.requiredEscrow;

    final householdLabel = sanitizedPersonName(
      request.householdName,
      request.householdEmail,
      defaultLabel: 'Hogar',
    );
    final householdAddress = request.householdAddress?.isNotEmpty == true
        ? request.householdAddress!
        : 'Dirección física registrada vía GPS';
    final centerLabel = sanitizedCenterName(
      request.assignedCenterName,
      request.assignedCenterEmail,
      defaultLabel: 'Centro de Acopio Asignado',
    );

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: LivoraColors.border),
      ),
      child: InkWell(
        onTap: onDetail,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (request.photoUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: request.photoUrl!,
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: 600,
                    memCacheHeight: 400,
                    placeholder: (context, url) => Container(
                      height: 130,
                      color: LivoraColors.forest.withValues(alpha: 0.08),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 130,
                      color: LivoraColors.paper,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: LivoraColors.ink,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      materialsSummary(request.itemsEstimated),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (distance != null)
                    StatusChip(
                      label: '${(distance / 1000).toStringAsFixed(1)} km',
                      color: LivoraColors.blue,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (request.description?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    request.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: LivoraColors.ink,
                    ),
                  ),
                ),

              // Formateo del Hogar (Nombre, Dirección y Fecha)
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: LivoraColors.forest),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$householdLabel · $householdAddress',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LivoraColors.deep,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 19),
                child: Text(
                  'Publicado: ${fmtDate(request.createdAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: LivoraColors.ink.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Badge destacado con el Nombre del Centro de Acopio Comprador y su tarifa por kg
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: LivoraColors.mint.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront, size: 15, color: LivoraColors.forest),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$centerLabel · S/ ${request.averageRatePerKg.toStringAsFixed(2)}/kg',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.forest,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Caja de Desglose Financiero Claro y Garantía Escrow
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Margen Neto Recolector (50%):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: LivoraColors.deep,
                          ),
                        ),
                        Text(
                          'S/ ${request.collectorMarginPEN.toStringAsFixed(2)} PEN',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: LivoraColors.forest,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFBFDBFE)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Garantía requerida en EcoTokens:',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: LivoraColors.deep,
                              ),
                            ),
                            Text(
                              '40% Hogar + 10% Comisión Livora',
                              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                        Text(
                          '${request.requiredEscrow.toStringAsFixed(2)} ECO',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: LivoraColors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // CTA Adaptativo según Jerarquía y Máquina de Estados
              SizedBox(
                width: double.infinity,
                child: _buildCardCta(context, hasEnoughEscrow),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardCta(BuildContext context, bool hasEnoughEscrow) {
    if (kycStatus == KycStatus.unverified) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          backgroundColor: const Color(0xFFD97706),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const KycScreen()),
          );
        },
        icon: const Icon(Icons.shield_outlined, size: 18),
        label: const Text(
          'Verificar Identidad para Aceptar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }

    if (kycStatus == KycStatus.pending) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          backgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.grey.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: null,
        icon: const Icon(Icons.hourglass_top_rounded, size: 18),
        label: const Text(
          'Verificación en Revisión',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }

    if (kycStatus == KycStatus.rejected) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          backgroundColor: const Color(0xFFC0392B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const KycScreen()),
          );
        },
        icon: const Icon(Icons.gpp_bad_rounded, size: 18),
        label: const Text(
          'Reintentar Verificación',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }

    // kycStatus == KycStatus.approved
    if (hasEnoughEscrow) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          backgroundColor: LivoraColors.forest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: accepting ? null : onAccept,
        icon: accepting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle_outline, size: 18),
        label: Text(
          accepting ? 'Aceptando…' : 'Aceptar Recolección',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    } else {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          backgroundColor: const Color(0xFFD97706),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          onRechargeNeeded();
        },
        icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
        label: const Text(
          'Saldo insuficiente (Recargar por Niubiz)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }
  }
}
