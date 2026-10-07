import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livora_labs/data/repositories/auctions_repository.dart';
import 'package:livora_labs/domain/state/ui_state.dart';
import 'package:livora_labs/models/models.dart';
import 'package:livora_labs/services/livora_realtime.dart';

/// ViewModel desacoplado para la gestión de subastas y cotizaciones de Centros de Acopio.
class AuctionsViewModel extends ChangeNotifier {
  final AuctionsRepository _repository;
  final LivoraRealtime? _realtime;
  final String? _centerId;

  UIState<List<CollectionRequest>> _auctionRequestsState = const UIState.initial();
  UIState<List<CollectionRequest>> get auctionRequestsState => _auctionRequestsState;

  UIState<List<CollectionRequest>> _directRequestsState = const UIState.initial();
  UIState<List<CollectionRequest>> get directRequestsState => _directRequestsState;

  Map<String, double> _centerPriceMap = {};
  Map<String, double> get centerPriceMap => _centerPriceMap;

  String? _claimingId;
  String? get claimingId => _claimingId;

  final List<StreamSubscription> _subscriptions = [];

  AuctionsViewModel({
    required AuctionsRepository repository,
    String? centerId,
    LivoraRealtime? realtime,
  })  : _repository = repository,
        _centerId = centerId,
        _realtime = realtime {
    _initRealtime();
    loadAllRequests();
  }

  void _initRealtime() {
    if (_realtime == null) return;
    void onRefresh(_) => loadAllRequests();
    _subscriptions.add(_realtime.on(RealtimeEvents.collectionCreated).listen(onRefresh));
    _subscriptions.add(_realtime.on(RealtimeEvents.collectionUpdated).listen(onRefresh));
    _subscriptions.add(_realtime.on(RealtimeEvents.auctionBid).listen(onRefresh));
  }

  Future<void> loadAllRequests() async {
    _auctionRequestsState = const UIState.loading();
    _directRequestsState = const UIState.loading();
    notifyListeners();

    try {
      final futures = await Future.wait([
        _repository.getCollectionRequests(page: 1, limit: 50),
        _centerId != null
            ? _repository.getCenterPrices(_centerId)
            : Future.value(<AcopioPriceList>[]),
      ]);

      final all = futures[0] as List<CollectionRequest>;
      final prices = futures[1] as List<AcopioPriceList>;
      _centerPriceMap = {
        for (final p in prices) p.materialType.toUpperCase().trim(): p.pricePerKg,
      };

      final auctions = all.where((r) => r.status == 'IN_AUCTION').toList();
      final directs = all.where((r) => r.assignedCenterId == _centerId || r.status == 'CONFIRMED').toList();

      _auctionRequestsState = auctions.isEmpty ? const UIState.empty() : UIState.success(auctions);
      _directRequestsState = directs.isEmpty ? const UIState.empty() : UIState.success(directs);
    } catch (e) {
      _auctionRequestsState = UIState.error(
        e.toString().replaceAll('Exception: ', ''),
        isNetworkError: true,
      );
      _directRequestsState = UIState.error(
        e.toString().replaceAll('Exception: ', ''),
        isNetworkError: true,
      );
    } finally {
      notifyListeners();
    }
  }

  Future<void> claimRequest(String requestId) async {
    _claimingId = requestId;
    notifyListeners();
    try {
      await _repository.claimAutomatic(requestId);
      await loadAllRequests();
    } finally {
      _claimingId = null;
      notifyListeners();
    }
  }

  Future<void> placeBid(String requestId, {required Map<String, double> pricePerKg}) async {
    _claimingId = requestId;
    notifyListeners();
    try {
      await _repository.submitBid(requestId, proposedRates: pricePerKg);
      await loadAllRequests();
    } finally {
      _claimingId = null;
      notifyListeners();
    }
  }

  Future<void> withdrawBid(String requestId, String bidId) async {
    _claimingId = requestId;
    notifyListeners();
    try {
      await _repository.withdrawBid(requestId, bidId);
      await loadAllRequests();
    } finally {
      _claimingId = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
