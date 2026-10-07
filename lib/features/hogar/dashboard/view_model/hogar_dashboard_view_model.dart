import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../../core/api_client.dart';
import '../../../../core/session.dart';
import '../../../../domain/state/ui_state.dart';
import '../../../../models/models.dart';
import '../../../../services/livora_api.dart';
import '../../../../services/livora_realtime.dart';
import '../models/hogar_dashboard_data.dart';

/// ViewModel desacoplado para el Dashboard del Hogar (Clean Architecture MVVM).
/// Aísla la lógica de negocio, WebSockets reactivos, caché inmutable y estados UI.
class HogarDashboardViewModel extends ChangeNotifier {
  HogarDashboardViewModel({
    required LivoraApi api,
    required LivoraRealtime realtime,
    required SessionController session,
  })  : _api = api,
        _realtime = realtime,
        _session = session {
    _initRealtimeSubscriptions();
    _session.addListener(_onSessionChanged);
    load();
  }

  final LivoraApi _api;
  final LivoraRealtime _realtime;
  final SessionController _session;
  int _lastBatchesVersion = 0;
  String? _lastActiveRequestId;

  void _onSessionChanged() {
    bool shouldReload = false;
    if (_session.batchesVersion != _lastBatchesVersion) {
      _lastBatchesVersion = _session.batchesVersion;
      shouldReload = true;
    }
    if (_session.activeRequest?.id != _lastActiveRequestId) {
      _lastActiveRequestId = _session.activeRequest?.id;
      shouldReload = true;
    }
    if (shouldReload) {
      load(silent: true);
    }
  }

  UIState<HogarDashboardData> _state = const UIState.initial();
  UIState<HogarDashboardData> get state => _state;

  HogarDashboardData? get data => _state.dataOrNull;

  // Notificador de eventos únicos en vivo (ej. ofertas de subasta entrantes)
  final ValueNotifier<String?> liveNotificationNotifier = ValueNotifier<String?>(null);

  StreamSubscription<Map<String, dynamic>>? _bidSub;
  StreamSubscription<Map<String, dynamic>>? _collectionSub;
  StreamSubscription<Map<String, dynamic>>? _collectionCreatedSub;
  StreamSubscription<Map<String, dynamic>>? _collectorArrivedSub;
  StreamSubscription<Map<String, dynamic>>? _notificationSub;

  void _initRealtimeSubscriptions() {
    _bidSub = _realtime.on(RealtimeEvents.auctionBid).listen((payload) {
      final centerName = payload['centerName'] ?? 'Un centro de acopio';
      final penn = payload['totalEstimatedPenn'];
      final livos = payload['totalEstimatedLivo'] ?? penn;
      liveNotificationNotifier.value =
          'Nueva oferta de $centerName: $livos LIVO (≈ S/ $penn)';
      load(silent: true);
    });

    _collectionSub = _realtime.on(RealtimeEvents.collectionUpdated).listen((_) {
      load(silent: true);
    });

    _collectionCreatedSub = _realtime.on(RealtimeEvents.collectionCreated).listen((_) {
      load(silent: true);
    });

    _collectorArrivedSub = _realtime.on(RealtimeEvents.collectorArrived).listen((_) {
      load(silent: true);
    });

    _notificationSub = _realtime.on(RealtimeEvents.notificationCreated).listen((_) {
      load(silent: true);
    });
  }

  /// Carga o refresca los datos del dashboard y las solicitudes activas.
  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _state = UIState.loading(cachedData: _state.dataOrNull);
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _api.getDashboard(),
        _api.collectionRequests(),
      ]);

      final metrics = results[0] as Map<String, dynamic>? ?? {};
      final requests = (results[1] as List<CollectionRequest>?) ?? const <CollectionRequest>[];

      // Detectar solicitud activa del hogar
      CollectionRequest? activeRequest;
      for (final r in requests) {
        if (_isActiveStatus(r.status)) {
          activeRequest = r;
          break;
        }
      }

      // Sincronizar solicitud activa en la sesión global
      _session.updateActiveRequest(activeRequest);

      final consolidated = HogarDashboardData(
        metrics: metrics,
        requests: requests,
        activeRequest: activeRequest,
      );

      _state = UIState.success(consolidated);
      notifyListeners();
    } on ApiException catch (e) {
      _state = UIState.error(e.message, cachedData: _state.dataOrNull);
      notifyListeners();
    } catch (_) {
      _state = UIState.error(
        'Error al sincronizar datos del panel de reciclaje',
        cachedData: _state.dataOrNull,
      );
      notifyListeners();
    }
  }

  Future<void> refresh() => load(silent: true);

  static bool _isActiveStatus(String? status) {
    if (status == null) return false;
    return status == 'PENDING' ||
        status == 'AUCTION_ACTIVE' ||
        status == 'AUCTION_ASSIGNED' ||
        status == 'AUCTION_OPEN' ||
        status == 'ACCEPTED' ||
        status == 'ASSIGNED' ||
        status == 'EN_ROUTE' ||
        status == 'ARRIVED';
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _bidSub?.cancel();
    _collectionSub?.cancel();
    _collectionCreatedSub?.cancel();
    _collectorArrivedSub?.cancel();
    _notificationSub?.cancel();
    liveNotificationNotifier.dispose();
    super.dispose();
  }
}
