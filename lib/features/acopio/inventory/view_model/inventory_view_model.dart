import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livora_labs/data/repositories/inventory_repository.dart';
import 'package:livora_labs/domain/state/ui_state.dart';
import 'package:livora_labs/models/models.dart';
import 'package:livora_labs/services/livora_realtime.dart';

/// ViewModel desacoplado para el control de stock, Kárdex y transferencias B2B.
class InventoryViewModel extends ChangeNotifier {
  final InventoryRepository _repository;
  final LivoraRealtime? _realtime;
  final String _centerId;

  UIState<List<InventoryItem>> _itemsState = const UIState.initial();
  UIState<List<InventoryItem>> get itemsState => _itemsState;

  UIState<List<B2bTransfer>> _transfersState = const UIState.initial();
  UIState<List<B2bTransfer>> get transfersState => _transfersState;

  int _selectedSegment = 0; // 0: Stock, 1: Despachos B2B
  int get selectedSegment => _selectedSegment;

  final List<StreamSubscription> _subscriptions = [];

  InventoryViewModel({
    required InventoryRepository repository,
    required String centerId,
    LivoraRealtime? realtime,
    bool canRegisterSale = false,
  })  : _repository = repository,
        _centerId = centerId,
        _realtime = realtime {
    _initRealtime(canRegisterSale);
    loadInventory();
    if (canRegisterSale) loadTransfers();
  }

  void _initRealtime(bool canRegisterSale) {
    if (_realtime == null) return;
    void onRefresh(_) {
      loadInventory(forceRefresh: true);
      if (canRegisterSale) loadTransfers();
    }
    _subscriptions.add(_realtime.on(RealtimeEvents.batchCompleted).listen(onRefresh));
    _subscriptions.add(_realtime.on(RealtimeEvents.batchUpdated).listen(onRefresh));
    _subscriptions.add(_realtime.on(RealtimeEvents.batchDispatched).listen(onRefresh));
  }

  void setSegment(int index) {
    if (_selectedSegment == index) return;
    _selectedSegment = index;
    notifyListeners();
  }

  double get totalKg =>
      (_itemsState.dataOrNull ?? []).fold(0.0, (sum, item) => sum + item.quantityKg);

  Future<void> loadInventory({bool forceRefresh = false}) async {
    final cached = _itemsState.dataOrNull;
    _itemsState = UIState.loading(cachedData: cached);
    notifyListeners();

    try {
      final items = await _repository.getInventory(_centerId, forceRefresh: forceRefresh);
      if (items.isEmpty) {
        _itemsState = const UIState.empty();
      } else {
        _itemsState = UIState.success(items);
      }
    } catch (e) {
      _itemsState = UIState.error(
        e.toString().replaceAll('Exception: ', ''),
        cachedData: cached,
        isNetworkError: true,
      );
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadTransfers() async {
    final cached = _transfersState.dataOrNull;
    _transfersState = UIState.loading(cachedData: cached);
    notifyListeners();

    try {
      final transfers = await _repository.getB2bTransfers();
      if (transfers.isEmpty) {
        _transfersState = const UIState.empty();
      } else {
        _transfersState = UIState.success(transfers);
      }
    } catch (e) {
      _transfersState = UIState.error(
        e.toString().replaceAll('Exception: ', ''),
        cachedData: cached,
        isNetworkError: true,
      );
    } finally {
      notifyListeners();
    }
  }

  Future<void> acceptTransfer(String transferId, {
    required Map<String, double> materialsReceived,
    String? notes,
  }) async {
    await _repository.acceptTransfer(transferId, actualMaterials: materialsReceived, notes: notes);
    await loadInventory(forceRefresh: true);
    await loadTransfers();
  }

  Future<List<InventoryMovement>> getKardex(String materialCode) {
    return _repository.getMovements(materialType: materialCode);
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
