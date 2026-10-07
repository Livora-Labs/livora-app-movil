import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../data/repositories/collection_repository.dart';
import '../../../../domain/state/ui_state.dart';
import '../../../../models/models.dart';
import '../../../../services/location_service.dart';
import '../../../../services/telemetry_service.dart';

/// ViewModel desacoplado para la consola de navegación en ruta del recolector.
class CollectorRouteViewModel extends ChangeNotifier {
  CollectorRouteViewModel({
    required CollectionRequest initialRequest,
    required CollectionRepository repository,
    required TelemetryService telemetryService,
    double? initialCollectorLat,
    double? initialCollectorLng,
  })  : _request = initialRequest,
        _repository = repository,
        _telemetryService = telemetryService,
        _state = UIState.success(initialRequest) {
    if (initialCollectorLat != null && initialCollectorLng != null) {
      _collectorPos = LatLng(initialCollectorLat, initialCollectorLng);
    }
    _init();
  }

  final CollectionRepository _repository;
  final TelemetryService _telemetryService;
  final CollectionRequest _request;
  final UIState<CollectionRequest> _state;

  LatLng? _collectorPos;
  double _heading = 0.0;
  List<LatLng> _polylinePoints = [];
  int? _etaMinutes;
  double? _distanceMeters;
  final String _transportType = 'MOTO_CARGA';
  bool _isLoadingRoute = true;
  bool _isGpsDisabled = false;
  bool _isBusy = false;
  bool _disposed = false;

  Timer? _routeRefreshTimer;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;

  CollectionRequest get request => _request;
  UIState<CollectionRequest> get state => _state;
  LatLng? get collectorPos => _collectorPos;
  double get heading => _heading;
  List<LatLng> get polylinePoints => _polylinePoints;
  int? get etaMinutes => _etaMinutes;
  double? get distanceMeters => _distanceMeters;
  String get transportType => _transportType;
  bool get isLoadingRoute => _isLoadingRoute;
  bool get isGpsDisabled => _isGpsDisabled;
  bool get isBusy => _isBusy;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _init() async {
    WakelockPlus.enable();
    _initGpsMonitoring();

    if (_collectorPos == null) {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        _collectorPos = LatLng(pos.latitude, pos.longitude);
        _heading = pos.heading;
      }
    }

    await fetchRoute();

    if (_request.status == 'EN_ROUTE') {
      _startTracking();
    }
  }

  void _initGpsMonitoring() async {
    final enabled = await LocationService.isLocationServiceEnabled();
    _isGpsDisabled = !enabled;
    _safeNotify();

    _serviceStatusSub = LocationService.getServiceStatusStream().listen((status) async {
      _isGpsDisabled = (status == ServiceStatus.disabled);
      if (!_isGpsDisabled) {
        final pos = await LocationService.getCurrentPosition();
        if (pos != null) {
          _collectorPos = LatLng(pos.latitude, pos.longitude);
          _heading = pos.heading;
          fetchRoute(silent: true);
        }
      }
      _safeNotify();
    });
  }

  void _startTracking() {
    _telemetryService.startTracking(
      requestId: _request.id,
      transportType: _transportType,
      onPositionUpdated: (pos, heading) {
        _collectorPos = pos;
        _heading = heading;

        if (_distanceMeters == null) {
          _distanceMeters = LocationService.distanceBetween(
            pos.latitude,
            pos.longitude,
            _request.latitude,
            _request.longitude,
          );
          _etaMinutes = max(1, (_distanceMeters! / 400).round());
        }
        _safeNotify();
      },
    );

    _routeRefreshTimer?.cancel();
    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_request.status == 'EN_ROUTE') {
        fetchRoute(silent: true);
      }
    });
  }

  Future<void> fetchRoute({bool silent = false}) async {
    final pos = _collectorPos;
    if (pos == null) return;
    if (!silent) {
      _isLoadingRoute = true;
      _safeNotify();
    }

    try {
      String profile = 'driving';
      if (_transportType == 'A_PIE') {
        profile = 'walking';
      } else if (_transportType == 'BICICLETA' || _transportType == 'TRICICLO') {
        profile = 'cycling';
      }

      final res = await _repository.calculateRoute(
        originLat: pos.latitude,
        originLng: pos.longitude,
        destLat: _request.latitude,
        destLng: _request.longitude,
        profile: profile,
      );

      final coordinates = res['coordinates'] as List<dynamic>?;
      if (coordinates != null && coordinates.isNotEmpty) {
        _polylinePoints = coordinates.map((c) {
          final pair = c as List<dynamic>;
          return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
        }).toList();

        if (res['distanceMeters'] != null) {
          _distanceMeters = (res['distanceMeters'] as num).toDouble();
        }
        if (res['etaMinutes'] != null) {
          _etaMinutes = (res['etaMinutes'] as num).toInt();
        }
      }
    } catch (_) {
      // Fallback a línea directa
      _polylinePoints = [pos, LatLng(_request.latitude, _request.longitude)];
    } finally {
      _isLoadingRoute = false;
      _safeNotify();
    }
  }

  Future<bool> markArrived() async {
    _isBusy = true;
    _safeNotify();
    try {
      await _repository.cancelRequest(_request.id); // O actualización de estado a ARRIVED
      _telemetryService.stopTracking();
      _isBusy = false;
      _safeNotify();
      return true;
    } catch (_) {
      _isBusy = false;
      _safeNotify();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WakelockPlus.disable();
    _serviceStatusSub?.cancel();
    _routeRefreshTimer?.cancel();
    _telemetryService.stopTracking();
    super.dispose();
  }
}
