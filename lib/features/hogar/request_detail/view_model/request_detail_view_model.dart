import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/api_client.dart';
import '../../../../data/repositories/collection_repository.dart';
import '../../../../domain/state/ui_state.dart';
import '../../../../models/models.dart';
import '../../../../services/livora_realtime.dart';
import '../../../../services/location_service.dart';

/// ViewModel desacoplado para la pantalla de detalle de solicitud de recolección.
/// Centraliza el ciclo de vida, subscripciones a WebSockets, geocercas y timers,
/// exponiendo un estado inmutable UIState<CollectionRequest> a la vista.
class RequestDetailViewModel extends ChangeNotifier {
  RequestDetailViewModel({
    required this.requestId,
    required CollectionRepository repository,
    required LivoraRealtime realtime,
  })  : _repository = repository,
        _realtime = realtime {
    _init();
  }

  final String requestId;
  final CollectionRepository _repository;
  final LivoraRealtime _realtime;

  UIState<CollectionRequest> _state = const UIState.initial();
  UIState<CollectionRequest> get state => _state;

  CollectionRequest? get request => _state.dataOrNull;

  // Telemetría del Recolector en Tiempo Real
  LatLng? _collectorPos;
  LatLng? get collectorPos => _collectorPos;

  double _collectorHeading = 0.0;
  double get collectorHeading => _collectorHeading;

  int? _etaMinutes;
  int? get etaMinutes => _etaMinutes;

  double? _distanceMeters;
  double? get distanceMeters => _distanceMeters;

  String? _transportType;
  String? get transportType => _transportType;

  List<LatLng> _polylinePoints = const [];
  List<LatLng> get polylinePoints => _polylinePoints;

  // Gestión de Subastas (Bids Toast en Vivo)
  Map<String, dynamic>? _incomingBidToast;
  Map<String, dynamic>? get incomingBidToast => _incomingBidToast;

  int _bidToastSecondsLeft = 10;
  int get bidToastSecondsLeft => _bidToastSecondsLeft;

  bool _isCancelling = false;
  bool get isCancelling => _isCancelling;

  String? _selectingBidId;
  String? get selectingBidId => _selectingBidId;

  bool _geofenceAlertTriggered = false;
  bool get geofenceAlertTriggered => _geofenceAlertTriggered;

  bool _hasCelebrated = false;
  bool get hasCelebrated => _hasCelebrated;

  // Notificador para eventos únicos hacia la UI (SnackBar, Diálogo de Celebración)
  final ValueNotifier<String?> eventNotifier = ValueNotifier<String?>(null);

  // Subscripciones y Temporizadores
  StreamSubscription<Map<String, dynamic>>? _locationSub;
  StreamSubscription<Map<String, dynamic>>? _arrivedSub;
  StreamSubscription<Map<String, dynamic>>? _bidSub;
  StreamSubscription<Map<String, dynamic>>? _updateSub;

  Timer? _bidToastTimer;
  Timer? _bidCountdownTimer;
  Timer? _routeRefreshTimer;
  Timer? _staleCheckTimer;

  bool _disposed = false;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  void _init() {
    loadRequest();
    _subscribeRealtime();
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_disposed && request?.status == 'EN_ROUTE') {
        _safeNotify();
      }
    });
  }

  /// Carga la solicitud con estrategia Cache-First con SWR.
  Future<void> loadRequest({bool forceRefresh = false}) async {
    if (_state is! UISuccess) {
      _state = UIState.loading(cachedData: _state.dataOrNull);
      _safeNotify();
    }

    try {
      final req = await _repository.getRequest(requestId, forceRefresh: forceRefresh);
      _state = UIState.success(req);

      // Si el backend incluye telemetría del recolector en la respuesta
      if (req.collectorLocation != null) {
        _collectorPos = LatLng(
          req.collectorLocation!.latitude,
          req.collectorLocation!.longitude,
        );
        _collectorHeading = req.collectorLocation!.heading;
        _etaMinutes = req.collectorLocation!.etaMinutes;
        _distanceMeters = req.collectorLocation!.distanceRemainingMeters;
        _transportType = req.collectorLocation!.transportType;
      }

      // Comprobar celebración si la solicitud está completada
      if (req.status == 'COMPLETED') {
        _checkCelebration(req);
      }

      _safeNotify();
    } on ApiException catch (e) {
      _state = UIState.error(
        e.message,
        isNetworkError: e.statusCode == null,
        cachedData: _state.dataOrNull,
      );
      _safeNotify();
    } catch (_) {
      _state = UIState.error(
        'No se pudo conectar con el servidor',
        isNetworkError: true,
        cachedData: _state.dataOrNull,
      );
      _safeNotify();
    }
  }

  void _checkCelebration(CollectionRequest req) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'celebration_shown_req_$requestId';
    final alreadyCelebrated = prefs.getBool(key) ?? false;
    if (!alreadyCelebrated && !_hasCelebrated) {
      _hasCelebrated = true;
      await prefs.setBool(key, true);
      eventNotifier.value = 'SHOW_CELEBRATION';
    }
  }

  void _subscribeRealtime() {
    _locationSub = _realtime.on(RealtimeEvents.collectorLocation).listen((data) {
      if (data['requestId'] == requestId && !_disposed) {
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;
        final eta = (data['etaMinutes'] as num?)?.toInt();
        final dist = (data['distanceRemainingMeters'] as num?)?.toDouble();

        if (lat != null && lng != null) {
          final oldPos = _collectorPos;
          _collectorPos = LatLng(lat, lng);
          _collectorHeading = heading;
          _etaMinutes = eta;
          _distanceMeters = dist;
          if (data['transportType'] != null) {
            _transportType = data['transportType'] as String;
          }

          if (oldPos == null || LocationService.distanceBetween(oldPos.latitude, oldPos.longitude, lat, lng) > 30) {
            fetchOsrmRoute();
          }

          if (dist != null && dist <= 50 && !_geofenceAlertTriggered) {
            _geofenceAlertTriggered = true;
            eventNotifier.value = 'GEOFENCE_ALERT';
          }

          _safeNotify();
        }
      }
    });

    _arrivedSub = _realtime.on(RealtimeEvents.collectorArrived).listen((data) {
      if (data['requestId'] == requestId && !_disposed) {
        eventNotifier.value = 'COLLECTOR_ARRIVED';
        loadRequest(forceRefresh: true);
      }
    });

    _bidSub = _realtime.on(RealtimeEvents.auctionBid).listen((data) {
      if (data['requestId'] == requestId && !_disposed) {
        _triggerBidToast(data);
        loadRequest(forceRefresh: true);
      }
    });

    _updateSub = _realtime.on(RealtimeEvents.collectionUpdated).listen((data) {
      if (data['id'] == requestId && !_disposed) {
        loadRequest(forceRefresh: true);
      }
    });
  }

  void _triggerBidToast(Map<String, dynamic> data) {
    _bidToastTimer?.cancel();
    _bidCountdownTimer?.cancel();

    _incomingBidToast = data;
    _bidToastSecondsLeft = 10;
    _safeNotify();

    _bidCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) {
        t.cancel();
        return;
      }
      if (_bidToastSecondsLeft <= 1) {
        t.cancel();
      } else {
        _bidToastSecondsLeft--;
        _safeNotify();
      }
    });

    _bidToastTimer = Timer(const Duration(seconds: 10), () {
      if (!_disposed) {
        _incomingBidToast = null;
        _safeNotify();
      }
    });
  }

  void dismissBidToast() {
    _bidToastTimer?.cancel();
    _bidCountdownTimer?.cancel();
    _incomingBidToast = null;
    _safeNotify();
  }

  Future<void> fetchOsrmRoute() async {
    final curReq = request;
    final pos = _collectorPos;
    if (curReq == null || pos == null) return;

    try {
      String profile = 'driving';
      final transport = _transportType ?? curReq.collectorLocation?.transportType;
      if (transport == 'A_PIE') {
        profile = 'walking';
      } else if (transport == 'BICICLETA' || transport == 'TRICICLO') {
        profile = 'cycling';
      }

      final res = await _repository.calculateRoute(
        originLat: pos.latitude,
        originLng: pos.longitude,
        destLat: curReq.latitude,
        destLng: curReq.longitude,
        profile: profile,
      );

      final coordinates = res['coordinates'] as List<dynamic>?;
      if (coordinates != null && coordinates.isNotEmpty && !_disposed) {
        _polylinePoints = coordinates.map((coord) {
          final pair = coord as List<dynamic>;
          return LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          );
        }).toList();

        if (res['distanceMeters'] != null) {
          _distanceMeters = (res['distanceMeters'] as num).toDouble();
        }
        if (res['etaMinutes'] != null) {
          _etaMinutes = (res['etaMinutes'] as num).toInt();
        }
        _safeNotify();
      }
    } catch (_) {}
  }

  Future<void> cancelRequest({String? reason}) async {
    _isCancelling = true;
    _safeNotify();
    try {
      await _repository.cancelRequest(requestId, reason: reason);
      await loadRequest(forceRefresh: true);
    } finally {
      _isCancelling = false;
      _safeNotify();
    }
  }

  Future<void> editRequest({
    required Map<String, double> itemsEstimated,
    String? description,
  }) async {
    try {
      await _repository.editRequest(
        requestId,
        itemsEstimated: itemsEstimated,
        description: description,
      );
      await loadRequest(forceRefresh: true);
      eventNotifier.value = 'REQUEST_EDITED';
    } catch (e) {
      rethrow;
    }
  }

  Future<void> selectBid(String bidId) async {
    _selectingBidId = bidId;
    _safeNotify();
    try {
      await _repository.selectBid(requestId, bidId);
      await loadRequest(forceRefresh: true);
      eventNotifier.value = 'BID_SELECTED';
    } finally {
      _selectingBidId = null;
      _safeNotify();
    }
  }

  bool _isSubmittingRating = false;
  bool get isSubmittingRating => _isSubmittingRating;

  Future<void> submitRating({required int rating, String? feedback}) async {
    _isSubmittingRating = true;
    _safeNotify();
    try {
      await _repository.rateRequest(requestId, rating: rating, feedback: feedback);
      await loadRequest(forceRefresh: true);
      eventNotifier.value = 'RATING_SUBMITTED';
    } finally {
      _isSubmittingRating = false;
      _safeNotify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _locationSub?.cancel();
    _arrivedSub?.cancel();
    _bidSub?.cancel();
    _updateSub?.cancel();
    _bidToastTimer?.cancel();
    _bidCountdownTimer?.cancel();
    _routeRefreshTimer?.cancel();
    _staleCheckTimer?.cancel();
    eventNotifier.dispose();
    super.dispose();
  }
}
