import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/session.dart';
import '../../../../domain/repositories/i_collector_repository.dart';
import '../../../../domain/repositories/i_wallet_repository.dart';
import '../../../../domain/state/ui_state.dart';
import '../../../../models/models.dart';
import '../../../../services/livora_api.dart';
import '../../../../services/livora_realtime.dart';

/// ViewModel desacoplado para el Radar GPS y solicitudes de recolección en ruta.
/// Implementa los principios SOLID: Single Responsibility (SRP) y Dependency Inversion (DIP).
class AvailableRequestsViewModel extends ChangeNotifier {
  AvailableRequestsViewModel({
    required ICollectorRepository collectorRepository,
    required IWalletRepository walletRepository,
    required SessionController sessionController,
    LivoraApi? api,
    LivoraRealtime? realtime,
  })  : _collectorRepository = collectorRepository,
        _walletRepository = walletRepository,
        _sessionController = sessionController,
        _api = api,
        _realtime = realtime {
    _subscribeRealtime();
  }

  final ICollectorRepository _collectorRepository;
  final IWalletRepository _walletRepository;
  final SessionController _sessionController;
  final LivoraApi? _api;
  final LivoraRealtime? _realtime;

  double? _userLat;
  double? _userLng;
  double _selectedRadiusKm = 5.0;
  String? _selectedCenterId;
  bool _onlyActiveBatches = false;

  UIState<List<CollectionRequest>> _requestsState = const UIState.initial();
  List<CollectionRequest> _inRouteRequests = [];
  List<Batch> _openBatches = [];
  double _walletEcoBalance = 0.0;
  String? _acceptingId;
  bool _loadInProgress = false;

  final List<StreamSubscription> _subscriptions = [];

  // Getters
  double? get userLat => _userLat;
  double? get userLng => _userLng;
  double get selectedRadiusKm => _selectedRadiusKm;
  String? get selectedCenterId => _selectedCenterId;
  bool get onlyActiveBatches => _onlyActiveBatches;

  UIState<List<CollectionRequest>> get requestsState => _requestsState;
  List<CollectionRequest> get inRouteRequests => _inRouteRequests;
  List<Batch> get openBatches => _openBatches;
  double get walletEcoBalance => _walletEcoBalance;
  String? get acceptingId => _acceptingId;
  bool get loadInProgress => _loadInProgress;

  Set<String> get activeAcopioIds => _openBatches
      .map((b) => b.destinationCenterId)
      .whereType<String>()
      .toSet();

  void setLocation(double lat, double lng) {
    _userLat = lat;
    _userLng = lng;
    notifyListeners();
  }

  Future<void> setRadius(double radiusKm) {
    _selectedRadiusKm = radiusKm;
    notifyListeners();
    return load();
  }

  Future<void> setFilters({String? centerId, required bool onlyActiveBatches}) {
    _selectedCenterId = centerId;
    _onlyActiveBatches = onlyActiveBatches;
    notifyListeners();
    return load();
  }

  void _subscribeRealtime() {
    if (_realtime == null) return;
    _subscriptions.add(
      _realtime.on(RealtimeEvents.collectionCreated).listen((_) {
        if (!_loadInProgress) load();
      }),
    );
    _subscriptions.add(
      _realtime.on(RealtimeEvents.collectionUpdated).listen((_) {
        if (!_loadInProgress) load();
      }),
    );
  }

  /// Carga solicitudes de recolección y sincroniza lotes en curso y balance LIVO.
  Future<void> load() async {
    if (_loadInProgress) return;
    _loadInProgress = true;

    final cached = _requestsState.dataOrNull;
    _requestsState = UIState.loading(cachedData: cached);
    notifyListeners();

    final lat = _userLat ?? -12.0464;
    final lng = _userLng ?? -77.0428;

    try {
      final futures = <Future<dynamic>>[
        _collectorRepository.getAvailableRequests(
          lat: lat,
          lng: lng,
          radiusKm: _selectedRadiusKm,
          centerId: _selectedCenterId,
          onlyActiveBatches: _onlyActiveBatches,
        ),
        _collectorRepository.getOpenBatches().catchError((_) => <Batch>[]),
        _walletRepository.getBalance().catchError((_) => '0.00'),
      ];

      if (_api != null) {
        futures.add(_sessionController.refreshKycStatus(_api).catchError((_) {}));
      }

      final results = await Future.wait(futures);

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

      final filtered = allAvailable.where((r) {
        if (_selectedCenterId != null && r.assignedCenterId != _selectedCenterId) {
          return false;
        }
        if (_onlyActiveBatches && !activeAcopioIds.contains(r.assignedCenterId)) {
          return false;
        }
        return true;
      }).toList();

      _inRouteRequests = inRoute;
      _openBatches = openBatches;
      _walletEcoBalance = balanceVal;

      if (filtered.isEmpty) {
        _requestsState = const UIState.empty();
      } else {
        _requestsState = UIState.success(filtered);
      }
    } catch (e) {
      _requestsState = UIState.error(
        e.toString().replaceAll('Exception: ', ''),
        cachedData: cached,
        isNetworkError: true,
      );
    } finally {
      _loadInProgress = false;
      notifyListeners();
    }
  }

  /// Acepta una solicitud de recolección asignándola al vehículo del recolector.
  Future<bool> acceptRequest(CollectionRequest request) async {
    _acceptingId = request.id;
    notifyListeners();

    try {
      await _collectorRepository.acceptRequest(request.id);
      _sessionController.notifyBatchesChanged();
      await load();
      return true;
    } catch (_) {
      return false;
    } finally {
      _acceptingId = null;
      notifyListeners();
    }
  }

  /// Obtiene la reputación operativa del recolector.
  Future<CollectorReputation> getReputation() {
    return _collectorRepository.getReputation();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}
